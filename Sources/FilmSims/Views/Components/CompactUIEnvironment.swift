import SwiftUI

private struct CompactUIKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// True when the device has a small screen (≤667 pt tall, e.g. iPhone SE 2/3).
    var compactUI: Bool {
        get { self[CompactUIKey.self] }
        set { self[CompactUIKey.self] = newValue }
    }
}
