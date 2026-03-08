import Foundation
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

enum AnalyticsManager {
    static func configure() {
        #if canImport(FirebaseAnalytics)
        Analytics.setAnalyticsCollectionEnabled(true)
        #endif
    }

    static func logImageImported(source: String) {
        logEvent("image_imported", parameters: ["source": source])
    }

    static func logLutApplied(brand: String?, category: String?) {
        logEvent("lut_applied", parameters: [
            "brand": brand,
            "category": category,
        ])
    }

    static func logImageSaved(isProUser: Bool, hasWatermark: Bool) {
        logEvent("image_saved", parameters: [
            "is_pro": isProUser ? "true" : "false",
            "watermark": hasWatermark ? "true" : "false",
        ])
    }

    static func logSignIn(provider: String) {
        logEvent("auth_sign_in", parameters: ["provider": provider])
    }

    static func logSignOut() {
        logEvent("auth_sign_out")
    }

    static func logPresetSaved() {
        logEvent("preset_saved")
    }

    static func logPresetLoaded() {
        logEvent("preset_loaded")
    }

    static func updateProStatus(isProUser: Bool) {
        #if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(isProUser ? "true" : "false", forName: "is_pro_user")
        #endif
    }

    static func logSecurityBlocked(reason: String) {
        logEvent("security_blocked", parameters: ["reason": reason])
    }

    private static func logEvent(_ name: String, parameters: [String: String?] = [:]) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(name, parameters: parameters.compactMapValues(normalize))
        #endif
    }

    private static func normalize(_ value: String?) -> String? {
        guard let value else { return nil }

        let normalized = String(value.lowercased().unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "_"
        })
        let collapsed = normalized.replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
        let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(36))
    }
}
