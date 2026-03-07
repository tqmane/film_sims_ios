import SwiftUI

struct LiquidAdjustPanel: View {
    @ObservedObject var viewModel: FilmSimsViewModel
    @Binding var selectedTab: AdjustTab
    let onClose: () -> Void
    let onSelectOverlayFilter: () -> Void
    @ObservedObject private var proRepo = ProUserRepository.shared
    @Environment(\.layoutMetrics) private var metrics
    @State private var lockedMessageKey = "pro_adjust_tools_hint"
    @State private var isShowingSavePresetDialog = false
    @State private var presetDraftName = ""

    enum AdjustTab: String, CaseIterable {
        case intensity
        case adjust
        case grain
        case watermark
        case presets
    }

    private var currentTab: AdjustTab {
        if !proRepo.isProUser, [.adjust, .watermark, .presets].contains(selectedTab) {
            return .intensity
        }
        return selectedTab
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 4)

            if viewModel.panelHintsEnabled {
                LiquidNoticeCard(
                    title: viewModel.currentLut?.name ?? L10n.tr("adjustments"),
                    message: L10n.tr(adjustHintKey(for: currentTab)),
                    label: tabLabel(for: currentTab)
                )
                .padding(.top, 4)
                .padding(.bottom, metrics.phoneValue(compact: 10, regular: 12))
            }

            if viewModel.panelHintsEnabled && !proRepo.isProUser {
                LiquidNoticeCard(
                    title: L10n.tr("more_tools_title"),
                    message: L10n.tr(lockedMessageKey),
                    label: L10n.tr("label_pro"),
                    accentColor: .accentSecondary
                )
                .padding(.bottom, metrics.phoneValue(compact: 10, regular: 12))
            }

            tabBar
                .padding(.bottom, metrics.adjustTabTopPad)

