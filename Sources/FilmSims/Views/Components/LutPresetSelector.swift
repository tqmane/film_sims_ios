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

                    // Adjust hint overlay
                    if isSelected {
                        VStack(spacing: 2) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: max(8, cardSize * 0.12), weight: .semibold))
                                .foregroundColor(.white)
                            if cardSize >= 80 {
                                Text(L10n.tr("adjustments"))
                                    .font(.system(size: max(7, cardSize * 0.096), weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
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
                        .clipShape(
                            .rect(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: metrics.cardCorner,
                                bottomTrailingRadius: metrics.cardCorner,
                                topTrailingRadius: 0,
                                style: .continuous
                            )
                        )
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
            .padding(.leading, 2)
            .padding(.trailing, 6)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .onAppear {
            loadPreview()
        }
        .onChange(of: thumbnail) { _, _ in
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
