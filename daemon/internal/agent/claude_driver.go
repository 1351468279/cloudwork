package agent

import (
	"fmt"
	"os/exec"
	"regexp"
	"strings"
	"time"

	"github.com/cloudwork/cloudwork-daemon/internal/config"
)

// ClaudeCodeDriver Claude Code (@anthropic-ai/claude-code) 专属驱动
type ClaudeCodeDriver struct {
	approvalRegex *regexp.Regexp
	toolCallRegex *regexp.Regexp
}

func NewClaudeCodeDriver() *ClaudeCodeDriver {
	return &ClaudeCodeDriver{
		approvalRegex: regexp.MustCompile(`(?i)(Do you want to run|Allow|approve|\[y/N\]|\[Y/n\])`),
		toolCallRegex: regexp.MustCompile(`(?i)Running (bash command|tool):\s*(.+)`),
	}
}

func (d *ClaudeCodeDriver) Name() string {
	return "Anthropic Claude Code"
}

func (d *ClaudeCodeDriver) Type() string {
	return "claude"
}

// Detect 检测本地系统是否已安装 claude
func (d *ClaudeCodeDriver) Detect() bool {
	_, err := exec.LookPath("claude")
	return err == nil
}

// BuildCommand 构造启动命令
func (d *ClaudeCodeDriver) BuildCommand(prompt string, model string, workingDir string) (string, []string) {
	args := []string{}
	if model != "" {
		args = append(args, "--model", model)
	}
	if prompt != "" {
		args = append(args, "-p", prompt)
	}
	return "claude", args
}

// BuildEnvironment 动态注入 NewAPI / OneAPI 或官方环境变量
func (d *ClaudeCodeDriver) BuildEnvironment(station *config.APIStation) []string {
	env := []string{}
	if station == nil {
		return env
	}

	if station.BaseURL != "" {
		// 标准 Claude Code 代理端点环境变量
		baseURL := strings.TrimSuffix(station.BaseURL, "/")
		env = append(env, fmt.Sprintf("ANTHROPIC_BASE_URL=%s", baseURL))
	}
	if station.APIKey != "" {
		env = append(env, fmt.Sprintf("ANTHROPIC_API_KEY=%s", station.APIKey))
	}
	// 禁用交互式动画以优化流式传输
	env = append(env, "NO_COLOR=0")
	return env
}

// ProcessOutput 分析输出流并识别审批和工具调用状态
func (d *ClaudeCodeDriver) ProcessOutput(rawOutput string) []*AgentEvent {
	var events []*AgentEvent
	now := time.Now().Unix()

	// 识别是否进入审批等待阶段
	if d.approvalRegex.MatchString(rawOutput) {
		toolName := "Command Execution"
		command := ""
		matches := d.toolCallRegex.FindStringSubmatch(rawOutput)
		if len(matches) > 2 {
			command = strings.TrimSpace(matches[2])
		}

		events = append(events, &AgentEvent{
			AgentType: d.Type(),
			Type:      EventToolCallRequest,
			Status:    StatusAwaitingApproval,
			Message:   "Claude Code 请求执行命令，等待手机端授权",
			ToolCall: &ToolCallPayload{
				ToolID:      fmt.Sprintf("tool_%d", now),
				ToolName:    toolName,
				Command:     command,
				Description: rawOutput,
			},
			RawOutput: rawOutput,
			Timestamp: now,
		})
	} else {
		// 普通输出事件
		events = append(events, &AgentEvent{
			AgentType: d.Type(),
			Type:      EventStdOutput,
			Status:    StatusThinking,
			RawOutput: rawOutput,
			Timestamp: now,
		})
	}

	return events
}
