package agent

import (
	"fmt"
	"os/exec"
	"regexp"
	"strings"
	"time"

	"github.com/cloudwork/cloudwork-daemon/internal/config"
)

// AiderDriver Aider (aider-chat) 专属驱动
type AiderDriver struct {
	approvalRegex *regexp.Regexp
}

func NewAiderDriver() *AiderDriver {
	return &AiderDriver{
		approvalRegex: regexp.MustCompile(`(?i)(Apply edit\?|Run command\?|\[y/n\])`),
	}
}

func (d *AiderDriver) Name() string {
	return "Aider"
}

func (d *AiderDriver) Type() string {
	return "aider"
}

func (d *AiderDriver) Detect() bool {
	_, err := exec.LookPath("aider")
	return err == nil
}

func (d *AiderDriver) BuildCommand(prompt string, model string, workingDir string) (string, []string) {
	args := []string{"--no-auto-commits"}
	if model != "" {
		args = append(args, "--model", model)
	}
	if prompt != "" {
		args = append(args, "--message", prompt)
	}
	return "aider", args
}

func (d *AiderDriver) BuildEnvironment(station *config.APIStation) []string {
	env := []string{}
	if station == nil {
		return env
	}

	if station.BaseURL != "" {
		baseURL := strings.TrimSuffix(station.BaseURL, "/")
		env = append(env, fmt.Sprintf("OPENAI_API_BASE=%s", baseURL))
	}
	if station.APIKey != "" {
		env = append(env, fmt.Sprintf("OPENAI_API_KEY=%s", station.APIKey))
		env = append(env, fmt.Sprintf("ANTHROPIC_API_KEY=%s", station.APIKey))
	}
	return env
}

func (d *AiderDriver) ProcessOutput(rawOutput string) []*AgentEvent {
	var events []*AgentEvent
	now := time.Now().Unix()

	if d.approvalRegex.MatchString(rawOutput) {
		events = append(events, &AgentEvent{
			AgentType: d.Type(),
			Type:      EventToolCallRequest,
			Status:    StatusAwaitingApproval,
			Message:   "Aider 请求修改/命令确认",
			ToolCall: &ToolCallPayload{
				ToolName:    "Apply Changes",
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
