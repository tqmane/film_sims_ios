import SwiftUI

// AndroidのLiquidSystem.ktにあるLiquidSlider / LiquidSectionHeader相当。

struct LiquidSectionHeader: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.accentPrimary)
            .tracking(0.12)
            .padding(.bottom, 8)
    }
}

struct LiquidSlider: View {
    @Binding var value: Float
    var enabled: Bool = true
    var range: ClosedRange<Float> = 0...1
    var onEditingChanged: ((Bool) -> Void)? = nil

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                .clamped01

            HStack(spacing: 0) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.glassSurfaceDark)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.accentPrimary)
                        .frame(width: width * progress, height: 6)
                }
                .frame(height: 40)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            guard enabled else { return }
                            if !isDragging {
                                isDragging = true
                                onEditingChanged?(true)
                            }
                            let x = min(max(0, g.location.x), width)
                            let p = Float(x / width)
                            value = range.lowerBound + p * (range.upperBound - range.lowerBound)
                        }
                        .onEnded { _ in
                            guard enabled else { return }
                            isDragging = false
                            onEditingChanged?(false)
                        }
                )
                .opacity(enabled ? 1 : 0.55)
            }
        }
        .frame(height: 40)
    }
}

private extension CGFloat {
    var clamped01: CGFloat {
        Swift.min(Swift.max(self, 0), 1)
    }
}
