package hub

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

// ClientType 连接类型
type ClientType string

const (
	TypeDaemon ClientType = "daemon" // 电脑端守护进程
	TypeMobile ClientType = "mobile" // 手机端客户端
)

// TunnelFrame 密文中继帧（中继服务器只转发密文，零知识存储）
type TunnelFrame struct {
	Type      string          `json:"type"`      // "handshake", "packet", "ping", "pong", "push_request"
	DeviceID  string          `json:"device_id"` // 目标/来源设备ID
	Client    ClientType      `json:"client"`    // 来源身份
	Payload   json.RawMessage `json:"payload,omitempty"`
	Cipher    string          `json:"cipher,omitempty"` // E2EE 密文
	Timestamp int64           `json:"timestamp"`
}

// DeviceSession 设备会话对
type DeviceSession struct {
	DeviceID   string
	DaemonConn *websocket.Conn
	MobileConn *websocket.Conn
	mu         sync.Mutex
}

// Hub 中继中心调度器
type Hub struct {
	sessions   map[string]*DeviceSession
	sessionsMu sync.RWMutex
}

func NewHub() *Hub {
	return &Hub{
		sessions: make(map[string]*DeviceSession),
	}
}

// HandleTunnel 处理 WebSocket 隧道长连接
func (h *Hub) HandleTunnel(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[Relay] WebSocket Upgrade failed: %v\n", err)
		return
	}
	defer conn.Close()

	var deviceID string
	var clientType ClientType

	// 1. 等待握手帧确定设备身份
	_, firstMsg, err := conn.ReadMessage()
	if err != nil {
		return
	}

	var handshake TunnelFrame
	if err := json.Unmarshal(firstMsg, &handshake); err != nil {
		return
	}

	deviceID = handshake.DeviceID
	clientType = handshake.Client
	if deviceID == "" {
		_ = conn.WriteJSON(map[string]string{"error": "missing device_id in handshake"})
		return
	}

	session := h.getOrCreateSession(deviceID)
	session.mu.Lock()
	if clientType == TypeDaemon {
		session.DaemonConn = conn
		log.Printf("🖥️  [Daemon 上线] 设备 ID: %s (IP: %s)\n", deviceID, r.RemoteAddr)
	} else {
		session.MobileConn = conn
		log.Printf("📱 [Mobile 接入] 目标设备: %s (IP: %s)\n", deviceID, r.RemoteAddr)
	}
	session.mu.Unlock()

	// 确认握手成功
	_ = conn.WriteJSON(TunnelFrame{
		Type:      "handshake_ack",
		DeviceID:  deviceID,
		Timestamp: time.Now().Unix(),
	})

	// 2. 密文帧实时双向中继转发
	for {
		_, msgBytes, err := conn.ReadMessage()
		if err != nil {
			break
		}

		var frame TunnelFrame
		if err := json.Unmarshal(msgBytes, &frame); err != nil {
			continue
		}

		session.mu.Lock()
		if clientType == TypeDaemon && session.MobileConn != nil {
			// Daemon -> Mobile 转发
			_ = session.MobileConn.WriteMessage(websocket.TextMessage, msgBytes)
		} else if clientType == TypeMobile && session.DaemonConn != nil {
			// Mobile -> Daemon 转发
			_ = session.DaemonConn.WriteMessage(websocket.TextMessage, msgBytes)
		}
		session.mu.Unlock()
	}

	// 3. 断开连接清理
	session.mu.Lock()
	if clientType == TypeDaemon && session.DaemonConn == conn {
		session.DaemonConn = nil
		log.Printf("🔌 [Daemon 下线] 设备 ID: %s\n", deviceID)
	} else if clientType == TypeMobile && session.MobileConn == conn {
		session.MobileConn = nil
		log.Printf("🔌 [Mobile 断开] 目标设备: %s\n", deviceID)
	}
	session.mu.Unlock()
}

func (h *Hub) getOrCreateSession(deviceID string) *DeviceSession {
	h.sessionsMu.Lock()
	defer h.sessionsMu.Unlock()

	if sess, ok := h.sessions[deviceID]; ok {
		return sess
	}

	sess := &DeviceSession{DeviceID: deviceID}
	h.sessions[deviceID] = sess
	return sess
}

// GetStats 获取当前中继统计
func (h *Hub) GetStats() map[string]interface{} {
	h.sessionsMu.RLock()
	defer h.sessionsMu.RUnlock()

	activeDaemons := 0
	activeMobiles := 0
	for _, s := range h.sessions {
		s.mu.Lock()
		if s.DaemonConn != nil {
			activeDaemons++
		}
		if s.MobileConn != nil {
			activeMobiles++
		}
		s.mu.Unlock()
	}

	return map[string]interface{}{
		"total_registered_devices": len(h.sessions),
		"active_daemons":           activeDaemons,
		"active_mobiles":           activeMobiles,
		"uptime_check":             fmt.Sprintf("OK @ %s", time.Now().Format(time.RFC3339)),
	}
}
