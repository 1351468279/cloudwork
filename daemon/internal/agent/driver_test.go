package agent

import (
	"testing"

	"github.com/cloudwork/cloudwork-daemon/internal/config"
)

func TestClaudeDriverEnvAndApproval(t *testing.T) {
	driver := NewClaudeCodeDriver()

	// 测试环境变量动态注入
	station := &config.APIStation{
		Name:    "Test NewAPI",
		Type:    config.StationNewAPI,
		BaseURL: "https://api.test-newapi.com/v1",
		APIKey:  "sk-test-key",
	}

	env := driver.BuildEnvironment(station)
	foundBaseURL := false
	foundKey := false
	for _, e := range env {
		if e == "ANTHROPIC_BASE_URL=https://api.test-newapi.com/v1" {
			foundBaseURL = true
		}
		if e == "ANTHROPIC_API_KEY=sk-test-key" {
			foundKey = true
		}
	}
	if !foundBaseURL || !foundKey {
		t.Fatalf("Claude driver failed to inject NewAPI env vars correctly: %v", env)
	}

	// 测试审批捕获
	sampleOutput := "Running bash command: npm run test\nDo you want to run this command? [y/N]"
	events := driver.ProcessOutput(sampleOutput)
	if len(events) == 0 {
		t.Fatalf("Expected event from Claude output")
	}

	hasApproval := false
	for _, ev := range events {
		if ev.Type == EventToolCallRequest && ev.Status == StatusAwaitingApproval {
			hasApproval = true
		}
	}
	if !hasApproval {
		t.Fatalf("Failed to detect awaiting approval status in Claude output")
	}
}

func TestCodexDriverEnvAndApproval(t *testing.T) {
	driver := NewCodexDriver()

	station := &config.APIStation{
		Name:    "Test OpenAI Relay",
		Type:    config.StationNewAPI,
		BaseURL: "https://api.openai-relay.com/v1",
		APIKey:  "sk-openai-test-key",
	}

	env := driver.BuildEnvironment(station)
	foundKey := false
	for _, e := range env {
		if e == "OPENAI_API_KEY=sk-openai-test-key" {
			foundKey = true
		}
	}
	if !foundKey {
		t.Fatalf("Codex driver failed to inject OPENAI_API_KEY: %v", env)
	}
}
