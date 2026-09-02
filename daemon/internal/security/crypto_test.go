package security

import (
	"bytes"
	"testing"
)

func TestE2EECryptoFlow(t *testing.T) {
	// 1. 模拟电脑端生成密钥对
	daemonKeys, err := GenerateKeyPair()
	if err != nil {
		t.Fatalf("Daemon keygen failed: %v", err)
	}

	// 2. 模拟手机端生成密钥对
	mobileKeys, err := GenerateKeyPair()
	if err != nil {
		t.Fatalf("Mobile keygen failed: %v", err)
	}

	// 3. 双方通过对方公钥计算共享密钥
	daemonSharedKey, err := daemonKeys.DeriveSharedSecret(mobileKeys.PublicKeyBase64())
	if err != nil {
		t.Fatalf("Daemon derive secret failed: %v", err)
	}

	mobileSharedKey, err := mobileKeys.DeriveSharedSecret(daemonKeys.PublicKeyBase64())
	if err != nil {
		t.Fatalf("Mobile derive secret failed: %v", err)
	}

	if !bytes.Equal(daemonSharedKey, mobileSharedKey) {
		t.Fatalf("Shared keys do not match!")
	}

	// 4. 模拟手机端加密发送指令
	plaintext := []byte("{\"action\":\"approve\",\"session_id\":\"sess_123\"}")
	ciphertext, err := EncryptPayload(mobileSharedKey, plaintext)
	if err != nil {
		t.Fatalf("Mobile encrypt failed: %v", err)
	}

	// 5. 模拟电脑端解密指令
	decrypted, err := DecryptPayload(daemonSharedKey, ciphertext)
	if err != nil {
		t.Fatalf("Daemon decrypt failed: %v", err)
	}

	if string(decrypted) != string(plaintext) {
		t.Fatalf("Decrypted plaintext mismatch! got %s, want %s", string(decrypted), string(plaintext))
	}
}
