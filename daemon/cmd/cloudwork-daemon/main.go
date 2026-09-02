package main

import (
	"encoding/json"
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/cloudwork/cloudwork-daemon/internal/agent"
	"github.com/cloudwork/cloudwork-daemon/internal/config"
	"github.com/cloudwork/cloudwork-daemon/internal/security"
	"github.com/cloudwork/cloudwork-daemon/internal/ws"
	"github.com/fatih/color"
)

func main() {
	portFlag := flag.Int("port", 0, "自定义本地监听端口 (默认读取配置 9288)")
	flag.Parse()

	// 1. 读取或初始化本地配置
	cfg, err := config.LoadConfig()
	if err != nil {
		log.Fatalf("读取配置文件失败: %v", err)
	}

	if *portFlag > 0 {
		cfg.Port = *portFlag
	}

	// 2. 生成 E2EE 密钥对
	keyPair, err := security.GenerateKeyPair()
	if err != nil {
		log.Fatalf("生成端到端加密密钥对失败: %v", err)
	}

	// 3. 生成并打印终端配对二维码
	payload, qrStr, err := security.GeneratePairingQRCode(
		cfg.DeviceID,
		cfg.DeviceName,
		keyPair.PublicKeyBase64(),
		cfg.RelayServer,
		cfg.Port,
	)
	if err != nil {
		log.Fatalf("生成配对二维码失败: %v", err)
	}

	payloadJson, _ := json.Marshal(payload)
	security.PrintPairingBanner(cfg.DeviceName, qrStr, string(payloadJson))

	// 4. 初始化驱动注册中心与检测系统环境
	registry := agent.NewRegistry()
	availableAgents := registry.ListAvailable()

	color.Cyan("\n🔍 [环境检测] 本地已就绪的受控 Agent:")
	for _, a := range availableAgents {
		color.Green("  ✓ %s (%s)", a.Name(), a.Type())
	}
	if len(availableAgents) == 0 {
		color.Yellow("  ⚠️  未在系统 PATH 中检测到 claude/codex/aider，将默认使用通用 CLI 驱动兜底。")
	}

	color.Cyan("\n📁 [工作目录] %s", cfg.WorkingDir)
	color.Cyan("🔒 [安全模式] 端到端加密 (E2EE) 已启用 | 零配置：100%% 继承电脑本地环境\n")

	// 5. 启动 WebSocket 服务与通信通道
	server := ws.NewWSServer(cfg, keyPair, registry)

	go func() {
		if err := server.Start(); err != nil {
			log.Fatalf("WebSocket 服务异常退出: %v", err)
		}
	}()

	// 6. 优雅监听系统退出信号
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	<-sigChan

	color.Yellow("\n正在安全关闭 CloudWork 守护进程...")
}
