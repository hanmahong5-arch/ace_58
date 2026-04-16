package crypto

import (
	"bytes"
	"math/big"
	"os"
	"path/filepath"
	"testing"
)

// TestRSAKeyPair_Generate verifies key generation and modulus extraction.
func TestRSAKeyPair_Generate(t *testing.T) {
	kp, err := GenerateRSAKeyPair()
	if err != nil {
		t.Fatalf("GenerateRSAKeyPair: %v", err)
	}

	mod := kp.PublicKeyModulus()
	if len(mod) != CredentialBlockSize {
		t.Errorf("modulus length: got %d, want %d", len(mod), CredentialBlockSize)
	}
}

// TestRSAKeyPair_PEMRoundTrip saves a key to a temp file and reloads it.
func TestRSAKeyPair_PEMRoundTrip(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "test_rsa.pem")

	original, err := GenerateRSAKeyPair()
	if err != nil {
		t.Fatal(err)
	}
	if err := original.SavePEM(path); err != nil {
		t.Fatalf("SavePEM: %v", err)
	}

	loaded, err := LoadRSAKeyPair(path)
	if err != nil {
		t.Fatalf("LoadRSAKeyPair: %v", err)
	}

	if !bytes.Equal(original.PublicKeyModulus(), loaded.PublicKeyModulus()) {
		t.Error("reloaded key modulus differs from original")
	}
}

// TestRSAKeyPair_AutoGenerate verifies that LoadRSAKeyPair creates the key
// when the file does not exist.
func TestRSAKeyPair_AutoGenerate(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "nonexistent.pem")

	kp, err := LoadRSAKeyPair(path)
	if err != nil {
		t.Fatalf("LoadRSAKeyPair (auto-gen): %v", err)
	}
	if kp == nil {
		t.Fatal("expected non-nil key pair")
	}

	// File should now exist.
	if _, statErr := os.Stat(path); statErr != nil {
		t.Errorf("PEM file not created: %v", statErr)
	}
}

// TestRSAKeyPair_DecryptRoundTrip encrypts a block with the public key (using
// the raw RSA operation) and decrypts it with DecryptCredentials.
func TestRSAKeyPair_DecryptRoundTrip(t *testing.T) {
	kp, err := GenerateRSAKeyPair()
	if err != nil {
		t.Fatal(err)
	}

	// Build a plaintext credential block.
	plain := make([]byte, CredentialBlockSize)
	copy(plain[1:], []byte("testaccount"))     // account at offset 1
	copy(plain[18:], []byte("hunter2"))         // password at offset 18

	// Raw RSA encrypt: c = m^e mod n
	m := new(big.Int).SetBytes(plain)
	e := big.NewInt(int64(kp.PublicKeyExponent()))
	n := kp.priv.N
	c := new(big.Int).Exp(m, e, n)
	ciphertext := make([]byte, CredentialBlockSize)
	cb := c.Bytes()
	copy(ciphertext[CredentialBlockSize-len(cb):], cb)

	decrypted, err := kp.DecryptCredentials(ciphertext)
	if err != nil {
		t.Fatalf("DecryptCredentials: %v", err)
	}
	if !bytes.Equal(decrypted, plain) {
		t.Errorf("decryption did not recover original plaintext")
	}
}

// TestParseCredentials verifies account/password extraction from a plain block.
func TestParseCredentials(t *testing.T) {
	plain := make([]byte, CredentialBlockSize)
	copy(plain[1:], "myaccount")
	copy(plain[18:], "mypassword123")

	account, password, err := ParseCredentials(plain)
	if err != nil {
		t.Fatalf("ParseCredentials: %v", err)
	}
	if account != "myaccount" {
		t.Errorf("account: got %q, want %q", account, "myaccount")
	}
	if password != "mypassword123" {
		t.Errorf("password: got %q, want %q", password, "mypassword123")
	}
}
