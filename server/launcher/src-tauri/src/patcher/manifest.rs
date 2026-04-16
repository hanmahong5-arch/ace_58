// patcher/manifest.rs — Fetch and deserialize the patch manifest from the Portal backend.
// Conforms to the schema defined in doc/portal/launcher-protocol.md §3.1.

use crate::commands::{PatchFile, PatchManifest};
use reqwest::Client;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum ManifestError {
    #[error("Network error while fetching manifest: {0}")]
    Network(#[from] reqwest::Error),

    #[error("Backend returned HTTP {0}")]
    BadStatus(u16),

    #[error("Failed to parse manifest JSON: {0}")]
    Parse(String),
}

/// GET the patch manifest from `url` and return a parsed PatchManifest.
/// Retries are handled at the call site (commands.rs / check_patch).
pub async fn fetch_manifest(http: &Client, url: &str) -> Result<PatchManifest, ManifestError> {
    let resp = http
        .get(url)
        .send()
        .await
        .map_err(ManifestError::Network)?;

    let status = resp.status().as_u16();
    if !resp.status().is_success() {
        return Err(ManifestError::BadStatus(status));
    }

    // Parse the raw JSON into our typed struct; surface any field mismatch as a clear error.
    let manifest: PatchManifest = resp
        .json()
        .await
        .map_err(|e| ManifestError::Parse(e.to_string()))?;

    log::info!(
        "Manifest fetched: version={} files={}",
        manifest.version,
        manifest.files.len()
    );

    Ok(manifest)
}

/// Filter `manifest.files` down to those that differ from local state.
/// A file needs updating if its local sha256 does not match the manifest entry,
/// or if the local file does not exist at all.
pub fn files_needing_update<'a>(
    manifest: &'a PatchManifest,
    client_root: &std::path::Path,
) -> Vec<&'a PatchFile> {
    manifest
        .files
        .iter()
        .filter(|f| {
            let local_path = client_root.join(&f.relative_path);
            if !local_path.exists() {
                return true;
            }
            // Quick sha256 check: read the file and compare.
            match crate::patcher::verifier::file_sha256(&local_path) {
                Ok(local_hash) => local_hash != f.sha256,
                Err(_) => true, // Treat unreadable files as needing update.
            }
        })
        .collect()
}
