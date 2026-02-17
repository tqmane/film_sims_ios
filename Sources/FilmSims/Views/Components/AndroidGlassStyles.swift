import SwiftUI

// Android app's drawable styles reimplemented in SwiftUI.

struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct AndroidTopShadow: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.0), location: 0.0),
                .init(color: .black.opacity(0.314), location: 0.55),
                .init(color: .black.opacity(0.902), location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct AndroidRoundGlassBackground: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.glassSurface) // 0x20FFFFFF

            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color.glassSurfaceDark, location: 0.0), // 0x15FFFFFF
                            .init(color: Color.white.opacity(0.0), location: 1.0),
                        ],
                        center: UnitPoint(x: 0.5, y: 0.35),
                        startRadius: 0,
                        endRadius: 24
                    )
                )

            Circle()
                .stroke(Color.glassBorderAndroid, lineWidth: 1) // 0x18FFFFFF
        }
    }
}

struct AndroidAccentGradientButtonBackground: View {
    var cornerRadius: CGFloat = 24

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.accentStart, .accentEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.208), location: 0.0), // #35FFFFFF
                            .init(color: Color.white.opacity(0.0), location: 1.0),
                        ],
                        center: UnitPoint(x: 0.5, y: 0.30),
                        startRadius: 0,
                        endRadius: 80
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.0), location: 0.0),
                            .init(color: Color.white.opacity(0.0), location: 0.6),
                            .init(color: Color.white.opacity(0.125), location: 1.0), // #20FFFFFF
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }
}

// Brand/genre selector containers (glass rounded rectangles)
struct AndroidSelectorContainerBackground: View {
    var cornerRadius: CGFloat = 18

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.082)) // ~#15FFFFFF

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.055), location: 0.0),
                            .init(color: Color.white.opacity(0.0), location: 1.0),
                        ],
                        center: UnitPoint(x: 0.5, y: 0.2),
                        startRadius: 0,
                        endRadius: 140
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.094), lineWidth: 1) // #18FFFFFF
        }
    }
}

struct AndroidControlPanelBackground: View {
    var topRadius: CGFloat = 28

    var body: some View {
        ZStack {
            // Main glass background
            RoundedCornerShape(radius: topRadius, corners: [.topLeft, .topRight])
                .fill(Color(hex: "#101014").opacity(0.949)) // #F2101014

            // Inner gradient for depth (bottom gets slightly lighter)
            RoundedCornerShape(radius: topRadius, corners: [.topLeft, .topRight])
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.clear, location: 0.0),
                            .init(color: Color.white.opacity(0.024), location: 1.0), // #06FFFFFF
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Border stroke - subtle
            RoundedCornerShape(radius: topRadius, corners: [.topLeft, .topRight])
                .stroke(Color.white.opacity(0.0627), lineWidth: 1) // #10FFFFFF

            // Subtle accent glow at top center
            RoundedCornerShape(radius: topRadius, corners: [.topLeft, .topRight])
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color.accentPrimary.opacity(0.0627), location: 0.0), // #10FFAB60
                            .init(color: Color.clear, location: 1.0),
                        ],
                        center: UnitPoint(x: 0.5, y: -0.05),
                        startRadius: 0,
                        endRadius: 180
                    )
                )

            // Top edge highlight line (with 48dp side inset)
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.0), location: 0.0),
                                .init(color: Color.white.opacity(0.094), location: 0.5), // #18FFFFFF
                                .init(color: Color.white.opacity(0.0), location: 1.0),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .padding(.horizontal, 48)

                Spacer(minLength: 0)
            }
        }
    }
}
