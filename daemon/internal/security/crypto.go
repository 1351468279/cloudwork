package security

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/ecdh"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"io"
)

// KeyPair 表示一个 X25519 端到端加密密钥对
type KeyPair struct {
	PrivateKey *ecdh.PrivateKey
	PublicKey  *ecdh.PublicKey
}

// GenerateKeyPair 生成新的 X25519 密钥对
func GenerateKeyPair() (*KeyPair, error) {
	curve := ecdh.X25519()
	priv, err := curve.GenerateKey(rand.Reader)
	if err != nil {
		return nil, err
	}
	return &KeyPair{
		PrivateKey: priv,
		PublicKey:  priv.PublicKey(),
	}, nil
}

// PublicKeyBase64 返回 Base64 编码的公钥
func (k *KeyPair) PublicKeyBase64() string {
	return base64.StdEncoding.EncodeToString(k.PublicKey.Bytes())
}

// DeriveSharedSecret 计算共享密钥（ECDH + SHA256 KDF）
func (k *KeyPair) DeriveSharedSecret(peerPubKeyBase64 string) ([]byte, error) {
	peerBytes, err := base64.StdEncoding.DecodeString(peerPubKeyBase64)
	if err != nil {
		return nil, err
	}

	curve := ecdh.X25519()
	peerKey, err := curve.NewPublicKey(peerBytes)
	if err != nil {
		return nil, err
	}

	rawSecret, err := k.PrivateKey.ECDH(peerKey)
	if err != nil {
		return nil, err
	}

	// 使用 SHA-256 生成标准的 32 字节 AES 密钥
	hash := sha256.Sum256(rawSecret)
	return hash[:], nil
}

// EncryptPayload 使用 AES-256-GCM 加密明文
func EncryptPayload(key []byte, plaintext []byte) (string, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}

	ciphertext := gcm.Seal(nonce, nonce, plaintext, nil)
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// DecryptPayload 使用 AES-256-GCM 解密密文
func DecryptPayload(key []byte, ciphertextBase64 string) ([]byte, error) {
	ciphertext, err := base64.StdEncoding.DecodeString(ciphertextBase64)
	if err != nil {
		return nil, err
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	nonceSize := gcm.NonceSize()
	if len(ciphertext) < nonceSize {
		return nil, errors.New("ciphertext too short")
	}

	nonce, actualCiphertext := ciphertext[:nonceSize], ciphertext[nonceSize:]
	return gcm.Open(nil, nonce, actualCiphertext, nil)
}
