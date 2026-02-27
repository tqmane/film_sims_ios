import SwiftUI

/// Matches Android's LiquidAdjustPanel: a tabbed panel with Intensity/Grain/Watermark tabs
/// that slides in above the control panel when a LUT card is tapped.
struct LiquidAdjustPanel: View {
    @ObservedObject var viewModel: FilmSimsViewModel
    @ObservedObject private var proRepo = ProUserRepository.shared
    @State private var selectedTab: AdjustTab = .intensity

    @Environment(\.compactUI) private var compactUI

    enum AdjustTab: String, CaseIterable {
        case intensity
        case grain
        case watermark
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar (matches Android pill-style tab row)
            tabBar
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Tab content
            Group {
                switch selectedTab {
                case .intensity:
                    intensityContent
                case .grain:
                    grainContent
                case .watermark:
                    watermarkContent
                }
            }
            .padding(.horizontal, compactUI ? 12 : 16)
            .padding(.bottom, compactUI ? 8 : 12)
        }
        .background(
            AndroidControlPanelBackground(topRadius: 20)
        )
    }

    // MARK: - Tab Bar (matches Android's pill-style AdjustTab row)
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AdjustTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tabLabel(for: tab))
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundColor(selectedTab == tab ? .white : .textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Group {
                                if selectedTab == tab {
                                    Capsule()
                                        .fill(Color.accentPrimary)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
        )
        .padding(.horizontal, compactUI ? 12 : 16)
    }

    private func tabLabel(for tab: AdjustTab) -> String {
        switch tab {
        case .intensity: return L10n.tr("adjustments")
        case .grain: return L10n.tr("grain")
        case .watermark:
            let label = L10n.tr("watermark")
            return proRepo.isProUser ? label : "\(label) 🔒"
        }
    }

    // MARK: - Intensity Tab Content
    private var intensityContent: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16))
                    .foregroundColor(.accentPrimary)

                Spacer().frame(width: 10)

                Text(L10n.tr("label_intensity"))
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)

                Spacer()

                Text("\(Int(viewModel.intensity * 100))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .frame(width: 40, alignment: .trailing)
            }
            .padding(.vertical, 6)

            LiquidSlider(value: $viewModel.intensity)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Grain Tab Content
    private var grainContent: some View {
        VStack(spacing: 0) {
            // Row 1: icon + label + percent + toggle
            HStack(spacing: 0) {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 18))
                    .foregroundColor(viewModel.grainEnabled ? .accentPrimary : .textTertiary)
                    .frame(width: 18)
                Spacer().frame(width: 12)
                Text(L10n.tr("label_film_grain"))
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                Spacer()
                Text("\(Int(viewModel.grainIntensity * 100))%")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(viewModel.grainEnabled ? .accentPrimary : .textTertiary)
                    .frame(width: 42, alignment: .trailing)
                    .padding(.trailing, 8)
                Toggle("", isOn: $viewModel.grainEnabled)
                    .labelsHidden()
                    .tint(.accentPrimary)
                    .frame(width: 24, height: 24)
                    .scaleEffect(0.8)
            }
            .padding(.vertical, 8)

            // Row 2: intensity slider
            LiquidSlider(value: $viewModel.grainIntensity, enabled: viewModel.grainEnabled)
                .padding(.bottom, 12)

            // Row 3: grain style selector
            HStack(spacing: 0) {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.accentSecondary)
                    .frame(width: 18)
                Spacer().frame(width: 12)
                Text(L10n.tr("label_grain_style"))
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .padding(.trailing, 12)
                HStack(spacing: 6) {
                    ForEach(["Xiaomi", "OnePlus"], id: \.self) { style in
                        ChipButton(
                            title: L10n.tr("grain_style_\(style.lowercased())"),
                            isSelected: viewModel.grainStyle == style,
                            enabled: viewModel.grainEnabled
                        ) {
                            if viewModel.grainEnabled {
                                viewModel.grainStyle = style
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .opacity(viewModel.grainEnabled ? 1 : 0.4)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Watermark Tab Content
    private var watermarkContent: some View {
        Group {
            if proRepo.isProUser {
                WatermarkView(viewModel: viewModel)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.textTertiary)
                    Text(L10n.tr("pro_watermark_locked"))
                        .font(.system(size: 13))
                        .foregroundColor(.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
        .padding(.bottom, 8)
    }
}
