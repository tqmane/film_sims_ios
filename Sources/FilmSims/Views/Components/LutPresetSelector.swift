import SwiftUI

struct LutPresetSelector: View {
    let luts: [LutItem]
    @Binding var selectedLut: LutItem?
    let sourceThumbnail: UIImage?
    @ObservedObject var viewModel: FilmSimsViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(luts) { lut in
                    LutPresetCard(
                        lut: lut,
                        isSelected: selectedLut == lut,
                        thumbnail: sourceThumbnail,
                        viewModel: viewModel
                    ) {
                        selectedLut = lut
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(height: 96)
    }
}

struct LutPresetCard: View {
    let lut: LutItem
    let isSelected: Bool
    let thumbnail: UIImage?
    @ObservedObject var viewModel: FilmSimsViewModel
    let action: () -> Void
    
    @State private var previewImage: UIImage?
    @State private var isLoading = true
    @State private var loadTask: Task<Void, Never>?
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack {
                    // Main card (Android: 86dp, corner 10dp)
                    ZStack {
                        if let previewImage = previewImage {
                            Image(uiImage: previewImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else if let thumbnail = thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .opacity(0.5)
                        } else {
                            Color.surfaceMedium
                        }
                    }
                    .frame(width: 86, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .background(Color.surfaceMedium)

                    if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.accentPrimary, lineWidth: 2)
                            .frame(width: 86, height: 86)
                    }

                    // Selection glow overlay (radial)
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [Color.accentPrimary.opacity(0.2), Color.clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 64
                                )
                            )
                            .frame(width: 86, height: 86)
                    }
                }

                Text(lut.name)
                    .font(.system(size: 9))
                    .foregroundColor(isSelected ? .textPrimary : .chipUnselectedText)
                    .tracking(0.01)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 86, height: 22, alignment: .top)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
            }
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

        loadTask?.cancel()
        loadTask = Task {
            let image = await viewModel.lutPreviewImage(for: lut)
            if Task.isCancelled { return }
            previewImage = image
            isLoading = false
        }
    }
}
