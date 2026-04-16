// build.rs — Tauri build script
// Must be present so Tauri can inject its code-signing and resource bundling.

fn main() {
    tauri_build::build()
}
