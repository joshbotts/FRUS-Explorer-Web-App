#if !canImport(Security)
// Linux stand-in for the Keychain-backed store the NARA client holds (scratch discovery shim).
public actor KeychainStore {
    public static let shared = KeychainStore()
    public init() {}
    nonisolated static func makeProduction() -> KeychainStore { KeychainStore() }
    public func getNARACatalogAPIKey() throws -> String? { nil }
    public func setNARACatalogAPIKey(_ key: String) throws {}
    public func hasAPIKey() -> Bool { false }
    public func deleteNARACatalogAPIKey() throws {}
}
#endif
