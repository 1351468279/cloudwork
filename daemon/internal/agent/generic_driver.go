package agent

import (
	"fmt"
	"regexp"
	"runtime"
	"time"

	"github.com/cloudwork/cloudwork-daemon/internal/config"
)

// GenericCLIDriver 通用 CLI 驱动
type GenericCLIDriver struct {
	approvalRegex *regexp.Regexp
}

func NewGenericCLIDriver() *GenericCLIDriver {
	return &GenericCLIDriver{
		approvalRegex: regexp.MustCompile(`(?i)(\[y/n\]|\(y/n\)|Press Enter|Proceed\?|password:)`),
	}
}

func (d *GenericCLIDriver) Name() string {
	return "Generic CLI Tool"
}

func (d *GenericCLIDriver) Type() string {
	return "generic"
}

func (d *GenericCLIDriver) Detect() bool {
	return true
}

func (d *GenericCLIDriver) BuildCommand(prompt string, model string, workingDir string) (string, []string) {
	if runtime.GOOS == "windows" {
		return "cmd.exe", []string{"/C", prompt}
	}
	return "bash", []string{"-c", prompt}
}

func (d *GenericCLIDriver) BuildEnvironment(station *config.APIStation) []string {
	env := []string{}
	if station != nil {
		if station.BaseURL != "" {
			env = append(env, fmt.Sprintf("OPENAI_BASE_URL=%s", station.BaseURL))
			env = append(env, fmt.Sprintf("ANTHROPIC_BASE_URL=%s", station.BaseURL))
		}
		if station.APIKey != "" {
			env = append(env, fmt.Sprintf("OPENAI_API_KEY=%s", station.APIKey))
			env = append(env, fmt.Sprintf("ANTHROPIC_API_KEY=%s", station.APIKey))
		}
	}
	return env
}

func (d *GenericCLIDriver) ProcessOutput(rawOutput string) []*AgentEvent {
	var events []*AgentEvent
	now := time.Now().Unix()

	if d.approvalRegex.MatchString(rawOutput) {
		events = append(events, &AgentEvent{
			AgentType: d.Type(),
			Type:      EventToolCallRequest,
			Status:    StatusAwaitingApproval,
			Message:   "终端等待用户输入确认",
			ToolCall: &ToolCallPayload{
				ToolName:    "Prompt Input",
				Description: rawOutput,
			},
			RawOutput: rawOutput,
			Timestamp: now,
		})
	} else {
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
