import SwiftUI

/// Adaptive layout metrics derived from the current render canvas.
/// Uses the active iPhone render mode so Display Zoom and native device families
/// resolve to safer metrics than a single hard-coded width threshold.
struct LayoutMetrics: Sendable {
    enum Category: Sendable { case compact, regular, large }
    let category: Category
    let phoneBlend: CGFloat

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

    // Content insets for scroll containers (chips/cards start with breathing room)
    let scrollContentInset: CGFloat

    // MARK: - Factory
    static func from(size: CGSize, horizontalSizeClass: UserInterfaceSizeClass?) -> LayoutMetrics {
        let normalizedSize = normalized(size)
        let w = size.width
        let isIpad = isPad(size: normalizedSize, horizontalSizeClass: horizontalSizeClass)
        let useSidebar = isIpad && w > 750

        if isIpad {
            return ipadMetrics(containerWidth: w, useSidebar: useSidebar)
        }

        let resolvedPhoneSize = effectivePhoneCanvasSize(fallback: normalizedSize)
        let shortSide = resolvedPhoneSize.width
        let longSide = resolvedPhoneSize.height
        let isCompact = shortSide <= 375
        let phoneBlend = blendedPhoneProgress(shortSide: shortSide, longSide: longSide)

        if isCompact {
            return compactPhoneMetrics(shortSide: shortSide, longSide: longSide, phoneBlend: phoneBlend)
        }

        return regularPhoneMetrics(shortSide: shortSide, longSide: longSide, phoneBlend: phoneBlend)
    }

    private static func ipadMetrics(containerWidth: CGFloat, useSidebar: Bool) -> LayoutMetrics {
        LayoutMetrics(
            category: .large,
            phoneBlend: 1,
            chipHeight: 40, chipFontSize: 14, chipHPad: 18, chipCorner: 22,
            chipSpacing: 10, chipRowPadBottom: 14,
            cardSize: 110, lutRowHeight: 150, cardTextSize: 11, cardCorner: 14,
            panelHPad: 24, panelBottomPad: 24, dragHandlePad: 16, panelTopRadius: 26,
            headerFontSize: 13, headerBottomPad: 12,
            titleFontSize: 26, subtitleFontSize: 12, actionButtonSize: 48,
            saveButtonWidth: 110, saveButtonHeight: 48, topBarVPad: 18, topBarHPad: 32,
            adjustTabVPad: 13, adjustHPad: 24, adjustTabFontSize: 14,
            adjustTabTopPad: 16, adjustPanelCorner: 28,
            usesSidebar: useSidebar, sidebarWidth: useSidebar ? min(containerWidth * 0.42, 400) : 0,
            scrollContentInset: 0
        )
    }

    private static func compactPhoneMetrics(shortSide: CGFloat, longSide: CGFloat, phoneBlend: CGFloat) -> LayoutMetrics {
        let widthScale = clamped(shortSide / 375, min: 0.84, max: 1.0)
        let heightScale = clamped(longSide / 667, min: 0.84, max: 1.15)
        let layoutScale = min(widthScale, heightScale)
        let fontScale = clamped((widthScale * 0.85) + (heightScale * 0.15), min: 0.88, max: 1.0)

        return LayoutMetrics(
            category: .compact,
            phoneBlend: phoneBlend,
            chipHeight: scaled(28, by: layoutScale),
            chipFontSize: scaled(11, by: fontScale),
            chipHPad: scaled(10, by: layoutScale),
            chipCorner: scaled(14, by: layoutScale),
            chipSpacing: scaled(6, by: layoutScale),
            chipRowPadBottom: scaled(8, by: heightScale),
            cardSize: scaled(68, by: layoutScale),
            lutRowHeight: scaled(94, by: layoutScale),
            cardTextSize: scaled(9, by: fontScale),
            cardCorner: scaled(10, by: layoutScale),
            panelHPad: scaled(12, by: layoutScale),
            panelBottomPad: scaled(8, by: heightScale),
            dragHandlePad: scaled(8, by: heightScale),
            panelTopRadius: scaled(16, by: layoutScale),
            headerFontSize: scaled(10, by: fontScale),
            headerBottomPad: scaled(7, by: heightScale),
            titleFontSize: scaled(20, by: fontScale),
            subtitleFontSize: scaled(10, by: fontScale),
            actionButtonSize: scaled(36, by: layoutScale),
            saveButtonWidth: scaled(76, by: layoutScale),
            saveButtonHeight: scaled(38, by: layoutScale),
            topBarVPad: scaled(8, by: heightScale),
            topBarHPad: scaled(16, by: layoutScale),
            adjustTabVPad: scaled(7, by: heightScale),
            adjustHPad: scaled(12, by: layoutScale),
            adjustTabFontSize: scaled(11, by: fontScale),
            adjustTabTopPad: scaled(10, by: heightScale),
            adjustPanelCorner: scaled(18, by: layoutScale),
            usesSidebar: false,
            sidebarWidth: 0,
            scrollContentInset: scaled(12, by: layoutScale)
        )
    }

