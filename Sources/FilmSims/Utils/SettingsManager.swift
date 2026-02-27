import Foundation
import Security

/// iOS equivalent of Android's SettingsManager with EncryptedSharedPreferences.
/// Uses the iOS Keychain for encrypted storage (equivalent to AES-256-GCM on Android).
/// Falls back to UserDefaults for non-sensitive settings.
///
/// Persists: save quality, intensity, grain enabled/intensity/style
/// (matches Android SettingsManager properties exactly).
final class SettingsManager: @unchecked Sendable {

    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard
    private let keychainService = "com.tqmane.filmsim.settings"

    private init() {
        migrateIfNeeded()
    }

    // MARK: - Type-safe Properties (matching Android SettingsManager)

    var saveQuality: Int {
        get {
            let v = defaults.integer(forKey: "save_quality")
            if v == 0 { return 100 }
            return Swift.min(Swift.max(v, 10), 100)
        }
        set { defaults.set(newValue, forKey: "save_quality") }
    }

    var lastIntensity: Float {
        get {
            let v = keychainFloat(forKey: "last_intensity")
            return v == nil ? 1.0 : Swift.min(Swift.max(v!, 0), 1)
        }
        set { setKeychainFloat(newValue, forKey: "last_intensity") }
    }

    var lastGrainEnabled: Bool {
        get { keychainBool(forKey: "last_grain_enabled") ?? false }
        set { setKeychainBool(newValue, forKey: "last_grain_enabled") }
    }

    var lastGrainIntensity: Float {
        get {
            let v = keychainFloat(forKey: "last_grain_intensity")
            return v == nil ? 0.5 : Swift.min(Swift.max(v!, 0), 1)
        }
        set { setKeychainFloat(newValue, forKey: "last_grain_intensity") }
    }

    var lastGrainStyle: String {
        get { keychainString(forKey: "last_grain_style") ?? "Xiaomi" }
        set { setKeychainString(newValue, forKey: "last_grain_style") }
    }

    // MARK: - Keychain Helpers (equivalent to EncryptedSharedPreferences)

    private func keychainString(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func setKeychainString(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            newItem.merge(attributes) { _, new in new }
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    private func keychainFloat(forKey key: String) -> Float? {
        guard let str = keychainString(forKey: key) else { return nil }
        return Float(str)
    }

    private func setKeychainFloat(_ value: Float, forKey key: String) {
        setKeychainString(String(value), forKey: key)
    }

    private func keychainBool(forKey key: String) -> Bool? {
        guard let str = keychainString(forKey: key) else { return nil }
        return str == "true"
    }

    private func setKeychainBool(_ value: Bool, forKey key: String) {
        setKeychainString(value ? "true" : "false", forKey: key)
    }

    // MARK: - Migration (equivalent to Android's migrateFromLegacy)

    private func migrateIfNeeded() {
        let migrated = defaults.bool(forKey: "_settings_migrated")
        guard !migrated else { return }

        if defaults.object(forKey: "save_quality") == nil {
            defaults.set(100, forKey: "save_quality")
        }

        defaults.set(true, forKey: "_settings_migrated")
    }
}