            Group {
                switch currentTab {
                case .intensity:
                    intensityContent
                case .adjust:
                    adjustContent
                case .grain:
                    grainContent
                case .watermark:
                    watermarkContent
                case .presets:
                    presetsContent
                }
            }
        }
        .padding(.top, metrics.adjustTabTopPad)
        .padding(.bottom, 10)
        .padding(.horizontal, metrics.adjustHPad)
        .background(
            AndroidControlPanelBackground(topRadius: metrics.adjustPanelCorner)
        )
        .alert(L10n.tr("preset_save_title"), isPresented: $isShowingSavePresetDialog) {
            TextField(L10n.tr("preset_name_hint"), text: $presetDraftName)
            Button(L10n.tr("save")) {
                _ = viewModel.savePreset(named: presetDraftName)
                presetDraftName = ""
            }
            .disabled(presetDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button(L10n.tr("cancel"), role: .cancel) {
                presetDraftName = ""
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: onClose) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: metrics.phoneValue(compact: 10, regular: 11), weight: .semibold))
                    Text(L10n.tr("btn_close"))
                        .font(.system(size: metrics.phoneValue(compact: 12, regular: 13), weight: .medium))
                }
                .foregroundColor(.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(tabLabel(for: currentTab).uppercased())
                .font(.system(size: metrics.headerFontSize, weight: .semibold))
                .foregroundColor(.accentPrimary)
                .tracking(0.15)
        }
    }

    // MARK: - Tab Bar
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AdjustTab.allCases, id: \.self) { tab in
                let isSelected = currentTab == tab

                Button {
                    withAnimation(AppMotion.selection) {
                        guard isTabAvailable(tab) else {
                            lockedMessageKey = lockMessageKey(for: tab)
                            return
                        }
                        lockedMessageKey = "pro_adjust_tools_hint"
                        selectedTab = tab
                    }
                } label: {
                    Text(tabLabel(for: tab))
                        .font(.system(size: metrics.adjustTabFontSize, weight: isSelected ? .semibold : .regular))
                        .tracking(0.01)
                        .foregroundColor(isSelected ? Color(hex: "#0C0C10") : .textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, metrics.adjustTabVPad)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(isSelected ? Color.accentPrimary : Color.clear)
                        )
                        .animation(AppMotion.selection, value: isSelected)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(white: 1, opacity: 0.071))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color(white: 1, opacity: 0.0627), lineWidth: 1)
                )
        )
    }

    private func isTabAvailable(_ tab: AdjustTab) -> Bool {
        guard !proRepo.isProUser else { return true }
        switch tab {
        case .intensity, .grain:
            return true
        case .adjust, .watermark, .presets:
            return false
        }
    }

    private func lockMessageKey(for tab: AdjustTab) -> String {
        switch tab {
        case .adjust:
            return "pro_adjust_locked"
        case .watermark:
            return "pro_watermark_locked"
        case .presets:
            return "preset_pro_locked"
        case .intensity, .grain:
            return "pro_adjust_tools_hint"
        }
    }

    private func tabLabel(for tab: AdjustTab) -> String {
        switch tab {
        case .intensity:
            return L10n.tr("adjustments")
        case .adjust:
            let label = L10n.tr("tab_adjust")
            return proRepo.isProUser ? label : "\(label) 🔒"
        case .grain:
            return L10n.tr("grain")
        case .watermark:
            let label = L10n.tr("watermark")
            return proRepo.isProUser ? label : "\(label) 🔒"
        case .presets:
            let label = L10n.tr("tab_presets")
            return proRepo.isProUser ? label : "\(label) 🔒"
        }
    }

    private func adjustHintKey(for tab: AdjustTab) -> String {
        switch tab {
        case .intensity:
            return "adjust_hint_intensity"
        case .adjust:
            return "adjust_hint_basic"
        case .grain:
            return "adjust_hint_grain"
        case .watermark:
            return "adjust_hint_watermark"
        case .presets:
            return "adjust_hint_presets"
        }
    }

    // MARK: - Intensity Tab
    private var intensityContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            SliderInfoRow(
                icon: "slider.horizontal.3",
                accentColor: .accentPrimary,
                title: L10n.tr("label_intensity"),
                valueText: "\(Int(viewModel.intensity * 100))%"
            )
            LiquidSlider(value: $viewModel.intensity)
                .padding(.bottom, 14)

            LiquidSectionHeader(text: L10n.tr("overlay_filter"))
            Text(viewModel.overlayLut?.name ?? L10n.tr("overlay_filter_none"))
                .font(.system(size: metrics.phoneValue(compact: 13, regular: 14), weight: .medium))
                .foregroundColor(viewModel.overlayLut != nil ? .textPrimary : .textSecondary)
                .padding(.bottom, 4)

            Text(
                L10n.tr(viewModel.overlayLut == nil ? "overlay_filter_hint_empty" : "overlay_filter_hint_active")
            )
            .font(.system(size: metrics.phoneValue(compact: 11, regular: 12)))
            .foregroundColor(.textTertiary)
            .lineSpacing(4)
            .padding(.bottom, 12)

            HStack(spacing: 8) {
                LiquidChip(
                    text: L10n.tr(viewModel.overlayLut == nil ? "overlay_pick" : "overlay_change"),
                    isSelected: false,
                    action: onSelectOverlayFilter
                )

                if viewModel.overlayLut != nil {
                    LiquidChip(
                        text: L10n.tr("overlay_remove"),
                        isSelected: false
                    ) {
                        viewModel.clearOverlayLut()
                    }
                }
            }
            .padding(.bottom, viewModel.overlayLut != nil ? 10 : 0)

            if viewModel.overlayLut != nil {
                AdjustSliderRow(
                    label: L10n.tr("overlay_blend"),
                    value: $viewModel.overlayIntensity,
                    range: 0...1,
                    valueFormatter: { "\(Int($0 * 100))%" }
                )
            }
        }
    }

    // MARK: - Adjust Tab
    private var adjustContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button(L10n.tr("btn_reset_adjustments")) {
                    viewModel.resetAdjustments()
                }
                .buttonStyle(.plain)
                .font(.system(size: metrics.phoneValue(compact: 11, regular: 12), weight: .medium))
                .foregroundColor(.accentPrimary)
            }
            .padding(.bottom, 4)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    AdjustSliderRow(label: L10n.tr("label_exposure"), value: $viewModel.exposure, range: -2...2)
                    AdjustSliderRow(label: L10n.tr("label_contrast"), value: $viewModel.contrast, range: -1...1)
                    AdjustSliderRow(label: L10n.tr("label_highlights"), value: $viewModel.highlights, range: -1...1)
                    AdjustSliderRow(label: L10n.tr("label_shadows"), value: $viewModel.shadows, range: -1...1)
                    AdjustSliderRow(label: L10n.tr("label_color_temp"), value: $viewModel.colorTemp, range: -1...1)
                }
            }
            .frame(maxHeight: metrics.phoneValue(compact: 190, regular: 220))
        }
    }

    // MARK: - Grain Tab
    private var grainContent: some View {
        VStack(spacing: 0) {
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

            LiquidSlider(value: $viewModel.grainIntensity, enabled: viewModel.grainEnabled)
                .padding(.bottom, 14)

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
    }

    // MARK: - Watermark Tab
    private var watermarkContent: some View {
        Group {
            if proRepo.isProUser {
                WatermarkView(viewModel: viewModel)
            } else {
                lockedTabView(message: L10n.tr("pro_watermark_locked"))
            }
        }
    }

    // MARK: - Presets Tab
    private var presetsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button(L10n.tr("preset_save")) {
                    presetDraftName = ""
                    isShowingSavePresetDialog = true
                }
                .buttonStyle(.plain)
                .font(.system(size: metrics.phoneValue(compact: 11, regular: 12), weight: .medium))
                .foregroundColor(.accentPrimary)
                .disabled(viewModel.presets.count >= 20)
                .opacity(viewModel.presets.count >= 20 ? 0.5 : 1)
            }
            .padding(.bottom, viewModel.presets.count >= 20 ? 4 : 8)

            if viewModel.presets.count >= 20 {
                Text(L10n.tr("preset_limit_reached"))
                    .font(.system(size: metrics.phoneValue(compact: 11, regular: 12)))
                    .foregroundColor(.textTertiary)
                    .padding(.bottom, 8)
            }

            if viewModel.presets.isEmpty {
                Text(L10n.tr("preset_empty"))
                    .font(.system(size: metrics.phoneValue(compact: 12, regular: 13)))
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(viewModel.presets) { preset in
                            PresetRow(
                                preset: preset,
                                onLoad: { viewModel.loadPreset(preset) },
                                onDelete: { viewModel.deletePreset(preset) }
                            )
                        }
                    }
                }
                .frame(maxHeight: metrics.phoneValue(compact: 160, regular: 190))
            }
        }
    }

    private func lockedTabView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 24))
                .foregroundColor(.textTertiary)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

