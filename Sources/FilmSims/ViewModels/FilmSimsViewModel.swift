import SwiftUI
import PhotosUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers
import ImageIO

@MainActor
class FilmSimsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var originalImage: UIImage?
    @Published var processedImage: UIImage?
    @Published var thumbnailImage: UIImage?
    @Published var imageLoadCount: Int = 0
    
    @Published var selectedPhotoItem: PhotosPickerItem? {
        didSet {
            Task {
                await loadImage(from: selectedPhotoItem)
            }
        }
    }
    
    @Published var brands: [LutBrand] = []
    @Published var selectedBrand: LutBrand? {
        didSet {
            if let brand = selectedBrand {
                selectedCategory = brand.categories.first
            }
        }
    }
    
    @Published var selectedCategory: LutCategory? {
        didSet {
            if !suppressAutomaticProcessing {
                performBatchedUpdates(applyAfter: true) {
                    currentLut = nil
                    overlayLut = nil
                }
            }
            prefetchCategoryLuts()
        }
    }
    
    @Published var currentLut: LutItem? {
        didSet {
            guard !suppressAutomaticProcessing else { return }
            scheduleApply()
        }
    }

    @Published var overlayLut: LutItem? {
        didSet {
            guard !suppressAutomaticProcessing else { return }
            scheduleApply()
        }
    }
    
    @Published var intensity: Float = 1.0 {
        didSet {
            guard !suppressAutomaticProcessing else { return }
            scheduleApply()
        }
    }

    @Published var overlayIntensity: Float = 0.35 {
        didSet {
            guard !suppressAutomaticProcessing else { return }
            if overlayLut != nil {
                scheduleApply()
            } else {
                saveSettings()
            }
        }
    }
    
    @Published var grainEnabled: Bool = false {
        didSet {
            guard !suppressAutomaticProcessing else { return }
            scheduleApply()
        }
    }
    
    @Published var grainIntensity: Float = 0.5 {
        didSet {
            guard !suppressAutomaticProcessing else { return }
            if grainEnabled {
                scheduleApply()
            } else {
                saveSettings()
            }
        }
    }

    @Published var grainStyle: String = "Xiaomi" {
        didSet {
            guard !suppressAutomaticProcessing else { return }
            if grainEnabled {
                scheduleApply()
            } else {
                saveSettings()
            }
        }
    }

    @Published var exposure: Float = 0 {
        didSet {
            guard !suppressAutomaticProcessing else { return }
            scheduleApply()
        }
    }

    @Published var contrast: Float = 0 {
        didSet {
            guard !suppressAutomaticProcessing else { return }
            scheduleApply()
        }
    }

    @Published var highlights: Float = 0 {
        didSet {
            guard !suppressAutomaticProcessing else { return }
            scheduleApply()
        }
    }

    @Published var shadows: Float = 0 {
        didSet {
            guard !suppressAutomaticProcessing else { return }
            scheduleApply()
        }
    }

    @Published var colorTemp: Float = 0 {
        didSet {
            guard !suppressAutomaticProcessing else { return }
            scheduleApply()
        }
    }

    // Watermark
    @Published var watermarkBrand: String = "None" {
        didSet {
            // Auto-select first style for the new brand; clear when None.
            switch watermarkBrand {
            case "Honor":
                watermarkStyle = .frame
            case "Meizu":
                watermarkStyle = .meizuNorm
            case "Vivo":
                watermarkStyle = .vivoZeiss
            case "TECNO":
                watermarkStyle = .tecno1
            default:
                watermarkStyle = .none
            }
        }
    }

    @Published var watermarkEnabled: Bool = false {
        didSet {
            guard !suppressAutomaticProcessing else { return }
            scheduleApply()
        }
    }
    
    @Published var watermarkStyle: WatermarkProcessor.WatermarkStyle = .none {
        didSet {
            watermarkEnabled = (watermarkStyle != .none)
            guard !suppressAutomaticProcessing else { return }
            scheduleApply()
        }
    }
    
    @Published var watermarkDeviceName: String = "" {
        didSet {
            guard !suppressAutomaticProcessing else { return }
            if watermarkEnabled {
                scheduleApply()
            } else {
                saveSettings()
            }
        }
    }
    
    @Published var watermarkLensInfo: String = "" {
        didSet {
            guard !suppressAutomaticProcessing else { return }
            if watermarkEnabled {
                scheduleApply()
            } else {
                saveSettings()
            }
        }
    }
    
    @Published var watermarkTimeText: String = "" {
        didSet {
            guard !suppressAutomaticProcessing else { return }
            if watermarkEnabled {
                scheduleApply()
            } else {
                saveSettings()
            }
        }
    }
    
    @Published var watermarkLocationText: String = "" {
        didSet {
            guard !suppressAutomaticProcessing else { return }
            if watermarkEnabled {
                scheduleApply()
            } else {
                saveSettings()
            }
        }
    }
    
    // Settings
    @Published var saveQuality: Int = 100
    @Published var panelHintsEnabled: Bool = true
    @Published var presets: [Preset] = []
    
    // MARK: - Private Properties
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var lutCache: [String: CubeLUT] = [:]
    private var originalImageData: Data?

    private var applyTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    private var thumbnailStamp = UUID()
    private var thumbnailPreviewCache: [String: UIImage] = [:]
    private var thumbnailPreviewTaskCache: [String: Task<UIImage?, Never>] = [:]
    private var suppressAutomaticProcessing = false
    // Limits concurrent LUT parse+apply tasks for thumbnail previews.
    private let previewSemaphore = AsyncSemaphore(limit: 4)

    nonisolated(unsafe) private static let basicAdjustKernel: CIColorKernel? = {
        CIColorKernel(source: """
        kernel vec4 basicAdjust(__sample image, float exposure, float contrast, float highlights, float shadows, float colorTemp) {
            vec3 adjusted = image.rgb;
            adjusted *= pow(2.0, exposure);
            adjusted = mix(vec3(0.5), adjusted, 1.0 + contrast);
            float luminance = dot(adjusted, vec3(0.299, 0.587, 0.114));
            float shadowMask = 1.0 - smoothstep(0.0, 0.5, luminance);
            float highlightMask = smoothstep(0.5, 1.0, luminance);
            adjusted += shadows * shadowMask * 0.4;
            adjusted += highlights * highlightMask * 0.4;
            adjusted.r *= 1.0 + colorTemp * 0.15;
            adjusted.g *= 1.0 + colorTemp * 0.05;
            adjusted.b *= 1.0 - colorTemp * 0.15;
            adjusted = clamp(adjusted, 0.0, 1.0);
            return vec4(adjusted, image.a);
        }
        """)
    }()
    
    // MARK: - Computed Properties
    var currentCategories: [LutCategory] {
        selectedBrand?.categories ?? []
    }
    
    var currentLuts: [LutItem] {
        selectedCategory?.items ?? []
    }

    var hasVisibleEdits: Bool {
        currentLut != nil ||
        overlayLut != nil ||
        hasBasicAdjustments ||
        (grainEnabled && grainIntensity > 0) ||
        (watermarkEnabled && watermarkStyle != .none)
    }
    
    // MARK: - Initialization
    init() {
        loadSettings()
        createDefaultThumbnailIfNeeded()
        loadLutBrands()
    }

    private func createDefaultThumbnailIfNeeded() {
        guard thumbnailImage == nil else { return }

        let size = CGSize(width: 500, height: 500)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return }

        let colors = [
            UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0).cgColor,
            UIColor(red: 0.20, green: 0.18, blue: 0.14, alpha: 1.0).cgColor,
            UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0).cgColor,
        ] as CFArray

        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 0.55, 1.0]) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        thumbnailImage = image
    }
    
    // MARK: - Settings
    private func loadSettings() {
        let settings = SettingsManager.shared
        performBatchedUpdates(applyAfter: false) {
            saveQuality = settings.saveQuality
            panelHintsEnabled = settings.panelHintsEnabled
            intensity = settings.lastIntensity
            overlayIntensity = settings.lastOverlayIntensity
            grainEnabled = settings.lastGrainEnabled
            grainIntensity = settings.lastGrainIntensity
            grainStyle = settings.lastGrainStyle
            exposure = settings.lastExposure
            contrast = settings.lastContrast
            highlights = settings.lastHighlights
            shadows = settings.lastShadows
            colorTemp = settings.lastColorTemp
        }
        presets = settings.loadPresets()
    }
    
    func saveSettings() {
        let settings = SettingsManager.shared
        settings.saveQuality = saveQuality
        settings.panelHintsEnabled = panelHintsEnabled
        settings.lastIntensity = intensity
        settings.lastOverlayIntensity = overlayIntensity
        settings.lastGrainEnabled = grainEnabled
        settings.lastGrainIntensity = grainIntensity
        settings.lastGrainStyle = grainStyle
        settings.lastExposure = exposure
        settings.lastContrast = contrast
        settings.lastHighlights = highlights
        settings.lastShadows = shadows
        settings.lastColorTemp = colorTemp
    }

    private func performBatchedUpdates(applyAfter: Bool, _ updates: () -> Void) {
        suppressAutomaticProcessing = true
        updates()
        suppressAutomaticProcessing = false

        if applyAfter {
            scheduleApply()
        }
    }

    private func selectionContext(for assetPath: String?) -> (brand: LutBrand, category: LutCategory, item: LutItem)? {
        guard let assetPath else { return nil }

        for brand in brands {
            for category in brand.categories {
                if let item = category.items.first(where: { $0.assetPath == assetPath }) {
                    return (brand, category, item)
                }
            }
        }

        return nil
    }

    private func item(for assetPath: String?) -> LutItem? {
        selectionContext(for: assetPath)?.item
    }

    private func restoreSelectionContext(for assetPath: String?) {
        guard let context = selectionContext(for: assetPath) else { return }
        selectedBrand = context.brand
        selectedCategory = context.category
    }

    private func resolvedWatermarkStyle(from storedName: String) -> WatermarkProcessor.WatermarkStyle {
        let normalizedName = storedName.lowercased()
        return WatermarkProcessor.WatermarkStyle.allCases.first {
            String(describing: $0).lowercased() == normalizedName
        } ?? .none
    }

    private func watermarkBrand(for style: WatermarkProcessor.WatermarkStyle) -> String {
        switch style {
        case .none:
            return "None"
        case .frame, .text, .frameYG, .textYG:
            return "Honor"
        case .meizuNorm, .meizuPro, .meizuZ1, .meizuZ2, .meizuZ3, .meizuZ4, .meizuZ5, .meizuZ6, .meizuZ7:
            return "Meizu"
        case .vivoZeiss, .vivoClassic, .vivoPro, .vivoIqoo, .vivoZeissV1, .vivoZeissSonnar, .vivoZeissHumanity,
             .vivoIqooV1, .vivoIqooHumanity, .vivoZeissFrame, .vivoZeissOverlay, .vivoZeissCenter,
             .vivoFrame, .vivoFrameTime, .vivoIqooFrame, .vivoIqooFrameTime, .vivoOS, .vivoOSCorner,
             .vivoOSSimple, .vivoEvent, .vivoZeiss0, .vivoZeiss1, .vivoZeiss2, .vivoZeiss3, .vivoZeiss4,
             .vivoZeiss5, .vivoZeiss6, .vivoZeiss7, .vivoZeiss8, .vivoIqoo4, .vivoCommonIqoo4,
             .vivo1, .vivo2, .vivo3, .vivo4, .vivo5:
            return "Vivo"
        case .tecno1, .tecno2, .tecno3, .tecno4:
            return "TECNO"
        }
    }

    func clearOverlayLut() {
        overlayLut = nil
    }

    func setPanelHintsEnabled(_ enabled: Bool) {
        panelHintsEnabled = enabled
        SettingsManager.shared.panelHintsEnabled = enabled
    }

    func resetAdjustments() {
        performBatchedUpdates(applyAfter: true) {
            exposure = 0
            contrast = 0
            highlights = 0
            shadows = 0
            colorTemp = 0
        }
    }

    @discardableResult
    func savePreset(named name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        let preset = Preset(
            id: UUID().uuidString,
            name: trimmedName,
            lutPath: currentLut?.assetPath,
            intensity: intensity,
            overlayLutPath: overlayLut?.assetPath,
            overlayIntensity: overlayIntensity,
            grainEnabled: grainEnabled,
            grainIntensity: grainIntensity,
            grainStyle: grainStyle,
            exposure: exposure,
            contrast: contrast,
            highlights: highlights,
            shadows: shadows,
            colorTemp: colorTemp,
            watermarkStyleName: String(describing: watermarkStyle),
            watermarkDeviceName: watermarkDeviceName,
            watermarkTimeText: watermarkTimeText,
            watermarkLocationText: watermarkLocationText,
            watermarkLensInfo: watermarkLensInfo
        )

        let didSave = SettingsManager.shared.savePreset(preset)
        if didSave {
            presets = SettingsManager.shared.loadPresets()
        }
        return didSave
    }

    func loadPreset(_ preset: Preset) {
        let style = resolvedWatermarkStyle(from: preset.watermarkStyleName)
        let currentItem = item(for: preset.lutPath)
        let overlayItem = item(for: preset.overlayLutPath)

        performBatchedUpdates(applyAfter: true) {
            if let basePath = preset.lutPath {
                restoreSelectionContext(for: basePath)
            }

            currentLut = currentItem
            overlayLut = overlayItem
            intensity = preset.intensity
            overlayIntensity = preset.overlayIntensity
            grainEnabled = preset.grainEnabled
            grainIntensity = preset.grainIntensity
            grainStyle = preset.grainStyle
            exposure = preset.exposure
            contrast = preset.contrast
            highlights = preset.highlights
            shadows = preset.shadows
            colorTemp = preset.colorTemp
            watermarkBrand = watermarkBrand(for: style)
            watermarkStyle = style
            watermarkDeviceName = preset.watermarkDeviceName
            watermarkTimeText = preset.watermarkTimeText
            watermarkLocationText = preset.watermarkLocationText
            watermarkLensInfo = preset.watermarkLensInfo
        }
    }

    func deletePreset(_ preset: Preset) {
        SettingsManager.shared.deletePreset(id: preset.id)
        presets = SettingsManager.shared.loadPresets()
    }
    
    // MARK: - Image Loading
    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                originalImageData = data
                
                if let uiImage = UIImage(data: data) {
                    originalImage = uiImage
                    processedImage = uiImage
                    imageLoadCount += 1
                    
                    // Create thumbnail for LUT previews
                    let maxDim: CGFloat = 256
                    let scale = min(maxDim / uiImage.size.width, maxDim / uiImage.size.height, 1.0)
                    let newSize = CGSize(
                        width: uiImage.size.width * scale,
                        height: uiImage.size.height * scale
                    )
                    
                    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                    uiImage.draw(in: CGRect(origin: .zero, size: newSize))
                    thumbnailImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()

                    // Invalidate per-thumbnail preview cache
                    thumbnailStamp = UUID()
                    thumbnailPreviewCache.removeAll(keepingCapacity: true)
                    thumbnailPreviewTaskCache.removeAll(keepingCapacity: true)

                    // Extract EXIF metadata to auto-populate watermark fields.
                    readExif(from: data)

                    await applyCurrentLut()
                }
            }
        } catch {
            print("Failed to load image: \(error)")
        }
    }
    
    // MARK: - LUT Loading
    private func loadLutBrands() {
        brands = LutRepository.shared.getLutBrands()
        if let firstBrand = brands.first {
            selectedBrand = firstBrand
        }
    }

    /// Pre-parse all LUTs in the selected category off the main thread
    /// so thumbnails appear immediately when the user scrolls the preset row.
    private func prefetchCategoryLuts() {
        prefetchTask?.cancel()
        guard let items = selectedCategory?.items, !items.isEmpty else { return }
        prefetchTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            for item in items {
                if Task.isCancelled { break }
                await self.prefetchLutIfNeeded(item)
            }
        }
    }

    private func prefetchLutIfNeeded(_ item: LutItem) async {
        let key = item.assetPath
        let alreadyCached = await MainActor.run { lutCache[key] != nil }
        guard !alreadyCached else { return }
        if let lut = CubeLUTParser.parse(assetPath: key) {
            await MainActor.run { [weak self] in
                self?.lutCache[key] = lut
            }
        }
    }

    func getLut(for item: LutItem) -> CubeLUT? {
        if let cached = lutCache[item.assetPath] {
            return cached
        }
        
        if let lut = CubeLUTParser.parse(assetPath: item.assetPath) {
            lutCache[item.assetPath] = lut
            return lut
        }
        
        return nil
    }
    
    // MARK: - LUT Application
    private var hasBasicAdjustments: Bool {
        abs(exposure) > 0.001 ||
        abs(contrast) > 0.001 ||
        abs(highlights) > 0.001 ||
        abs(shadows) > 0.001 ||
        abs(colorTemp) > 0.001
    }

    func applyCurrentLut() async {
        guard let originalImage = originalImage else { return }

        // Security check (matches Android applyLut: SecurityManager.isEnvironmentTrusted())
        guard SecurityManager.shared.isEnvironmentTrusted() else {
            processedImage = originalImage
            return
        }

        if Task.isCancelled { return }

        // Scale down for preview to keep UI responsive.
        let previewImage = scaleToMaxPixels(originalImage, maxPixels: 10_000_000)

        if Task.isCancelled { return }

        var finalImage = await renderEditedImage(from: previewImage) ?? previewImage

        if Task.isCancelled { return }
        
        if grainEnabled && grainIntensity > 0 {
            finalImage = await applyFilmGrainAsync(to: finalImage, intensity: grainIntensity) ?? finalImage
        }
        
        if watermarkEnabled && watermarkStyle != .none {
            finalImage = applyWatermark(to: finalImage)
        }

        if Task.isCancelled { return }
        processedImage = finalImage
    }

    private func scheduleApply() {
        saveSettings()
        applyTask?.cancel()
        applyTask = Task { [weak self] in
            guard let self else { return }
            // Coalesce rapid slider/toggle edits.
            try? await Task.sleep(nanoseconds: 40_000_000)
            if Task.isCancelled { return }
            await self.applyCurrentLut()
        }
    }

    private func renderEditedImage(from image: UIImage) async -> UIImage? {
        let baseLut = currentLut.flatMap(getLut(for:))
        let overlayCube = overlayLut.flatMap(getLut(for:))
        let shouldRender = baseLut != nil || overlayCube != nil || hasBasicAdjustments

        guard shouldRender else { return image }
        guard let cgImage = image.cgImage else { return nil }

        let context = ciContext
        let baseIntensity = intensity
        let overlayBlend = overlayIntensity
        let exposureValue = exposure
        let contrastValue = contrast
        let highlightsValue = highlights
        let shadowsValue = shadows
        let colorTemperature = colorTemp

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let inputImage = CIImage(cgImage: cgImage)
                guard let outputImage = Self.renderPipelineImage(
                    from: inputImage,
                    baseLut: baseLut,
                    intensity: baseIntensity,
                    overlayLut: overlayCube,
                    overlayIntensity: overlayBlend,
                    exposure: exposureValue,
                    contrast: contrastValue,
                    highlights: highlightsValue,
                    shadows: shadowsValue,
                    colorTemp: colorTemperature
                ) else {
                    continuation.resume(returning: image)
                    return
                }

                guard let rendered = context.createCGImage(outputImage, from: outputImage.extent) else {
                    continuation.resume(returning: image)
                    return
                }

                continuation.resume(returning: UIImage(cgImage: rendered, scale: image.scale, orientation: image.imageOrientation))
            }
        }
    }

    nonisolated private static func renderPipelineImage(
        from inputImage: CIImage,
        baseLut: CubeLUT?,
        intensity: Float,
        overlayLut: CubeLUT?,
        overlayIntensity: Float,
        exposure: Float,
        contrast: Float,
        highlights: Float,
        shadows: Float,
        colorTemp: Float
    ) -> CIImage? {
        var workingImage = inputImage

        if abs(exposure) > 0.001 || abs(contrast) > 0.001 || abs(highlights) > 0.001 || abs(shadows) > 0.001 || abs(colorTemp) > 0.001 {
            workingImage = applyBasicAdjustments(
                to: workingImage,
                exposure: exposure,
                contrast: contrast,
                highlights: highlights,
                shadows: shadows,
                colorTemp: colorTemp
            )
        }

        if let baseLut,
           let baseImage = applyColorCube(to: workingImage, lut: baseLut) {
            workingImage = blendImage(base: workingImage, filtered: baseImage, intensity: intensity) ?? baseImage
        }

        if let overlayLut,
           overlayIntensity > 0.001,
           let overlayImage = applyColorCube(to: workingImage, lut: overlayLut) {
            workingImage = blendImage(base: workingImage, filtered: overlayImage, intensity: overlayIntensity) ?? overlayImage
        }

        return workingImage.cropped(to: inputImage.extent)
    }

    nonisolated private static func applyBasicAdjustments(
        to image: CIImage,
        exposure: Float,
        contrast: Float,
        highlights: Float,
        shadows: Float,
        colorTemp: Float
    ) -> CIImage {
        guard let kernel = Self.basicAdjustKernel,
              let adjusted = kernel.apply(
                extent: image.extent,
                arguments: [
                    image,
                    NSNumber(value: exposure),
                    NSNumber(value: contrast),
                    NSNumber(value: highlights),
                    NSNumber(value: shadows),
                    NSNumber(value: colorTemp),
                ]
              ) else {
            return image
        }

        return adjusted.cropped(to: image.extent)
    }

    nonisolated private static func applyColorCube(to image: CIImage, lut: CubeLUT) -> CIImage? {
        guard let filter = CIFilter(name: "CIColorCubeWithColorSpace") else { return nil }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(lut.size, forKey: "inputCubeDimension")
        filter.setValue(lut.cubeData, forKey: "inputCubeData")
        filter.setValue(CGColorSpaceCreateDeviceRGB(), forKey: "inputColorSpace")
        return filter.outputImage?.cropped(to: image.extent)
    }

    nonisolated private static func blendImage(base: CIImage, filtered: CIImage, intensity: Float) -> CIImage? {
        if intensity <= 0.001 {
            return base
        }
        if intensity >= 0.999 {
            return filtered.cropped(to: base.extent)
        }

        guard let dissolveFilter = CIFilter(name: "CIDissolveTransition") else {
            return filtered
        }

        dissolveFilter.setValue(base, forKey: kCIInputImageKey)
        dissolveFilter.setValue(filtered, forKey: kCIInputTargetImageKey)
        dissolveFilter.setValue(NSNumber(value: intensity), forKey: kCIInputTimeKey)
        return dissolveFilter.outputImage?.cropped(to: base.extent)
    }
    
    // MARK: - Watermark Application
    private func readExif(from data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            // No EXIF — set default time
            watermarkTimeText = WatermarkProcessor.defaultTimeString()
            return
        }

        let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let gps  = props[kCGImagePropertyGPSDictionary  as String] as? [String: Any]

        // Always reset all fields from EXIF when new image loads; user can edit afterwards
        watermarkDeviceName = (tiff?[kCGImagePropertyTIFFModel as String] as? String) ?? ""

        if let dt = exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            // Convert "2024:01:15 10:30:00" → "2024-01-15 10:30:00"
            let cutoff = dt.index(dt.startIndex, offsetBy: min(10, dt.count))
            let datePart = dt[dt.startIndex..<cutoff].replacingOccurrences(of: ":", with: "-")
            let timePart = dt.count > 11 ? String(dt[dt.index(cutoff, offsetBy: 1)...]) : ""
            watermarkTimeText = timePart.isEmpty ? datePart : "\(datePart) \(timePart)"
        } else {
            watermarkTimeText = WatermarkProcessor.defaultTimeString()
        }

        watermarkLensInfo = (exif?[kCGImagePropertyExifLensModel as String] as? String) ?? ""

        if let lat = gps?[kCGImagePropertyGPSLatitude  as String] as? Double,
           let lon = gps?[kCGImagePropertyGPSLongitude as String] as? Double {
            let latRef = gps?[kCGImagePropertyGPSLatitudeRef  as String] as? String ?? "N"
            let lonRef = gps?[kCGImagePropertyGPSLongitudeRef as String] as? String ?? "E"
            watermarkLocationText = String(format: "%.4f°%@ %.4f°%@", lat, latRef, lon, lonRef)
        } else {
            watermarkLocationText = ""
        }
    }

    private func applyWatermark(to image: UIImage) -> UIImage {
        let config = WatermarkProcessor.WatermarkConfig(
            style: watermarkStyle,
            deviceName: watermarkDeviceName.isEmpty ? nil : watermarkDeviceName,
            timeText: watermarkTimeText.isEmpty ? nil : watermarkTimeText,
            locationText: watermarkLocationText.isEmpty ? nil : watermarkLocationText,
            lensInfo: watermarkLensInfo.isEmpty ? nil : watermarkLensInfo
        )
        return WatermarkProcessor.applyWatermark(image, config: config)
    }

    private func applyFilmGrainAsync(to image: UIImage, intensity: Float) async -> UIImage? {
        // Capture context on the MainActor, then do the expensive work off-main.
        let context = ciContext
        let style = grainStyle
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard self != nil else {
                    continuation.resume(returning: nil)
                    return
                }
                let result = Self.applyFilmGrain(to: image, intensity: intensity, ciContext: context, style: style)
                continuation.resume(returning: result)
            }
        }
    }
    
    private func applyLutToImage(_ image: UIImage, lut: CubeLUT, intensity: Float) async -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let context = ciContext
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let inputImage = CIImage(cgImage: cgImage)
                guard let filtered = Self.applyColorCube(to: inputImage, lut: lut) else {
                    continuation.resume(returning: nil)
                    return
                }

                let blendedImage = Self.blendImage(base: inputImage, filtered: filtered, intensity: intensity) ?? filtered

                guard let outputCGImage = context.createCGImage(blendedImage, from: inputImage.extent) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let result = UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
                continuation.resume(returning: result)
            }
        }
    }
    
    nonisolated private static func applyFilmGrain(to image: UIImage, intensity: Float, ciContext: CIContext, style: String = "Xiaomi") -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let ciImage = CIImage(cgImage: cgImage)

        guard intensity > 0 else { return image }

        let extent = ciImage.extent

        // CIRandomGenerator is infinite (no tiling) — use it directly.
        guard let random = CIFilter(name: "CIRandomGenerator")?.outputImage else { return image }
        let randomCropped = random.cropped(to: extent)

        // Soft-blur the white noise to produce organic film-like grain clusters.
        // OnePlus uses a slightly coarser grain than Xiaomi.
        let blurRadius: Double = style == "OnePlus" ? 1.5 : 0.8
        let blurredNoise: CIImage
        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(randomCropped, forKey: kCIInputImageKey)
            blur.setValue(blurRadius, forKey: kCIInputRadiusKey)
            blurredNoise = (blur.outputImage ?? randomCropped).cropped(to: extent)
        } else {
            blurredNoise = randomCropped
        }

        // Desaturate to luma-only noise.
        let grayNoise: CIImage
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(blurredNoise, forKey: kCIInputImageKey)
            controls.setValue(0.0, forKey: kCIInputSaturationKey)
            controls.setValue(1.0, forKey: kCIInputContrastKey)
            controls.setValue(0.0, forKey: kCIInputBrightnessKey)
            grayNoise = (controls.outputImage ?? blurredNoise).cropped(to: extent)
        } else {
            grayNoise = blurredNoise
        }

        // Convert [0,1] -> [-amp,+amp] and add to the image.
        // Smaller amp looks more like film grain (not a visible texture overlay).
        let amp = CGFloat(intensity) * 0.06
        guard let matrix = CIFilter(name: "CIColorMatrix") else { return image }
        matrix.setValue(grayNoise, forKey: kCIInputImageKey)
        matrix.setValue(CIVector(x: 2 * amp, y: 0, z: 0, w: 0), forKey: "inputRVector")
        matrix.setValue(CIVector(x: 0, y: 2 * amp, z: 0, w: 0), forKey: "inputGVector")
        matrix.setValue(CIVector(x: 0, y: 0, z: 2 * amp, w: 0), forKey: "inputBVector")
        matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        matrix.setValue(CIVector(x: -amp, y: -amp, z: -amp, w: 0), forKey: "inputBiasVector")
        let signedNoise = (matrix.outputImage ?? grayNoise).cropped(to: extent)

        guard let add = CIFilter(name: "CIAdditionCompositing") else { return image }
        add.setValue(signedNoise, forKey: kCIInputImageKey)
        add.setValue(ciImage, forKey: kCIInputBackgroundImageKey)
        let out = (add.outputImage ?? ciImage).cropped(to: extent)

        guard let outputCGImage = ciContext.createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
    }

    nonisolated(unsafe) private static var cachedFilmGrainTextures: [String: CIImage] = [:]

    nonisolated private static func filmGrainTextureCIImage(style: String = "Xiaomi") -> CIImage? {
        if let cached = cachedFilmGrainTextures[style] { return cached }
        let resourceName = style == "OnePlus" ? "film_grain_oneplus" : "film_grain"
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "png") else {
            return nil
        }
        guard let ci = CIImage(contentsOf: url, options: [CIImageOption.applyOrientationProperty: true]) else {
            return nil
        }
        // Clamp so tiling doesn't sample transparent edges.
        let clamped = ci.clampedToExtent()
        cachedFilmGrainTextures[style] = clamped
        return clamped
    }
    
    private func scaleToMaxPixels(_ image: UIImage, maxPixels: Int) -> UIImage {
        let currentPixels = Int(image.size.width * image.size.height)
        if currentPixels <= maxPixels {
            return image
        }
        
        let scale = sqrt(Float(maxPixels) / Float(currentPixels))
        let newSize = CGSize(
            width: image.size.width * CGFloat(scale),
            height: image.size.height * CGFloat(scale)
        )
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage ?? image
    }
    
    // MARK: - LUT Preview
    func applyLutToThumbnail(_ lut: CubeLUT) async -> UIImage? {
        guard let thumbnail = thumbnailImage else { return nil }
        return await applyLutToImage(thumbnail, lut: lut, intensity: 1.0)
    }

    func lutPreviewImage(for item: LutItem) async -> UIImage? {
        // Avoid parsing/applying hundreds of LUTs before the user picks an image.
        guard originalImage != nil else { return nil }
        guard thumbnailImage != nil else { return nil }

        let key = "\(thumbnailStamp.uuidString)|\(item.assetPath)"
        if let cached = thumbnailPreviewCache[key] { return cached }
        if let task = thumbnailPreviewTaskCache[key] { return await task.value }

        let task: Task<UIImage?, Never> = Task { [weak self] in
            guard let self else { return nil }
            // Rate-limit concurrent preview renders to avoid memory pressure.
            await self.previewSemaphore.wait()
            defer { Task { await self.previewSemaphore.signal() } }
            guard let lut = self.getLut(for: item) else { return nil }
            return await self.applyLutToThumbnail(lut)
        }

        thumbnailPreviewTaskCache[key] = task
        let result = await task.value
        thumbnailPreviewTaskCache[key] = nil
        if let result {
            thumbnailPreviewCache[key] = result
        }
        return result
    }
    
    // MARK: - Save Image
    func saveImage() {
        guard let originalImage = originalImage else { return }
        
        Task {
            var imageToSave = await renderEditedImage(from: originalImage) ?? originalImage

            if grainEnabled && grainIntensity > 0 {
                imageToSave = Self.applyFilmGrain(to: imageToSave, intensity: grainIntensity, ciContext: ciContext, style: grainStyle) ?? imageToSave
            }
            
            // Apply watermark if enabled
            if watermarkEnabled && watermarkStyle != .none {
                imageToSave = applyWatermark(to: imageToSave)
            }
            
            // Save to photo library
            saveToPhotoLibrary(imageToSave)
        }
    }
    
    private func saveToPhotoLibrary(_ image: UIImage) {
        // Cap quality at 60% for non-pro users (matches Android)
        let effectiveQuality = ProUserRepository.shared.isProUser ? saveQuality : min(saveQuality, 60)
        let compressionQuality = CGFloat(effectiveQuality) / 100.0
        let metadataSourceData = originalImageData

        guard let data = makeJPEGDataPreservingMetadata(
            from: image,
            originalData: metadataSourceData,
            compressionQuality: compressionQuality
        ) else { return }
        
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            
            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: data, options: nil)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("Image saved successfully")
                    } else if let error = error {
                        print("Save error: \(error)")
                    }
                }
            }
        }
    }

    private func makeJPEGDataPreservingMetadata(
        from image: UIImage,
        originalData: Data?,
        compressionQuality: CGFloat
    ) -> Data? {
        guard let cgImage = image.normalizedUp().cgImage else { return nil }

        var properties: [CFString: Any] = [:]
        if let originalData,
           let source = CGImageSourceCreateWithData(originalData as CFData, nil),
           let originalProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            properties = originalProperties
        }

        // Ensure the output is physically oriented "up".
        properties[kCGImagePropertyOrientation] = 1
        properties[kCGImagePropertyPixelWidth] = cgImage.width
        properties[kCGImagePropertyPixelHeight] = cgImage.height
        properties[kCGImageDestinationLossyCompressionQuality] = compressionQuality

        let outData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            outData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return outData as Data
    }
}

private extension UIImage {
    func normalizedUp() -> UIImage {
        if imageOrientation == .up { return self }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
