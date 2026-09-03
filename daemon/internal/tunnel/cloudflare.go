package tunnel

import (
	"bufio"
	"fmt"
	"os/exec"
	"regexp"
	"strings"
	"time"
)

var cfUrlRegex = regexp.MustCompile(`https://[a-zA-Z0-9-]+\.trycloudflare\.com`)

// StartCloudflareTunnel 启动并捕获 Cloudflare 免费穿透隧道
func StartCloudflareTunnel(localPort int) (string, *exec.Cmd, error) {
	cmd := exec.Command("cloudflared", "tunnel", "--url", fmt.Sprintf("http://127.0.0.1:%d", localPort), "--protocol", "http2", "--no-autoupdate")
	
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return "", nil, fmt.Errorf("failed to pipe stderr: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return "", nil, fmt.Errorf("failed to start cloudflared: %w (请确认已安装 cloudflared)", err)
	}

	urlChan := make(chan string, 1)
	errChan := make(chan error, 1)

	go func() {
		scanner := bufio.NewScanner(stderr)
		for scanner.Scan() {
			line := scanner.Text()
			if match := cfUrlRegex.FindString(line); match != "" {
				wsUrl := strings.Replace(match, "https://", "wss://", 1) + "/ws"
				urlChan <- wsUrl
				return
			}
		}
	}()

	select {
	case url := <-urlChan:
		return url, cmd, nil
	case err := <-errChan:
		return "", cmd, err
	case <-time.After(15 * time.Second):
		return "", cmd, fmt.Errorf("timeout waiting for cloudflared tunnel URL")
	}
}
