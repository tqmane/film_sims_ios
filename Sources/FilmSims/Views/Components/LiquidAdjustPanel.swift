import SwiftUI

/// Matches Android's LiquidAdjustPanel: a tabbed panel with Intensity/Grain/Watermark tabs
/// that slides in above the control panel when a LUT card is tapped.
struct LiquidAdjustPanel: View {
    @ObservedObject var viewModel: FilmSimsViewModel
    @ObservedObject private var proRepo = ProUserRepository.shared
    @State private var selectedTab: AdjustTab = .intensity

    enum AdjustTab: String, CaseIterable {
        case intensity
        case grain
        case watermark
    }

    var body: some View {
        // Android LiquidAdjustPanel: topCorners 24dp, padding top=14/bottom=10/h=18
        VStack(spacing: 0) {
            // Tab bar (matches Android LiquidTabBar)
            tabBar
                .padding(.bottom, 14)

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
        }
        .padding(.top, 14)
        .padding(.bottom, 10)
        .padding(.horizontal, 18)
        .background(
            // Android: SurfaceMedium 95% → SurfaceDark 97%, topCorners 24dp
            AndroidControlPanelBackground(topRadius: 24)
        )
    }

    // MARK: - Tab Bar (matches Android LiquidTabBar exactly)
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AdjustTab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if tab == .watermark && !proRepo.isProUser {
                            // Show toast-like effect but don't switch tab
                        } else {
                            selectedTab = tab
                        }
                    }
                } label: {
                    // Android: NOT uppercase, 13sp, SemiBold when selected / Normal when not
                    Text(tabLabel(for: tab))
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .tracking(0.01)
                        .foregroundColor(isSelected ? Color(hex: "#0C0C10") : .textTertiary)
                        .frame(maxWidth: .infinity)
                        // Android: tab vertical padding 11dp, corner 18dp
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(isSelected ? Color.accentPrimary : Color.clear)
                        )
                        .animation(.easeInOut(duration: 0.25), value: isSelected)
                }
                .buttonStyle(.plain)
            }
        }
        // Android: RoundedRectangle(22dp), background 0x12FFFFFF, border 0x10FFFFFF, inner padding 4dp
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(white: 1, opacity: 0.071)) // 0x12FFFFFF
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color(white: 1, opacity: 0.0627), lineWidth: 1) // 0x10FFFFFF
                )
        )
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
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)

                Spacer()

                Text("\(Int(viewModel.intensity * 100))%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.accentPrimary)
                    .frame(width: 46, alignment: .trailing)
            }
            .padding(.vertical, 8)

            LiquidSlider(value: $viewModel.intensity)
                .padding(.bottom, 4)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Grain Tab Content (matches Android LiquidGrainControls)
    private var grainContent: some View {
        VStack(spacing: 0) {
            // Row 1: icon + label + percent + switch (Android: icon 20dp, font 14sp)
            HStack(spacing: 0) {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 20))
                    .foregroundColor(viewModel.grainEnabled ? .accentPrimary : .textTertiary)
                    .frame(width: 20)
                Spacer().frame(width: 12)
                Text(L10n.tr("label_film_grain"))
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                Spacer()
                Text("\(Int(viewModel.grainIntensity * 100))%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(viewModel.grainEnabled ? .accentPrimary : .textTertiary)
                    .frame(width: 46, alignment: .trailing)
                    .padding(.trailing, 8)
                Toggle("", isOn: $viewModel.grainEnabled)
                    .labelsHidden()
                    .tint(.accentPrimary)
            }
            .padding(.vertical, 8)

            // Row 2: intensity slider
            LiquidSlider(value: $viewModel.grainIntensity, enabled: viewModel.grainEnabled)
                .padding(.bottom, 14)

            // Row 3: grain style selector (Android: icon 20dp, font 14sp, spacedBy 8dp)
            HStack(spacing: 0) {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentSecondary)
                    .frame(width: 20)
                Spacer().frame(width: 12)
                Text(L10n.tr("label_grain_style"))
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .padding(.trailing, 12)
                HStack(spacing: 8) {
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
        .padding(.bottom, 4)
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
        .padding(.bottom, 4)
    }
}