    private static func regularPhoneMetrics(shortSide: CGFloat, longSide: CGFloat, phoneBlend: CGFloat) -> LayoutMetrics {
        let widthScale = clamped(shortSide / 390, min: 0.95, max: 1.15)
        let heightScale = clamped(longSide / 844, min: 0.92, max: 1.15)
        let layoutScale = clamped(min(widthScale, heightScale + 0.06), min: 0.95, max: 1.14)
        let fontScale = clamped(min(widthScale, heightScale + 0.10), min: 0.96, max: 1.12)

        return LayoutMetrics(
            category: .regular,
            phoneBlend: phoneBlend,
            chipHeight: scaled(32, by: layoutScale),
            chipFontSize: scaled(12, by: fontScale),
            chipHPad: scaled(14, by: layoutScale),
            chipCorner: scaled(18, by: layoutScale),
            chipSpacing: scaled(8, by: layoutScale),
            chipRowPadBottom: scaled(10, by: heightScale),
            cardSize: scaled(84, by: layoutScale),
            lutRowHeight: scaled(116, by: layoutScale),
            cardTextSize: scaled(9, by: fontScale),
            cardCorner: scaled(11, by: layoutScale),
            panelHPad: scaled(16, by: layoutScale),
            panelBottomPad: scaled(14, by: heightScale),
            dragHandlePad: scaled(12, by: heightScale),
            panelTopRadius: scaled(20, by: layoutScale),
            headerFontSize: scaled(10.5, by: fontScale),
            headerBottomPad: scaled(9, by: heightScale),
            titleFontSize: scaled(23, by: fontScale),
            subtitleFontSize: scaled(10, by: fontScale),
            actionButtonSize: scaled(36, by: layoutScale),
            saveButtonWidth: scaled(72, by: layoutScale),
            saveButtonHeight: scaled(38, by: layoutScale),
            topBarVPad: scaled(14, by: heightScale),
            topBarHPad: scaled(20, by: layoutScale),
            adjustTabVPad: scaled(10, by: heightScale),
            adjustHPad: scaled(16, by: layoutScale),
            adjustTabFontSize: scaled(12, by: fontScale),
            adjustTabTopPad: scaled(12, by: heightScale),
            adjustPanelCorner: scaled(22, by: layoutScale),
            usesSidebar: false,
            sidebarWidth: 0,
            scrollContentInset: scaled(16, by: layoutScale)
        )
    }

    func phoneValue(compact: CGFloat, regular: CGFloat) -> CGFloat {
        switch category {
        case .large:
            return regular
        case .compact, .regular:
            return Self.interpolated(compact, regular, t: phoneBlend)
        }
    }

    func value(compact: CGFloat, regular: CGFloat, large: CGFloat) -> CGFloat {
        switch category {
        case .large:
            return large
        case .compact, .regular:
            return Self.interpolated(compact, regular, t: phoneBlend)
        }
    }

    private static func normalized(_ size: CGSize) -> CGSize {
        CGSize(width: min(size.width, size.height), height: max(size.width, size.height))
    }

    private static func blendedPhoneProgress(shortSide: CGFloat, longSide: CGFloat) -> CGFloat {
        let widthBlend = clamped((shortSide - 375) / 55, min: 0, max: 1)
        let heightBlend = clamped((longSide - 667) / 265, min: 0, max: 1)
        return max(widthBlend, heightBlend)
    }

    private static func scaled(_ value: CGFloat, by scale: CGFloat) -> CGFloat {
        ((value * scale) * 2).rounded() / 2
    }

    private static func interpolated(_ compact: CGFloat, _ regular: CGFloat, t: CGFloat) -> CGFloat {
        let value = compact + ((regular - compact) * t)
        return (value * 2).rounded() / 2
    }

    private static func clamped(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }

    private static func isPad(size: CGSize, horizontalSizeClass: UserInterfaceSizeClass?) -> Bool {
        horizontalSizeClass == .regular && size.width >= 700
    }

    private static func effectivePhoneCanvasSize(fallback: CGSize) -> CGSize {
        // geometry.size from a GeometryReader with .ignoresSafeArea() already reflects
        // the full screen canvas — including Display Zoom mode — so the fallback is correct.
        return fallback
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
