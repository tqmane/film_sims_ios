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
        .environment(\.compactUI, {
            // We need a way to inject compactUI from geometry; use screen bounds as proxy.
            UIScreen.main.bounds.height <= 700
        }())
        .animation(.easeInOut(duration: 0.3), value: isImmersiveMode)
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
                Button(action: { viewModel.saveImage() }) {
                    Text(L10n.tr("save"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: compactUI ? 72 : 80, height: compactUI ? 36 : 44)
                        .background(AndroidAccentGradientButtonBackground(cornerRadius: 24))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
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
    
    // MARK: - Control Panel
    private var controlPanel: some View {
        VStack(spacing: 0) {
            // Adjustments header + grain controls (collapsible)
            if viewModel.originalImage != nil {
                adjustmentHeader

                if isAdjustmentPanelExpanded {
                    grainControls
                    watermarkControls
                }
            }
            
            // Camera Brands Section
            VStack(alignment: .leading, spacing: 0) {
                LiquidSectionHeader(text: L10n.tr("header_camera"))
                
                BrandSelector(
                    brands: viewModel.brands,
                    selectedBrand: $viewModel.selectedBrand
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
            
            // Quick Intensity Slider
            if viewModel.currentLut != nil {
                intensitySlider
            }
            
            // Presets Section
            VStack(alignment: .leading, spacing: 0) {
                LiquidSectionHeader(text: L10n.tr("header_presets"))
                
                LutPresetSelector(
                    luts: viewModel.currentLuts,
                    selectedLut: $viewModel.currentLut,
                    sourceThumbnail: viewModel.thumbnailImage,
                    viewModel: viewModel
                )
            }
        }
        .padding(.horizontal, compactUI ? 12 : 16)
        .padding(.top, compactUI ? 12 : 16)
        .padding(.bottom, compactUI ? 14 : 20)
        .background(
            AndroidControlPanelBackground(topRadius: 20)
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
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.accentPrimary)
                    .tracking(0.15)
                    .textCase(.uppercase)

                Spacer()

                Image(systemName: isAdjustmentPanelExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textTertiary)
                    .rotationEffect(.degrees(isAdjustmentPanelExpanded ? 180 : 0))
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Grain Controls
    private var grainControls: some View {
        VStack(spacing: 0) {
            // Row 1: icon + label + percent + checkbox
            HStack(spacing: 0) {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 18))
                    .foregroundColor(viewModel.grainEnabled ? .accentPrimary : .textTertiary)
                    .frame(width: 18)
                Spacer().frame(width: 12)
                Text(L10n.tr("label_film_grain"))
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                Spacer()
                Text("\(Int(viewModel.grainIntensity * 100))%")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(viewModel.grainEnabled ? .accentPrimary : .textTertiary)
                    .frame(width: 42, alignment: .trailing)
                    .padding(.trailing, 8)
                Toggle("", isOn: $viewModel.grainEnabled)
                    .labelsHidden()
                    .tint(.accentPrimary)
                    .frame(width: 24, height: 24)
                    .scaleEffect(0.8)
            }
            .padding(.vertical, 8)

            // Row 2: intensity slider
            LiquidSlider(value: $viewModel.grainIntensity, enabled: viewModel.grainEnabled)
                .padding(.bottom, 12)

            // Row 3: grain style selector (Xiaomi / OnePlus)
            HStack(spacing: 0) {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.accentSecondary)
                    .frame(width: 18)
                Spacer().frame(width: 12)
                Text(L10n.tr("label_grain_style"))
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .padding(.trailing, 12)
                HStack(spacing: 6) {
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

            // Divider before watermark section
            Divider()
                .background(Color.white.opacity(0.063))
                .padding(.vertical, 8)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Watermark Controls
    private var watermarkControls: some View {
        WatermarkView(viewModel: viewModel)
            .padding(.bottom, 16)
    }
    
    // MARK: - Intensity Slider
    private var intensitySlider: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16))
                    .foregroundColor(.accentPrimary)

                Spacer().frame(width: 10)

                Text(L10n.tr("label_intensity"))
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                Text("\(Int(viewModel.intensity * 100))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .frame(width: 40, alignment: .trailing)
            }
            .padding(.vertical, 6)

            LiquidSlider(value: $viewModel.intensity)
        }
        .padding(.bottom, 14)
    }
}
