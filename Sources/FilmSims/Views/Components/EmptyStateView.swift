import SwiftUI
import PhotosUI
#if canImport(TipKit)
import TipKit
#endif

struct EmptyStateView: View {
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let showsTips: Bool
    @Environment(\.layoutMetrics) private var metrics

    @State private var breathScale: CGFloat = 0.92
    @State private var breathAlpha: Double = 0.5

    private var outerSize: CGFloat {
        metrics.value(compact: 108, regular: 130, large: 148)
    }

    private var innerSize: CGFloat {
        metrics.value(compact: 80, regular: 96, large: 108)
    }

    private var titleFontSize: CGFloat {
        metrics.value(compact: 22, regular: 28, large: 30)
    }

    private var bodyFontSize: CGFloat {
        metrics.value(compact: 13, regular: 15, large: 16)
    }

    private var buttonHeight: CGFloat {
        metrics.value(compact: 48, regular: 58, large: 60)
    }

    private var iconSize: CGFloat {
        metrics.value(compact: 30, regular: 38, large: 40)
    }

    private var contentPadding: CGFloat {
        metrics.value(compact: 28, regular: 56, large: 64)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: metrics.value(compact: 28, regular: 32, large: 32), style: .continuous)
                    .fill(Color.accentPrimary.opacity(0.12))
                    .frame(width: outerSize, height: outerSize)
                    .scaleEffect(breathScale)
                    .opacity(breathAlpha * 0.4)

                RoundedRectangle(cornerRadius: metrics.value(compact: 22, regular: 24, large: 24), style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.13),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: metrics.value(compact: 22, regular: 24, large: 24), style: .continuous)
                            .stroke(Color.accentPrimary.opacity(breathAlpha * 0.3), lineWidth: 1)
                    )
                    .frame(width: innerSize, height: innerSize)
                    .scaleEffect(breathScale)
                    .opacity(breathAlpha)

                PlaceholderPhotoBadgeIcon(
                    size: iconSize,
                    accentOpacity: 0.82 + ((breathAlpha - 0.5) * 0.18)
                )
                .frame(width: innerSize, height: innerSize)
                .scaleEffect(0.94 + ((breathScale - 0.92) * 0.6))
                .opacity(0.82 + ((breathAlpha - 0.5) * 0.22))
            }

            Text(L10n.tr("label_pick_image"))
                .font(.system(size: titleFontSize, weight: .regular))
                .foregroundColor(.textPrimary)
                .padding(.top, metrics.value(compact: 24, regular: 32, large: 32))

            Text(L10n.tr("desc_pick_image"))
                .font(.system(size: bodyFontSize))
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 12)

            Text(L10n.tr("workflow_title").uppercased())
                .font(.system(size: metrics.value(compact: 10, regular: 11, large: 11), weight: .semibold))
                .foregroundColor(.accentPrimary)
                .tracking(0.12)
                .padding(.top, metrics.value(compact: 24, regular: 28, large: 28))
                .padding(.bottom, 10)

            VStack(spacing: metrics.value(compact: 8, regular: 10, large: 10)) {
                WorkflowStepRow(stepNumber: 1, text: L10n.tr("workflow_step_import"))
                WorkflowStepRow(stepNumber: 2, text: L10n.tr("workflow_step_choose"))
                WorkflowStepRow(stepNumber: 3, text: L10n.tr("workflow_step_refine_save"))
            }
            .frame(maxWidth: metrics.value(compact: 320, regular: 320, large: 360))

            galleryButton
                .padding(.top, metrics.value(compact: 26, regular: 32, large: 32))
        }
        .padding(contentPadding)
        .onAppear {
            withAnimation(AppMotion.ambient(duration: 3.2)) {
                breathScale = 1.04
                breathAlpha = 0.92
            }
        }
    }

    @ViewBuilder
    private var galleryButton: some View {
        let spacing = metrics.value(compact: 8, regular: 10, large: 10)
        let symbolSize = metrics.value(compact: 18, regular: 20, large: 20)
        let textSize = metrics.value(compact: 14, regular: 16, large: 16)
        let minWidth = metrics.value(compact: 180, regular: 220, large: 220)
        let height = buttonHeight
        let cornerRadius = height / 2
        let button = PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            HStack(spacing: spacing) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: symbolSize, weight: .medium))
                Text(L10n.tr("btn_open_gallery"))
                    .font(.system(size: textSize, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(minWidth: minWidth)
            .frame(height: height)
            .background(AndroidAccentGradientButtonBackground(cornerRadius: cornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }

        if #available(iOS 17.0, *), FilmSimsTips.isSupported, showsTips {
            button.popoverTip(FilmSimsTips.ImportPhotoTip(), arrowEdge: .bottom)
        } else {
            button
        }
    }
}

