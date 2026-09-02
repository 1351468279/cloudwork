package agent

import (
	"github.com/cloudwork/cloudwork-daemon/internal/config"
)

// EventType 定义 Agent 触发给手机端的结构化事件类型
type EventType string

const (
	EventStatusChange    EventType = "status_change"     // 状态变更: IDLE, THINKING, EXECUTING, AWAITING_APPROVAL
	EventToolCallRequest EventType = "tool_call_request" // 触发工具调用请求（等待手机审批）
	EventFileDiff        EventType = "file_diff"         // 文件变更 Diff
	EventStdOutput       EventType = "std_output"        // 终端标准输出流
	EventSessionFinished EventType = "session_finished"  // 任务完成
	EventError           EventType = "error"             // 报错提醒
)

// AgentStatus Agent 运行状态
type AgentStatus string

const (
	StatusIdle             AgentStatus = "idle"
	StatusThinking         AgentStatus = "thinking"
	StatusExecutingTool    AgentStatus = "executing_tool"
	StatusAwaitingApproval AgentStatus = "awaiting_approval"
	StatusCompleted        AgentStatus = "completed"
	StatusFailed           AgentStatus = "failed"
)

// ToolCallPayload 工具调用结构（供手机端一键审批）
type ToolCallPayload struct {
	ToolID      string `json:"tool_id"`
	ToolName    string `json:"tool_name"`    // e.g. "Bash", "EditFile", "ReadFile"
	Command     string `json:"command"`      // e.g. "npm test", "git commit -m ..."
	FilePath    string `json:"file_path"`    // e.g. "src/app.ts"
	Description string `json:"description"`  // 为什么执行该操作
	Diff        string `json:"diff,omitempty"` // 修改的 patch 内容
}

// AgentEvent 手机端接收到的结构化统一事件
type AgentEvent struct {
	SessionID string           `json:"session_id"`
	AgentType string           `json:"agent_type"` // "claude", "codex", "aider", "generic"
	Type      EventType        `json:"type"`
	Status    AgentStatus      `json:"status"`
	Message   string           `json:"message,omitempty"`
	ToolCall  *ToolCallPayload `json:"tool_call,omitempty"`
	RawOutput string           `json:"raw_output,omitempty"`
	Timestamp int64            `json:"timestamp"`
}

// AgentDriver 所有 Agent 驱动必须实现的统一接口
type AgentDriver interface {
	Name() string
	Type() string
	Detect() bool
	BuildCommand(prompt string, model string, workingDir string) (string, []string)
	BuildEnvironment(station *config.APIStation) []string
	ProcessOutput(rawOutput string) []*AgentEvent
}
