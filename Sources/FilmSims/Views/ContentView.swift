import SwiftUI
import PhotosUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers
import ImageIO
#if os(iOS)
import UIKit
#endif
#if canImport(TipKit)
import TipKit
#endif

struct ContentView: View {
    @StateObject private var viewModel = FilmSimsViewModel()
    @ObservedObject private var proRepo = ProUserRepository.shared
    @ObservedObject private var incomingImageCoordinator = IncomingImageCoordinator.shared
    @State private var isSettingsPresented = false
    @State private var isShowingOriginal = false
    @State private var isImmersiveMode = false
    @State private var panelMode: BottomPanelMode = .selection
    @State private var selectedAdjustTab: LiquidAdjustPanel.AdjustTab = .intensity
    @State private var overlaySelectionSnapshot: LutItem?
    @State private var compareEnabled = false
    @State private var comparePosition: Float = 0.5
    @State private var compareVertical = true
    /// Measured height of the bottom panel (phone layout), used to offset the image upward.
    @State private var bottomPanelHeight: CGFloat = 0
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
                ipadLayout(geometry: geometry, metrics: metrics)
            } else {
                phoneLayout(geometry: geometry, metrics: metrics)
            }
        }
        .ignoresSafeArea()
        .animation(AppMotion.panel, value: isImmersiveMode)
        .animation(AppMotion.panel, value: panelMode)
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(viewModel: viewModel)
                .presentationBackground(.clear)
                .presentationDragIndicator(.hidden)
        }
        .onAppear(perform: processPendingIncomingImage)
        .onChangeCompat(of: incomingImageCoordinator.pendingRequest?.id) { _ in
            processPendingIncomingImage()
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
        let safeArea = resolvedSafeAreaInsets(for: geometry)
        // Shift image upward by a fraction of the panel height so it doesn't hide behind controls.
        // Use ~40% of the measured panel height; in immersive mode reset to zero.
        let imageOffset: CGFloat = (!isImmersiveMode && viewModel.originalImage != nil)
            ? -(bottomPanelHeight * 0.4) : 0

        ZStack {
            LivingBackground()

            Group {
                if viewModel.originalImage == nil {
                    placeholderView(metrics: metrics, safeArea: safeArea)
                } else {
                    imagePreviewView(contentOffset: imageOffset)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .zIndex(0)

            VStack(spacing: 0) {
                if !isImmersiveMode {
                    topBar(metrics: metrics)
                        .padding(.top, safeArea.top + 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer(minLength: 0)

                if !isImmersiveMode && viewModel.originalImage != nil {
                    activeBottomPanel(metrics: metrics, showsDragHandle: true)
                        .background(
                            GeometryReader { panelGeo in
                                Color.clear.preference(
                                    key: PanelHeightPreferenceKey.self,
                                    value: panelGeo.size.height
                                )
                            }
                        )
                        .onPreferenceChange(PanelHeightPreferenceKey.self) { height in
                            bottomPanelHeight = height
                        }
                        .padding(.bottom, max(8, safeArea.bottom))
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(10)
        }
        .ignoresSafeArea()
        .environment(\.layoutMetrics, metrics)
    }

    // MARK: - iPad Layout (sidebar + main)
    @ViewBuilder
    private func ipadLayout(geometry: GeometryProxy, metrics: LayoutMetrics) -> some View {
        let safeArea = resolvedSafeAreaInsets(for: geometry)
        let hasImage = viewModel.originalImage != nil

        ZStack {
            LivingBackground()

            if hasImage {
                // Image positioned in the area to the right of the sidebar
                let imageAreaWidth = geometry.size.width - metrics.sidebarWidth
                HStack(spacing: 0) {
                    Spacer().frame(width: metrics.sidebarWidth)
                    imagePreviewView(contentOffset: 0)
                        .frame(width: imageAreaWidth, height: geometry.size.height)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .zIndex(0)

                // Sidebar background extended into left safe area — sits above image
                HStack(spacing: 0) {
                    AndroidSidebarBackground()
                        .frame(width: metrics.sidebarWidth + safeArea.leading)
                    Spacer(minLength: 0)
                }
                .ignoresSafeArea()
                .zIndex(5)

                HStack(spacing: 0) {
                    // Left: Sidebar with selectors
                    ipadSidebar(metrics: metrics, safeArea: safeArea)
                        .frame(width: metrics.sidebarWidth)

                    Spacer(minLength: 0)

                    // Top bar overlay (over image area only, to the right of sidebar)
                    VStack(spacing: 0) {
                        if !isImmersiveMode {
                            topBar(metrics: metrics, showsTitle: false)
                                .padding(.top, safeArea.top + 4)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(width: geometry.size.width - metrics.sidebarWidth)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(10)
            } else {
                // No image: full-width placeholder with normal top bar (shows title)
                ZStack {
                    placeholderView(metrics: metrics, safeArea: safeArea)
                        .frame(width: geometry.size.width, height: geometry.size.height)

                    VStack(spacing: 0) {
                        if !isImmersiveMode {
                            topBar(metrics: metrics, showsTitle: true)
                                .padding(.top, safeArea.top + 4)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .ignoresSafeArea()
        .environment(\.layoutMetrics, metrics)
    }

    // MARK: - iPad Sidebar
    @ViewBuilder
    private func ipadSidebar(metrics: LayoutMetrics, safeArea: EdgeInsets) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Title in sidebar
                VStack(alignment: .leading, spacing: 2) {
                    Text("FilmSims")
                        .font(.system(size: metrics.titleFontSize, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .tracking(0.005)

                    Text(L10n.tr("subtitle_film_simulator").uppercased())
                        .font(.system(size: metrics.subtitleFontSize, weight: .medium))
                        .foregroundColor(.accentPrimary)
                        .tracking(0.15)
                        .padding(.top, 3)
                }
                .padding(.bottom, 20)

                if viewModel.originalImage != nil {
                    if viewModel.panelHintsEnabled {
                        selectionNotice(metrics: metrics)
                    }

                    if viewModel.panelHintsEnabled && !proRepo.isProUser && !isSelectingOverlay {
                        premiumNotice(metrics: metrics)
                    }

                    if isSelectingOverlay {
                        overlaySelectionActions(metrics: metrics)
                            .padding(.bottom, 12)
                    }

                    brandSection
                    categorySection
                    lutSection

                    // Adjust panel content inline in sidebar when a LUT is selected
                    if viewModel.currentLut != nil {
                        Divider()
                            .background(Color.white.opacity(0.08))
                            .padding(.vertical, 16)

                        ipadAdjustSection(metrics: metrics)
                    }
                }
            }
            .padding(.horizontal, metrics.panelHPad)
            .padding(.top, safeArea.top + 16)
            .padding(.bottom, max(safeArea.bottom, 24))
        }
        .background(Color.clear)
    }

    // MARK: - iPad Adjust Section (inline in sidebar)
    @ViewBuilder
    private func ipadAdjustSection(metrics: LayoutMetrics) -> some View {
        LiquidAdjustPanel(
            viewModel: viewModel,
            selectedTab: $selectedAdjustTab,
            onSelectOverlayFilter: startOverlaySelection,
            compareEnabled: $compareEnabled,
            comparePosition: $comparePosition,
            compareVertical: $compareVertical,
            isInline: true
        )
    }

    // MARK: - iPad Placeholder
    @ViewBuilder
    private func ipadPlaceholderView(metrics: LayoutMetrics, safeArea: EdgeInsets) -> some View {
        let topReserved = isImmersiveMode ? safeArea.top : topBarReservedHeight(metrics: metrics, safeArea: safeArea)

        VStack(spacing: 0) {
            Color.clear
                .frame(height: topReserved)

            Spacer(minLength: 0)

            EmptyStateView(
                selectedPhotoItem: $viewModel.selectedPhotoItem,
                showsTips: viewModel.panelHintsEnabled
            )
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func activeBottomPanel(metrics: LayoutMetrics, showsDragHandle: Bool) -> some View {
        if isShowingAdjustPanel {
            LiquidAdjustPanel(
                viewModel: viewModel,
                selectedTab: $selectedAdjustTab,
                onClose: closeAdjustPanel,
                onSelectOverlayFilter: startOverlaySelection,
                compareEnabled: $compareEnabled,
                comparePosition: $comparePosition,
                compareVertical: $compareVertical
            )
        } else {
            selectionPanel(metrics: metrics, showsDragHandle: showsDragHandle)
        }
    }

    // MARK: - Top Bar
    @ViewBuilder
    private func topBar(metrics: LayoutMetrics, showsTitle: Bool = true) -> some View {
        HStack(alignment: .center) {
            if showsTitle {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FilmSims")
                        .font(.system(size: metrics.titleFontSize, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .tracking(0.005)

                    Text(L10n.tr("subtitle_film_simulator").uppercased())
                        .font(.system(size: metrics.subtitleFontSize, weight: .medium))
                        .foregroundColor(.accentPrimary)
                        .tracking(0.15)
                        .padding(.top, metrics.phoneValue(compact: 1, regular: 3))
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if viewModel.hasVisibleEdits {
                    Button(action: { compareEnabled.toggle() }) {
                        Image(systemName: "square.split.2x1")
                            .font(.system(size: metrics.phoneValue(compact: 15, regular: 19), weight: .medium))
                            .foregroundColor(compareEnabled ? .accentPrimary : .textPrimary)
                            .frame(width: metrics.actionButtonSize, height: metrics.actionButtonSize)
                            .background(AndroidRoundGlassBackground())
                    }
                }

                PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                    Image(systemName: "plus")
                        .font(.system(size: metrics.phoneValue(compact: 15, regular: 19), weight: .medium))
                        .foregroundColor(.textPrimary)
                        .frame(width: metrics.actionButtonSize, height: metrics.actionButtonSize)
                        .background(AndroidRoundGlassBackground())
                }

                Button(action: { isSettingsPresented = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: metrics.phoneValue(compact: 15, regular: 19), weight: .medium))
                        .foregroundColor(.textPrimary)
                        .frame(width: metrics.actionButtonSize, height: metrics.actionButtonSize)
                        .background(AndroidRoundGlassBackground())
                }
                .padding(.trailing, 4)

                saveButton(metrics: metrics)
            }
        }
        .padding(.horizontal, metrics.topBarHPad)
        .padding(.vertical, metrics.topBarVPad)
        .background(AndroidTopShadow())
    }

    // MARK: - Placeholder View
    @ViewBuilder
    private func placeholderView(metrics: LayoutMetrics, safeArea: EdgeInsets) -> some View {
        let topReserved = isImmersiveMode ? safeArea.top : topBarReservedHeight(metrics: metrics, safeArea: safeArea)
        let bottomReserved = safeArea.bottom + metrics.phoneValue(compact: 12, regular: 18)

        VStack(spacing: 0) {
            Color.clear
                .frame(height: topReserved)

            Spacer(minLength: 0)

            EmptyStateView(
                selectedPhotoItem: $viewModel.selectedPhotoItem,
                showsTips: viewModel.panelHintsEnabled
            )
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            Color.clear
                .frame(height: bottomReserved)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Image Preview View
    @ViewBuilder
    private func imagePreviewView(contentOffset: CGFloat) -> some View {
        ZStack {
            if compareEnabled && !isShowingOriginal && viewModel.hasVisibleEdits {
                CompareImageView(
                    originalImage: viewModel.originalImage,
                    processedImage: viewModel.processedImage,
                    split: comparePosition,
                    vertical: compareVertical,
                    isImmersive: isImmersiveMode,
                    contentOffset: contentOffset,
                    onTap: { withAnimation { isImmersiveMode.toggle() } }
                )
                .id(viewModel.imageLoadCount)

                ComparePreviewOverlay(
                    split: comparePosition,
                    vertical: compareVertical,
                    onSplitChange: { comparePosition = $0 }
                )
                .allowsHitTesting(true)
            } else {
                ZoomableImageView(
                    image: isShowingOriginal ? viewModel.originalImage : viewModel.processedImage,
                    isImmersive: isImmersiveMode,
                    contentOffset: contentOffset,
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
        }
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
                    .padding(.bottom, metrics.phoneValue(compact: 10, regular: 12))
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
        .padding(.bottom, metrics.phoneValue(compact: 10, regular: 12))
    }

    private func premiumNotice(metrics: LayoutMetrics) -> some View {
        LiquidNoticeCard(
            title: L10n.tr("more_brands_title"),
            message: L10n.tr("premium_brands_hint"),
            label: L10n.tr("label_pro"),
            accentColor: .accentSecondary
        )
        .padding(.bottom, metrics.phoneValue(compact: 10, regular: 14))
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

    @ViewBuilder
    private var lutSection: some View {
        let section = VStack(alignment: .leading, spacing: 0) {
            LiquidSectionHeader(text: L10n.tr("header_presets"))
            LutPresetSelector(
                luts: viewModel.currentLuts,
                selectedLut: activeLutBinding,
                sourceThumbnail: viewModel.thumbnailImage,
                viewModel: viewModel,
                onLutReselected: lutReselectAction
            )
        }

        if #available(iOS 17.0, *), FilmSimsTips.isSupported, viewModel.panelHintsEnabled, viewModel.currentLut == nil {
            section.popoverTip(FilmSimsTips.ChooseLookTip(), arrowEdge: .top)
        } else {
            section
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
        withAnimation(AppMotion.panel) {
            panelMode = .adjustments
        }
    }

    private func closeAdjustPanel() {
        withAnimation(AppMotion.panel) {
            panelMode = .selection
        }
    }

    private func startOverlaySelection() {
        selectedAdjustTab = .intensity
        overlaySelectionSnapshot = viewModel.overlayLut
        withAnimation(AppMotion.panel) {
            panelMode = .overlaySelection
        }
    }

    private func finishOverlaySelection() {
        overlaySelectionSnapshot = nil
        withAnimation(AppMotion.panel) {
            panelMode = viewModel.currentLut == nil ? .selection : .adjustments
        }
    }

    private func cancelOverlaySelection() {
        viewModel.overlayLut = overlaySelectionSnapshot
        overlaySelectionSnapshot = nil
        withAnimation(AppMotion.panel) {
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
        return viewModel.currentLutCategoryDisplayName ?? viewModel.selectedCategory?.displayName
    }

    private func topBarReservedHeight(metrics: LayoutMetrics, safeArea: EdgeInsets) -> CGFloat {
        let titleBlockHeight = metrics.titleFontSize + metrics.subtitleFontSize + metrics.phoneValue(compact: 6, regular: 8)
        let controlsHeight = max(metrics.actionButtonSize, metrics.saveButtonHeight)
        return safeArea.top + max(titleBlockHeight, controlsHeight) + (metrics.topBarVPad * 2) + metrics.phoneValue(compact: 8, regular: 12)
    }

    @ViewBuilder
    private func saveButton(metrics: LayoutMetrics) -> some View {
        let button = LiquidButton(action: { viewModel.saveImage() }, height: metrics.saveButtonHeight) {
            HStack(spacing: metrics.phoneValue(compact: 3, regular: 5)) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: metrics.phoneValue(compact: 12, regular: 15), weight: .semibold))
                Text(L10n.tr("save"))
                    .font(.system(size: metrics.phoneValue(compact: 12, regular: 14), weight: .semibold))
            }
            .foregroundColor(.white)
        }
        .frame(width: metrics.saveButtonWidth)

        if #available(iOS 17.0, *), FilmSimsTips.isSupported, viewModel.panelHintsEnabled, viewModel.currentLut != nil {
            button.popoverTip(FilmSimsTips.RefineSaveTip(), arrowEdge: .bottom)
        } else {
            button
        }
    }

    private func resolvedSafeAreaInsets(for geometry: GeometryProxy) -> EdgeInsets {
        #if os(iOS)
        let windowInsets = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets ?? .zero

        return EdgeInsets(
            top: max(geometry.safeAreaInsets.top, windowInsets.top),
            leading: max(geometry.safeAreaInsets.leading, windowInsets.left),
            bottom: max(geometry.safeAreaInsets.bottom, windowInsets.bottom),
            trailing: max(geometry.safeAreaInsets.trailing, windowInsets.right)
        )
        #else
        return geometry.safeAreaInsets
        #endif
    }

    private func processPendingIncomingImage() {
        guard let request = incomingImageCoordinator.pendingRequest else { return }

        Task {
            let handled = await viewModel.handleIncomingImage(request)
            await MainActor.run {
                if handled {
                    isImmersiveMode = false
                    isShowingOriginal = false
                    panelMode = .selection
                }
                incomingImageCoordinator.consume(request)
            }
        }
    }
}

// MARK: - Preference Key for measuring bottom panel height
private struct PanelHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
