package crypto

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"math/big"
	"os"
)

const (
	// RSAKeyBits is the RSA key size used by NCSoft AION 5.8 — 1024 bits.
	// This produces a 128-byte modulus and credential block.
	RSAKeyBits = 1024

	// CredentialBlockSize is the size (bytes) of the RSA-encrypted credential
	// block sent by the AION client inside CM_LOGIN.
	CredentialBlockSize = 128

	// AccountNameMaxLen is the maximum account name length supported by the
	// RSA credential block layout.  Names are null-padded to this length.
	AccountNameMaxLen = 17
)

// RSAKeyPair holds an RSA-1024 key pair used by the Protocol Gateway.
// The public key modulus (128 bytes, big-endian) is transmitted to clients
// inside SM_KEY so they can encrypt their login credentials.
type RSAKeyPair struct {
	priv *rsa.PrivateKey
}

// GenerateRSAKeyPair creates a fresh RSA-1024 key pair.
// Key generation is called once at server startup; the key pair is then
// either kept in memory or persisted to a PEM file.
func GenerateRSAKeyPair() (*RSAKeyPair, error) {
	priv, err := rsa.GenerateKey(rand.Reader, RSAKeyBits)
	if err != nil {
		return nil, fmt.Errorf("rsa: key generation failed: %w", err)
	}
	return &RSAKeyPair{priv: priv}, nil
}

// LoadRSAKeyPair reads a PEM-encoded RSA private key from path.
// If the file does not exist, a new key pair is generated and saved.
func LoadRSAKeyPair(path string) (*RSAKeyPair, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			// Generate and persist.
			kp, genErr := GenerateRSAKeyPair()
			if genErr != nil {
				return nil, genErr
			}
			if saveErr := kp.SavePEM(path); saveErr != nil {
				return nil, fmt.Errorf("rsa: could not save generated key: %w", saveErr)
			}
			return kp, nil
		}
		return nil, fmt.Errorf("rsa: read key file %q: %w", path, err)
	}

	block, _ := pem.Decode(data)
	if block == nil {
		return nil, fmt.Errorf("rsa: %q contains no PEM block", path)
	}

	priv, err := x509.ParsePKCS1PrivateKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("rsa: parse PKCS1 key: %w", err)
	}
	return &RSAKeyPair{priv: priv}, nil
}

// SavePEM writes the private key to path in PKCS#1 PEM format.
func (k *RSAKeyPair) SavePEM(path string) error {
	der := x509.MarshalPKCS1PrivateKey(k.priv)
	block := &pem.Block{Type: "RSA PRIVATE KEY", Bytes: der}

	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o600)
	if err != nil {
		return fmt.Errorf("rsa: open %q: %w", path, err)
	}
	defer f.Close()

	return pem.Encode(f, block)
}

// PublicKeyModulus returns the 128-byte big-endian RSA modulus.
// This is the value transmitted to the client inside SM_KEY.
func (k *RSAKeyPair) PublicKeyModulus() []byte {
	b := k.priv.N.Bytes()
	// Pad to CredentialBlockSize bytes (leading zeros if needed).
	result := make([]byte, CredentialBlockSize)
	copy(result[CredentialBlockSize-len(b):], b)
	return result
}

// PublicKeyExponent returns the RSA public exponent (e.g. 65537).
func (k *RSAKeyPair) PublicKeyExponent() int {
	return k.priv.E
}

// DecryptCredentials decrypts a CredentialBlockSize-byte block received in
// CM_LOGIN using raw (NoPadding) RSA — the mode used by NCSoft AION clients.
//
// The returned 128-byte plaintext layout:
//
//	[0..0]       : ignored (scramble byte set by client)
//	[1..17]      : account name, null-padded (AccountNameMaxLen chars max)
//	[18..127]    : password, null-padded
//
// Note: raw RSA is cryptographically weak but must match the client.
func (k *RSAKeyPair) DecryptCredentials(ciphertext []byte) ([]byte, error) {
	if len(ciphertext) != CredentialBlockSize {
		return nil, fmt.Errorf("rsa: credential block must be %d bytes, got %d",
			CredentialBlockSize, len(ciphertext))
	}

	// Raw RSA: m = c^d mod n
	c := new(big.Int).SetBytes(ciphertext)
	m := new(big.Int).Exp(c, k.priv.D, k.priv.N)

	plain := make([]byte, CredentialBlockSize)
	decoded := m.Bytes()
	if len(decoded) > CredentialBlockSize {
		return nil, fmt.Errorf("rsa: decrypted value exceeds credential block size")
	}
	// Right-align (big-endian integer → fixed-size byte slice).
	copy(plain[CredentialBlockSize-len(decoded):], decoded)
	return plain, nil
}

// ParseCredentials extracts account name and password from a decrypted
// credential block (output of DecryptCredentials).
func ParseCredentials(plain []byte) (account, password string, err error) {
	if len(plain) < CredentialBlockSize {
		return "", "", fmt.Errorf("rsa: credential plaintext too short: %d", len(plain))
	}

	// Account name starts at byte 1, maximum AccountNameMaxLen bytes, null-terminated.
	account = nullTermString(plain[1 : 1+AccountNameMaxLen])

	// Password occupies bytes 18..127, null-terminated.
	password = nullTermString(plain[18:CredentialBlockSize])

	return account, password, nil
}

// nullTermString converts a null-padded byte slice to a Go string.
func nullTermString(b []byte) string {
	for i, c := range b {
		if c == 0 {
			return string(b[:i])
		}
	}
	return string(b)
}
