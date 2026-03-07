import SwiftUI
import PhotosUI

struct EmptyStateView: View {
    @Binding var selectedPhotoItem: PhotosPickerItem?
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

                Image(systemName: "photo.badge.plus")
                    .font(.system(size: metrics.value(compact: 28, regular: 36, large: 36)))
                    .foregroundColor(.accentPrimary.opacity(0.85))
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

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: metrics.value(compact: 8, regular: 10, large: 10)) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: metrics.value(compact: 18, regular: 20, large: 20), weight: .medium))
                    Text(L10n.tr("btn_open_gallery"))
                        .font(.system(size: metrics.value(compact: 14, regular: 16, large: 16), weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(minWidth: metrics.value(compact: 180, regular: 220, large: 220))
                .frame(height: buttonHeight)
                .background(AndroidAccentGradientButtonBackground(cornerRadius: buttonHeight / 2))
                .clipShape(RoundedRectangle(cornerRadius: buttonHeight / 2, style: .continuous))
            }
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
