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
        // Matches Android LiquidTopBar gradient: dark at top → transparent at bottom
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.02, green: 0.02, blue: 0.03).opacity(0.75), location: 0.0),
                .init(color: Color(red: 0.047, green: 0.047, blue: 0.067).opacity(0.5), location: 0.5),
                .init(color: .clear, location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct AndroidRoundGlassBackground: View {
    var body: some View {
        ZStack {
            // Android LiquidRoundButton: bg = 0x12FFFFFF, border = 0x14FFFFFF
            Circle()
                .fill(Color.white.opacity(0.071)) // 0x12FFFFFF

            Circle()
                .stroke(Color.white.opacity(0.078), lineWidth: 1) // 0x14FFFFFF
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
    var topRadius: CGFloat = 20

    var body: some View {
        ZStack {
            // Android GlassBottomSheet: SurfaceMedium(0.95) → SurfaceDark(0.97)
            RoundedCornerShape(radius: topRadius, corners: [.topLeft, .topRight])
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "#141419").opacity(0.95), location: 0.0), // SurfaceMedium
                            .init(color: Color(hex: "#0C0C11").opacity(0.97), location: 1.0), // SurfaceDark
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
                                .init(color: Color.white.opacity(0.157), location: 0.5), // 0x28FFFFFF
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
