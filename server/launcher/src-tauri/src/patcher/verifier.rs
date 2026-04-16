// patcher/verifier.rs — SHA-256 checksum helpers for downloaded patch files.
// All downloaded bytes must pass this check before the file is moved into place.

use sha2::{Digest, Sha256};
use std::fs::File;
use std::io::{self, Read};
use std::path::Path;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum VerifyError {
    #[error("IO error reading file for checksum: {0}")]
    Io(#[from] io::Error),

    #[error("Checksum mismatch: expected {expected}, got {actual}")]
    Mismatch { expected: String, actual: String },
}

/// Read the file at `path` and return its SHA-256 hex digest.
pub fn file_sha256(path: &Path) -> Result<String, io::Error> {
    let mut file = File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buf = [0u8; 65536]; // 64 KiB read buffer
    loop {
        let n = file.read(&mut buf)?;
        if n == 0 {
            break;
        }
        hasher.update(&buf[..n]);
    }
    Ok(format!("{:x}", hasher.finalize()))
}

/// Compute SHA-256 over a byte slice (used for in-memory buffers during streaming).
pub fn bytes_sha256(data: &[u8]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(data);
    format!("{:x}", hasher.finalize())
}

/// Assert that the file at `path` matches `expected_sha256`.
/// Returns Err(VerifyError::Mismatch) if they differ.
pub fn verify_file(path: &Path, expected_sha256: &str) -> Result<(), VerifyError> {
    let actual = file_sha256(path)?;
    if actual != expected_sha256 {
        return Err(VerifyError::Mismatch {
            expected: expected_sha256.to_string(),
            actual,
        });
    }
    Ok(())
}
