package session

import (
	"fmt"
	"sync"
	"time"

	"github.com/cloudwork/cloudwork-daemon/internal/agent"
	"github.com/cloudwork/cloudwork-daemon/internal/config"
	"github.com/cloudwork/cloudwork-daemon/internal/pty"
	"github.com/google/uuid"
)

// SessionState 运行时会话状态
type SessionState struct {
	ID         string            `json:"id"`
	AgentType  string            `json:"agent_type"`
	AgentName  string            `json:"agent_name"`
	Prompt     string            `json:"prompt"`
	Model      string            `json:"model"`
	StationID  string            `json:"station_id"`
	StationName string           `json:"station_name"`
	WorkingDir string            `json:"working_dir"`
	Status     agent.AgentStatus `json:"status"`
	CreatedAt  int64             `json:"created_at"`
	Process    *pty.ProcessSession `json:"-"`
	Driver     agent.AgentDriver `json:"-"`
}

// Manager 会话调度中心
type Manager struct {
	cfg        *config.DaemonConfig
	registry   *agent.Registry
	sessions   map[string]*SessionState
	mu         sync.RWMutex
	Broadcast  func(event *agent.AgentEvent)
}

func NewManager(cfg *config.DaemonConfig, registry *agent.Registry, broadcast func(*agent.AgentEvent)) *Manager {
	return &Manager{
		cfg:       cfg,
		registry:  registry,
		sessions:  make(map[string]*SessionState),
		Broadcast: broadcast,
	}
}

// StartSession 启动一个新 Agent 会话并自动注入对应中转站环境变量
func (m *Manager) StartSession(agentType string, prompt string, model string, stationID string, workingDir string) (*SessionState, error) {
	driver := m.registry.Get(agentType)
	if driver == nil {
		return nil, fmt.Errorf("agent driver not found: %s", agentType)
	}

	// 智能路由中转站
	var station *config.APIStation
	if stationID != "" {
		station = m.cfg.GetStationByID(stationID)
	}
	if station == nil {
		station = m.cfg.FindStationForModel(model)
	}

	sessionID := "sess_" + uuid.New().String()[:8]
	cmdName, args := driver.BuildCommand(prompt, model, workingDir)
	env := driver.BuildEnvironment(station)

	stationName := "Default/Local"
	if station != nil {
		stationName = station.Name
	}

	sess := &SessionState{
		ID:          sessionID,
		AgentType:   driver.Type(),
		AgentName:   driver.Name(),
		Prompt:      prompt,
		Model:       model,
		StationID:   stationID,
		StationName: stationName,
		WorkingDir:  workingDir,
		Status:      agent.StatusThinking,
		CreatedAt:   time.Now().Unix(),
		Driver:      driver,
	}

	// 启动子进程与管道监听
	proc, err := pty.StartProcess(
		sessionID,
		cmdName,
		args,
		workingDir,
		env,
		func(rawOutput string) {
			m.handleProcessOutput(sess, rawOutput)
		},
		func(exitCode int) {
			m.handleProcessExit(sess, exitCode)
		},
	)
	if err != nil {
		return nil, fmt.Errorf("failed to start agent process: %w", err)
	}

	sess.Process = proc

	// 对于通过参数携带 prompt 启动的命令（如 claude -p / codex exec），关闭 stdin 避免其等待 3 秒标准输入
	if prompt != "" {
		_ = proc.CloseStdin()
	}

	m.mu.Lock()
	m.sessions[sessionID] = sess
	m.mu.Unlock()

	// 广播会话创建事件
	if m.Broadcast != nil {
		m.Broadcast(&agent.AgentEvent{
			SessionID: sessionID,
			AgentType: driver.Type(),
			Type:      agent.EventStatusChange,
			Status:    agent.StatusThinking,
			Message:   "会话已启动，正在电脑端执行任务...",
			Timestamp: time.Now().Unix(),
		})
	}

	return sess, nil
}

func (m *Manager) handleProcessOutput(sess *SessionState, rawOutput string) {
	events := sess.Driver.ProcessOutput(rawOutput)
	for _, ev := range events {
		ev.SessionID = sess.ID
		if ev.Status != "" {
			sess.Status = ev.Status
		}
		if m.Broadcast != nil {
			m.Broadcast(ev)
		}
	}
}

func (m *Manager) handleProcessExit(sess *SessionState, exitCode int) {
	m.mu.Lock()
	if exitCode == 0 {
		sess.Status = agent.StatusCompleted
	} else {
		sess.Status = agent.StatusFailed
	}
	m.mu.Unlock()

	if m.Broadcast != nil {
		m.Broadcast(&agent.AgentEvent{
			SessionID: sess.ID,
			AgentType: sess.AgentType,
			Type:      agent.EventSessionFinished,
			Status:    sess.Status,
			Message:   fmt.Sprintf("Agent 任务已结束 (退出码: %d)", exitCode),
			Timestamp: time.Now().Unix(),
		})
	}
}

// ApproveTool 手机端一键同意执行命令
func (m *Manager) ApproveTool(sessionID string) error {
	m.mu.RLock()
	sess, ok := m.sessions[sessionID]
	m.mu.RUnlock()

	if !ok || sess.Process == nil {
		return fmt.Errorf("session not found: %s", sessionID)
	}
	return sess.Process.SendInput("y\n")
}

// RejectTool 手机端拒绝执行命令
func (m *Manager) RejectTool(sessionID string) error {
	m.mu.RLock()
	sess, ok := m.sessions[sessionID]
	m.mu.RUnlock()

	if !ok || sess.Process == nil {
		return fmt.Errorf("session not found: %s", sessionID)
	}
	return sess.Process.SendInput("n\n")
}

// SendInput 发送普通文本/Prompt 指令
func (m *Manager) SendInput(sessionID string, input string) error {
	m.mu.RLock()
	sess, ok := m.sessions[sessionID]
	m.mu.RUnlock()

	if !ok || sess.Process == nil {
		return fmt.Errorf("session not found: %s", sessionID)
	}
	if !inputHasNewline(input) {
		input += "\n"
	}
	return sess.Process.SendInput(input)
}

func inputHasNewline(s string) bool {
	return len(s) > 0 && (s[len(s)-1] == '\n' || s[len(s)-1] == '\r')
}

// TerminateSession 终止会话
func (m *Manager) TerminateSession(sessionID string) error {
	m.mu.RLock()
	sess, ok := m.sessions[sessionID]
	m.mu.RUnlock()

	if !ok || sess.Process == nil {
		return fmt.Errorf("session not found: %s", sessionID)
	}
	return sess.Process.Terminate()
}

// ListSessions 获取所有活动会话快照
func (m *Manager) ListSessions() []*SessionState {
	m.mu.RLock()
	defer m.mu.RUnlock()

	list := make([]*SessionState, 0, len(m.sessions))
	for _, s := range m.sessions {
		list = append(list, s)
	}
	return list
}
