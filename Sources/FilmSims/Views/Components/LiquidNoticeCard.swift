import SwiftUI

struct LiquidNoticeCard: View {
    let title: String
    let message: String
    var label: String? = nil
    var accentColor: Color = .accentPrimary

    @Environment(\.layoutMetrics) private var metrics

    private var cornerRadius: CGFloat {
        switch metrics.category {
        case .compact: 14
        case .regular: 16
        case .large: 18
        }
    }

    private var titleFontSize: CGFloat {
        switch metrics.category {
        case .compact: 13
        case .regular: 14
        case .large: 15
        }
    }

    private var messageFontSize: CGFloat {
        switch metrics.category {
        case .compact: 11
        case .regular: 12
        case .large: 13
        }
    }

    private var verticalPadding: CGFloat {
        switch metrics.category {
        case .compact: 10
        case .regular: 12
        case .large: 14
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: titleFontSize, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)

                    Text(message)
                        .font(.system(size: messageFontSize))
                        .foregroundColor(.textTertiary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if let label, !label.isEmpty {
                    Text(label.uppercased())
                        .font(.system(size: max(10, messageFontSize - 1), weight: .semibold))
                        .foregroundColor(Color(hex: "#0C0C10"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(accentColor)
                        )
                }
            }
        }
        .padding(.horizontal, metrics.category == .compact ? 12 : 14)
        .padding(.vertical, verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.071))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.102), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(0.10),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
    }
}
