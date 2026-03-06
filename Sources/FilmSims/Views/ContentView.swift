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
        .animation(.spring(response: 0.45, dampingFraction: 0.55), value: isImmersiveMode)
        .animation(.spring(response: 0.45, dampingFraction: 0.55), value: showAdjustPanel)
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(viewModel: viewModel)
                .presentationBackground(.clear)
                .presentationDragIndicator(.hidden)
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
        VStack(spacing: 0) {
            // Subtle divider at the left edge
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(maxHeight: .infinity)
                .frame(width: 1)
                .overlay(alignment: .trailing) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if showAdjustPanel && viewModel.currentLut != nil {
                                LiquidAdjustPanel(viewModel: viewModel)
                                    .padding(.bottom, 16)
                            }

                            selectionSections(metrics: metrics)
                        }
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

            selectionSections(metrics: metrics)
        }
        .padding(.horizontal, metrics.panelHPad)
        .padding(.bottom, metrics.panelBottomPad)
        .background(
            AndroidControlPanelBackground(
                topRadius: showAdjustPanel && viewModel.currentLut != nil ? 0 : metrics.panelTopRadius
            )
        )
    }

    @ViewBuilder
    private func selectionSections(metrics: LayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            LiquidNoticeCard(
                title: currentLookNoticeTitle,
                message: currentLookNoticeMessage,
                label: currentLookNoticeLabel
            )
            .padding(.bottom, metrics.category == .compact ? 10 : 12)

            if !proRepo.isProUser {
                LiquidNoticeCard(
                    title: L10n.tr("more_brands_title"),
                    message: L10n.tr("premium_brands_hint"),
                    label: L10n.tr("label_pro"),
                    accentColor: .accentSecondary
                )
                .padding(.bottom, metrics.category == .compact ? 10 : 14)
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
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                            showAdjustPanel.toggle()
                        }
                    }
                )
            }
        }
    }

    private var currentLookNoticeTitle: String {
        viewModel.currentLut?.name
            ?? viewModel.selectedBrand?.displayName
            ?? L10n.tr("header_camera")
    }

    private var currentLookNoticeMessage: String {
        if viewModel.currentLut != nil {
            return L10n.tr("look_ready_hint")
        }
        return L10n.tr("look_preview_hint", viewModel.currentLuts.count)
    }

    private var currentLookNoticeLabel: String? {
        viewModel.selectedCategory?.displayName
    }
}
