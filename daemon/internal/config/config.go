package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
)

// StationType 定义中转站/提供商类型
type StationType string

const (
	StationNewAPI   StationType = "newapi"
	StationOneAPI   StationType = "oneapi"
	StationOfficial StationType = "official"
	StationCustom   StationType = "custom"
)

// APIStation 表示一个中转站或 API 提供商配置
type APIStation struct {
	ID          string      `json:"id"`
	Name        string      `json:"name"`
	Type        StationType `json:"type"`
	BaseURL     string      `json:"base_url"`
	APIKey      string      `json:"api_key"`
	Models      []string    `json:"models,omitempty"`
	Balance     float64     `json:"balance,omitempty"`
	Currency    string      `json:"currency,omitempty"`
	IsDefault   bool        `json:"is_default"`
	HealthScore int         `json:"health_score"` // 0-100 健康分/可用度
}

// ModelRoutingRule 模型智能路由规则
type ModelRoutingRule struct {
	ModelPattern string `json:"model_pattern"` // e.g. "claude-*", "gpt-*", "o3-*"
	StationID    string `json:"station_id"`
	FallbackID   string `json:"fallback_id,omitempty"`
}

// DaemonConfig 守护进程总配置
type DaemonConfig struct {
	DeviceID      string             `json:"device_id"`
	DeviceName    string             `json:"device_name"`
	RelayServer   string             `json:"relay_server"`   // 默认公共中继或自建中继
	Port          int                `json:"port"`           // 本地 WebSocket 端口
	Stations      []APIStation       `json:"stations"`       // 用户保存的多个中转站
	RoutingRules  []ModelRoutingRule `json:"routing_rules"`  // 智能路由规则
	AutoApprove   bool               `json:"auto_approve"`   // 是否开启部分安全操作自动批准
	WorkingDir    string             `json:"working_dir"`    // 默认工作目录
	AllowedHosts  []string           `json:"allowed_hosts"`  // 允许绑定的手机端设备公钥指纹
}

var (
	configInstance *DaemonConfig
	configMutex    sync.RWMutex
)

// GetConfigPath 获取配置文件路径 ~/.cloudwork/config.json
func GetConfigPath() string {
	home, err := os.UserHomeDir()
	if err != nil {
		home = "."
	}
	dir := filepath.Join(home, ".cloudwork")
	_ = os.MkdirAll(dir, 0755)
	return filepath.Join(dir, "config.json")
}

// LoadConfig 读取本地配置文件
func LoadConfig() (*DaemonConfig, error) {
	configMutex.Lock()
	defer configMutex.Unlock()

	path := GetConfigPath()
	if _, err := os.Stat(path); os.IsNotExist(err) {
		hostname, _ := os.Hostname()
		if hostname == "" {
			hostname = "My-Computer"
		}
		defaultCfg := &DaemonConfig{
			DeviceID:     fmt.Sprintf("dev_%d", os.Getpid()),
			DeviceName:   hostname,
			RelayServer:  "wss://relay.cloudwork.dev/v1/tunnel", // 默认中立中继地址
			Port:         9288,
			Stations:     []APIStation{},
			RoutingRules: []ModelRoutingRule{},
			WorkingDir:   ".",
		}
		_ = saveConfigUnlocked(defaultCfg, path)
		configInstance = defaultCfg
		return defaultCfg, nil
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var cfg DaemonConfig
	if err := json.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}
	configInstance = &cfg
	return &cfg, nil
}

// SaveConfig 保存配置到磁盘
func SaveConfig(cfg *DaemonConfig) error {
	configMutex.Lock()
	defer configMutex.Unlock()
	configInstance = cfg
	return saveConfigUnlocked(cfg, GetConfigPath())
}

func saveConfigUnlocked(cfg *DaemonConfig, path string) error {
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0600)
}

// GetStationByID 根据 ID 获取中转站配置
func (c *DaemonConfig) GetStationByID(id string) *APIStation {
	for i := range c.Stations {
		if c.Stations[i].ID == id {
			return &c.Stations[i]
		}
	}
	return nil
}

// FindStationForModel 根据模型名找到最佳中转站（支持智能路由与降级）
func (c *DaemonConfig) FindStationForModel(modelName string) *APIStation {
	for _, rule := range c.RoutingRules {
		matched, _ := filepath.Match(rule.ModelPattern, modelName)
		if matched {
			if st := c.GetStationByID(rule.StationID); st != nil {
				return st
			}
			if rule.FallbackID != "" {
				if fb := c.GetStationByID(rule.FallbackID); fb != nil {
					return fb
				}
			}
		}
	}

	// 找默认站点
	for i := range c.Stations {
		if c.Stations[i].IsDefault {
			return &c.Stations[i]
		}
	}

	// 如果没有默认站点，返回第一个
	if len(c.Stations) > 0 {
		return &c.Stations[0]
	}

	return nil
}
