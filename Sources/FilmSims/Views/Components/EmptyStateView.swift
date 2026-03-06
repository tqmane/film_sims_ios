import SwiftUI
import PhotosUI

struct EmptyStateView: View {
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Environment(\.layoutMetrics) private var metrics

    @State private var breathScale: CGFloat = 0.92
    @State private var breathAlpha: Double = 0.5

    private var outerSize: CGFloat {
        switch metrics.category {
        case .compact: 108
        case .regular: 130
        case .large: 148
        }
    }

    private var innerSize: CGFloat {
        switch metrics.category {
        case .compact: 80
        case .regular: 96
        case .large: 108
        }
    }

    private var titleFontSize: CGFloat {
        switch metrics.category {
        case .compact: 22
        case .regular: 28
        case .large: 30
        }
    }

    private var bodyFontSize: CGFloat {
        switch metrics.category {
        case .compact: 13
        case .regular: 15
        case .large: 16
        }
    }

    private var buttonHeight: CGFloat {
        switch metrics.category {
        case .compact: 48
        case .regular: 58
        case .large: 60
        }
    }

    private var contentPadding: CGFloat {
        switch metrics.category {
        case .compact: 28
        case .regular: 56
        case .large: 64
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: metrics.category == .compact ? 28 : 32, style: .continuous)
                    .fill(Color.accentPrimary.opacity(0.12))
                    .frame(width: outerSize, height: outerSize)
                    .scaleEffect(breathScale)
                    .opacity(breathAlpha * 0.4)

                RoundedRectangle(cornerRadius: metrics.category == .compact ? 22 : 24, style: .continuous)
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
                        RoundedRectangle(cornerRadius: metrics.category == .compact ? 22 : 24, style: .continuous)
                            .stroke(Color.accentPrimary.opacity(breathAlpha * 0.3), lineWidth: 1)
                    )
                    .frame(width: innerSize, height: innerSize)
                    .scaleEffect(breathScale)
                    .opacity(breathAlpha)

                Image(systemName: "photo.badge.plus")
                    .font(.system(size: metrics.category == .compact ? 28 : 36))
                    .foregroundColor(.accentPrimary.opacity(0.85))
            }

            Text(L10n.tr("label_pick_image"))
                .font(.system(size: titleFontSize, weight: .regular))
                .foregroundColor(.textPrimary)
                .padding(.top, metrics.category == .compact ? 24 : 32)

            Text(L10n.tr("desc_pick_image"))
                .font(.system(size: bodyFontSize))
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 12)

            Text(L10n.tr("workflow_title").uppercased())
                .font(.system(size: metrics.category == .compact ? 10 : 11, weight: .semibold))
                .foregroundColor(.accentPrimary)
                .tracking(0.12)
                .padding(.top, metrics.category == .compact ? 24 : 28)
                .padding(.bottom, 10)

            VStack(spacing: metrics.category == .compact ? 8 : 10) {
                WorkflowStepRow(stepNumber: 1, text: L10n.tr("workflow_step_import"))
                WorkflowStepRow(stepNumber: 2, text: L10n.tr("workflow_step_choose"))
                WorkflowStepRow(stepNumber: 3, text: L10n.tr("workflow_step_refine_save"))
            }
            .frame(maxWidth: metrics.category == .large ? 360 : 320)

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: metrics.category == .compact ? 8 : 10) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: metrics.category == .compact ? 18 : 20, weight: .medium))
                    Text(L10n.tr("btn_open_gallery"))
                        .font(.system(size: metrics.category == .compact ? 14 : 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(minWidth: metrics.category == .compact ? 180 : 220)
                .frame(height: buttonHeight)
                .background(AndroidAccentGradientButtonBackground(cornerRadius: buttonHeight / 2))
                .clipShape(RoundedRectangle(cornerRadius: buttonHeight / 2, style: .continuous))
            }
            .padding(.top, metrics.category == .compact ? 26 : 32)
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
                    .font(.system(size: metrics.category == .compact ? 11 : 12, weight: .semibold))
                    .foregroundColor(.accentPrimary)
            }
            .frame(width: metrics.category == .compact ? 24 : 28, height: metrics.category == .compact ? 24 : 28)

            Text(text)
                .font(.system(size: metrics.category == .compact ? 12 : 13))
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
        }
    }
}
