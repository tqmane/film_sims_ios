import SwiftUI

// AndroidのLivingBackground（aurora + noise overlay）のSwiftUI再実装。
struct LivingBackground: View {
    @State private var amberX: CGFloat = 0
    @State private var amberY: CGFloat = 0
    @State private var cyanX: CGFloat = 1
    @State private var cyanY: CGFloat = 0.5
    @State private var purpleX: CGFloat = 0.5
    @State private var purpleY: CGFloat = 1
    @State private var scalePulse: CGFloat = 0.9

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack {
                Color.surfaceDark

                // Amber light
                RadialGradient(
                    colors: [Color.accentPrimary.opacity(0.15), Color.accentPrimary.opacity(0.0)],
                    center: UnitPoint(
                        x: Double((0.2 * amberX + 0.1).clamped01),
                        y: Double((0.3 * amberY + 0.1).clamped01)
                    ),
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.4 * scalePulse
                )

                // Cyan light
                RadialGradient(
                    colors: [Color.secondaryStart.opacity(0.12), Color.secondaryStart.opacity(0.0)],
                    center: UnitPoint(
                        x: Double((0.8 * cyanX + 0.1).clamped01),
                        y: Double((0.7 * cyanY + 0.1).clamped01)
                    ),
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.35 * scalePulse
                )

                // Purple light
                RadialGradient(
                    colors: [Color.accentTertiary.opacity(0.10), Color.accentTertiary.opacity(0.0)],
                    center: UnitPoint(
                        x: Double((0.5 * purpleX + 0.3).clamped01),
                        y: Double((0.8 * purpleY + 0.1).clamped01)
                    ),
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.30 * scalePulse
                )

                NoiseOverlay(opacity: 0.03)
            }
            .ignoresSafeArea()
            .onAppear {
                // Androidのtween+Reverseに近い「ゆっくり往復」アニメーション
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    amberX = 1
                }
                withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                    amberY = 1
                }
                withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                    cyanX = 0
                }
                withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                    cyanY = 1
                }
                withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) {
                    purpleX = 0
                }
                withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                    purpleY = 0
                }
                withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                    scalePulse = 1.1
                }
            }
        }
    }
}

private struct NoiseOverlay: View {
    let opacity: Double

    @State private var noise: UIImage? = nil

    var body: some View {
        Rectangle()
            .fill(
                ImagePaint(
                    image: Image(uiImage: noise ?? UIImage()),
                    scale: 1
                )
            )
            .opacity(noise == nil ? 0 : opacity)
            .blendMode(.overlay)
            .allowsHitTesting(false)
            .onAppear {
                if noise == nil {
                    noise = Self.generateNoiseImage(width: 256, height: 256)
                }
            }
    }

    private static func generateNoiseImage(width: Int, height: Int) -> UIImage? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var data = Data(count: bytesPerRow * height)

        var seed: UInt32 = 12345
        data.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for i in 0..<(width * height) {
                // LCG（Androidの実装に合わせた簡易ノイズ）
                seed = seed &* 1103515245 &+ 12345
                let gray = UInt8((seed % 256))
                let o = i * 4
                base[o + 0] = gray
                base[o + 1] = gray
                base[o + 2] = gray
                base[o + 3] = 255
            }
        }

        let cs = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue))
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        guard let cg = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: cs,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else { return nil }

        return UIImage(cgImage: cg)
    }
}

private extension CGFloat {
    var clamped01: CGFloat {
        Swift.min(Swift.max(self, 0), 1)
    }
}
