// patcher/downloader.rs — Concurrent patch file downloader with resume support.
//
// Protocol compliance (launcher-protocol.md §4):
//   - Max 4 concurrent downloads via Semaphore
//   - Resume via Range header if a .pending/<sha256>.part file exists
//   - HTTP 206: append; HTTP 200: overwrite
//   - SHA-256 verify after each file; retry up to 3 times on mismatch
//   - Atomic rename from .pending/<sha256>.part to client/<relative_path>

use crate::commands::{DownloadProgress, PatchManifest};
use crate::patcher::verifier;
use futures::stream::{self, StreamExt};
use reqwest::Client;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use tauri::{AppHandle, Emitter};
use thiserror::Error;
use tokio::io::AsyncWriteExt;
use tokio::sync::Semaphore;

/// Maximum number of files downloaded simultaneously.
const MAX_CONCURRENCY: usize = 4;

/// Maximum retry attempts per file on checksum failure.
const MAX_RETRIES: usize = 3;

#[derive(Debug, Error)]
pub enum DownloadError {
    #[error("Network error: {0}")]
    Network(#[from] reqwest::Error),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Checksum failed after {retries} retries for file {path}")]
    ChecksumFailed { sha256: String, path: String, retries: usize },

    #[error("Backend returned HTTP {0}")]
    BadStatus(u16),
}

/// Download all files in the manifest that need updating.
/// Emits "patch://progress" events to the Tauri frontend during download.
pub async fn download_all(
    manifest: &PatchManifest,
    api_base: &str,
    client_root: &Path,
    pending_dir: &Path,
    app: &AppHandle,
) -> Result<(), DownloadError> {
    // Identify which files actually need downloading.
    let to_download = crate::patcher::manifest::files_needing_update(manifest, client_root);
    if to_download.is_empty() {
        log::info!("All files up to date, skipping download.");
        return Ok(());
    }

    tokio::fs::create_dir_all(pending_dir).await?;

    let semaphore = Arc::new(Semaphore::new(MAX_CONCURRENCY));
    let total_files = to_download.len();

    // Build owned download tasks so we can move data into async closures.
    let tasks: Vec<_> = to_download
        .into_iter()
        .enumerate()
        .map(|(idx, file)| {
            let sem = Arc::clone(&semaphore);
            let http = Client::builder()
                .user_agent("ShiguangLauncher/1.0.0")
                .build()
                .unwrap();
            let download_url = if file.download_url.starts_with("http") {
                file.download_url.clone()
            } else {
                format!("{}{}", api_base, file.download_url)
            };
            let dest = client_root.join(&file.relative_path);
            let part = pending_dir.join(format!("{}.part", &file.sha256));
            let sha256 = file.sha256.clone();
            let size_bytes = file.size_bytes;
            let rel_path = file.relative_path.clone();
            let app_handle = app.clone();

            async move {
                let _permit = sem.acquire().await.unwrap();
                download_file_with_retry(
                    &http,
                    &download_url,
                    &dest,
                    &part,
                    &sha256,
                    size_bytes,
                    idx,
                    total_files,
                    &rel_path,
                    &app_handle,
                )
                .await
            }
        })
        .collect();

    // Run all download tasks concurrently (semaphore limits actual parallelism).
    let results: Vec<Result<(), DownloadError>> = stream::iter(tasks)
        .buffer_unordered(MAX_CONCURRENCY * 2)
        .collect()
        .await;

    // Surface the first error if any task failed.
    for r in results {
        r?;
    }

    Ok(())
}

/// Download a single file with up to MAX_RETRIES attempts on checksum failure.
async fn download_file_with_retry(
    http: &Client,
    url: &str,
    dest: &Path,
    part: &PathBuf,
    expected_sha256: &str,
    total_bytes: u64,
    file_index: usize,
    total_files: usize,
    rel_path: &str,
    app: &AppHandle,
) -> Result<(), DownloadError> {
    for attempt in 0..MAX_RETRIES {
        match download_single(http, url, dest, part, expected_sha256, total_bytes, file_index, total_files, rel_path, app).await {
            Ok(()) => return Ok(()),
            Err(DownloadError::ChecksumFailed { .. }) if attempt + 1 < MAX_RETRIES => {
                log::warn!("Checksum mismatch for {}, retrying ({}/{})", rel_path, attempt + 1, MAX_RETRIES);
                // Remove the corrupt part file before retrying.
                let _ = tokio::fs::remove_file(part).await;
            }
            Err(e) => return Err(e),
        }
    }
    Err(DownloadError::ChecksumFailed {
        sha256: expected_sha256.to_string(),
        path: rel_path.to_string(),
        retries: MAX_RETRIES,
    })
}

/// Perform a single download attempt of one file.
/// Supports HTTP 206 resume if a .part file exists.
async fn download_single(
    http: &Client,
    url: &str,
    dest: &Path,
    part: &PathBuf,
    expected_sha256: &str,
    total_bytes: u64,
    file_index: usize,
    total_files: usize,
    rel_path: &str,
    app: &AppHandle,
) -> Result<(), DownloadError> {
    // Check for an existing partial download to enable resume.
    let existing_size = if part.exists() {
        tokio::fs::metadata(part).await.map(|m| m.len()).unwrap_or(0)
    } else {
        0
    };

    let mut req = http.get(url);
    if existing_size > 0 {
        req = req.header("Range", format!("bytes={}-", existing_size));
        log::info!("Resuming {} from byte {}", rel_path, existing_size);
    }

    let resp = req.send().await.map_err(DownloadError::Network)?;
    let status = resp.status().as_u16();

    // HTTP 304: local file is already up to date (ETag matched).
    if status == 304 {
        log::info!("{} is up to date (304)", rel_path);
        return Ok(());
    }

    if status != 200 && status != 206 {
        return Err(DownloadError::BadStatus(status));
    }

    // Open the part file in append mode for 206, overwrite for 200.
    let file_open = if status == 206 && existing_size > 0 {
        tokio::fs::OpenOptions::new().append(true).open(part).await?
    } else {
        tokio::fs::File::create(part).await?
    };

    let mut writer = tokio::io::BufWriter::new(file_open);
    let mut stream = resp.bytes_stream();
    let mut downloaded = if status == 206 { existing_size } else { 0 };

    while let Some(chunk) = stream.next().await {
        let chunk = chunk.map_err(DownloadError::Network)?;
        writer.write_all(&chunk).await?;
        downloaded += chunk.len() as u64;

        // Emit progress event to the frontend.
        let _ = app.emit(
            "patch://progress",
            DownloadProgress {
                file_path: rel_path.to_string(),
                downloaded_bytes: downloaded,
                total_bytes,
                file_index,
                total_files,
            },
        );
    }

    writer.flush().await?;
    drop(writer);

    // Verify checksum before promoting the file.
    verifier::verify_file(part, expected_sha256).map_err(|_| DownloadError::ChecksumFailed {
        sha256: expected_sha256.to_string(),
        path: rel_path.to_string(),
        retries: 0,
    })?;

    // Atomic rename: move from .pending/<sha256>.part to client/<relative_path>.
    if let Some(parent) = dest.parent() {
        tokio::fs::create_dir_all(parent).await?;
    }
    tokio::fs::rename(part, dest).await?;

    log::info!("Downloaded and verified: {}", rel_path);
    Ok(())
}
