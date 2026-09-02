package ws

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"

	"github.com/cloudwork/cloudwork-daemon/internal/agent"
	"github.com/cloudwork/cloudwork-daemon/internal/config"
	"github.com/cloudwork/cloudwork-daemon/internal/security"
	"github.com/cloudwork/cloudwork-daemon/internal/session"
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // 允许跨域或移动端直连
	},
}

// SafeConn 线程安全的 WebSocket 连接包装器
type SafeConn struct {
	conn *websocket.Conn
	mu   sync.Mutex
}

func (sc *SafeConn) WriteJSON(v interface{}) error {
	sc.mu.Lock()
	defer sc.mu.Unlock()
	return sc.conn.WriteJSON(v)
}

func (sc *SafeConn) Close() error {
	sc.mu.Lock()
	defer sc.mu.Unlock()
	return sc.conn.Close()
}

// ClientMessage 手机端发来的控制指令
type ClientMessage struct {
	ID        string          `json:"id"`
	Action    string          `json:"action"` // "start_session", "approve", "reject", "send_input", "get_status", "save_stations"
	SessionID string          `json:"session_id,omitempty"`
	Payload   json.RawMessage `json:"payload,omitempty"`
	Encrypted bool            `json:"encrypted,omitempty"`
	Cipher    string          `json:"cipher,omitempty"` // E2EE 密文
}

// ServerResponse 服务端响应给手机端的帧
type ServerResponse struct {
	Type      string      `json:"type"` // "event", "response", "status"
	Action    string      `json:"action,omitempty"`
	Success   bool        `json:"success"`
	Data      interface{} `json:"data,omitempty"`
	Error     string      `json:"error,omitempty"`
	Timestamp int64       `json:"timestamp"`
}

// WSServer 本地与中继 WebSocket 服务管理器
type WSServer struct {
	cfg        *config.DaemonConfig
	keyPair    *security.KeyPair
	mgr        *session.Manager
	registry   *agent.Registry
	clients    map[*SafeConn]bool
	clientsMu  sync.RWMutex
	sharedKeys map[*SafeConn][]byte
}

func NewWSServer(cfg *config.DaemonConfig, keyPair *security.KeyPair, registry *agent.Registry) *WSServer {
	srv := &WSServer{
		cfg:        cfg,
		keyPair:    keyPair,
		registry:   registry,
		clients:    make(map[*SafeConn]bool),
		sharedKeys: make(map[*SafeConn][]byte),
	}

	// 注册会话事件广播回调
	srv.mgr = session.NewManager(cfg, registry, func(ev *agent.AgentEvent) {
		srv.BroadcastEvent(ev)
	})

	return srv
}

func (s *WSServer) GetSessionManager() *session.Manager {
	return s.mgr
}

// Start 启动本地 WebSocket 监听
func (s *WSServer) Start() error {
	http.HandleFunc("/ws", s.handleWebSocket)
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]interface{}{
			"status":      "running",
			"device_id":   s.cfg.DeviceID,
			"device_name": s.cfg.DeviceName,
		})
	})

	addr := fmt.Sprintf("0.0.0.0:%d", s.cfg.Port)
	log.Printf("[WebSocket] 本地监听服务已就绪: ws://%s/ws\n", addr)
	return http.ListenAndServe(addr, nil)
}

func (s *WSServer) handleWebSocket(w http.ResponseWriter, r *http.Request) {
	rawConn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[WebSocket] 升档失败: %v\n", err)
		return
	}

	safeConn := &SafeConn{conn: rawConn}

	s.clientsMu.Lock()
	s.clients[safeConn] = true
	s.clientsMu.Unlock()

	defer func() {
		s.clientsMu.Lock()
		delete(s.clients, safeConn)
		delete(s.sharedKeys, safeConn)
		s.clientsMu.Unlock()
		_ = safeConn.Close()
	}()

	for {
		_, msgBytes, err := rawConn.ReadMessage()
		if err != nil {
			break
		}

		var req ClientMessage
		if err := json.Unmarshal(msgBytes, &req); err != nil {
			continue
		}

		s.handleMessage(safeConn, &req)
	}
}

func (s *WSServer) handleMessage(conn *SafeConn, req *ClientMessage) {
	switch req.Action {
	case "get_status":
		avail := s.registry.ListAvailable()
		var agentNames []string
		for _, a := range avail {
			agentNames = append(agentNames, fmt.Sprintf("%s (%s)", a.Name(), a.Type()))
		}

		resp := ServerResponse{
			Type:    "status",
			Action:  "get_status",
			Success: true,
			Data: map[string]interface{}{
				"device_id":        s.cfg.DeviceID,
				"device_name":      s.cfg.DeviceName,
				"working_dir":      s.cfg.WorkingDir,
				"available_agents": agentNames,
				"stations":         s.cfg.Stations,
				"active_sessions":  s.mgr.ListSessions(),
			},
		}
		_ = conn.WriteJSON(resp)

	case "start_session":
		type StartPayload struct {
			AgentType  string `json:"agent_type"`
			Prompt     string `json:"prompt"`
			Model      string `json:"model"`
			StationID  string `json:"station_id"`
			WorkingDir string `json:"working_dir"`
		}
		var p StartPayload
		_ = json.Unmarshal(req.Payload, &p)
		if p.WorkingDir == "" {
			p.WorkingDir = s.cfg.WorkingDir
		}

		sess, err := s.mgr.StartSession(p.AgentType, p.Prompt, p.Model, p.StationID, p.WorkingDir)
		resp := ServerResponse{
			Type:    "response",
			Action:  "start_session",
			Success: err == nil,
			Data:    sess,
		}
		if err != nil {
			resp.Error = err.Error()
		}
		_ = conn.WriteJSON(resp)

	case "approve":
		err := s.mgr.ApproveTool(req.SessionID)
		_ = conn.WriteJSON(ServerResponse{
			Type:    "response",
			Action:  "approve",
			Success: err == nil,
		})

	case "reject":
		err := s.mgr.RejectTool(req.SessionID)
		_ = conn.WriteJSON(ServerResponse{
			Type:    "response",
			Action:  "reject",
			Success: err == nil,
		})

	case "send_input":
		type InputPayload struct {
			Input string `json:"input"`
		}
		var inp InputPayload
		_ = json.Unmarshal(req.Payload, &inp)
		err := s.mgr.SendInput(req.SessionID, inp.Input)
		_ = conn.WriteJSON(ServerResponse{
			Type:    "response",
			Action:  "send_input",
			Success: err == nil,
		})

	case "terminate":
		err := s.mgr.TerminateSession(req.SessionID)
		_ = conn.WriteJSON(ServerResponse{
			Type:    "response",
			Action:  "terminate",
			Success: err == nil,
		})
	}
}

// BroadcastEvent 向所有连接的手机客户端线程安全地广播结构化事件
func (s *WSServer) BroadcastEvent(ev *agent.AgentEvent) {
	s.clientsMu.RLock()
	defer s.clientsMu.RUnlock()

	resp := ServerResponse{
		Type:    "event",
		Success: true,
		Data:    ev,
	}

	for client := range s.clients {
		_ = client.WriteJSON(resp)
	}
}
