import SwiftUI

struct ZoomableImageView: View {
    let image: UIImage?
    /// When this toggles to `true`, the view resets to centered position (immersive/fullscreen mode).
    var isImmersive: Bool = false
    /// Vertical offset applied to the image rest position so it doesn't sit behind the bottom panel.
    /// Negative values shift the image upward.
    var contentOffset: CGFloat = 0
    var onTap: (() -> Void)?
    var onLongPressStart: (() -> Void)?
    var onLongPressEnd: (() -> Void)?
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isLongPressing = false

    // Compute natural fit size of `img` within `frame` using .aspectRatio(.fit) rules.
    private func naturalFitSize(for img: UIImage, in frame: CGSize) -> CGSize {
        guard img.size.width > 0, img.size.height > 0,
              frame.width > 0, frame.height > 0 else { return frame }
        let imageAspect = img.size.width / img.size.height
        let frameAspect = frame.width / frame.height
        if imageAspect > frameAspect {
            return CGSize(width: frame.width, height: frame.width / imageAspect)
        } else {
            return CGSize(width: frame.height * imageAspect, height: frame.height)
        }
    }

    // Removed clampOffset to allow free panning

    var body: some View {
        GeometryReader { geometry in
            if let image = image {
                let effectiveOffset = CGSize(
                    width: offset.width,
                    height: offset.height + contentOffset
                )
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(effectiveOffset)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .gesture(
                        SimultaneousGesture(
                            // Magnification (pinch to zoom)
                            MagnificationGesture()
                                .onChanged { value in
                                    let newScale = lastScale * value
                                    scale = min(max(newScale, 0.1), 10.0)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                },
                            // Drag (pan)
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width:  lastOffset.width  + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                    )
                    .gesture(
                        // Double tap to reset
                        TapGesture(count: 2)
                            .onEnded {
                                withAnimation(AppMotion.reset) {
                                    scale = 1.0
                                    lastScale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                    )
                    .gesture(
                        // Single tap for immersive mode
                        TapGesture(count: 1)
                            .onEnded {
                                onTap?()
                            }
                    )
                    .gesture(
                        // Long press for before/after comparison
                        LongPressGesture(minimumDuration: 0.3)
                            .onEnded { _ in
                                isLongPressing = true
                                onLongPressStart?()
                            }
                            .sequenced(before: DragGesture(minimumDistance: 0))
                            .onEnded { _ in
                                if isLongPressing {
                                    isLongPressing = false
                                    onLongPressEnd?()
                                }
                            }
                    )
                    .onChangeCompat(of: isImmersive) { newValue in
                        // Auto-center when entering fullscreen immersive mode
                        if newValue {
                            withAnimation(AppMotion.reset) {
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                    }
            } else {
                Color.clear
            }
        }
    }
}
