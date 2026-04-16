// injector/mod.rs — DLL injection subsystem.
// Currently implements default injection (placing version.dll alongside aion.bin).
// The Windows PE loader auto-loads it; no explicit injection API is needed.

pub mod version_dll;
