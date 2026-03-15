import SwiftUI

/// A non-zoomable image view that splits between the processed (left/top) and original
/// (right/bottom) images at a given `split` position. Used during comparison mode.
struct CompareImageView: View {
    let originalImage: UIImage?
    let processedImage: UIImage?
    let split: Float
    let vertical: Bool
    var isImmersive: Bool = false
    /// Vertical offset applied to images so they don't sit behind the bottom panel.
    var contentOffset: CGFloat = 0
    var onTap: (() -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height

            if let original = originalImage, let processed = processedImage {
                ZStack {
                    // Original image (the "before" side – right / bottom)
                    Image(uiImage: original)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: w, height: h)

                    // Processed image (the "after" side – left / top), clipped
                    Image(uiImage: processed)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: w, height: h)
                        .clipShape(
                            SplitClipShape(split: CGFloat(split), vertical: vertical)
                        )
                }
                .offset(y: contentOffset)
                .onTapGesture { onTap?() }
            } else {
                Color.clear
            }
        }
    }
}

/// Clips the view to show only the "after" portion of the comparison.
private struct SplitClipShape: Shape {
    let split: CGFloat
    let vertical: Bool

    func path(in rect: CGRect) -> Path {
        if vertical {
            return Path(CGRect(x: 0, y: 0, width: rect.width * split, height: rect.height))
        } else {
            return Path(CGRect(x: 0, y: 0, width: rect.width, height: rect.height * split))
        }
    }
}
