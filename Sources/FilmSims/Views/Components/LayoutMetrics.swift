import SwiftUI

/// Adaptive layout metrics derived from device screen dimensions and size class.
/// Compact: iPhone SE/mini (h<700 || w<385), Regular: standard iPhone, Large: iPad
struct LayoutMetrics: Sendable {
    enum Category: Sendable { case compact, regular, large }
    let category: Category

    // Chip (brand/category selectors) — Android LiquidChip
    let chipHeight: CGFloat
    let chipFontSize: CGFloat
    let chipHPad: CGFloat
    let chipCorner: CGFloat
    let chipSpacing: CGFloat
    let chipRowPadBottom: CGFloat

    // LUT card carousel — Android LiquidLutCard
    let cardSize: CGFloat
    let lutRowHeight: CGFloat
    let cardTextSize: CGFloat
    let cardCorner: CGFloat

    // Control panel — Android GlassBottomSheet
    let panelHPad: CGFloat
    let panelBottomPad: CGFloat
    let dragHandlePad: CGFloat
    let panelTopRadius: CGFloat

    // Section header — Android LiquidSectionHeader
    let headerFontSize: CGFloat
    let headerBottomPad: CGFloat

    // Top bar — Android LiquidTopBar
    let titleFontSize: CGFloat
    let subtitleFontSize: CGFloat
    let actionButtonSize: CGFloat
    let saveButtonWidth: CGFloat
    let saveButtonHeight: CGFloat
    let topBarVPad: CGFloat
    let topBarHPad: CGFloat

    // Adjust panel tabs — Android LiquidTabBar
    let adjustTabVPad: CGFloat
    let adjustHPad: CGFloat
    let adjustTabFontSize: CGFloat
    let adjustTabTopPad: CGFloat
    let adjustPanelCorner: CGFloat

    // iPad sidebar
    let usesSidebar: Bool
    let sidebarWidth: CGFloat

    // MARK: - Factory
    static func from(size: CGSize, horizontalSizeClass: UserInterfaceSizeClass?) -> LayoutMetrics {
        let w = size.width
        let h = size.height
        let isIpad = horizontalSizeClass == .regular
        let isCompact = !isIpad && (h < 700 || w < 385)
        let useSidebar = isIpad && w > 750

        if isIpad {
            return LayoutMetrics(
                category: .large,
                chipHeight: 40, chipFontSize: 14, chipHPad: 18, chipCorner: 22,
                chipSpacing: 10, chipRowPadBottom: 14,
                cardSize: 110, lutRowHeight: 150, cardTextSize: 11, cardCorner: 14,
                panelHPad: 28, panelBottomPad: 24, dragHandlePad: 16, panelTopRadius: 26,
                headerFontSize: 13, headerBottomPad: 12,
                titleFontSize: 30, subtitleFontSize: 13, actionButtonSize: 48,
                saveButtonWidth: 110, saveButtonHeight: 50, topBarVPad: 18, topBarHPad: 28,
                adjustTabVPad: 13, adjustHPad: 28, adjustTabFontSize: 14,
                adjustTabTopPad: 16, adjustPanelCorner: 28,
                usesSidebar: useSidebar, sidebarWidth: useSidebar ? min(w * 0.42, 400) : 0
            )
        } else if isCompact {
            return LayoutMetrics(
                category: .compact,
                chipHeight: 28, chipFontSize: 11, chipHPad: 10, chipCorner: 14,
                chipSpacing: 6, chipRowPadBottom: 8,
                cardSize: 68, lutRowHeight: 94, cardTextSize: 9, cardCorner: 10,
                panelHPad: 12, panelBottomPad: 8, dragHandlePad: 8, panelTopRadius: 16,
                headerFontSize: 10, headerBottomPad: 7,
                titleFontSize: 20, subtitleFontSize: 10, actionButtonSize: 34,
                saveButtonWidth: 76, saveButtonHeight: 36, topBarVPad: 8, topBarHPad: 16,
                adjustTabVPad: 7, adjustHPad: 12, adjustTabFontSize: 11,
                adjustTabTopPad: 10, adjustPanelCorner: 18,
                usesSidebar: false, sidebarWidth: 0
            )
        } else {
            return LayoutMetrics(
                category: .regular,
                chipHeight: 36, chipFontSize: 13, chipHPad: 16, chipCorner: 20,
                chipSpacing: 8, chipRowPadBottom: 12,
                cardSize: 94, lutRowHeight: 130, cardTextSize: 10, cardCorner: 12,
                panelHPad: 18, panelBottomPad: 16, dragHandlePad: 14, panelTopRadius: 22,
                headerFontSize: 11.5, headerBottomPad: 10,
                titleFontSize: 26, subtitleFontSize: 11.5, actionButtonSize: 42,
                saveButtonWidth: 94, saveButtonHeight: 44, topBarVPad: 16, topBarHPad: 24,
                adjustTabVPad: 11, adjustHPad: 18, adjustTabFontSize: 13,
                adjustTabTopPad: 14, adjustPanelCorner: 24,
                usesSidebar: false, sidebarWidth: 0
            )
        }
    }
}

// MARK: - Environment Key
private struct LayoutMetricsKey: EnvironmentKey {
    static let defaultValue = LayoutMetrics.from(
        size: CGSize(width: 390, height: 844),
        horizontalSizeClass: nil
    )
}

extension EnvironmentValues {
    var layoutMetrics: LayoutMetrics {
        get { self[LayoutMetricsKey.self] }
        set { self[LayoutMetricsKey.self] = newValue }
    }
}
