import SwiftUI
import PhotosUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers
import ImageIO

struct ContentView: View {
    @StateObject private var viewModel = FilmSimsViewModel()
    @ObservedObject private var proRepo = ProUserRepository.shared
    @State private var isSettingsPresented = false
    @State private var isShowingOriginal = false
    @State private var isImmersiveMode = false
    @State private var panelMode: BottomPanelMode = .selection
    @State private var selectedAdjustTab: LiquidAdjustPanel.AdjustTab = .intensity
    @State private var overlaySelectionSnapshot: LutItem?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let freeBrands: Set<String> = ["TECNO", "Nothing", "Nubia"]

    private enum BottomPanelMode: Equatable {
        case selection
        case adjustments
        case overlaySelection

        var isOverlaySelection: Bool {
            self == .overlaySelection
        }

        var showsAdjustments: Bool {
            self == .adjustments
        }
    }

    private var isSelectingOverlay: Bool {
        panelMode.isOverlaySelection
    }

    private var isShowingAdjustPanel: Bool {
        panelMode.showsAdjustments && viewModel.currentLut != nil
    }

    var body: some View {
        GeometryReader { geometry in
            let metrics = LayoutMetrics.from(
                size: geometry.size,
                horizontalSizeClass: horizontalSizeClass
            )
            if metrics.usesSidebar {
                sidebarLayout(geometry: geometry, metrics: metrics)
            } else {
                phoneLayout(geometry: geometry, metrics: metrics)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.55), value: isImmersiveMode)
        .animation(.spring(response: 0.45, dampingFraction: 0.55), value: panelMode)
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(viewModel: viewModel)
                .presentationBackground(.clear)
                .presentationDragIndicator(.hidden)
        }
        .onChangeCompat(of: viewModel.currentLut) { currentLut in
            if currentLut == nil && panelMode == .adjustments {
                panelMode = .selection
            }
        }
    }

    // MARK: - Phone Layout (bottom panel)
    @ViewBuilder
    private func phoneLayout(geometry: GeometryProxy, metrics: LayoutMetrics) -> some View {
        ZStack {
            LivingBackground()

            Group {
                if viewModel.originalImage == nil {
                    placeholderView(metrics: metrics)
                } else {
                    imagePreviewView
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .zIndex(0)

            if isShowingAdjustPanel {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { closeAdjustPanel() }
                    .zIndex(5)
            }

            VStack(spacing: 0) {
                if !isImmersiveMode {
                    topBar(metrics: metrics)
                        .padding(.top, geometry.safeAreaInsets.top + 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer(minLength: 0)

                if !isImmersiveMode && viewModel.originalImage != nil {
                    activeBottomPanel(metrics: metrics, showsDragHandle: true)
                        .padding(.bottom, max(8, geometry.safeAreaInsets.bottom))
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(10)
        }
        .environment(\.layoutMetrics, metrics)
    }

    // MARK: - iPad Sidebar Layout
    @ViewBuilder
    private func sidebarLayout(geometry: GeometryProxy, metrics: LayoutMetrics) -> some View {
        ZStack {
            LivingBackground()

            VStack(spacing: 0) {
                if !isImmersiveMode {
                    topBar(metrics: metrics)
                        .padding(.top, geometry.safeAreaInsets.top + 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                HStack(spacing: 0) {
                    ZStack {
                        Group {
                            if viewModel.originalImage == nil {
                                placeholderView(metrics: metrics)
                            } else {
                                imagePreviewView
                            }
                        }

                        if isShowingAdjustPanel {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { closeAdjustPanel() }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if !isImmersiveMode {
                        sidebarPanel(metrics: metrics)
                            .frame(width: metrics.sidebarWidth)
                            .padding(.bottom, geometry.safeAreaInsets.bottom)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .environment(\.layoutMetrics, metrics)
    }

    // MARK: - iPad Sidebar Panel
    @ViewBuilder
    private func sidebarPanel(metrics: LayoutMetrics) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(maxHeight: .infinity)
                .frame(width: 1)
                .overlay(alignment: .trailing) {
                    ScrollView {
                        activeBottomPanel(metrics: metrics, showsDragHandle: false)
                            .padding(.horizontal, metrics.panelHPad)
                            .padding(.vertical, 16)
                    }
                    .frame(width: metrics.sidebarWidth - 1)
                }
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "#1A1A22"), Color(hex: "#050508")],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private func activeBottomPanel(metrics: LayoutMetrics, showsDragHandle: Bool) -> some View {
        if isShowingAdjustPanel {
            LiquidAdjustPanel(
                viewModel: viewModel,
                selectedTab: $selectedAdjustTab,
                onClose: closeAdjustPanel,
                onSelectOverlayFilter: startOverlaySelection
            )
        } else {
            selectionPanel(metrics: metrics, showsDragHandle: showsDragHandle)
        }
    }

    // MARK: - Top Bar
    @ViewBuilder
    private func topBar(metrics: LayoutMetrics) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("FilmSims")
                    .font(.system(size: metrics.titleFontSize, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .tracking(0.005)

                Text(L10n.tr("subtitle_film_simulator").uppercased())
                    .font(.system(size: metrics.subtitleFontSize, weight: .medium))
                    .foregroundColor(.accentPrimary)
                    .tracking(0.15)
                    .padding(.top, metrics.category == .compact ? 1 : 3)
            }

            Spacer()

            HStack(spacing: 8) {
                PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                    Image(systemName: "plus")
                        .font(.system(size: metrics.category == .compact ? 15 : 19, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .frame(width: metrics.actionButtonSize, height: metrics.actionButtonSize)
                        .background(AndroidRoundGlassBackground())
                }

                Button(action: { isSettingsPresented = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: metrics.category == .compact ? 15 : 19, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .frame(width: metrics.actionButtonSize, height: metrics.actionButtonSize)
                        .background(AndroidRoundGlassBackground())
                }
                .padding(.trailing, 4)

                LiquidButton(action: { viewModel.saveImage() }, height: metrics.saveButtonHeight) {
                    HStack(spacing: metrics.category == .compact ? 3 : 5) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: metrics.category == .compact ? 12 : 15, weight: .semibold))
                        Text(L10n.tr("save"))
                            .font(.system(size: metrics.category == .compact ? 12 : 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                }
                .frame(width: metrics.saveButtonWidth)
            }
        }
        .padding(.horizontal, metrics.topBarHPad)
        .padding(.vertical, metrics.topBarVPad)
        .background(AndroidTopShadow())
    }

    // MARK: - Placeholder View
    @ViewBuilder
    private func placeholderView(metrics: LayoutMetrics) -> some View {
        EmptyStateView(selectedPhotoItem: $viewModel.selectedPhotoItem)
    }

    // MARK: - Image Preview View
    private var imagePreviewView: some View {
        ZoomableImageView(
            image: isShowingOriginal ? viewModel.originalImage : viewModel.processedImage,
            isImmersive: isImmersiveMode,
            onTap: {
                withAnimation { isImmersiveMode.toggle() }
            },
            onLongPressStart: {
                if viewModel.hasVisibleEdits {
                    isShowingOriginal = true
                }
            },
            onLongPressEnd: {
                isShowingOriginal = false
            }
        )
        .id(viewModel.imageLoadCount)
    }

    // MARK: - Selection Panel
    @ViewBuilder
    private func selectionPanel(metrics: LayoutMetrics, showsDragHandle: Bool) -> some View {
        VStack(spacing: 0) {
            if showsDragHandle {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 44, height: 4.5)
                    .padding(.top, 10)
                    .padding(.bottom, metrics.dragHandlePad)
            } else {
                Spacer().frame(height: 10)
            }

            selectionSections(metrics: metrics)
        }
        .padding(.horizontal, metrics.panelHPad)
        .padding(.bottom, metrics.panelBottomPad)
        .background(
            AndroidControlPanelBackground(topRadius: metrics.panelTopRadius)
        )
    }

    private func selectionSections(metrics: LayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.panelHintsEnabled {
                selectionNotice(metrics: metrics)
            }

            if viewModel.panelHintsEnabled && !proRepo.isProUser && !isSelectingOverlay {
                premiumNotice(metrics: metrics)
            }

            if isSelectingOverlay {
                overlaySelectionActions(metrics: metrics)
                    .padding(.bottom, metrics.category == .compact ? 10 : 12)
            }

            brandSection
            categorySection
            lutSection
        }
    }

    private func selectionNotice(metrics: LayoutMetrics) -> some View {
        LiquidNoticeCard(
            title: currentLookNoticeTitle,
            message: currentLookNoticeMessage,
            label: currentLookNoticeLabel
        )
        .padding(.bottom, metrics.category == .compact ? 10 : 12)
    }

    private func premiumNotice(metrics: LayoutMetrics) -> some View {
        LiquidNoticeCard(
            title: L10n.tr("more_brands_title"),
            message: L10n.tr("premium_brands_hint"),
            label: L10n.tr("label_pro"),
            accentColor: .accentSecondary
        )
        .padding(.bottom, metrics.category == .compact ? 10 : 14)
    }

    private var brandSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            LiquidSectionHeader(text: L10n.tr("header_camera"))
            BrandSelector(
                brands: viewModel.brands,
                selectedBrand: $viewModel.selectedBrand,
                isProUser: proRepo.isProUser,
                freeBrands: freeBrands
            )
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            LiquidSectionHeader(text: L10n.tr("header_style"))
            GenreSelector(
                categories: viewModel.currentCategories,
                selectedCategory: $viewModel.selectedCategory
            )
        }
    }

    private var lutSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            LiquidSectionHeader(text: L10n.tr("header_presets"))
            LutPresetSelector(
                luts: viewModel.currentLuts,
                selectedLut: activeLutBinding,
                sourceThumbnail: viewModel.thumbnailImage,
                viewModel: viewModel,
                onLutReselected: lutReselectAction,
                selectedHintKey: lutSelectedHintKey
            )
        }
    }

    private func overlaySelectionActions(metrics: LayoutMetrics) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if viewModel.overlayLut != nil {
                    LiquidChip(text: L10n.tr("overlay_remove"), isSelected: false) {
                        viewModel.clearOverlayLut()
                    }
                }

                LiquidChip(text: L10n.tr("overlay_done"), isSelected: false) {
                    finishOverlaySelection()
                }

                LiquidChip(text: L10n.tr("cancel"), isSelected: false) {
                    cancelOverlaySelection()
                }
            }
            .padding(.horizontal, metrics.scrollContentInset)
        }
    }

    private var lutReselectAction: (() -> Void)? {
        if isSelectingOverlay {
            return nil
        }

        return { openAdjustPanel() }
    }

    private var lutSelectedHintKey: String? {
        guard viewModel.panelHintsEnabled, !isSelectingOverlay else { return nil }
        return "adjustments"
    }

    private var activeLutBinding: Binding<LutItem?> {
        Binding(
            get: { isSelectingOverlay ? viewModel.overlayLut : viewModel.currentLut },
            set: { newValue in
                if isSelectingOverlay {
                    viewModel.overlayLut = newValue
                } else {
                    viewModel.currentLut = newValue
                }
            }
        )
    }

    private func openAdjustPanel() {
        guard viewModel.currentLut != nil else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
            panelMode = .adjustments
        }
    }

    private func closeAdjustPanel() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
            panelMode = .selection
        }
    }

    private func startOverlaySelection() {
        selectedAdjustTab = .intensity
        overlaySelectionSnapshot = viewModel.overlayLut
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
            panelMode = .overlaySelection
        }
    }

    private func finishOverlaySelection() {
        overlaySelectionSnapshot = nil
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
            panelMode = viewModel.currentLut == nil ? .selection : .adjustments
        }
    }

    private func cancelOverlaySelection() {
        viewModel.overlayLut = overlaySelectionSnapshot
        overlaySelectionSnapshot = nil
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
            panelMode = viewModel.currentLut == nil ? .selection : .adjustments
        }
    }

    private var currentLookNoticeTitle: String {
        if isSelectingOverlay {
            return L10n.tr("overlay_selection_title")
        }

        return viewModel.currentLut?.name
            ?? viewModel.selectedBrand?.displayName
            ?? L10n.tr("header_camera")
    }

    private var currentLookNoticeMessage: String {
        if isSelectingOverlay {
            return L10n.tr("overlay_selection_hint")
        }

        if viewModel.currentLut != nil {
            return L10n.tr("look_ready_hint")
        }
        return L10n.tr("look_preview_hint", viewModel.currentLuts.count)
    }

    private var currentLookNoticeLabel: String? {
        if isSelectingOverlay {
            return viewModel.overlayLut?.name ?? L10n.tr("overlay_filter_none")
        }
        return viewModel.selectedCategory?.displayName
    }
}