private struct SliderInfoRow: View {
    let icon: String
    let accentColor: Color
    let title: String
    let valueText: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(accentColor)

            Spacer().frame(width: 10)

            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)

            Spacer()

            Text(valueText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(accentColor)
                .frame(width: 52, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }
}

private struct AdjustSliderRow: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    var valueFormatter: (Float) -> String = {
        let percentage = Int($0 * 100)
        if percentage > 0 {
            return "+\(percentage)"
        }
        return "\(percentage)"
    }
    @Environment(\.layoutMetrics) private var metrics

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.system(size: metrics.phoneValue(compact: 11, regular: 12)))
                .foregroundColor(.textSecondary)
                .frame(width: metrics.phoneValue(compact: 72, regular: 82), alignment: .leading)

            LiquidSlider(value: $value, range: range)
                .frame(maxWidth: .infinity)

            Text(valueFormatter(value))
                .font(.system(size: metrics.phoneValue(compact: 11, regular: 12), weight: .medium))
                .foregroundColor(.accentPrimary)
                .frame(width: metrics.phoneValue(compact: 42, regular: 48), alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

private struct PresetRow: View {
    let preset: Preset
    let onLoad: () -> Void
    let onDelete: () -> Void
    @Environment(\.layoutMetrics) private var metrics

    private var lutName: String {
        preset.lutPath?
            .split(separator: "/")
            .last?
            .split(separator: ".")
            .dropLast()
            .joined(separator: ".") ?? "—"
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.system(size: metrics.phoneValue(compact: 12, regular: 14), weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Text(lutName)
                    .font(.system(size: metrics.phoneValue(compact: 10, regular: 11)))
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: metrics.phoneValue(compact: 12, regular: 14), weight: .medium))
                    .foregroundColor(.textTertiary)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onLoad)
    }
}
