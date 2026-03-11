import SwiftUI

/// Draggable before/after split overlay matching the Android ComparePreviewOverlay composable.
struct ComparePreviewOverlay: View {
    let split: Float
    let vertical: Bool
    let onSplitChange: (Float) -> Void

    @State private var dragActive = false

    var body: some View {
        GeometryReader { geometry in
            let maxW = geometry.size.width
            let maxH = geometry.size.height
            let available = vertical ? maxW : maxH
            let indicatorOffset = CGFloat(split) * available

            // Drag surface
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let axis = vertical ? value.location.x : value.location.y
                            if !dragActive {
                                let indicator = CGFloat(split) * available
                                guard abs(axis - indicator) <= 28 else { return }
                                dragActive = true
                            }
                            if dragActive {
                                let clamped = Float(min(max(0, axis), available) / available)
                                onSplitChange(clamped)
                            }
                        }
                        .onEnded { _ in
                            dragActive = false
                        }
                )

            // Labels
            if vertical {
                Text(L10n.tr("compare_after"))
                    .comparisonLabel()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 14)

                Text(L10n.tr("compare_before"))
                    .comparisonLabel()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, 14)
            } else {
                Text(L10n.tr("compare_after"))
                    .comparisonLabel()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                Text(L10n.tr("compare_before"))
                    .comparisonLabel()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }

            // Divider line + drag handle
            if vertical {
                Rectangle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .position(x: indicatorOffset, y: maxH / 2)

                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 6, height: 44)
                    .position(x: indicatorOffset, y: maxH / 2)
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.92))
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .position(x: maxW / 2, y: indicatorOffset)

                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 44, height: 6)
                    .position(x: maxW / 2, y: indicatorOffset)
            }
        }
        .padding(.vertical, 20)
    }
}

private extension Text {
    func comparisonLabel() -> some View {
        self
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.4))
            )
    }
}
