package security

import (
	"encoding/json"
	"fmt"
	"net"
	"strings"
	"time"

	"github.com/skip2/go-qrcode"
)

// PairingPayload 扫码配对载荷
type PairingPayload struct {
	Version    int      `json:"v"`
	DeviceID   string   `json:"device_id"`
	DeviceName string   `json:"device_name"`
	PublicKey  string   `json:"pub_key"`
	RelayURL   string   `json:"relay_url"`
	LocalIPs   []string `json:"local_ips"`
	Port       int      `json:"port"`
	Timestamp  int64    `json:"ts"`
}

// GeneratePairingQRCode 生成配对二维码并在终端打印
func GeneratePairingQRCode(deviceID, deviceName, pubKeyBase64, relayURL string, localPort int) (*PairingPayload, string, error) {
	localIPs := getLocalIPv4s()

	payload := &PairingPayload{
		Version:    1,
		DeviceID:   deviceID,
		DeviceName: deviceName,
		PublicKey:  pubKeyBase64,
		RelayURL:   relayURL,
		LocalIPs:   localIPs,
		Port:       localPort,
		Timestamp:  time.Now().Unix(),
	}

	data, err := json.Marshal(payload)
	if err != nil {
		return nil, "", err
	}

	rawString := string(data)

	// 生成适合终端直接显示的 ASCII 二维码
	qr, err := qrcode.New(rawString, qrcode.Medium)
	if err != nil {
		return nil, "", err
	}

	terminalQR := qr.ToSmallString(false)
	return payload, terminalQR, nil
}

// getLocalIPv4s 获取当前机器的所有真实局域网 IPv4 地址
func getLocalIPv4s() []string {
	var preferred []string
	var others []string
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return preferred
	}

	for _, addr := range addrs {
		if ipNet, ok := addr.(*net.IPNet); ok && !ipNet.IP.IsLoopback() {
			if ipNet.IP.To4() != nil {
				ipStr := ipNet.IP.String()
				// 过滤 Clash TUN 虚拟网卡 (198.18.x.x) 和 APIPA (169.254.x.x)
				if strings.HasPrefix(ipStr, "198.18.") || strings.HasPrefix(ipStr, "169.254.") {
					continue
				}
				if strings.HasPrefix(ipStr, "192.168.") || strings.HasPrefix(ipStr, "10.") || strings.HasPrefix(ipStr, "172.") {
					preferred = append(preferred, ipStr)
				} else {
					others = append(others, ipStr)
				}
			}
		}
	}
	return append(preferred, others...)
}

// PrintPairingBanner 终端打印炫酷配对横幅
func PrintPairingBanner(deviceName string, qrCodeStr string, rawJson string) {
	fmt.Println("==================================================================")
	fmt.Printf("   🚀 CloudWork 移动端连接助手 - 主机: %s\n", deviceName)
	fmt.Println("==================================================================")
	fmt.Println("请使用 CloudWork 手机 App 扫描下方二维码建立端到端加密(E2EE)连接：")
	fmt.Println()
	fmt.Println(qrCodeStr)
	fmt.Println("如果摄像头无法扫描，可以在 App 中选择手动粘贴连接码：")
	fmt.Printf("[连接数据]: %s\n", rawJson)
	fmt.Println("==================================================================")
}