private struct PlaceholderPhotoBadgeIcon: View {
    let size: CGFloat
    let accentOpacity: Double

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let lineWidth = max(1.5, size * 0.08)
            let frameRect = CGRect(
                x: w * 0.12,
                y: h * 0.18,
                width: w * 0.62,
                height: h * 0.50
            )

            let framePath = Path(
                roundedRect: frameRect,
                cornerRadius: size * 0.16
            )
            context.fill(
                framePath,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.24),
                        Color.white.opacity(0.08)
                    ]),
                    startPoint: CGPoint(x: frameRect.midX, y: frameRect.minY),
                    endPoint: CGPoint(x: frameRect.midX, y: frameRect.maxY)
                )
            )
            context.stroke(
                framePath,
                with: .color(.accentPrimary.opacity(accentOpacity)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )

            let sunRect = CGRect(
                x: frameRect.minX + (frameRect.width * 0.14),
                y: frameRect.minY + (frameRect.height * 0.14),
                width: size * 0.14,
                height: size * 0.14
            )
            context.fill(Path(ellipseIn: sunRect), with: .color(.accentPrimary.opacity(accentOpacity)))

            var ridgePath = Path()
            ridgePath.move(to: CGPoint(x: frameRect.minX + frameRect.width * 0.14, y: frameRect.maxY - frameRect.height * 0.18))
            ridgePath.addLine(to: CGPoint(x: frameRect.minX + frameRect.width * 0.38, y: frameRect.minY + frameRect.height * 0.52))
            ridgePath.addLine(to: CGPoint(x: frameRect.minX + frameRect.width * 0.52, y: frameRect.minY + frameRect.height * 0.66))
            ridgePath.addLine(to: CGPoint(x: frameRect.minX + frameRect.width * 0.72, y: frameRect.minY + frameRect.height * 0.38))
            context.stroke(
                ridgePath,
                with: .color(.accentPrimary.opacity(accentOpacity)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )

            let badgeDiameter = size * 0.34
            let badgeRect = CGRect(
                x: frameRect.maxX - (badgeDiameter * 0.22),
                y: frameRect.maxY - (badgeDiameter * 0.10),
                width: badgeDiameter,
                height: badgeDiameter
            )
            context.fill(Path(ellipseIn: badgeRect), with: .color(.accentPrimary))

            var plusVertical = Path()
            plusVertical.move(to: CGPoint(x: badgeRect.midX, y: badgeRect.minY + badgeDiameter * 0.25))
            plusVertical.addLine(to: CGPoint(x: badgeRect.midX, y: badgeRect.maxY - badgeDiameter * 0.25))
            context.stroke(
                plusVertical,
                with: .color(.white.opacity(0.95)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )

            var plusHorizontal = Path()
            plusHorizontal.move(to: CGPoint(x: badgeRect.minX + badgeDiameter * 0.25, y: badgeRect.midY))
            plusHorizontal.addLine(to: CGPoint(x: badgeRect.maxX - badgeDiameter * 0.25, y: badgeRect.midY))
            context.stroke(
                plusHorizontal,
                with: .color(.white.opacity(0.95)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
        }
        .frame(width: size, height: size)
    }
}

private struct WorkflowStepRow: View {
    let stepNumber: Int
    let text: String

    @Environment(\.layoutMetrics) private var metrics

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentPrimary.opacity(0.16))
                    .overlay(
                        Circle()
                            .stroke(Color.accentPrimary.opacity(0.28), lineWidth: 1)
                    )

                Text("\(stepNumber)")
                    .font(.system(size: metrics.value(compact: 11, regular: 12, large: 12), weight: .semibold))
                    .foregroundColor(.accentPrimary)
            }
            .frame(
                width: metrics.value(compact: 24, regular: 28, large: 28),
                height: metrics.value(compact: 24, regular: 28, large: 28)
            )

            Text(text)
                .font(.system(size: metrics.value(compact: 12, regular: 13, large: 13)))
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
        }
    }
}
