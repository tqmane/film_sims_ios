import SwiftUI

struct LutPresetSelector: View {
    let luts: [LutItem]
    @Binding var selectedLut: LutItem?
    let sourceThumbnail: UIImage?
    @ObservedObject var viewModel: FilmSimsViewModel
    var onLutReselected: (() -> Void)? = nil
    @Environment(\.layoutMetrics) private var metrics

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: metrics.cardSize > 80 ? 6 : 4) {
                ForEach(luts) { lut in
                    LutPresetCard(
                        lut: lut,
                        isSelected: selectedLut == lut,
                        thumbnail: sourceThumbnail,
                        viewModel: viewModel
                    ) {
                        if selectedLut == lut {
                            onLutReselected?()
                        } else {
                            selectedLut = lut
                        }
                    }
                }
            }
            .padding(.horizontal, metrics.scrollContentInset)
            .padding(.vertical, 2)
        }
        .frame(height: metrics.lutRowHeight)
    }
}

// MARK: - Shimmer Modifier (matches Android Shimmer 0.15→0.35/700ms)
private struct ShimmerModifier: ViewModifier {
    let active: Bool
    @State private var phase: CGFloat = 0.15

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if active {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: Color.white.opacity(phase), location: 0.5),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
                .allowsHitTesting(false)
            )
            .onAppear {
                guard active else { return }
                withAnimation(
                    .easeInOut(duration: 0.7)
                    .repeatForever(autoreverses: true)
                ) {
                    phase = 0.35
                }
            }
    }
}

struct LutPresetCard: View {
    let lut: LutItem
    let isSelected: Bool
    let thumbnail: UIImage?
    @ObservedObject var viewModel: FilmSimsViewModel
    let action: () -> Void
    @Environment(\.layoutMetrics) private var metrics

    @State private var previewImage: UIImage?
    @State private var isLoading = true
    @State private var loadTask: Task<Void, Never>?

    private var cardSize: CGFloat { metrics.cardSize }
    private var adjustHintHeight: CGFloat { max(20, cardSize * 0.29) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    // Card image
                    ZStack {
                        if let previewImage {
                            Image(uiImage: previewImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else if let thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .opacity(0.5)
                        } else {
                            Color.surfaceMedium
                        }
                    }
                    .frame(width: cardSize, height: cardSize)
                    .clipShape(RoundedRectangle(cornerRadius: metrics.cardCorner, style: .continuous))
                    .modifier(ShimmerModifier(active: isLoading))

                    // Android preview badge shown on the selected LUT card.
                    if isSelected {
                        HStack(spacing: max(2, cardSize * 0.03)) {
                            AdjustBadgeIcon(size: max(10, cardSize * 0.138))
                            Text(L10n.tr("adjustments"))
                                .font(.system(size: max(6.5, cardSize * 0.085), weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: adjustHintHeight)
                        .background(
                            LinearGradient(
                                colors: [Color.clear, Color.black.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(BottomCardHintShape(radius: metrics.cardCorner))
                    }

                    // Selection border
                    if isSelected {
                        RoundedRectangle(cornerRadius: metrics.cardCorner, style: .continuous)
                            .stroke(Color.accentPrimary, lineWidth: 2.5)
                            .frame(width: cardSize, height: cardSize)
                    }

                    // Selection glow
                    if isSelected {
                        RoundedRectangle(cornerRadius: metrics.cardCorner, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [Color.accentPrimary.opacity(0.18), Color.clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 64
                                )
                            )
                            .frame(width: cardSize, height: cardSize)
                    }
                }

                Text(lut.name)
                    .font(.system(size: metrics.cardTextSize))
                    .lineSpacing(2)
                    .foregroundColor(isSelected ? .textPrimary : .textTertiary)
                    .tracking(0.01)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: cardSize, alignment: .top)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
            }
            .padding(.horizontal, 3)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .onAppear {
            loadPreview()
        }
        .onChangeCompat(of: thumbnail) { _ in
            loadPreview()
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
    }

    private func loadPreview() {
        guard thumbnail != nil else { return }
        isLoading = true
        loadTask?.cancel()
        loadTask = Task {
            let image = await viewModel.lutPreviewImage(for: lut)
            if Task.isCancelled { return }
            await MainActor.run {
                previewImage = image
                isLoading = false
            }
        }
    }
}

private struct AdjustBadgeIcon: View {
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let stroke = max(1, size * 0.12)
            let knobRadius = size * 0.18

            var upper = Path()
            upper.move(to: CGPoint(x: 0, y: h * 0.28))
            upper.addLine(to: CGPoint(x: w, y: h * 0.28))
            context.stroke(upper, with: .color(.white), style: StrokeStyle(lineWidth: stroke, lineCap: .round))

            let upperCenter = CGPoint(x: w * 0.68, y: h * 0.28)
            context.fill(Path(ellipseIn: CGRect(
                x: upperCenter.x - knobRadius,
                y: upperCenter.y - knobRadius,
                width: knobRadius * 2,
                height: knobRadius * 2
            )), with: .color(.white))
            context.fill(Path(ellipseIn: CGRect(
                x: upperCenter.x - knobRadius * 0.45,
                y: upperCenter.y - knobRadius * 0.45,
                width: knobRadius * 0.9,
                height: knobRadius * 0.9
            )), with: .color(.black.opacity(0.6)))

            var lower = Path()
            lower.move(to: CGPoint(x: 0, y: h * 0.72))
            lower.addLine(to: CGPoint(x: w, y: h * 0.72))
            context.stroke(lower, with: .color(.white), style: StrokeStyle(lineWidth: stroke, lineCap: .round))

            let lowerCenter = CGPoint(x: w * 0.32, y: h * 0.72)
            context.fill(Path(ellipseIn: CGRect(
                x: lowerCenter.x - knobRadius,
                y: lowerCenter.y - knobRadius,
                width: knobRadius * 2,
                height: knobRadius * 2
            )), with: .color(.white))
            context.fill(Path(ellipseIn: CGRect(
                x: lowerCenter.x - knobRadius * 0.45,
                y: lowerCenter.y - knobRadius * 0.45,
                width: knobRadius * 0.9,
                height: knobRadius * 0.9
            )), with: .color(.black.opacity(0.6)))
        }
        .frame(width: size, height: size)
    }
}

private struct BottomCardHintShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
