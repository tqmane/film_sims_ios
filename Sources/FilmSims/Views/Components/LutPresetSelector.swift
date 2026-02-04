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
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Glow layer (behind the card)
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentPrimary.opacity(0.251)) // #40FFAB60
                            .frame(width: 76, height: 76)
                    }
                    
                    // Main card
                    Group {
                        if let previewImage = previewImage {
                            Image(uiImage: previewImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else if let thumbnail = thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .overlay(
                                    ProgressView()
                                        .tint(.white)
                                )
                        } else {
                            Color.surfaceLight
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // Selection border
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                Color.accentPrimary,
                                lineWidth: 2
                            )
                            .frame(width: 72, height: 72)
                    }
                }
                
                Text(lut.name)
                    .font(.system(size: 9))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
                    .frame(width: 72)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            loadPreview()
        }
        .onChange(of: thumbnail) { _, _ in
            loadPreview()
        }
    }
    
    private func loadPreview() {
        guard thumbnail != nil else { return }
        
        Task {
            if let lutData = viewModel.getLut(for: lut) {
                previewImage = await viewModel.applyLutToThumbnail(lutData)
            }
            isLoading = false
        }
    }
}
