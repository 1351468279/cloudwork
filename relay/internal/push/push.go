package push

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"
)

// NotificationPayload 手机系统推送通知载荷
type NotificationPayload struct {
	DeviceToken string `json:"device_token"`
	Title       string `json:"title"`       // e.g. "CloudWork 审批提醒"
	Body        string `json:"body"`        // e.g. "Claude Code 正在请求执行命令：npm test"
	SessionID   string `json:"session_id"`
	Type        string `json:"type"`        // "approval", "finished", "error"
}

// Service 推送服务接口
type Service interface {
	Send(p *NotificationPayload) error
}

// MockPushService 开发与自建测试默认使用的推送服务实现
type MockPushService struct {
	WebhookURL string
}

func NewMockPushService(webhook string) *MockPushService {
	return &MockPushService{WebhookURL: webhook}
}

func (s *MockPushService) Send(p *NotificationPayload) error {
	log.Printf("🔔 [系统推送] 标题: %s | 内容: %s (目标Token: %s)\n", p.Title, p.Body, p.DeviceToken)

	if s.WebhookURL != "" {
		data, _ := json.Marshal(p)
		client := &http.Client{Timeout: 5 * time.Second}
		_, err := client.Post(s.WebhookURL, "application/json", bytes.NewReader(data))
		if err != nil {
			return fmt.Errorf("webhook push failed: %w", err)
		}
	}
	return nil
}
