import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var viewModel = FilmSimsViewModel()
    @State private var isSettingsPresented = false
    @State private var isShowingOriginal = false
    @State private var isImmersiveMode = false
    @State private var isAdjustmentPanelExpanded = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.surfaceDark.ignoresSafeArea()

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

                // UI overlay layer (top bar + bottom controls)
                VStack(spacing: 0) {
                    if !isImmersiveMode {
                        topBar
                            .padding(.top, geometry.safeAreaInsets.top + 4)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer(minLength: 0)

                    if !isImmersiveMode {
                        controlPanel
                            .padding(.bottom, max(8, geometry.safeAreaInsets.bottom))
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isImmersiveMode)
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(viewModel: viewModel)
        }
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack(alignment: .center) {
            // App Title
            VStack(alignment: .leading, spacing: 2) {
                Text("FilmSims")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.textPrimary)
                
                Text(L10n.tr("subtitle_film_simulator"))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.accentPrimary)
                    .tracking(1.2)
                    .textCase(.uppercase)
            }
            
            Spacer()
            
            // Action Buttons
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
                
                // Save Button
                Button(action: { viewModel.saveImage() }) {
                    Text(L10n.tr("save"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 40)
                        .background(AndroidAccentGradientButtonBackground(cornerRadius: 24))
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(
            AndroidTopShadow()
        )
    }
    
    // MARK: - Placeholder View
    private var placeholderView: some View {
        VStack(spacing: 0) {
            // Icon Container
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.glassBackground)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 36))
                    .foregroundColor(.textTertiary)
            }
            
            Text(L10n.tr("label_pick_image"))
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.textPrimary)
                .padding(.top, 32)
            
            Text(L10n.tr("desc_pick_image"))
                .font(.system(size: 14))
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
            
            PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 16))
                    Text(L10n.tr("btn_open_gallery"))
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .frame(height: 52)
                .background(AndroidAccentGradientButtonBackground(cornerRadius: 24))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .padding(.top, 40)
        }
        .padding(48)
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
    
    // MARK: - Control Panel
    private var controlPanel: some View {
        VStack(spacing: 0) {
            // Adjustments header + grain controls (collapsible)
            if viewModel.originalImage != nil {
                adjustmentHeader

                if isAdjustmentPanelExpanded {
                    grainControls
                }
            }
            
            // Camera Brands Section
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("header_camera"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.accentPrimary)
                    .tracking(1.5)
                    .textCase(.uppercase)
                
                BrandSelector(
                    brands: viewModel.brands,
                    selectedBrand: $viewModel.selectedBrand
                )
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .background(AndroidSelectorContainerBackground(cornerRadius: 18))
            }
            .padding(.bottom, 10)
            
            // Style Section
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("header_style"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.accentPrimary)
                    .tracking(1.5)
                    .textCase(.uppercase)
                
                GenreSelector(
                    categories: viewModel.currentCategories,
                    selectedCategory: $viewModel.selectedCategory
                )
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .background(AndroidSelectorContainerBackground(cornerRadius: 18))
            }
            .padding(.bottom, 10)
            
            // Quick Intensity Slider
            if viewModel.currentLut != nil {
                intensitySlider
            }
            
            // Presets Section
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("header_presets"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.accentPrimary)
                    .tracking(1.5)
                    .textCase(.uppercase)
                
                LutPresetSelector(
                    luts: viewModel.currentLuts,
                    selectedLut: $viewModel.currentLut,
                    sourceThumbnail: viewModel.thumbnailImage,
                    viewModel: viewModel
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(
            AndroidControlPanelBackground(topRadius: 28)
        )
    }

    // MARK: - Adjustment Header
    private var adjustmentHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isAdjustmentPanelExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Text(L10n.tr("header_grain"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.accentPrimary)
                    .tracking(1.8)
                    .textCase(.uppercase)

                Spacer()

                Image(systemName: isAdjustmentPanelExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textTertiary)
                    .rotationEffect(.degrees(isAdjustmentPanelExpanded ? 180 : 0))
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Grain Controls
    private var grainControls: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 14))
                    .foregroundColor(viewModel.grainEnabled ? .accentPrimary : .textTertiary)
                
                Text(L10n.tr("label_film_grain"))
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                Text("\(Int(viewModel.grainIntensity * 100))%")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(viewModel.grainEnabled ? .accentPrimary : .textTertiary)
                    .frame(width: 42, alignment: .trailing)
                
                Toggle("", isOn: $viewModel.grainEnabled)
                    .labelsHidden()
                    .tint(.accentPrimary)
                    .scaleEffect(0.8)
            }
            
            Slider(value: $viewModel.grainIntensity, in: 0...1)
                .tint(viewModel.grainEnabled ? .accentPrimary : .textTertiary)
                .disabled(!viewModel.grainEnabled)
            
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.vertical, 8)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Intensity Slider
    private var intensitySlider: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12))
                    .foregroundColor(.accentPrimary)
                
                Text(L10n.tr("label_intensity"))
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                Text("\(Int(viewModel.intensity * 100))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .frame(width: 40, alignment: .trailing)
            }
            
            Slider(value: $viewModel.intensity, in: 0...1)
                .tint(.accentPrimary)
        }
        .padding(.bottom, 14)
    }
}
