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
                            // Adjust Panel - Android uses expandVertically(Bottom) + fadeIn
                            if showAdjustPanel && viewModel.currentLut != nil {
                                adjustPanel
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .move(edge: .bottom).combined(with: .opacity)
                                    ))
                            }

                            // Glass Control Panel - Android uses slideInVertically + fadeIn(tween300)
                            controlPanel
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .bottom).combined(with: .opacity)
                                ))
                        }
                        .padding(.bottom, max(8, geometry.safeAreaInsets.bottom))
                    }
                }
                .padding(.horizontal, 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isImmersiveMode)
        .animation(.easeInOut(duration: 0.25), value: showAdjustPanel)
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(viewModel: viewModel)
        }
    }

    // MARK: - Top Bar (matches Android LiquidTopBar exactly)
    private var topBar: some View {
        HStack(alignment: .center) {
            // App Title — Android: 26sp SemiBold, subtitle 11.5sp Medium tracking 0.15sp
            VStack(alignment: .leading, spacing: 2) {
                Text("FilmSims")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Text(L10n.tr("subtitle_film_simulator").uppercased())
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.accentPrimary)
                    .tracking(0.15)
                    .padding(.top, 3)
            }
            
            Spacer()
            
            // Action Buttons (Android: round buttons + LiquidButton)
            HStack(spacing: 8) {
                // Change Photo Button
                PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .frame(width: 42, height: 42)
                        .background(AndroidRoundGlassBackground())
                }
                
                // Settings Button
                Button(action: { isSettingsPresented = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.textPrimary)
                        .frame(width: 42, height: 42)
                        .background(AndroidRoundGlassBackground())
                }
                .padding(.trailing, 4)
                
                // Save Button — Android: width=94dp, save icon (15dp) + "Save" text (14sp SemiBold)
                LiquidButton(action: { viewModel.saveImage() }, height: 44) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 15, weight: .semibold))
                        Text(L10n.tr("save"))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                }
                .frame(width: 94)
            }
        }
        // Android: padding horizontal=24, vertical=16
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(AndroidTopShadow())
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
    
    // MARK: - Control Panel (matches Android GlassBottomSheet: top=10, bottom=16, h=18, topCorners=22dp)
    private var controlPanel: some View {
        VStack(spacing: 0) {
            // Drag handle (Android: padding bottom=14dp between handle and first section)
            if !(showAdjustPanel && viewModel.currentLut != nil) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 44, height: 4.5)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
            } else {
                // squareTop=true still has top=10dp padding
                Spacer().frame(height: 10)
            }

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
            
            // Style Section
            VStack(alignment: .leading, spacing: 0) {
                LiquidSectionHeader(text: L10n.tr("header_style"))
                
                GenreSelector(
                    categories: viewModel.currentCategories,
                    selectedCategory: $viewModel.selectedCategory
                )
            }
            
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
        // Android GlassBottomSheet: padding bottom=16, horizontal=18 (top handled by drag handle)
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
        .background(
            AndroidControlPanelBackground(topRadius: showAdjustPanel && viewModel.currentLut != nil ? 0 : 22)
        )
    }

    // MARK: - Adjust Panel (matches Android LiquidAdjustPanel with 3 tabs)
    private var adjustPanel: some View {
        LiquidAdjustPanel(viewModel: viewModel)
    }
}
