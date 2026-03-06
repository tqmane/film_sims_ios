import SwiftUI

enum AppMotion {
    static let panel = Animation.easeInOut(duration: 0.22)
    static let selection = Animation.easeInOut(duration: 0.18)
    static let press = Animation.easeOut(duration: 0.14)
    static let reset = Animation.easeOut(duration: 0.2)

    static func ambient(duration: Double) -> Animation {
        .easeInOut(duration: duration).repeatForever(autoreverses: true)
    }
}
