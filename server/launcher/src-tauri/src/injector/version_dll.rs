// injector/version_dll.rs — Ensure bin32/version.dll is present and has the correct checksum.
//
// Protocol compliance (launcher-protocol.md §5):
//   - If version.dll is absent → download from manifest
//   - If sha256 does not match → overwrite
//   - Default injection: DLL sits next to aion.bin, PE loader auto-loads it
//   - No destructive action on the existing DLL at D:/拾光ai/tools/version-dll/

use crate::patcher::manifest as patch_manifest;
use crate::patcher::verifier;
use reqwest::Client;
use std::path::Path;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum InjectorError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Network error: {0}")]
    Network(#[from] reqwest::Error),

    #[error("Manifest error: {0}")]
    Manifest(String),

    #[error("version.dll not found in manifest — cannot proceed")]
    NotInManifest,
}

/// Relative path of version.dll within the client tree.
const VERSION_DLL_REL: &str = "bin32/version.dll";

/// Verify that bin32/version.dll exists and matches the manifest's checksum.
/// Downloads the file if absent or corrupted.
pub async fn ensure_version_dll(
    client_root: &Path,
    http: &Client,
    api_base: &str,
) -> Result<(), InjectorError> {
    let dll_path = client_root.join(VERSION_DLL_REL);

    // Fetch the manifest to learn the expected sha256 for version.dll.
    let manifest_url = format!("{}/launcher/patch/manifest?client=beyond48", api_base);
    let manifest = patch_manifest::fetch_manifest(http, &manifest_url)
        .await
        .map_err(|e| InjectorError::Manifest(e.to_string()))?;

    // Locate the version.dll entry in the manifest.
    let dll_entry = manifest
        .files
        .iter()
        .find(|f| f.relative_path == VERSION_DLL_REL)
        .ok_or(InjectorError::NotInManifest)?;

    // If the file exists and checksum matches, nothing to do.
    if dll_path.exists() {
        match verifier::verify_file(&dll_path, &dll_entry.sha256) {
            Ok(()) => {
                log::info!("version.dll OK (sha256 verified).");
                return Ok(());
            }
            Err(e) => {
                log::warn!("version.dll checksum mismatch ({}); re-downloading.", e);
            }
        }
    } else {
        log::info!("version.dll not found; downloading from manifest.");
    }

    // Download version.dll and place it in bin32/.
    download_version_dll(http, api_base, dll_entry, &dll_path).await
}

/// Fetch version.dll from the patch endpoint and write it to `dest`.
async fn download_version_dll(
    http: &Client,
    api_base: &str,
    entry: &crate::commands::PatchFile,
    dest: &Path,
) -> Result<(), InjectorError> {
    let url = if entry.download_url.starts_with("http") {
        entry.download_url.clone()
    } else {
        format!("{}{}", api_base, entry.download_url)
    };

    let bytes = http
        .get(&url)
        .send()
        .await
        .map_err(InjectorError::Network)?
        .bytes()
        .await
        .map_err(InjectorError::Network)?;

    // Verify before writing to avoid placing a corrupt DLL.
    let actual_hash = verifier::bytes_sha256(&bytes);
    if actual_hash != entry.sha256 {
        return Err(InjectorError::Io(std::io::Error::new(
            std::io::ErrorKind::InvalidData,
            format!("Downloaded version.dll sha256 mismatch: got {}", actual_hash),
        )));
    }

    if let Some(parent) = dest.parent() {
        std::fs::create_dir_all(parent)?;
    }
    std::fs::write(dest, &bytes)?;
    log::info!("version.dll installed at {:?}", dest);
    Ok(())
}
