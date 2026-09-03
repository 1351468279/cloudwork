package pty

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"runtime"
	"sync"
)

// ProcessSession 表示一个运行中的 Agent 终端进程
type ProcessSession struct {
	ID         string
	Command    string
	Args       []string
	Cwd        string
	Env        []string
	cmd        *exec.Cmd
	stdin      io.WriteCloser
	stdout     io.ReadCloser
	stderr     io.ReadCloser
	ctx        context.Context
	cancel     context.CancelFunc
	mu         sync.Mutex
	IsRunning  bool
	ExitCode   int
	OnOutput   func(line string)
	OnExit     func(exitCode int)
}

// StartProcess 启动一个跨平台子进程并监听其输出
func StartProcess(id string, command string, args []string, cwd string, env []string, onOutput func(string), onExit func(int)) (*ProcessSession, error) {
	ctx, cancel := context.WithCancel(context.Background())

	var cmd *exec.Cmd
	if runtime.GOOS == "windows" {
		// Windows: 若命令是 npm/npx/node 包装脚本，使用 cmd.exe /c 保证兼容解析
		cmd = exec.CommandContext(ctx, command, args...)
	} else {
		cmd = exec.CommandContext(ctx, command, args...)
	}

	if cwd != "" {
		cmd.Dir = cwd
	}

	// 合并系统环境变量与注入的环境变量，并确保控制台采用 UTF-8 编码
	utf8Envs := []string{
		"PYTHONIOENCODING=utf-8",
		"LANG=zh_CN.UTF-8",
		"LC_ALL=zh_CN.UTF-8",
	}
	cmd.Env = append(os.Environ(), append(utf8Envs, env...)...)

	stdinPipe, err := cmd.StdinPipe()
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to open stdin pipe: %w", err)
	}

	stdoutPipe, err := cmd.StdoutPipe()
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to open stdout pipe: %w", err)
	}

	stderrPipe, err := cmd.StderrPipe()
	if err != nil {
		cancel()
		return nil, fmt.Errorf("failed to open stderr pipe: %w", err)
	}

	session := &ProcessSession{
		ID:        id,
		Command:   command,
		Args:      args,
		Cwd:       cwd,
		Env:       env,
		cmd:       cmd,
		stdin:     stdinPipe,
		stdout:    stdoutPipe,
		stderr:    stderrPipe,
		ctx:       ctx,
		cancel:    cancel,
		IsRunning: true,
		OnOutput:  onOutput,
		OnExit:    onExit,
	}

	if err := cmd.Start(); err != nil {
		cancel()
		return nil, fmt.Errorf("failed to start command %s: %w", command, err)
	}

	// 异步监听 stdout
	go session.readPipe(stdoutPipe)
	// 异步监听 stderr
	go session.readPipe(stderrPipe)

	// 监听进程退出
	go session.waitForExit()

	return session, nil
}

func (s *ProcessSession) readPipe(r io.Reader) {
	scanner := bufio.NewScanner(r)
	// 支持单行最大 2MB 完整传输（处理大型 diff 与结构化 JSONL 输出）
	buf := make([]byte, 64*1024)
	scanner.Buffer(buf, 2*1024*1024)

	for scanner.Scan() {
		line := scanner.Text()
		if s.OnOutput != nil {
			s.OnOutput(line + "\n")
		}
	}
}

func (s *ProcessSession) waitForExit() {
	err := s.cmd.Wait()
	s.mu.Lock()
	s.IsRunning = false
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			s.ExitCode = exitErr.ExitCode()
		} else {
			s.ExitCode = 1
		}
	} else {
		s.ExitCode = 0
	}
	s.mu.Unlock()

	if s.OnExit != nil {
		s.OnExit(s.ExitCode)
	}
}

// SendInput 向进程的标准输入写入数据（例如：确认审批 "y\n" 或输入指令）
func (s *ProcessSession) SendInput(input string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.IsRunning || s.stdin == nil {
		return fmt.Errorf("process is not running")
	}
	_, err := s.stdin.Write([]byte(input))
	return err
}

// CloseStdin 关闭标准输入以通知子进程（如 codex exec）输入结束并开始执行
func (s *ProcessSession) CloseStdin() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.stdin != nil {
		err := s.stdin.Close()
		s.stdin = nil
		return err
	}
	return nil
}

// Terminate 终止进程
func (s *ProcessSession) Terminate() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.IsRunning {
		return nil
	}
	s.cancel()
	if s.cmd.Process != nil {
		return s.cmd.Process.Kill()
	}
	return nil
}
