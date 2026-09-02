package agent

import "strings"

// Registry Agent 驱动注册中心
type Registry struct {
	drivers map[string]AgentDriver
}

func NewRegistry() *Registry {
	r := &Registry{
		drivers: make(map[string]AgentDriver),
	}
	r.Register(NewClaudeCodeDriver())
	r.Register(NewCodexDriver())
	r.Register(NewAiderDriver())
	r.Register(NewGenericCLIDriver())
	return r
}

func (r *Registry) Register(d AgentDriver) {
	r.drivers[strings.ToLower(d.Type())] = d
}

func (r *Registry) Get(agentType string) AgentDriver {
	if d, ok := r.drivers[strings.ToLower(agentType)]; ok {
		return d
	}
	return r.drivers["generic"]
}

// ListAvailable 返回本地系统上已检测到的所有可用 Agent 驱动
func (r *Registry) ListAvailable() []AgentDriver {
	var available []AgentDriver
	for _, d := range r.drivers {
		if d.Detect() {
			available = append(available, d)
		}
	}
	return available
}
