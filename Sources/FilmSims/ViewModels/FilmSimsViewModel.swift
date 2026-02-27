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
            currentLut = nil
            prefetchCategoryLuts()
        }
    }
    
    @Published var currentLut: LutItem? {
        didSet {
            scheduleApply()
        }
    }
    
    @Published var intensity: Float = 1.0 {
        didSet {
            scheduleApply()
        }
    }
    
    @Published var grainEnabled: Bool = false {
        didSet {
            scheduleApply()
        }
    }
    
    @Published var grainIntensity: Float = 0.5 {
        didSet {
            if grainEnabled {
                scheduleApply()
            }
        }
    }

    @Published var grainStyle: String = "Xiaomi" {
        didSet {
            if grainEnabled {
                scheduleApply()
            }
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
            scheduleApply()
        }
    }
    
    @Published var watermarkStyle: WatermarkProcessor.WatermarkStyle = .none {
        didSet {
            watermarkEnabled = (watermarkStyle != .none)
            scheduleApply()
        }
    }
    
    @Published var watermarkDeviceName: String = "" {
        didSet {
            if watermarkEnabled {
                scheduleApply()
            }
        }
    }
    
    @Published var watermarkLensInfo: String = "" {
        didSet {
            if watermarkEnabled {
                scheduleApply()
            }
        }
    }
    
    @Published var watermarkTimeText: String = "" {
        didSet {
            if watermarkEnabled {
                scheduleApply()
            }
        }
    }
    
    @Published var watermarkLocationText: String = "" {
        didSet {
            if watermarkEnabled {
                scheduleApply()
            }
        }
    }
    
    // Settings
    @Published var saveQuality: Int = 100
    
    // MARK: - Private Properties
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var lutCache: [String: CubeLUT] = [:]
    private var originalImageData: Data?

    private var applyTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    private var thumbnailStamp = UUID()
    private var thumbnailPreviewCache: [String: UIImage] = [:]
    private var thumbnailPreviewTaskCache: [String: Task<UIImage?, Never>] = [:]
    // Limits concurrent LUT parse+apply tasks for thumbnail previews.
    private let previewSemaphore = AsyncSemaphore(limit: 4)
    
    // MARK: - Computed Properties
    var currentCategories: [LutCategory] {
        selectedBrand?.categories ?? []
    }
    
    var currentLuts: [LutItem] {
        selectedCategory?.items ?? []
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
        saveQuality = settings.saveQuality
        intensity = settings.lastIntensity
        grainEnabled = settings.lastGrainEnabled
        grainIntensity = settings.lastGrainIntensity
        grainStyle = settings.lastGrainStyle
    }
    
    func saveSettings() {
        let settings = SettingsManager.shared
        settings.saveQuality = saveQuality
        settings.lastIntensity = intensity
        settings.lastGrainEnabled = grainEnabled
        settings.lastGrainIntensity = grainIntensity
        settings.lastGrainStyle = grainStyle
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
                    
                    // Reset intensity when new image is loaded
                    intensity = 1.0

                    // Extract EXIF metadata to auto-populate watermark fields.
                    readExif(from: data)

                    // Apply current LUT if selected
                    if currentLut != nil {
                        await applyCurrentLut()
                    }
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

        // If no LUT selected, still allow grain/watermark to be applied.
        guard let lutItem = currentLut,
              let lut = getLut(for: lutItem) else {
            var noLutImage = previewImage
            if grainEnabled && grainIntensity > 0 {
                noLutImage = await applyFilmGrainAsync(to: noLutImage, intensity: grainIntensity) ?? noLutImage
            }
            if watermarkEnabled && watermarkStyle != .none {
                noLutImage = applyWatermark(to: noLutImage)
            }
            processedImage = noLutImage
            return
        }
        
        if let processed = await applyLutToImage(previewImage, lut: lut, intensity: intensity) {
            var finalImage = processed

            if Task.isCancelled { return }
            
            // Apply grain if enabled
            if grainEnabled && grainIntensity > 0 {
                if let grainedImage = await applyFilmGrainAsync(to: finalImage, intensity: grainIntensity) {
                    finalImage = grainedImage
                }
            }
            
            // Apply watermark if enabled
            if watermarkEnabled && watermarkStyle != .none {
                finalImage = applyWatermark(to: finalImage)
            }
            
            if Task.isCancelled { return }
            processedImage = finalImage
        }
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
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let ciImage = CIImage(cgImage: cgImage)
                
                // Apply LUT using CIColorCube filter
                guard let filter = CIFilter(name: "CIColorCubeWithColorSpace") else {
                    continuation.resume(returning: nil)
                    return
                }
                
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filter.setValue(lut.size, forKey: "inputCubeDimension")
                filter.setValue(lut.cubeData, forKey: "inputCubeData")
                filter.setValue(CGColorSpaceCreateDeviceRGB(), forKey: "inputColorSpace")
                
                guard let outputCIImage = filter.outputImage else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Blend with original based on intensity
                let blendedImage: CIImage
                if intensity < 1.0 {
                    guard CIFilter(name: "CISourceOverCompositing") != nil else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    // Use dissolve blend instead for proper intensity mixing
                    guard let dissolveFilter = CIFilter(name: "CIDissolveTransition") else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    dissolveFilter.setValue(ciImage, forKey: kCIInputImageKey)
                    dissolveFilter.setValue(outputCIImage, forKey: kCIInputTargetImageKey)
                    dissolveFilter.setValue(NSNumber(value: intensity), forKey: kCIInputTimeKey)
                    
                    blendedImage = dissolveFilter.outputImage ?? outputCIImage
                } else {
                    blendedImage = outputCIImage
                }
                
                guard let outputCGImage = self.ciContext.createCGImage(blendedImage, from: blendedImage.extent) else {
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
            // Apply LUT to full resolution image
            var imageToSave: UIImage
            
            if let lutItem = currentLut, let lut = getLut(for: lutItem) {
                if let processed = await applyLutToImage(originalImage, lut: lut, intensity: intensity) {
                    if grainEnabled && grainIntensity > 0 {
                        imageToSave = Self.applyFilmGrain(to: processed, intensity: grainIntensity, ciContext: ciContext, style: grainStyle) ?? processed
                    } else {
                        imageToSave = processed
                    }
                } else {
                    imageToSave = originalImage
                }
            } else {
                if grainEnabled && grainIntensity > 0 {
                    imageToSave = Self.applyFilmGrain(to: originalImage, intensity: grainIntensity, ciContext: ciContext, style: grainStyle) ?? originalImage
                } else {
                    imageToSave = originalImage
                }
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
