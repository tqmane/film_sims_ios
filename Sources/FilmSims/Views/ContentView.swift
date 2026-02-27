import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var viewModel = FilmSimsViewModel()
    @ObservedObject private var proRepo = ProUserRepository.shared
    @State private var isSettingsPresented = false
    @State private var isShowingOriginal = false
    @State private var isImmersiveMode = false
    @State private var showAdjustPanel = false

    private let freeBrands: Set<String> = ["TECNO", "Nothing", "Nubia"]
    
    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.height <= 700
            ZStack {
                LivingBackground()

                // Preview layer (GLSurfaceView equivalent)
                Group {
                    if viewModel.originalImage == nil {
                        placeholderView
                    } else {
                        imagePreviewView
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .zIndex(0)

                // Dismiss adjust panel on background tap (matches Android)
                if showAdjustPanel {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { showAdjustPanel = false }
                        .zIndex(5)
                }

                // UI overlay layer (top bar + bottom controls)
                VStack(spacing: 0) {
                    if !isImmersiveMode {
                        topBar
                            .padding(.top, geometry.safeAreaInsets.top + 4)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer(minLength: 0)

                    // Bottom Area: Adjust Panel + Control Panel (matches Android Column layout)
                    if !isImmersiveMode && viewModel.originalImage != nil {
                        VStack(spacing: 0) {
                            // Adjust Panel (slides in from bottom, matches Android LiquidAdjustPanel)
                            if showAdjustPanel && viewModel.currentLut != nil {
                                adjustPanel
                                    .transition(.asymmetric(
                                        insertion: .push(from: .bottom).combined(with: .opacity),
                                        removal: .push(from: .top).combined(with: .opacity)
                                    ))
                            }

                            // Glass Control Panel (Camera/Style/Presets only, matches Android GlassControlPanel)
                            controlPanel
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        .padding(.bottom, max(8, geometry.safeAreaInsets.bottom))
                    }
                }
                .padding(.horizontal, 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(10)
            }
        }
        .environment(\.compactUI, {
            UIScreen.main.bounds.height <= 700
        }())
        .animation(.easeInOut(duration: 0.3), value: isImmersiveMode)
        .animation(.easeInOut(duration: 0.25), value: showAdjustPanel)
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(viewModel: viewModel)
        }
    }
    
    @Environment(\.compactUI) private var compactUI

    // MARK: - Top Bar
    private var topBar: some View {
        HStack(alignment: .center) {
            // App Title
            VStack(alignment: .leading, spacing: 2) {
                Text("FilmSims")
                    .font(.system(size: compactUI ? 20 : 24, weight: .medium))
                    .foregroundColor(.textPrimary)
                
                Text(L10n.tr("subtitle_film_simulator"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.accentPrimary)
                    .tracking(0.1)
                    .textCase(.uppercase)
                    .padding(.top, 3)
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 8) {
                // Change Photo Button
                PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                    Image(systemName: "plus")
                        .font(.system(size: compactUI ? 14 : 16, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .frame(width: compactUI ? 36 : 42, height: compactUI ? 36 : 42)
                        .background(AndroidRoundGlassBackground())
                }
                
                // Settings Button
                Button(action: { isSettingsPresented = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: compactUI ? 14 : 16, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .frame(width: compactUI ? 36 : 42, height: compactUI ? 36 : 42)
                        .background(AndroidRoundGlassBackground())
                }
                
                // Save Button
                LiquidButton(action: { viewModel.saveImage() }, height: compactUI ? 36 : 44) {
                    Text(L10n.tr("save"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(width: compactUI ? 72 : 80)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, compactUI ? 16 : 24)
        .background(
            AndroidTopShadow()
        )
    }
    
    // MARK: - Placeholder View
    private var placeholderView: some View {
        VStack(spacing: 0) {
            // Icon Container
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.glassSurface)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 36))
                    .foregroundColor(.textTertiary)
            }
            
            Text(L10n.tr("label_pick_image"))
                .font(.system(size: 26, weight: .light))
                .foregroundColor(.textPrimary)
                .padding(.top, 36)
            
            Text(L10n.tr("desc_pick_image"))
                .font(.system(size: 15))
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
            
            PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 22))
                    Text(L10n.tr("btn_open_gallery"))
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(height: 56)
                .background(AndroidAccentGradientButtonBackground(cornerRadius: 24))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .frame(minWidth: 200)
            .padding(.top, 44)
        }
        .padding(56)
    }
    
    // MARK: - Image Preview View
    private var imagePreviewView: some View {
        GeometryReader { geometry in
            ZoomableImageView(
                image: isShowingOriginal ? viewModel.originalImage : viewModel.processedImage,
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
        }
    }
    
    // MARK: - Control Panel (matches Android GlassControlPanel: Camera/Style/Presets ONLY)
    private var controlPanel: some View {
        VStack(spacing: 0) {
            // Camera Brands Section
            VStack(alignment: .leading, spacing: 0) {
                LiquidSectionHeader(text: L10n.tr("header_camera"))
                
                BrandSelector(
                    brands: viewModel.brands,
                    selectedBrand: $viewModel.selectedBrand,
                    isProUser: proRepo.isProUser,
                    freeBrands: freeBrands
                )
            }
            .padding(.bottom, 10)
            
            // Style Section
            VStack(alignment: .leading, spacing: 0) {
                LiquidSectionHeader(text: L10n.tr("header_style"))
                
                GenreSelector(
                    categories: viewModel.currentCategories,
                    selectedCategory: $viewModel.selectedCategory
                )
            }
            .padding(.bottom, 10)
            
            // Presets Section
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
        .padding(.horizontal, compactUI ? 12 : 16)
        .padding(.top, compactUI ? 12 : 16)
        .padding(.bottom, compactUI ? 14 : 20)
        .background(
            AndroidControlPanelBackground(topRadius: showAdjustPanel && viewModel.currentLut != nil ? 0 : 20)
        )
    }

    // MARK: - Adjust Panel (matches Android LiquidAdjustPanel with 3 tabs)
    private var adjustPanel: some View {
        LiquidAdjustPanel(viewModel: viewModel)
    }
}
