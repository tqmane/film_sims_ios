import Foundation
#if canImport(UIKit)
import UIKit
#endif
import MachO

/// iOS equivalent of Android's SecurityManager.
/// Performs jailbreak detection, debugger detection, and code integrity checks.
/// In DEBUG builds, always returns true (matches Android behavior).
final class SecurityManager: @unchecked Sendable {

    static let shared = SecurityManager()
    private init() {}

    // Cached result to avoid expensive re-computation on every call.
    private var cachedTrustResult: Bool?
    private var lastCheckTimestamp: TimeInterval = 0
    private let cacheTTL: TimeInterval = 60

    /// Comprehensive environment trust check.
    func isEnvironmentTrusted() -> Bool {
        #if DEBUG
        return true
        #else
        let now = Date().timeIntervalSince1970
        if let cached = cachedTrustResult, (now - lastCheckTimestamp) < cacheTTL {
            return cached
        }

        let result = !Self.isJailbroken() && !Self.isDebuggerAttached() && !Self.isHookingFrameworkPresent()

        cachedTrustResult = result
        lastCheckTimestamp = now
        return result
        #endif
    }

    /// Force re-evaluation on next call.
    func invalidateCache() {
        cachedTrustResult = nil
        lastCheckTimestamp = 0
    }

    // MARK: - Jailbreak Detection

    private static func isJailbroken() -> Bool {
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/usr/bin/ssh",
            "/private/var/lib/apt",
            "/private/var/lib/cydia",
            "/private/var/stash",
            "/usr/libexec/cydia",
            "/var/jb",
            "/var/binpack",
            "/usr/lib/TweakInject",
            "/var/Liy/.procursus_strapped",
            "/cores/binpack",
        ]

        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }

        // Check if app can write outside sandbox
        let testPath = "/private/jailbreak_test_\(UUID().uuidString)"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            // Expected — not jailbroken
        }

        return false
    }

    // MARK: - Debugger Detection

    private static func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        if result == 0 {
            return (info.kp_proc.p_flag & P_TRACED) != 0
        }
        return false
    }

    // MARK: - Hooking Framework Detection

    private static func isHookingFrameworkPresent() -> Bool {
        let fridaIndicators = [
            "FridaGadget",
            "frida-agent",
            "libfrida",
        ]

        let count = _dyld_image_count()
        for i in 0..<count {
            if let name = _dyld_get_image_name(i) {
                let imageName = String(cString: name)
                for indicator in fridaIndicators {
                    if imageName.localizedCaseInsensitiveContains(indicator) {
                        return true
                    }
                }
                if imageName.contains("MobileSubstrate") ||
                   imageName.contains("libsubstitute") ||
                   imageName.contains("SubstrateLoader") ||
                   imageName.contains("TweakInject") ||
                   imageName.contains("ElleKit") {
                    return true
                }
            }
        }

        // Check for Frida server on default port
        let fridaPort: UInt16 = 27042
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = fridaPort.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let sock = socket(AF_INET, SOCK_STREAM, 0)
        if sock >= 0 {
            let connected = withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    connect(sock, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            close(sock)
            if connected == 0 {
                return true
            }
        }

        return false
    }
}
