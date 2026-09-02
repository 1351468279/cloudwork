package agent

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"regexp"
	"strings"
	"time"

	"github.com/cloudwork/cloudwork-daemon/internal/config"
)

// CodexDriver OpenAI Codex CLI (@openai/codex) 专属驱动
type CodexDriver struct {
	approvalRegex *regexp.Regexp
	patchRegex    *regexp.Regexp
}

func NewCodexDriver() *CodexDriver {
	return &CodexDriver{
		approvalRegex: regexp.MustCompile(`(?i)(Approval required|Permission requested|Run command\?|\[y/N\])`),
		patchRegex:    regexp.MustCompile(`(?i)(Applying diff to|Modifying file)\s+(.+)`),
	}
}

func (d *CodexDriver) Name() string {
	return "OpenAI Codex CLI"
}

func (d *CodexDriver) Type() string {
	return "codex"
}

func (d *CodexDriver) Detect() bool {
	_, err := exec.LookPath("codex")
	return err == nil
}

// BuildCommand 构造启动命令：使用 exec 子命令支持非交互与标准输入流
func (d *CodexDriver) BuildCommand(prompt string, model string, workingDir string) (string, []string) {
	args := []string{"exec", "--skip-git-repo-check", "--json"}
	if model != "" {
		args = append(args, "--model", model)
	}
	if prompt != "" {
		args = append(args, prompt)
	}
	return "codex", args
}

// BuildEnvironment 动态注入 OpenAI/NewAPI 环境变量
func (d *CodexDriver) BuildEnvironment(station *config.APIStation) []string {
	env := []string{}
	if station == nil {
		return env
	}

	if station.APIKey != "" {
		env = append(env, fmt.Sprintf("OPENAI_API_KEY=%s", station.APIKey))
	}
	return env
}

// ProcessOutput 分析输出流（支持 JSONL 结构化解析与文本兜底）
func (d *CodexDriver) ProcessOutput(rawOutput string) []*AgentEvent {
	var events []*AgentEvent
	now := time.Now().Unix()

	lines := strings.Split(rawOutput, "\n")
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" {
			continue
		}

		// 尝试解析 JSONL 事件
		var jsonEvent map[string]interface{}
		if err := json.Unmarshal([]byte(trimmed), &jsonEvent); err == nil {
			evType := StatusThinking
			msg := ""
			t, _ := jsonEvent["type"].(string)

			switch t {
			case "thread.started":
				msg = "🧵 任务线程已创建"
			case "turn.started":
				msg = "⚡ Codex 正在思考与分析需求..."
			case "item.completed":
				if item, ok := jsonEvent["item"].(map[string]interface{}); ok {
					itemType, _ := item["type"].(string)
					if itemType == "agent_message" {
						if text, ok := item["text"].(string); ok {
							msg = text
						}
					}
				}
			case "turn.completed":
				evType = StatusCompleted
				msg = "✅ Codex 任务处理完成！"
			}

			if msg == "" {
				msg = trimmed
			}

			events = append(events, &AgentEvent{
				AgentType: d.Type(),
				Type:      EventStdOutput,
				Status:    evType,
				Message:   msg,
				RawOutput: line,
				Timestamp: now,
			})
			continue
		}

		// 文本正则匹配审批
		if d.approvalRegex.MatchString(trimmed) {
			events = append(events, &AgentEvent{
				AgentType: d.Type(),
				Type:      EventToolCallRequest,
				Status:    StatusAwaitingApproval,
				Message:   "Codex 请求沙箱命令执行授权",
				ToolCall: &ToolCallPayload{
					ToolID:      fmt.Sprintf("codex_tool_%d", now),
					ToolName:    "Sandbox Execution",
					Description: trimmed,
				},
				RawOutput: trimmed,
				Timestamp: now,
			})
		} else {
			events = append(events, &AgentEvent{
				AgentType: d.Type(),
				Type:      EventStdOutput,
				Status:    StatusThinking,
				RawOutput: trimmed,
				Timestamp: now,
			})
		}
	}

	if len(events) == 0 && rawOutput != "" {
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
