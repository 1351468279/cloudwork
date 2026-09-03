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

// ProcessOutput 分析输出流（结构化 JSONL 优雅提取，杜绝生硬的 JSON 源码泄漏）
func (d *CodexDriver) ProcessOutput(rawOutput string) []*AgentEvent {
	var events []*AgentEvent
	now := time.Now().Unix()

	lines := strings.Split(rawOutput, "\n")
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" {
			continue
		}

		// 尝试解析 JSONL 结构化事件
		var jsonEvent map[string]interface{}
		if err := json.Unmarshal([]byte(trimmed), &jsonEvent); err == nil {
			t, _ := jsonEvent["type"].(string)

			switch t {
			case "thread.started":
				events = append(events, &AgentEvent{
					AgentType: d.Type(),
					Type:      EventStatusChange,
					Status:    StatusThinking,
					Message:   "🧵 任务会话已拉起，Codex 正在初始化上下文...",
					Timestamp: now,
				})
			case "turn.started":
				events = append(events, &AgentEvent{
					AgentType: d.Type(),
					Type:      EventThinking,
					Status:    StatusThinking,
					Message:   "Codex 正在深度思考与规划...",
					Timestamp: now,
				})
			case "item.started":
				if item, ok := jsonEvent["item"].(map[string]interface{}); ok {
					itemType, _ := item["type"].(string)
					if itemType == "command_execution" {
						cmd, _ := item["command"].(string)
						cleanCmd := prettifyCommand(cmd)
						events = append(events, &AgentEvent{
							AgentType: d.Type(),
							Type:      EventToolCallStart,
							Status:    StatusExecutingTool,
							Message:   cleanCmd,
							ToolCall: &ToolCallPayload{
								ToolName: "Bash",
								Command:  cleanCmd,
							},
							Timestamp: now,
						})
					}
				}
			case "item.completed":
				if item, ok := jsonEvent["item"].(map[string]interface{}); ok {
					itemType, _ := item["type"].(string)
					if itemType == "agent_message" {
						if text, ok := item["text"].(string); ok && text != "" {
							events = append(events, &AgentEvent{
								AgentType: d.Type(),
								Type:      EventAgentMessage,
								Status:    StatusThinking,
								Message:   text,
								RawOutput: text,
								Timestamp: now,
							})
						}
					} else if itemType == "command_execution" {
						output, _ := item["aggregated_output"].(string)
						cmd, _ := item["command"].(string)
						cleanCmd := prettifyCommand(cmd)
						events = append(events, &AgentEvent{
							AgentType: d.Type(),
							Type:      EventToolCallEnd,
							Status:    StatusThinking,
							Message:   cleanCmd,
							RawOutput: strings.TrimSpace(output),
							Timestamp: now,
						})
					}
				}
			case "turn.completed":
				usageMsg := "✅ Codex 任务处理完毕！"
				if usage, ok := jsonEvent["usage"].(map[string]interface{}); ok {
					inTokens, _ := usage["input_tokens"].(float64)
					outTokens, _ := usage["output_tokens"].(float64)
					if inTokens > 0 || outTokens > 0 {
						usageMsg = fmt.Sprintf("✅ Codex 任务处理完毕 (消耗 Token: 输入 %.0f / 输出 %.0f)", inTokens, outTokens)
					}
				}
				events = append(events, &AgentEvent{
					AgentType: d.Type(),
					Type:      EventStatusChange,
					Status:    StatusCompleted,
					Message:   usageMsg,
					Timestamp: now,
				})
			}
			// 结构化 JSON 识别完毕后不再向下当普通文本泄露
			continue
		}

		// 过滤底层 CLI 引擎噪音（如启动日志、内部模型获取报错、JSON dump 等）
		if strings.HasPrefix(trimmed, "Reading additional input") ||
			strings.Contains(trimmed, "codex_models_manager") ||
			strings.Contains(trimmed, "failed to refresh available models") ||
			(strings.HasPrefix(trimmed, "{") && strings.Contains(trimmed, "gpt-")) {
			continue
		}

		// 文本正则匹配审批
		if d.approvalRegex.MatchString(trimmed) {
			events = append(events, &AgentEvent{
				AgentType: d.Type(),
				Type:      EventToolCallRequest,
				Status:    StatusAwaitingApproval,
				Message:   "Codex 请求执行命令授权",
				ToolCall: &ToolCallPayload{
					ToolID:      fmt.Sprintf("codex_tool_%d", now),
					ToolName:    "Command Execution",
					Command:     trimmed,
					Description: trimmed,
				},
				RawOutput: trimmed,
				Timestamp: now,
			})
		} else {
			// 普通控制台纯文本输出
			events = append(events, &AgentEvent{
				AgentType: d.Type(),
				Type:      EventStdOutput,
				Status:    StatusThinking,
				RawOutput: trimmed,
				Message:   trimmed,
				Timestamp: now,
			})
		}
	}

	return events
}

func prettifyCommand(cmd string) string {
	trimmed := strings.TrimSpace(cmd)
	// 去除 powershell 冗长全路径与参数
	rePs := regexp.MustCompile(`(?i)^"?[A-Z]:\\Windows\\System32\\WindowsPowerShell\\v1\.0\\powershell(\.exe)?"?\s+(-(NoProfile|NonInteractive|ExecutionPolicy\s+\w+|Command)\s+)*`)
	if rePs.MatchString(trimmed) {
		trimmed = rePs.ReplaceAllString(trimmed, "powershell ")
	}
	reCmd := regexp.MustCompile(`(?i)^"?[A-Z]:\\Windows\\System32\\cmd(\.exe)?"?\s+(/c\s+)*`)
	if reCmd.MatchString(trimmed) {
		trimmed = reCmd.ReplaceAllString(trimmed, "cmd ")
	}
	// 去除多余包装双引号
	trimmed = strings.Trim(trimmed, `"'`)
	return trimmed
}
