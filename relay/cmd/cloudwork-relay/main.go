package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/cloudwork/cloudwork-relay/internal/hub"
	"github.com/cloudwork/cloudwork-relay/internal/push"
	"github.com/fatih/color"
)

func main() {
	portFlag := flag.Int("port", 9289, "中继服务器监听端口 (默认 9289)")
	webhookFlag := flag.String("webhook", "", "可选的第三方推送 Webhook 通知地址")
	flag.Parse()

	port := *portFlag
	if envPort := os.Getenv("PORT"); envPort != "" {
		fmt.Sscanf(envPort, "%d", &port)
	}

	relayHub := hub.NewHub()
	pushSvc := push.NewMockPushService(*webhookFlag)

	// 1. WebSocket 隧道
	http.HandleFunc("/v1/tunnel", relayHub.HandleTunnel)

	// 2. 健康检查
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]string{
			"status":  "healthy",
			"service": "cloudwork-relay",
		})
	})

	// 3. 实时中继统计
	http.HandleFunc("/stats", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(relayHub.GetStats())
	})

	// 4. 推送接口
	http.HandleFunc("/v1/push", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
			return
		}
		var payload push.NotificationPayload
		if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		_ = pushSvc.Send(&payload)
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"success":true}`))
	})

	color.Green("==========================================================")
	color.Green("   🌐 CloudWork Open-Source E2EE Relay Server")
	color.Green("==========================================================")
	color.Cyan("  ✓ 隧道接口: ws://0.0.0.0:%d/v1/tunnel", port)
	color.Cyan("  ✓ 健康检查: http://0.0.0.0:%d/health", port)
	color.Cyan("  ✓ 状态监控: http://0.0.0.0:%d/stats", port)
	color.White("  🔒 架构声明: 本中继服务仅做端到端加密密文转发，零知识存储\n")

	addr := fmt.Sprintf("0.0.0.0:%d", port)
	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatalf("Relay server failed: %v", err)
	}
}
