import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var viewModel = FilmSimsViewModel()
    @ObservedObject private var proRepo = ProUserRepository.shared
    @State private var isSettingsPresented = false
    @State private var isShowingOriginal = false
    @State private var isImmersiveMode = false
    @State private var showAdjustPanel = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let freeBrands: Set<String> = ["TECNO", "Nothing", "Nubia"]

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
        .animation(.easeInOut(duration: 0.3), value: isImmersiveMode)
        .animation(.easeInOut(duration: 0.25), value: showAdjustPanel)
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(viewModel: viewModel)
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

            if showAdjustPanel {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { showAdjustPanel = false }
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
                    VStack(spacing: 0) {
                        if showAdjustPanel && viewModel.currentLut != nil {
                            LiquidAdjustPanel(viewModel: viewModel)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .bottom).combined(with: .opacity)
                                ))
                        }
                        controlPanel(metrics: metrics)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                    }
                    .padding(.bottom, max(8, geometry.safeAreaInsets.bottom))
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
                    // Left: image preview
                    ZStack {
                        Group {
                            if viewModel.originalImage == nil {
                                placeholderView(metrics: metrics)
                            } else {
                                imagePreviewView
                            }
                        }
                        if showAdjustPanel {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { showAdjustPanel = false }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Right: sidebar panel
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
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if showAdjustPanel && viewModel.currentLut != nil {
                    LiquidAdjustPanel(viewModel: viewModel)
                        .padding(.bottom, 16)
                }

                LiquidSectionHeader(text: L10n.tr("header_camera"))
                BrandSelector(
                    brands: viewModel.brands,
                    selectedBrand: $viewModel.selectedBrand,
                    isProUser: proRepo.isProUser,
                    freeBrands: freeBrands
                )

                LiquidSectionHeader(text: L10n.tr("header_style"))
                GenreSelector(
                    categories: viewModel.currentCategories,
                    selectedCategory: $viewModel.selectedCategory
                )

                LiquidSectionHeader(text: L10n.tr("header_presets"))
                LutPresetSelector(
                    luts: viewModel.currentLuts,
                    selectedLut: $viewModel.currentLut,
                    sourceThumbnail: viewModel.thumbnailImage,
                    viewModel: viewModel,
                    onLutReselected: {
                        withAnimation { showAdjustPanel.toggle() }
                    }
                )
            }
            .padding(.horizontal, metrics.panelHPad)
            .padding(.vertical, 16)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "#1A1A22"), Color(hex: "#050508")],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Top Bar
    @ViewBuilder
    private func topBar(metrics: LayoutMetrics) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("FilmSims")
                    .font(.system(size: metrics.titleFontSize, weight: .semibold))
                    .foregroundColor(.textPrimary)

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
                        .font(.system(size: metrics.category == .compact ? 13 : 16, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .frame(width: metrics.actionButtonSize, height: metrics.actionButtonSize)
                        .background(AndroidRoundGlassBackground())
                }

                Button(action: { isSettingsPresented = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: metrics.category == .compact ? 13 : 16, weight: .medium))
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
        let isCompact = metrics.category == .compact
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: isCompact ? 16 : 20, style: .continuous)
                    .fill(Color.glassSurface)
                    .frame(width: isCompact ? 76 : 100, height: isCompact ? 76 : 100)

                Image(systemName: "photo.badge.plus")
                    .font(.system(size: isCompact ? 28 : 36))
                    .foregroundColor(.textTertiary)
            }

            Text(L10n.tr("label_pick_image"))
                .font(.system(size: isCompact ? 20 : 26, weight: .light))
                .foregroundColor(.textPrimary)
                .padding(.top, isCompact ? 20 : 36)

            Text(L10n.tr("desc_pick_image"))
                .font(.system(size: isCompact ? 13 : 15))
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, isCompact ? 10 : 14)

            PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: isCompact ? 18 : 22))
                    Text(L10n.tr("btn_open_gallery"))
                        .font(.system(size: isCompact ? 14 : 15, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(height: isCompact ? 44 : 56)
                .background(AndroidAccentGradientButtonBackground(cornerRadius: 24))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .frame(minWidth: 180)
            .padding(.top, isCompact ? 28 : 44)
        }
        .padding(isCompact ? 32 : 56)
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
                if viewModel.currentLut != nil {
                    isShowingOriginal = true
                }
            },
            onLongPressEnd: {
                isShowingOriginal = false
            }
        )
        .id(viewModel.imageLoadCount)
    }

    // MARK: - Control Panel
    @ViewBuilder
    private func controlPanel(metrics: LayoutMetrics) -> some View {
        VStack(spacing: 0) {
            if !(showAdjustPanel && viewModel.currentLut != nil) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 44, height: 4.5)
                    .padding(.top, 10)
                    .padding(.bottom, metrics.dragHandlePad)
            } else {
                Spacer().frame(height: 10)
            }

            VStack(alignment: .leading, spacing: 0) {
                LiquidSectionHeader(text: L10n.tr("header_camera"))
                BrandSelector(
                    brands: viewModel.brands,
                    selectedBrand: $viewModel.selectedBrand,
                    isProUser: proRepo.isProUser,
                    freeBrands: freeBrands
                )
            }

            VStack(alignment: .leading, spacing: 0) {
                LiquidSectionHeader(text: L10n.tr("header_style"))
                GenreSelector(
                    categories: viewModel.currentCategories,
                    selectedCategory: $viewModel.selectedCategory
                )
            }

            VStack(alignment: .leading, spacing: 0) {
                LiquidSectionHeader(text: L10n.tr("header_presets"))
                LutPresetSelector(
                    luts: viewModel.currentLuts,
                    selectedLut: $viewModel.currentLut,
                    sourceThumbnail: viewModel.thumbnailImage,
                    viewModel: viewModel,
                    onLutReselected: {
                        withAnimation { showAdjustPanel.toggle() }
                    }
                )
            }
        }
        .padding(.horizontal, metrics.panelHPad)
        .padding(.bottom, metrics.panelBottomPad)
        .background(
            AndroidControlPanelBackground(
                topRadius: showAdjustPanel && viewModel.currentLut != nil ? 0 : metrics.panelTopRadius
            )
        )
    }
}
