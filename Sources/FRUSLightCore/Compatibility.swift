// The index format this build serves (docs/SPEC.md, Compatibility contract).

/// The one index format this build serves. Both numbers come from the pinned FRUS-Explorer
/// commit; `CompatibilityTests` reads them from the submodule's sources, so a pin move that
/// changes either one fails until this file follows.
public enum IndexCompatibility {
    /// `IndexingPipeline.currentDateIndexVersion` at the pin (34a5120, build 49).
    public static let supportedIndexVersion = 65
    /// `FTS5Connection.currentSchemaGeneration`, stored in `PRAGMA user_version`.
    public static let ftsSchemaVersion = 4
}

/// The server's version, reported by `--version` and `/api/v1/status`.
public enum FRUSLightVersion {
    public static let string = "0.1.0-dev"
}
