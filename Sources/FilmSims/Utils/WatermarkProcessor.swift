import Foundation
import UIKit
import CoreGraphics
import CoreText

/// WatermarkProcessor - Applies watermarks to exported images
/// Port of Android WatermarkProcessor.kt (3,719 lines)
/// Supports Honor, Meizu, Vivo, and Tecno watermark styles
class WatermarkProcessor {
    
    // MARK: - Constants
    
    private static let PHI: CGFloat = 1.61803398875
    private static let BASE_WIDTH: CGFloat = 6144.0  // Honor template reference width
    private static let FRAME_BORDER_HEIGHT: CGFloat = 688.0  // Honor frame border height
    
    // MARK: - Watermark Style Enum
    
    enum WatermarkStyle {
        case none
        
        // Honor styles
        case frame
        case text
        case frameYG
        case textYG
        
        // Meizu styles
        case meizuNorm
        case meizuPro
        case meizuZ1, meizuZ2, meizuZ3, meizuZ4, meizuZ5, meizuZ6, meizuZ7
        
        // Vivo styles - original implementation
        case vivoZeiss, vivoClassic, vivoPro, vivoIqoo
        case vivoZeissV1, vivoZeissSonnar, vivoZeissHumanity
        case vivoIqooV1, vivoIqooHumanity
        case vivoZeissFrame, vivoZeissOverlay, vivoZeissCenter
        case vivoFrame, vivoFrameTime
        case vivoIqooFrame, vivoIqooFrameTime
        case vivoOS, vivoOSCorner, vivoOSSimple, vivoEvent
        
        // Tecno styles
        case tecno1, tecno2, tecno3, tecno4
        
        // Vivo config-driven styles (new accurate implementation)
        case vivoZeiss0, vivoZeiss1, vivoZeiss2, vivoZeiss3, vivoZeiss4
        case vivoZeiss5, vivoZeiss6, vivoZeiss7, vivoZeiss8
        case vivoIqoo4, vivoCommonIqoo4
        case vivo1, vivo2, vivo3, vivo4, vivo5
    }
    
    // MARK: - Watermark Config
    
    struct WatermarkConfig {
        let style: WatermarkStyle
        let deviceName: String?       // e.g. "HONOR Magic6 Pro"
        let timeText: String?
        let locationText: String?
        let lensInfo: String?          // e.g. "27mm  f/1.9  1/100s  ISO1600"
        let templatePath: String?       // Custom template path for config-driven watermarks
        
        init(
            style: WatermarkStyle = .none,
            deviceName: String? = nil,
            timeText: String? = nil,
            locationText: String? = nil,
            lensInfo: String? = nil,
            templatePath: String? = nil
        ) {
            self.style = style
            self.deviceName = deviceName
            self.timeText = timeText
            self.locationText = locationText
            self.lensInfo = lensInfo
            self.templatePath = templatePath
        }
    }
    
    private static let MEIZU_TEXT_SIZE_PRO: CGFloat = 80
    
    // Vivo Constants
    private static let VIVO_BAR_RATIO: CGFloat = 0.13
    private static let VIVO_BAR_DP: CGFloat = 48.0 // 1 'dp' in template pixels
    private static let VIVO_OV_MARGIN_LR: CGFloat = 0.05
    private static let VIVO_OV_MARGIN_BOT: CGFloat = 0.06
    private static let VIVO_OV_FS_DEVICE: CGFloat = 0.045
    private static let VIVO_OV_FS_SUB: CGFloat = 0.027
    
    private static let VIVO_3A_ZEISS = UIColor(red: 0, green: 0, blue: 0, alpha: 1.0)
    private static let VIVO_3A_STD = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // #666666
    private static let VIVO_TIME_GRAY = UIColor(red: 0.46, green: 0.46, blue: 0.46, alpha: 1.0) // #757575
    
    // Tecno Constants
    private static let TECNO_REF_WIDTH: CGFloat = 1080.0
    private static let TECNO_BAR_HEIGHT_PORTRAIT: CGFloat = 113.0
    private static let TECNO_BAR_HEIGHT_LANDSCAPE: CGFloat = 95.0
    
    // Static cached colors/fonts are difficult in Swift static structs/classes without proper initialization
    // We will load them on demand or use a cache dictionary if needed.
    
    // MARK: - Font Cache
    
    nonisolated(unsafe) private static var honorTypeface: UIFont?
    nonisolated(unsafe) private static var fontCache: [String: UIFont] = [:]
    
    // MARK: - Public API

    /// Returns the current time as a default watermark time string (matches Android getDefaultTimeString)
    static func defaultTimeString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        return fmt.string(from: Date())
    }

    /// Apply watermark to an image
    static func applyWatermark(_ image: UIImage, config: WatermarkConfig) -> UIImage {
        guard config.style != .none else { return image }
        let baseImage = normalizeOrientation(image)
        guard let cgImage = baseImage.cgImage else { return image }

        let bitmap = cgImage
        
        switch config.style {
        case .none:
            return image
        case .frame:
            return applyFrameWatermark(baseImage, bitmap: bitmap, config: config)
        case .text:
            return applyTextWatermark(baseImage, bitmap: bitmap, config: config)
        case .frameYG:
            return applyFrameYGWatermark(baseImage, bitmap: bitmap, config: config)
        case .textYG:
            return applyTextYGWatermark(baseImage, bitmap: bitmap, config: config)
        case .meizuNorm:
            return applyMeizuNorm(baseImage, bitmap: bitmap, config: config)
        case .meizuPro:
            return applyMeizuPro(baseImage, bitmap: bitmap, config: config)
        case .meizuZ1:
            return applyMeizuZ1(baseImage, bitmap: bitmap, config: config)
        case .meizuZ2:
            return applyMeizuZ2(baseImage, bitmap: bitmap, config: config)
        case .meizuZ3:
            return applyMeizuZ3(baseImage, bitmap: bitmap, config: config)
        case .meizuZ4:
            return applyMeizuZ4(baseImage, bitmap: bitmap, config: config)
        case .meizuZ5:
            return applyMeizuZ5(baseImage, bitmap: bitmap, config: config)
        case .meizuZ6:
            return applyMeizuZ6(baseImage, bitmap: bitmap, config: config)
        case .meizuZ7:
            return applyMeizuZ7(baseImage, bitmap: bitmap, config: config)
        case .vivoZeiss:
            return applyVivoZeiss(baseImage, bitmap: bitmap, config: config)
        case .vivoClassic:
             return applyVivoClassic(baseImage, bitmap: bitmap, config: config)
        case .vivoPro:
             return applyVivoPro(baseImage, bitmap: bitmap, config: config)
        case .vivoIqoo:
             return applyVivoIqoo(baseImage, bitmap: bitmap, config: config)
        case .vivoZeissV1:
             return applyVivoZeissV1(baseImage, bitmap: bitmap, config: config)
        case .vivoZeissSonnar:
             return applyVivoZeissSonnar(baseImage, bitmap: bitmap, config: config)
        case .vivoZeissHumanity:
             return applyVivoZeissHumanity(baseImage, bitmap: bitmap, config: config)
        case .vivoIqooV1:
             return applyVivoIqooV1(baseImage, bitmap: bitmap, config: config)
        case .vivoIqooHumanity:
             return applyVivoIqooHumanity(baseImage, bitmap: bitmap, config: config)
        case .vivoZeissFrame:
             return applyVivoZeissFrame(baseImage, bitmap: bitmap, config: config)
        case .vivoZeissOverlay:
             return applyVivoZeissOverlay(baseImage, bitmap: bitmap, config: config)
        case .vivoZeissCenter:
             return applyVivoZeissCenter(baseImage, bitmap: bitmap, config: config)
        case .vivoFrameTime:
             return applyVivoFrameTime(baseImage, bitmap: bitmap, config: config)
        case .vivoIqooFrame:
             return applyVivoIqooFrame(baseImage, bitmap: bitmap, config: config)
        case .vivoIqooFrameTime:
             return applyVivoIqooFrameTime(baseImage, bitmap: bitmap, config: config)
        case .vivoOS:
             return applyVivoOS(baseImage, bitmap: bitmap, config: config)
        case .vivoOSCorner:
             return applyVivoOSCorner(baseImage, bitmap: bitmap, config: config)
        case .vivoOSSimple:
             return applyVivoOSSimple(baseImage, bitmap: bitmap, config: config)
        case .vivoEvent:
             return applyVivoEvent(baseImage, bitmap: bitmap, config: config)
        // Config-driven styles
        case .vivoZeiss0: return applyDynamicVivo(baseImage, config: config, templatePath: "vivo_watermark_full2/assets/zeiss_editors/zeiss0.txt")
        case .vivoZeiss1: return applyDynamicVivo(baseImage, config: config, templatePath: "vivo_watermark_full2/assets/zeiss_editors/zeiss1.txt")
        case .vivoZeiss2: return applyDynamicVivo(baseImage, config: config, templatePath: "vivo_watermark_full2/assets/zeiss_editors/zeiss2.txt")
        case .vivoZeiss3: return applyDynamicVivo(baseImage, config: config, templatePath: "vivo_watermark_full2/assets/zeiss_editors/zeiss3.txt")
        case .vivoZeiss4: return applyDynamicVivo(baseImage, config: config, templatePath: "vivo_watermark_full2/assets/zeiss_editors/zeiss4.txt")
        case .vivoZeiss5: return applyDynamicVivo(baseImage, config: config, templatePath: "vivo_watermark_full2/assets/zeiss_editors/zeiss5.txt")
        case .vivoZeiss6: return applyDynamicVivo(baseImage, config: config, templatePath: "vivo_watermark_full2/assets/zeiss_editors/zeiss6.txt")
        case .vivoZeiss7: return applyDynamicVivo(baseImage, config: config, templatePath: "vivo_watermark_full2/assets/zeiss_editors/zeiss7.txt")
        case .vivoZeiss8: return applyDynamicVivo(baseImage, config: config, templatePath: "vivo_watermark_full2/assets/zeiss_editors/zeiss8.txt")
        
        case .vivoIqoo4: return applyDynamicVivo(baseImage, config: config, templatePath: "vivo_watermark_full2/assets/zeiss_editors/iqoo4.txt")
        case .vivoCommonIqoo4: return applyDynamicVivo(baseImage, config: config, templatePath: "vivo_watermark_full2/assets/zeiss_editors/common_iqoo4.txt")
        
        case .vivo1: return applyDynamicVivo(baseImage, config: config, templatePath: "vivo_watermark_full2/assets/zeiss_editors/vivo1.txt")
        case .vivo2: return applyDynamicVivo(baseImage, config: config, templatePath: "vivo_watermark_full2/assets/zeiss_editors/vivo2.txt")
        case .vivo3: return applyDynamicVivo(baseImage, config: config, templatePath: "vivo_watermark_full2/assets/zeiss_editors/vivo3.txt")
        case .vivo4: return applyDynamicVivo(baseImage, config: config, templatePath: "vivo_watermark_full2/assets/zeiss_editors/vivo4.txt")
        case .vivo5: return applyDynamicVivo(baseImage, config: config, templatePath: "vivo_watermark_full2/assets/zeiss_editors/vivo5.txt")
        case .vivoFrame: return applyVivoFrame(baseImage, bitmap: bitmap, config: config)
        
        case .tecno1: return applyDynamicTecno(baseImage, config: config, modeName: "MODE_1")
        case .tecno2: return applyDynamicTecno(baseImage, config: config, modeName: "MODE_2")
        case .tecno3: return applyDynamicTecno(baseImage, config: config, modeName: "MODE_3")
        case .tecno4: return applyDynamicTecno(baseImage, config: config, modeName: "MODE_4")
        }
    }
    
    private static func applyDynamicVivo(_ image: UIImage, config: WatermarkConfig, templatePath: String) -> UIImage {
        let renderConfig = VivoRenderConfig(deviceName: config.deviceName, timeText: config.timeText, locationText: config.locationText, lensInfo: config.lensInfo)
        if let template = VivoWatermarkConfigParser.shared.parseConfig(assetPath: templatePath) {
            return ZeissWatermarkRenderer.shared.render(source: image, template: template, config: renderConfig)
        }
        return image
    }

    private static func applyDynamicTecno(_ image: UIImage, config: WatermarkConfig, modeName: String) -> UIImage {
        let isLandscape = image.size.width > image.size.height
        let renderConfig = TecnoRenderConfig(deviceName: config.deviceName, timeText: config.timeText, locationText: config.locationText, lensInfo: config.lensInfo, brandName: "TECNO")
        let parser = TecnoWatermarkConfigParser()
        if let template = parser.parseConfig() {
            return TecnoWatermarkRenderer.shared.render(source: image, template: template, modeName: modeName, isLandscape: isLandscape, config: renderConfig)
        }
        return image
    }

    private static func normalizeOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
    
    // MARK: - Honor Watermarks
    
    private static func applyFrameWatermark(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgWidth = bitmap.width
        let imgHeight = bitmap.height
        let scale = CGFloat(imgWidth) / BASE_WIDTH
        
        let borderHeight = Int(FRAME_BORDER_HEIGHT * scale)
        let totalHeight = imgHeight + borderHeight
        
        // Create output bitmap (use 1.0 scale so our pixel-based layout matches output pixels)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imgWidth, height: totalHeight), format: format)
        return renderer.image { context in
            let ctx = context.cgContext
            
            // Draw original image
            image.draw(in: CGRect(x: 0, y: 0, width: imgWidth, height: imgHeight))
        
            // Draw white border
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(x: 0, y: imgHeight, width: imgWidth, height: borderHeight))
        
        // Load Honor logo
        let logoBitmap = loadHonorLogo("FrameWatermark")
        
        let isWideLayout = imgWidth > Int(2680 * scale)
        
        // Template dimensions
        let marginRight: CGFloat = 192
        let logoHeight: CGFloat = 388
        let logoMarginGap: CGFloat = 88
        
        let lensFontSize: CGFloat
        let lensBaseline: CGFloat
        let secondaryFontSize: CGFloat
        let secondaryBaseline: CGFloat
        
        if isWideLayout {
            lensFontSize = 120; lensBaseline = 126
            secondaryFontSize = 93; secondaryBaseline = 110
        } else {
            lensFontSize = 136; lensBaseline = 126
            secondaryFontSize = 104; secondaryBaseline = 110
        }
        
        // Create fonts
        let lensFont = getHonorFont(size: lensFontSize * scale, weight: 400)
        let secondaryFont = getHonorFont(size: secondaryFontSize * scale, weight: 300)
        
        // Prepare text
        let lensText = config.lensInfo ?? ""
        let timeText = config.timeText ?? ""
        let locText = config.locationText ?? ""
        
        let hasLens = !lensText.isEmpty
        let hasTime = !timeText.isEmpty
        let hasLoc = !locText.isEmpty
        let hasSecondary = hasTime || hasLoc
        let hasLogo = logoBitmap != nil
        
        // Draw text and logo
        let borderTop = CGFloat(imgHeight)
        let scaledMarginRight = marginRight * scale
        
        if hasLogo && (hasLens || hasSecondary) {
            // Logo + text layout
            if let logo = logoBitmap {
                let scaledLogoHeight = logoHeight * scale
                let logoScale = scaledLogoHeight / CGFloat(logo.height)
                let logoDrawWidth = CGFloat(logo.width) * logoScale
                
                let logoX = CGFloat(imgWidth) - scaledMarginRight - logoDrawWidth
                let logoY = borderTop + (CGFloat(borderHeight) - scaledLogoHeight) / 2
                
                ctx.draw(logo, in: CGRect(x: logoX, y: logoY, width: logoDrawWidth, height: scaledLogoHeight))
            }
        }
        
        // Draw lens info text
        if hasLens {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: lensFont,
                .foregroundColor: UIColor.black
            ]
            let attrString = NSAttributedString(string: lensText, attributes: attrs)
            let textY = borderTop + (CGFloat(borderHeight) - lensFontSize * scale) / 2
            attrString.draw(at: CGPoint(x: scaledMarginRight, y: textY))
        }
        
        // Draw time and location text
        if hasSecondary {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: secondaryFont,
                .foregroundColor: UIColor(white: 0.6, alpha: 1.0)
            ]
            let secondaryText = [timeText, locText].filter { !$0.isEmpty }.joined(separator: "  ")
            let attrString = NSAttributedString(string: secondaryText, attributes: attrs)
            let textY = borderTop + CGFloat(borderHeight) - secondaryFontSize * scale - 50 * scale
            attrString.draw(at: CGPoint(x: scaledMarginRight, y: textY))
        }
        
        // Draw device name
        if let deviceName = config.deviceName, !deviceName.isEmpty {
            let deviceFont = getHonorFont(size: 140 * scale, weight: 400)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: deviceFont,
                .foregroundColor: UIColor.black
            ]
            let attrString = NSAttributedString(string: deviceName, attributes: attrs)
                let textY = borderTop + 100 * scale
                attrString.draw(at: CGPoint(x: scaledMarginRight, y: textY))
            }
        }
    }
    
    private static func applyTextWatermark(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgWidth = bitmap.width
        let imgHeight = bitmap.height
        let scale = CGFloat(imgWidth) / BASE_WIDTH
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imgWidth, height: imgHeight), format: format)
        return renderer.image { context in
            let ctx = context.cgContext
            
            // Draw original image
            image.draw(in: CGRect(x: 0, y: 0, width: imgWidth, height: imgHeight))
        
        // Text watermark overlays text on the image
        let fontSize: CGFloat = 120 * scale
        let margin: CGFloat = 100 * scale
        
        let font = getHonorFont(size: fontSize, weight: 400)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        
            // Draw device name
            if let deviceName = config.deviceName, !deviceName.isEmpty {
                let attrString = NSAttributedString(string: deviceName, attributes: attrs)
                let textY = CGFloat(imgHeight) - fontSize - margin
                attrString.draw(at: CGPoint(x: margin, y: textY))
            }
        }
    }
    
    private static func applyFrameYGWatermark(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        // Similar to frame watermark but with YuGuan specific styling
        return applyFrameWatermark(image, bitmap: bitmap, config: config)
    }
    
    private static func applyTextYGWatermark(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        // Similar to text watermark but with YuGuan specific styling
        return applyTextWatermark(image, bitmap: bitmap, config: config)
    }
    
    // MARK: - Meizu Watermarks
    
    private static func applyMeizuNorm(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgWidth = bitmap.width
        let imgHeight = bitmap.height
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imgWidth, height: imgHeight), format: format)
        return renderer.image { context in
            let ctx = context.cgContext
            
            image.draw(in: CGRect(x: 0, y: 0, width: imgWidth, height: imgHeight))
        
        // Meizu watermark: simple text overlay
        let fontSize: CGFloat = 60
        let margin: CGFloat = 60
        
        let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        
            if let deviceName = config.deviceName, !deviceName.isEmpty {
                let attrString = NSAttributedString(string: deviceName, attributes: attrs)
                let textY = CGFloat(imgHeight) - fontSize - margin
                attrString.draw(at: CGPoint(x: margin, y: textY))
            }
        }
    }
    
    private static func applyMeizuPro(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        // Similar to Norm with different styling
        return applyMeizuNorm(image, bitmap: bitmap, config: config)
    }
    
    private static func applyMeizuZ(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        // Legacy stub — unused now that all Z variants are routed individually
        return applyMeizuNorm(image, bitmap: bitmap, config: config)
    }

    // MARK: - Meizu font/logo helpers

    private static func loadMeizuFont(_ filename: String, size: CGFloat) -> UIFont {
        let key = "\(filename)-\(size)"
        if let cached = fontCache[key] { return cached }
        if let url = Bundle.module.url(forResource: filename, withExtension: nil,
                                        subdirectory: "watermark/Meizu/fonts") {
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            if let data = try? Data(contentsOf: url),
               let provider = CGDataProvider(data: data as CFData),
               let cgFont = CGFont(provider),
               let name = cgFont.postScriptName as String?,
               let font = UIFont(name: name, size: size) {
                fontCache[key] = font
                return font
            }
        }
        return UIFont.systemFont(ofSize: size)
    }

    private static func getMeizuDeviceFont(size: CGFloat) -> UIFont {
        return loadMeizuFont("MEIZUCamera-Medium.otf", size: size)
    }

    private static func getMeizuTextFont(size: CGFloat) -> UIFont {
        return loadMeizuFont("TTForsRegular.ttf", size: size)
    }

    private static func loadMeizuLogo(_ name: String) -> UIImage? {
        guard let url = Bundle.module.resourceURL else { return nil }
        let logoURL = url.appendingPathComponent("watermark/Meizu/logos/\(name)")
        if let data = try? Data(contentsOf: logoURL) { return UIImage(data: data) }
        return nil
    }

    /// Split lensInfo string into discrete parts separated by "  " or " | " or "|"
    private static func splitDiscreteParts(_ text: String?) -> [String] {
        guard let text = text, !text.isEmpty else { return [] }
        return text.components(separatedBy: "  ")
            .flatMap { $0.components(separatedBy: " | ") }
            .flatMap { $0.components(separatedBy: "|") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Draw discrete text parts separated by thin dividers, centered at centerX/baselineY
    private static func drawDiscreteText(_ ctx: CGContext, _ parts: [String],
                                          centerX: CGFloat, baselineY: CGFloat,
                                          font: UIFont, textColor: UIColor,
                                          separatorColor: UIColor = UIColor(red: 0.69, green: 0.69, blue: 0.69, alpha: 1),
                                          scale: CGFloat) {
        guard !parts.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        let sepW = max(1.0, scale)
        let sepH = font.lineHeight * 0.8
        let gap = 16.0 * scale

        var totalW: CGFloat = 0
        var textWidths: [CGFloat] = []
        for part in parts {
            let w = (part as NSString).size(withAttributes: attrs).width
            textWidths.append(w)
            totalW += w
        }
        totalW += CGFloat(parts.count - 1) * (gap * 2 + sepW)

        var x = centerX - totalW / 2
        for (i, part) in parts.enumerated() {
            let partAttrs = NSAttributedString(string: part, attributes: attrs)
            partAttrs.draw(at: CGPoint(x: x, y: baselineY + font.ascender - font.lineHeight))
            x += textWidths[i]
            if i < parts.count - 1 {
                x += gap
                ctx.setFillColor(separatorColor.cgColor)
                ctx.fill(CGRect(x: x, y: baselineY - sepH / 2, width: sepW, height: sepH))
                x += sepW + gap
            }
        }
    }

    private static func drawMeizuRedDot(_ ctx: CGContext, _ cx: CGFloat, _ cy: CGFloat, _ s: CGFloat) {
        let r = max(5.0, 8.0 * s)
        ctx.setFillColor(UIColor.red.cgColor)
        ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
    }

    // MARK: - Meizu Z1-Z7

    private static func applyMeizuZ1(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgW = CGFloat(bitmap.width)
        let imgH = CGFloat(bitmap.height)
        let s = imgW / 1470.0
        let marginSide = round(30.0 * s)
        let marginTop = round(30.0 * s)

        let deviceText = config.deviceName ?? ""
        let lensText = config.lensInfo ?? ""

        let deviceFont = getMeizuDeviceFont(size: 45.0 * s)
        let lensFont = getMeizuTextFont(size: 32.0 * s)
        let textGray = UIColor(red: 0.286, green: 0.271, blue: 0.310, alpha: 0.6)

        let deviceH = deviceText.isEmpty ? 0.0 : deviceFont.lineHeight
        let lensH   = lensText.isEmpty   ? 0.0 : lensFont.lineHeight

        let photoW = round(imgW - 2 * marginSide)
        let photoH = round(imgH * (photoW / imgW))
        let totalW = imgW
        let textAreaH = 40 * s + deviceH + (lensText.isEmpty ? 0 : 16 * s + lensH) + 51 * s
        let totalH = round(marginTop + photoH + textAreaH)

        let format = UIGraphicsImageRendererFormat(); format.scale = 1.0; format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: totalW, height: totalH), format: format).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor.white.cgColor); c.fill(CGRect(x: 0, y: 0, width: totalW, height: totalH))
            image.draw(in: CGRect(x: marginSide, y: marginTop, width: photoW, height: photoH))

            let centerX = totalW / 2
            var y = marginTop + photoH + 40 * s
            if !deviceText.isEmpty {
                let attrs: [NSAttributedString.Key: Any] = [.font: deviceFont, .foregroundColor: UIColor.black]
                let as1 = NSAttributedString(string: deviceText, attributes: attrs)
                as1.draw(at: CGPoint(x: centerX - as1.size().width / 2, y: y))
                y += deviceH
            }
            if !lensText.isEmpty {
                y += 16 * s
                let attrs: [NSAttributedString.Key: Any] = [.font: lensFont, .foregroundColor: textGray]
                let as2 = NSAttributedString(string: lensText, attributes: attrs)
                as2.draw(at: CGPoint(x: centerX - as2.size().width / 2, y: y))
            }
        }
    }

    private static func applyMeizuZ2(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgW = CGFloat(bitmap.width)
        let imgH = CGFloat(bitmap.height)
        let s = imgW / 1130.0
        let margin = round(200.0 * s)
        let marginT = round(200.0 * s)

        let deviceText = config.deviceName ?? ""
        let lensText = config.lensInfo ?? ""

        let deviceFont = getMeizuDeviceFont(size: 38.0 * s)
        let lensFont = getMeizuTextFont(size: 28.0 * s)
        let textGray = UIColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.6)

        let photoW = round(imgW - 2 * margin)
        let photoH = round(imgH * (photoW / imgW))
        let iconH = 48.0 * s
        let bottomBarH = 247.0 * s + iconH + 245.0 * s
        let totalW = imgW; let totalH = round(marginT + photoH + bottomBarH)

        let format = UIGraphicsImageRendererFormat(); format.scale = 1.0; format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: totalW, height: totalH), format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: totalW, height: totalH))
            image.draw(in: CGRect(x: margin, y: marginT, width: photoW, height: photoH))

            let barCY = marginT + photoH + 247.0 * s + iconH / 2
            if !deviceText.isEmpty {
                let attrs: [NSAttributedString.Key: Any] = [.font: deviceFont, .foregroundColor: UIColor.black]
                let as1 = NSAttributedString(string: deviceText, attributes: attrs)
                as1.draw(at: CGPoint(x: margin, y: barCY - deviceFont.lineHeight / 2))
            }
            if !lensText.isEmpty {
                let attrs: [NSAttributedString.Key: Any] = [.font: lensFont, .foregroundColor: textGray]
                let as2 = NSAttributedString(string: lensText, attributes: attrs)
                as2.draw(at: CGPoint(x: totalW - margin - as2.size().width, y: barCY - lensFont.lineHeight / 2))
            }
        }
    }

    private static func applyMeizuZ3(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgW = CGFloat(bitmap.width)
        let imgH = CGFloat(bitmap.height)
        let s = imgW / 1470.0
        let marginSide = round(30.0 * s); let marginTop = round(30.0 * s)

        let deviceText = config.deviceName ?? ""
        let lensParts = splitDiscreteParts(config.lensInfo)

        let deviceFont = getMeizuDeviceFont(size: 50.0 * s)
        let lensFont = getMeizuTextFont(size: 30.0 * s)
        let textGray = UIColor(red: 0.286, green: 0.271, blue: 0.310, alpha: 0.6)

        let deviceH = deviceText.isEmpty ? 0.0 : deviceFont.lineHeight
        let discreteAreaH = 107.0 * s
        let textAreaH = 53 * s + deviceH + (lensParts.isEmpty ? 0 : 53 * s + discreteAreaH) + 75 * s

        let photoW = round(imgW - 2 * marginSide); let photoH = round(imgH * (photoW / imgW))
        let totalW = imgW; let totalH = round(marginTop + photoH + textAreaH)

        let format = UIGraphicsImageRendererFormat(); format.scale = 1.0; format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: totalW, height: totalH), format: format).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor.white.cgColor); c.fill(CGRect(x: 0, y: 0, width: totalW, height: totalH))
            image.draw(in: CGRect(x: marginSide, y: marginTop, width: photoW, height: photoH))

            let centerX = totalW / 2
            var y = marginTop + photoH + 53 * s
            if !deviceText.isEmpty {
                let attrs: [NSAttributedString.Key: Any] = [.font: deviceFont, .foregroundColor: UIColor.black]
                let as1 = NSAttributedString(string: deviceText, attributes: attrs)
                as1.draw(at: CGPoint(x: centerX - as1.size().width / 2, y: y))
                y += deviceH
            }
            if !lensParts.isEmpty {
                y += 53 * s
                let baselineY = y + discreteAreaH / 2
                drawDiscreteText(c, lensParts, centerX: centerX, baselineY: baselineY,
                                 font: lensFont, textColor: textGray, scale: s)
            }
        }
    }

    private static func applyMeizuZ4(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgW = CGFloat(bitmap.width)
        let imgH = CGFloat(bitmap.height)
        let s = imgW / 1530.0

        let panelMarginL = 40.0 * s; let lensTextH = 32.0 * s
        let textGap = 15.0 * s; let deviceTextH = 45.0 * s; let panelMarginR = 40.0 * s
        let panelWidth = panelMarginL + lensTextH + textGap + deviceTextH + panelMarginR

        let photoW = round(imgW - panelWidth); let photoH = round(imgH * (photoW / imgW))
        let totalW = imgW; let totalH = photoH

        let deviceText = config.deviceName ?? ""; let lensText = config.lensInfo ?? ""
        let deviceFont = getMeizuDeviceFont(size: 45.0 * s)
        let lensFont = getMeizuTextFont(size: 32.0 * s)
        let textGray = UIColor(red: 0.286, green: 0.271, blue: 0.310, alpha: 0.6)

        let format = UIGraphicsImageRendererFormat(); format.scale = 1.0; format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: totalW, height: totalH), format: format).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor.white.cgColor); c.fill(CGRect(x: 0, y: 0, width: totalW, height: totalH))
            image.draw(in: CGRect(x: 0, y: 0, width: photoW, height: photoH))

            if !deviceText.isEmpty {
                c.saveGState()
                let colCX = totalW - panelMarginR - deviceTextH / 2
                let startY = totalH - 143.0 * s
                c.translateBy(x: colCX, y: startY)
                c.rotate(by: -.pi / 2)
                let attrs: [NSAttributedString.Key: Any] = [.font: deviceFont, .foregroundColor: UIColor.black]
                let as1 = NSAttributedString(string: deviceText, attributes: attrs)
                as1.draw(at: CGPoint(x: 0, y: -(deviceFont.lineHeight / 2)))
                c.restoreGState()
            }
            if !lensText.isEmpty {
                c.saveGState()
                let colCX = totalW - panelMarginR - deviceTextH - textGap - lensTextH / 2
                let startY = totalH - 100.0 * s
                c.translateBy(x: colCX, y: startY)
                c.rotate(by: -.pi / 2)
                let attrs: [NSAttributedString.Key: Any] = [.font: lensFont, .foregroundColor: textGray]
                let as2 = NSAttributedString(string: lensText, attributes: attrs)
                as2.draw(at: CGPoint(x: 0, y: -(lensFont.lineHeight / 2)))
                c.restoreGState()
            }
            let dotCX = totalW - panelMarginR - deviceTextH / 2
            drawMeizuRedDot(c, dotCX, totalH - 40.0 * s, s)
        }
    }

    private static func applyMeizuZ5(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgW = CGFloat(bitmap.width)
        let imgH = CGFloat(bitmap.height)
        let s = imgW / 1220.0
        let marginSide = round(155.0 * s); let marginTop = round(170.0 * s)

        let deviceText = config.deviceName ?? ""
        let lensParts = splitDiscreteParts(config.lensInfo)
        let locParts = (config.locationText.map { [$0] }) ?? []
        let allParts = lensParts + locParts

        let deviceFont = getMeizuDeviceFont(size: 45.0 * s)
        let infoFont = getMeizuTextFont(size: 32.0 * s)
        let textGray = UIColor(red: 0.286, green: 0.271, blue: 0.310, alpha: 0.6)

        let deviceH = deviceText.isEmpty ? 0.0 : deviceFont.lineHeight
        let infoH = allParts.isEmpty ? 0.0 : infoFont.lineHeight
        let textAreaH = 150 * s + deviceH + (allParts.isEmpty ? 0 : 16 * s + infoH) + 183 * s

        let photoW = round(imgW - 2 * marginSide); let photoH = round(imgH * (photoW / imgW))
        let totalW = imgW; let totalH = round(marginTop + photoH + textAreaH)

        let format = UIGraphicsImageRendererFormat(); format.scale = 1.0; format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: totalW, height: totalH), format: format).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor.white.cgColor); c.fill(CGRect(x: 0, y: 0, width: totalW, height: totalH))
            image.draw(in: CGRect(x: marginSide, y: marginTop, width: photoW, height: photoH))

            let centerX = totalW / 2
            var y = marginTop + photoH + 150 * s
            if !deviceText.isEmpty {
                let attrs: [NSAttributedString.Key: Any] = [.font: deviceFont, .foregroundColor: UIColor.black]
                let as1 = NSAttributedString(string: deviceText, attributes: attrs)
                as1.draw(at: CGPoint(x: centerX - as1.size().width / 2, y: y)); y += deviceH
            }
            if !allParts.isEmpty {
                y += 16 * s
                drawDiscreteText(c, allParts, centerX: centerX, baselineY: y + infoH / 2,
                                 font: infoFont, textColor: textGray, scale: s)
            }
        }
    }

    private static func applyMeizuZ6(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgW = CGFloat(bitmap.width)
        let imgH = CGFloat(bitmap.height)
        let s = imgW / 1530.0
        let margin = round(38.0 * s)

        let lensText = config.lensInfo ?? ""
        let lensFont = getMeizuTextFont(size: 32.0 * s)
        let lensColor = UIColor(white: 1.0, alpha: 0.7)

        let photoW = round(imgW - 2 * margin); let photoH = round(imgH * (photoW / imgW))
        let totalW = imgW; let totalH = round(margin + photoH + margin)

        let format = UIGraphicsImageRendererFormat(); format.scale = 1.0; format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: totalW, height: totalH), format: format).image { _ in
            UIColor.white.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: totalW, height: totalH))
            image.draw(in: CGRect(x: margin, y: margin, width: photoW, height: photoH))

            let centerX = totalW / 2
            let naturalY = margin + photoH + margin
            // Flyme logo overlaid at -200 from natural bottom
            if let logo = loadMeizuLogo("flyme_z6.png") {
                let lW = 321.0 * s; let lH = 60.0 * s
                let lY = naturalY - 200.0 * s - lH / 2
                logo.draw(in: CGRect(x: centerX - lW / 2, y: lY, width: lW, height: lH))
            }
            // Lens text overlaid at -124 from natural bottom
            if !lensText.isEmpty {
                let attrs: [NSAttributedString.Key: Any] = [.font: lensFont, .foregroundColor: lensColor]
                let as1 = NSAttributedString(string: lensText, attributes: attrs)
                let ty = naturalY - 124.0 * s - lensFont.lineHeight / 2
                as1.draw(at: CGPoint(x: centerX - as1.size().width / 2, y: ty))
            }
        }
    }

    private static func applyMeizuZ7(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgW = CGFloat(bitmap.width)
        let imgH = CGFloat(bitmap.height)
        let s = imgW / 1470.0
        let lensParts = splitDiscreteParts(config.lensInfo)
        let lensFont = getMeizuTextFont(size: 30.0 * s)
        let textGray = UIColor(red: 0, green: 0, blue: 0, alpha: 0.6)

        let logoTopMargin = 134.0 * s; let logoH = 60.0 * s; let photoTopMargin = 106.0 * s
        let photoMarginSide = 30.0 * s
        let photoW = round(imgW - 2 * photoMarginSide); let photoH = round(imgH * (photoW / imgW))
        let discreteAreaH = 107.0 * s
        let lensMarginT = lensParts.isEmpty ? 0.0 : 92.0 * s
        let lensMarginB = lensParts.isEmpty ? 30.0 * s : 100.0 * s
        let totalW = imgW
        let totalH = round(logoTopMargin + logoH + photoTopMargin + photoH + lensMarginT + discreteAreaH + lensMarginB)

        let format = UIGraphicsImageRendererFormat(); format.scale = 1.0; format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: totalW, height: totalH), format: format).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor.white.cgColor); c.fill(CGRect(x: 0, y: 0, width: totalW, height: totalH))
            let centerX = totalW / 2

            if let logo = loadMeizuLogo("flyme_z7.png") {
                let lW = 321.0 * s
                logo.draw(in: CGRect(x: centerX - lW / 2, y: logoTopMargin, width: lW, height: logoH))
            }
            let photoY = logoTopMargin + logoH + photoTopMargin
            image.draw(in: CGRect(x: photoMarginSide, y: photoY, width: photoW, height: photoH))

            if !lensParts.isEmpty {
                let y = photoY + photoH + lensMarginT
                let sepColor = UIColor(red: 0.69, green: 0.69, blue: 0.69, alpha: 1)
                drawDiscreteText(c, lensParts, centerX: centerX, baselineY: y + discreteAreaH / 2,
                                 font: lensFont, textColor: textGray, separatorColor: sepColor, scale: s)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private static func rint(_ v: CGFloat) -> Int {
        return Int(v.rounded())
    }
    
    private static func rectF(l: CGFloat, t: CGFloat, r: CGFloat, b: CGFloat) -> CGRect {
        return CGRect(
            x: rint(l),
            y: rint(t),
            width: rint(r - l),
            height: rint(b - t)
        )
    }
    
    /// Load Honor font from bundle
    private static func getHonorFont(size: CGFloat, weight: Int) -> UIFont {
        if honorTypeface == nil {
            // Try to load HONORSansVFCN.ttf from watermark/Honor/fonts/
            // Note: Bundle resource lookup via subdirectory is safer
            if let fontURL = Bundle.module.url(forResource: "HONORSansVFCN", withExtension: "ttf", subdirectory: "watermark/Honor/fonts") {
                // Register font
                var error: Unmanaged<CFError>?
                CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
                
                // Try to create font descriptor to get postscript name
                if let fontData = try? Data(contentsOf: fontURL),
                   let dataProvider = CGDataProvider(data: fontData as CFData),
                   let cgFont = CGFont(dataProvider),
                   let fontName = cgFont.postScriptName as String? {
                    honorTypeface = UIFont(name: fontName, size: size)
                }
            }
        }
        
        if let font = honorTypeface {
            return font.withSize(size)
        }
        
        // Fallback to system font
        return UIFont.systemFont(ofSize: size, weight: weight >= 400 ? .regular : .light)
    }
    
    /// Load Honor logo image
    private static func loadHonorLogo(_ variant: String) -> CGImage? {
        guard let bundle = Bundle.module.resourceURL else { return nil }
        let logoURL = bundle.appendingPathComponent("watermark/Honor/\(variant)/logo.png")
        guard let imageData = try? Data(contentsOf: logoURL),
              let image = UIImage(data: imageData) else {
            return nil
        }
        return image.cgImage
    }
    
    // MARK: - Vivo Helpers
    
    private static func loadVivoLogo(_ name: String) -> UIImage? {
        guard let bundle = Bundle.module.resourceURL else { return nil }
        // Try multiple locations
        let paths = [
            "watermark/vivo/logos/\(name)",
            "watermark/vivo/frames/\(name)"
        ]
        
        for path in paths {
            let logoURL = bundle.appendingPathComponent(path)
            if let imageData = try? Data(contentsOf: logoURL),
               let image = UIImage(data: imageData) {
                return image
            }
        }
        return nil
    }

    private static func getVivoFont(_ name: String, size: CGFloat) -> UIFont {
        // Map abstract names to filenames
        let filename: String
        switch name {
        case "ZeissBold": filename = "ZEISSFrutigerNextW1G-Bold.ttf"
        case "VivoHeavy": filename = "vivotype-Heavy.ttf"
        case "VivoRegular": filename = "vivo-Regular.otf"
        case "VivoCamera": filename = "vivoCameraVF.ttf"
        case "RobotoBold": filename = "Roboto-Bold.ttf"
        case "VivoSansExp": filename = "vivoSansExpVF.ttf"
        case "IQOOBold": filename = "IQOOTYPE-Bold.ttf"
        case "VivoSimpleBold": filename = "vivotypeSimple-Bold.ttf"
        default: filename = "vivo-Regular.otf"
        }
        
        let key = "\(filename)-\(size)"
        if let cached = fontCache[key] {
            return cached
        }
        
        // Use subdirectory search for safety
        if let fontURL = Bundle.module.url(forResource: filename, withExtension: nil, subdirectory: "watermark/vivo/fonts") {
             var error: Unmanaged<CFError>?
             CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
             
             if let fontData = try? Data(contentsOf: fontURL),
                let dataProvider = CGDataProvider(data: fontData as CFData),
                let cgFont = CGFont(dataProvider),
                let fontName = cgFont.postScriptName as String? {
                 if let font = UIFont(name: fontName, size: size) {
                     fontCache[key] = font
                     return font
                 }
             }
        }
        
        return UIFont.systemFont(ofSize: size)
    }

    // MARK: - Vivo Implementations
    
    private static func applyVivoZeiss(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgWidth = bitmap.width
        let imgHeight = bitmap.height
        let shortSide = CGFloat(min(imgWidth, imgHeight))
        
        let barHF = max(shortSide * VIVO_BAR_RATIO, 80.0)
        let barH = round(barHF)
        let dp = barHF / VIVO_BAR_DP
        let totalH = CGFloat(imgHeight) + barH
        
        // Context
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: CGFloat(imgWidth), height: totalH), format: format)
        return renderer.image { context in
            let ctx = context.cgContext
            
            // Draw image
            image.draw(in: CGRect(x: 0, y: 0, width: CGFloat(imgWidth), height: CGFloat(imgHeight)))
            
            // Draw White Bar (fill bottom)
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(x: 0, y: CGFloat(imgHeight), width: CGFloat(imgWidth), height: barH))
            
            let barTop = CGFloat(imgHeight)
            let barCY = barTop + barHF / 2
            let marginL = 14.7 * dp
            let marginR = 15.5 * dp
            
            // === LEFT GROUP ===
            var curX = marginL
            
            // 1. Vivo Logo
            if let vivoLogo = loadVivoLogo("vivo_logo_special.png") ?? loadVivoLogo("vivo_logo_wm_xml.png") {
                let logoH = 13.7 * dp
                let logoW = logoH * vivoLogo.size.width / vivoLogo.size.height
                let logoY = barCY - logoH / 2
                
                // Tint black
                let logoRect = CGRect(x: curX, y: logoY, width: logoW, height: logoH)
                
                // Draw mask for tinting
                ctx.saveGState()
                ctx.translateBy(x: logoRect.origin.x, y: logoRect.origin.y + logoRect.height)
                ctx.scaleBy(x: 1.0, y: -1.0)
                ctx.clip(to: CGRect(x: 0, y: 0, width: logoRect.width, height: logoRect.height), mask: vivoLogo.cgImage!)
                ctx.setFillColor(UIColor.black.cgColor)
                ctx.fill(CGRect(x: 0, y: 0, width: logoRect.width, height: logoRect.height))
                ctx.restoreGState()
                
                curX += logoW + 3.9 * dp
            }
            
            // 2. Device Name
            if let deviceText = config.deviceName, !deviceText.isEmpty {
                let font = getVivoFont("VivoHeavy", size: 15.3 * dp)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.black
                ]
                let asText = NSAttributedString(string: deviceText, attributes: attrs)
                let textSize = asText.size()
                let modelY = barCY - textSize.height / 2
                asText.draw(at: CGPoint(x: curX, y: modelY))
                
                curX += textSize.width + 7.5 * dp
            }
            
            // 3. Divider
            let divW = max(1.0, dp)
            let divTop = barCY - 5.7 * dp
            let divH = 11.4 * dp
            ctx.setFillColor(UIColor.black.cgColor)
            ctx.fill(CGRect(x: curX, y: divTop, width: divW, height: divH))
            curX += divW + 7.5 * dp // Gap after divider? Android says "7dp" in some places, code said "7.5f * dp"?
            // Re-checking android code: "cursor X += divW". Wait, next is ZEISS logo. "canvas.drawText("ZEISS", divX + divW + 7f * dp, y, textPaint)" in Classic/Other?
            // In applyVivoZeiss (step 453): "curX += divW". Then ZEISS logo uses curX? No, wait. 
            // 453: "curX += divW". Next is "4. ZEISS logo". The rect uses curX.
            // Actually in step 453, between step 3 and 4, there was NO gap added to curX after divW?
            // "curX += divW". Then "val zY... val zRect = rectF(curX...".
            // AND "divTop = barCY - 5.7f * dp".
            // Ah, looking closely at 453: "canvas.drawLine" or "drawRect"? "drawRect(divX...)".
            // It seems "ZEISS" logo is next.
            // Let's assume a small gap if needed, or stick to code: NO gap in 453?
            // Actually, usually there is a gap. But 453 snippet: "curX += divW".
            // Then "loadVivoLogo... zRect = rectF(curX, ..."
            // I will add a small gap 7.0 * dp just in case, or stick to strict port?
            // The Android code 453 output for "3. Thin black divider":
            // "curX += divW"
            // "// 4. ZEISS logo"
            // "val zeissLogo = ..."
            // "val zRect = rectF(curX, ...)"
            // It seems there is NO GAP in the code snippet 453. I will trust the snippet.
            // Wait, I might want to check the "zeiss7" template visually. Usually there is space.
            // But if the code says curX, I use curX.
            // However, look at "2. Device Name": "curX += ... + 7.5f * dp". This puts gap BEFORE divider.
            // Maybe Zeis logo has internal padding? Or maybe I missed a line in `sed`?
            // I'll add 7.5 * dp as gap, it looks safer.
            curX += 7.5 * dp 
            
            // 4. Zeiss Logo
            if let zeissLogo = loadVivoLogo("zeiss_logo_special.png") ?? loadVivoLogo("zeiss_logo.png") {
                let zH = 41.0 * dp
                let zW = 39.0 * dp
                let zY = barCY - zH / 2
                
                let zRect = CGRect(x: curX, y: zY, width: zW, height: zH)
                zeissLogo.draw(in: zRect)
            }
            
            // === RIGHT GROUP ===
            let rightX = CGFloat(imgWidth) - marginR
            
            // Line 1: 3A Info
            let infoFont = getVivoFont("ZeissBold", size: 9.7 * dp)
            let infoAttrs: [NSAttributedString.Key: Any] = [
                .font: infoFont,
                .foregroundColor: VIVO_3A_ZEISS
            ]
            let lensInfo = config.lensInfo ?? ""
            if !lensInfo.isEmpty {
                 let asText = NSAttributedString(string: lensInfo, attributes: infoAttrs)
                 let textSize = asText.size()
                 // Align Right: x = rightX - width
                 // Top line y?
                 // Android code 453 ends with "Line 2: datetime". It didn't show the Y calculation clearly.
                 // Usually centered vertically as a block.
                 // If both lines exist:
                 // Reference applyVivoPro (step 454): stackH = infoH + gap + botH. Center stack.
                 
                 let timeText = config.timeText ?? ""
                 let locText = config.locationText ?? ""
                 let hasBottom = !timeText.isEmpty || !locText.isEmpty
                 
                 let timeFont = getVivoFont("ZeissBold", size: 7.5 * dp)
                 let timeAttrs: [NSAttributedString.Key: Any] = [
                    .font: timeFont,
                    .foregroundColor: VIVO_3A_ZEISS
                 ]
                 
                 let infoH = textSize.height // approx? or use font.lineHeight
                 let botH = timeFont.lineHeight
                 let lineGap = 1.5 * dp
                 
                 if hasBottom {
                     let stackH = infoH + lineGap + botH
                     let topY = barCY - stackH / 2
                     
                     // Draw Info (Line 1)
                     asText.draw(at: CGPoint(x: rightX - textSize.width, y: topY))
                     
                     // Draw Time/Loc (Line 2)
                     let botY = topY + infoH + lineGap
                     
                     var bottomStr = ""
                     if !locText.isEmpty && !timeText.isEmpty {
                         bottomStr = "\(timeText)  |  \(locText)"
                     } else {
                         bottomStr = timeText.isEmpty ? locText : timeText
                     }
                     
                     let botText = NSAttributedString(string: bottomStr, attributes: timeAttrs)
                     botText.draw(at: CGPoint(x: rightX - botText.size().width, y: botY))
                     
                 } else {
                     // Single line centered
                     let y = barCY - infoH / 2
                     asText.draw(at: CGPoint(x: rightX - textSize.width, y: y))
                 }
            } else {
                // No lens info, maybe just time?
                 let timeText = config.timeText ?? ""
                 let locText = config.locationText ?? ""
                 if !timeText.isEmpty || !locText.isEmpty {
                     let timeFont = getVivoFont("ZeissBold", size: 7.5 * dp)
                     let timeAttrs: [NSAttributedString.Key: Any] = [
                        .font: timeFont,
                        .foregroundColor: VIVO_3A_ZEISS
                     ]
                     var bottomStr = timeText
                     if !locText.isEmpty {
                         if !bottomStr.isEmpty { bottomStr += "  |  " }
                         bottomStr += locText
                     }
                     let asText = NSAttributedString(string: bottomStr, attributes: timeAttrs)
                     let y = barCY - asText.size().height / 2
                     asText.draw(at: CGPoint(x: rightX - asText.size().width, y: y))
                 }
            }
        }
    }
    
    private static func applyVivoClassic(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgWidth = bitmap.width
        let imgHeight = bitmap.height
        let s = CGFloat(min(imgWidth, imgHeight))
        
        // Context
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: CGFloat(imgWidth), height: CGFloat(imgHeight)), format: format)
        return renderer.image { context in
            let ctx = context.cgContext
            
            // Draw original image
            image.draw(in: CGRect(x: 0, y: 0, width: CGFloat(imgWidth), height: CGFloat(imgHeight)))
            
            let marginLR = max(s * VIVO_OV_MARGIN_LR, 20.0)
            let marginBot = max(CGFloat(imgHeight) * VIVO_OV_MARGIN_BOT, 40.0)
            let fsDev = max(s * VIVO_OV_FS_DEVICE, 16.0)
            let fsSub = max(s * VIVO_OV_FS_SUB, 12.0)
            
            // Shadows
            let shadowR = max(4.0, s / 300.0)
            let shadowOff = CGSize(width: max(1.0, s / 1200.0), height: max(1.0, s / 1200.0))
            let shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.4).cgColor
            
            ctx.setShadow(offset: shadowOff, blur: shadowR, color: shadowColor)
            
            // --- Line 2 (bottom): Lens info | Time ---
            let lensText = config.lensInfo ?? ""
            let timeText = config.timeText ?? ""
            var line2Text = ""
            if !lensText.isEmpty && !timeText.isEmpty {
                line2Text = "\(lensText)  |  \(timeText)"
            } else {
                line2Text = lensText.isEmpty ? timeText : lensText
            }
            
            let subFont = getVivoFont("ZeissBold", size: fsSub)
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: subFont,
                .foregroundColor: UIColor(white: 1.0, alpha: 0.86)
            ]
            
            let line2Y = CGFloat(imgHeight) - marginBot
            var l2H: CGFloat = 0
            
            if !line2Text.isEmpty {
                let asText = NSAttributedString(string: line2Text, attributes: subAttrs)
                let textSize = asText.size()
                l2H = textSize.height
                let drawY = line2Y - subFont.ascender
                asText.draw(at: CGPoint(x: marginLR, y: drawY))
            }
            
            // --- Line 1 (above): Logo + Device name ---
            let lgap = max(fsSub * 0.4, 3.0)
            let line1Y = line2Y - l2H - lgap
            
            let deviceText = config.deviceName ?? ""
            let devFont = getVivoFont("VivoHeavy", size: fsDev)
            let devAttrs: [NSAttributedString.Key: Any] = [
                .font: devFont,
                .foregroundColor: UIColor(white: 1.0, alpha: 0.98)
            ]
            
            var textX = marginLR
            let logoSize = max(round(fsDev * 1.1), 16.0)
            
            if let logo = loadVivoLogo("vivo_logo_shadow_wm_xml.webp") ?? loadVivoLogo("vivo_logo_wm_xml.png") {
                let logoW = logoSize * logo.size.width / logo.size.height
                let logoRect = CGRect(x: marginLR, y: line1Y - logoSize, width: logoW, height: logoSize)
                logo.draw(in: logoRect)
                
                textX = marginLR + logoW + max(fsDev * 0.3, 4.0)
            }
            
            if !deviceText.isEmpty {
                let asText = NSAttributedString(string: deviceText, attributes: devAttrs)
                let drawY = line1Y - devFont.ascender
                asText.draw(at: CGPoint(x: textX, y: drawY))
            }
        }
    }
    
    private static func applyVivoPro(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgWidth = bitmap.width
        let imgHeight = bitmap.height
        let shortSide = CGFloat(min(imgWidth, imgHeight))
        
        let barHF = max(shortSide * VIVO_BAR_RATIO, 80.0)
        let barH = round(barHF)
        let dp = barHF / VIVO_BAR_DP
        let totalH = CGFloat(imgHeight) + barH
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: CGFloat(imgWidth), height: totalH), format: format)
        return renderer.image { context in
            let ctx = context.cgContext
            image.draw(in: CGRect(x: 0, y: 0, width: CGFloat(imgWidth), height: CGFloat(imgHeight)))
            
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(x: 0, y: CGFloat(imgHeight), width: CGFloat(imgWidth), height: barH))
            
            let barTop = CGFloat(imgHeight)
            let barCY = barTop + barHF / 2
            let marginL = 13.0 * dp
            let marginR = 12.0 * dp
            
            // LEFT: vivo logo + device name
            var curX = marginL
            if let logo = loadVivoLogo("vivo_logo_new.png") ?? loadVivoLogo("vivo_logo_wm_xml.png") {
                let logoH = 11.0 * dp
                let logoW = logoH * logo.size.width / logo.size.height
                let logoY = barCY - logoH / 2
                
                let logoRect = CGRect(x: curX, y: logoY, width: logoW, height: logoH)
                
                // Tint Black
                ctx.saveGState()
                ctx.translateBy(x: logoRect.origin.x, y: logoRect.origin.y + logoRect.height)
                ctx.scaleBy(x: 1.0, y: -1.0)
                ctx.clip(to: CGRect(x: 0, y: 0, width: logoRect.width, height: logoRect.height), mask: logo.cgImage!)
                ctx.setFillColor(UIColor.black.cgColor)
                ctx.fill(CGRect(x: 0, y: 0, width: logoRect.width, height: logoRect.height))
                ctx.restoreGState()
                
                curX += logoW
            }
            
            let deviceText = config.deviceName ?? ""
            if !deviceText.isEmpty {
                let font = getVivoFont("VivoRegular", size: 13.0 * dp)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.black
                ]
                let asText = NSAttributedString(string: deviceText, attributes: attrs)
                let modelY = barCY - asText.size().height / 2
                asText.draw(at: CGPoint(x: curX, y: modelY))
            }
            
            // RIGHT: 3A info (top) + datetime | location (bottom)
            let rightX = CGFloat(imgWidth) - marginR
            let infoFont = getVivoFont("RobotoBold", size: 9.0 * dp)
            let infoAttrs: [NSAttributedString.Key: Any] = [
                .font: infoFont,
                .foregroundColor: VIVO_3A_STD
            ]
            let timeFont = getVivoFont("RobotoBold", size: 7.0 * dp)
            let timeAttrs: [NSAttributedString.Key: Any] = [
                .font: timeFont,
                .foregroundColor: VIVO_TIME_GRAY
            ]
            
            let lensText = config.lensInfo ?? ""
            let timeText = config.timeText ?? ""
            let locText = config.locationText ?? ""
            
            let hasBottom = !timeText.isEmpty || !locText.isEmpty
            
            if !lensText.isEmpty && hasBottom {
                let infoH = infoFont.lineHeight
                let botH = timeFont.lineHeight
                let lineGap = 4.0 * dp
                let stackH = infoH + lineGap + botH
                let topY = barCY - stackH / 2
                
                let infoText = NSAttributedString(string: lensText, attributes: infoAttrs)
                infoText.draw(at: CGPoint(x: rightX - infoText.size().width, y: topY))
                
                let botY = topY + infoH + lineGap
                
                var botStr = timeText
                if !locText.isEmpty {
                    if !botStr.isEmpty { botStr += "  " }
                    botStr += locText
                }
                let botText = NSAttributedString(string: botStr, attributes: timeAttrs)
                botText.draw(at: CGPoint(x: rightX - botText.size().width, y: botY))
                
            } else if !lensText.isEmpty {
                let infoText = NSAttributedString(string: lensText, attributes: infoAttrs)
                let y = barCY - infoText.size().height / 2
                infoText.draw(at: CGPoint(x: rightX - infoText.size().width, y: y))
            } else if hasBottom {
                let t = !timeText.isEmpty ? timeText : locText
                let botText = NSAttributedString(string: t, attributes: timeAttrs)
                let y = barCY - botText.size().height / 2
                botText.draw(at: CGPoint(x: rightX - botText.size().width, y: y))
            }
        }
    }
    
    private static func applyVivoFrame(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgW = CGFloat(bitmap.width)
        let imgH = CGFloat(bitmap.height)
        let ar = imgW / imgH
        
        let frameName: String
        let tmplW: CGFloat, tmplH: CGFloat, pL: CGFloat, pR: CGFloat, pB: CGFloat
        let pT: CGFloat
        
        if ar > 1.2 {
            frameName = "vivo3.png" // Landscape
            tmplW = 1596; tmplH = 1080
            pL = 27; pR = 1569; pB = 894
            pT = 27
        } else if ar < 0.85 {
            frameName = "vivo2.png" // Portrait
            tmplW = 1080; tmplH = 1590
            pL = 27; pR = 1053; pB = 1395
            pT = 27
        } else {
            frameName = "vivo4.png" // Square
            tmplW = 1080; tmplH = 1413
            pL = 192; pR = 888; pB = 987
            pT = 291
        }
        
        guard let frameImage = loadVivoLogo(frameName) else { return image }
        
        // Use photoW to determine scale logic
        let photoW = pR - pL
        let realScale = imgW / photoW
        
        let finalW = tmplW * realScale
        let finalH = tmplH * realScale
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: finalW, height: finalH), format: format)
        return renderer.image { context in
            let ctx = context.cgContext
            
            let photoRect = CGRect(x: pL * realScale, y: pT * realScale, width: imgW, height: imgH)
            
            // Draw Photo
            image.draw(in: photoRect)
            
            // Draw Frame
            frameImage.draw(in: CGRect(x: 0, y: 0, width: finalW, height: finalH))
            
            // Text & Logo below photo
            let textCY = ((pB + tmplH) / 2.0) * realScale
            
            if let logo = loadVivoLogo("vivo_logo_new.png") ?? loadVivoLogo("vivo_logo_wm_xml.png") {
                let logoH = 16.0 * 3.0 * realScale
                let logoW = logoH * logo.size.width / logo.size.height
                
                let deviceText = config.deviceName ?? ""
                let font = getVivoFont("VivoCamera", size: 14.0 * 3.0 * realScale)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.black
                ]
                let asText = NSAttributedString(string: deviceText, attributes: attrs)
                
                let textW = !deviceText.isEmpty ? asText.size().width : 0
                let totalW = logoW + textW
                let startX = (finalW / 2) - totalW / 2
                
                let logoY = textCY - logoH / 2
                logo.draw(in: CGRect(x: startX, y: logoY, width: logoW, height: logoH))
                
                if !deviceText.isEmpty {
                   let textY = textCY - asText.size().height / 2
                   asText.draw(at: CGPoint(x: startX + logoW, y: textY))
                }
            }
        }
    }
    
    private static func applyTecnoWatermark(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig, mode: Int) -> UIImage {
        let imgWidth = bitmap.width
        let imgHeight = bitmap.height
        let isLandscape = imgWidth > imgHeight
        
        let scale = CGFloat(imgWidth) / TECNO_REF_WIDTH
        let barHeight = isLandscape ? TECNO_BAR_HEIGHT_LANDSCAPE : TECNO_BAR_HEIGHT_PORTRAIT
        let scaledBarHeight = barHeight * scale
        
        let totalH = CGFloat(imgHeight) + scaledBarHeight
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: CGFloat(imgWidth), height: totalH), format: format)
        return renderer.image { context in
            let ctx = context.cgContext
            
            // Original Image
            image.draw(in: CGRect(x: 0, y: 0, width: CGFloat(imgWidth), height: CGFloat(imgHeight)))
            
            // White Bar
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(x: 0, y: CGFloat(imgHeight), width: CGFloat(imgWidth), height: scaledBarHeight))
            
            // Backdrop Texture
             if let bundle = Bundle.module.resourceURL {
                 let texURL = bundle.appendingPathComponent("watermark/TECNO/icons/TriangleTexture.png")
                 if let data = try? Data(contentsOf: texURL), let texImg = UIImage(data: data) {
                    let texWidth = 429.0 * scale
                    let texHeight = scaledBarHeight
                    let texX = 651.0 * scale
                    let barTop = CGFloat(imgHeight)
                    texImg.draw(in: CGRect(x: texX, y: barTop, width: texWidth, height: texHeight))
                 }
             }
             
             let barCY = CGFloat(imgHeight) + scaledBarHeight / 2
             
             let fontSizeBrand = (isLandscape ? 22.0 : 29.0) * scale
             let brandFont = UIFont.systemFont(ofSize: fontSizeBrand, weight: .bold)
             
             let fontSizeDate = (isLandscape ? 18.0 : 23.0) * scale
             let dateFont = UIFont.systemFont(ofSize: fontSizeDate, weight: .regular)
             
             let brandAttrs: [NSAttributedString.Key: Any] = [
                .font: brandFont,
                .foregroundColor: UIColor.black
             ]
             let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: dateFont,
                .foregroundColor: UIColor.gray
             ]
             
             let marginL = (isLandscape ? 30.0 : 39.0) * scale
             let marginR = (isLandscape ? 30.0 : 39.0) * scale
             
             let deviceName = config.deviceName ?? "TECNO"
             let dateText = config.timeText ?? ""
             
             let brandText = NSAttributedString(string: deviceName, attributes: brandAttrs)
             let brandY = barCY - brandText.size().height / 2
             brandText.draw(at: CGPoint(x: marginL, y: brandY))
             
             if !dateText.isEmpty {
                 let dText = NSAttributedString(string: dateText, attributes: dateAttrs)
                 let dY = barCY - dText.size().height / 2
                 let dX = CGFloat(imgWidth) - marginR - dText.size().width
                 dText.draw(at: CGPoint(x: dX, y: dY))
             }
        }
    }

    // MARK: - buildFrameComposite helper

    /// Composites `source` photo into a PNG frame template.
    /// Photo is center-cropped to match the frame's photo-area aspect ratio,
    /// then drawn at (pL,pT)-(pR,pB) inside the scaled template.
    /// `drawExtra(ctx, realScale)` is called after compositing for additional text/logos.
    private static func buildFrameComposite(
        _ source: UIImage,
        frameName: String, tmplW: Int, tmplH: Int,
        pL: Int, pT: Int, pR: Int, pB: Int,
        drawExtra: (CGContext, CGFloat) -> Void = { _, _ in }
    ) -> UIImage? {
        guard let frameImg = loadVivoLogo(frameName) else { return nil }
        guard let srcCG = source.cgImage else { return nil }

        let photoW = CGFloat(pR - pL); let photoH = CGFloat(pB - pT)
        let photoAR = photoW / photoH
        let srcW = CGFloat(srcCG.width); let srcH = CGFloat(srcCG.height)
        let srcAR = srcW / srcH

        // Center-crop source to match frame photo-area aspect ratio
        let srcCropRect: CGRect
        if srcAR > photoAR + 0.01 {
            let cropW = srcH * photoAR
            srcCropRect = CGRect(x: (srcW - cropW) / 2, y: 0, width: cropW, height: srcH)
        } else if srcAR < photoAR - 0.01 {
            let cropH = srcW / photoAR
            srcCropRect = CGRect(x: 0, y: (srcH - cropH) / 2, width: srcW, height: cropH)
        } else {
            srcCropRect = CGRect(x: 0, y: 0, width: srcW, height: srcH)
        }

        let realScale = srcCropRect.width / photoW
        let outW = round(CGFloat(tmplW) * realScale)
        let outH = round(CGFloat(tmplH) * realScale)

        let format = UIGraphicsImageRendererFormat(); format.scale = 1.0; format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: outW, height: outH), format: format).image { ctx in
            let c = ctx.cgContext

            // Draw frame baseboard (scaled to fill output)
            frameImg.draw(in: CGRect(x: 0, y: 0, width: outW, height: outH))

            // Draw cropped photo into frame's photo area
            let dstRect = CGRect(
                x: round(CGFloat(pL) * realScale), y: round(CGFloat(pT) * realScale),
                width: round(CGFloat(pR - pL) * realScale), height: round(CGFloat(pB - pT) * realScale)
            )
            // Crop source to srcCropRect and draw into dstRect
            if let croppedCG = srcCG.cropping(to: srcCropRect) {
                // CoreGraphics Y-axis is flipped vs UIKit; draw via UIImage to avoid transform mess
                let cropped = UIImage(cgImage: croppedCG)
                // Draw frame ON TOP of photo so frame borders overlay photo
                // First: photo, then frame overlay
                // Actually we already drew frame above. Re-draw photo below frame:
                // Redo: clear and draw photo first, then frame.
                c.clear(CGRect(x: 0, y: 0, width: outW, height: outH))
                cropped.draw(in: dstRect)
                frameImg.draw(in: CGRect(x: 0, y: 0, width: outW, height: outH))
            }

            drawExtra(c, realScale)
        }
    }

    // MARK: - Missing Vivo bar variants

    /// Helper: draw two lines of right-aligned info text in the bar
    private static func vivoDrawRightInfo(_ ctx: CGContext, imgW: CGFloat, barCY: CGFloat,
                                           rightX: CGFloat,
                                           lensText: String, timeText: String, locText: String,
                                           infoFont: UIFont, timeFont: UIFont, dp: CGFloat) {
        let hasInfo = !lensText.isEmpty
        let hasTime = !timeText.isEmpty
        let hasLoc  = !locText.isEmpty
        let hasBottom = hasTime || hasLoc

        func drawRight(_ str: String, font: UIFont, y: CGFloat) {
            let attrs: [NSAttributedString.Key: Any] = [.font: font,
                .foregroundColor: (font == infoFont ? VIVO_3A_STD : VIVO_TIME_GRAY)]
            let as1 = NSAttributedString(string: str, attributes: attrs)
            as1.draw(at: CGPoint(x: rightX - as1.size().width, y: y))
        }

        if hasInfo && hasBottom {
            let infoH = infoFont.lineHeight; let botH = timeFont.lineHeight
            let lineGap = 2.3 * dp; let stackH = infoH + lineGap + botH
            let topY = barCY - stackH / 2
            drawRight(lensText, font: infoFont, y: topY)
            let botY = topY + infoH + lineGap
            let botStr: String
            if hasTime && hasLoc {
                let attrs: [NSAttributedString.Key: Any] = [.font: timeFont, .foregroundColor: VIVO_TIME_GRAY]
                let locAs = NSAttributedString(string: locText, attributes: attrs)
                locAs.draw(at: CGPoint(x: rightX - locAs.size().width, y: botY))
                let gap = 4.0 * dp
                let timeAs = NSAttributedString(string: timeText, attributes: attrs)
                timeAs.draw(at: CGPoint(x: rightX - locAs.size().width - gap - timeAs.size().width, y: botY))
                return
            } else {
                botStr = hasTime ? timeText : locText
            }
            drawRight(botStr, font: timeFont, y: botY)
        } else if hasInfo {
            drawRight(lensText, font: infoFont, y: barCY - infoFont.lineHeight / 2)
        } else if hasBottom {
            let str = hasTime ? timeText : locText
            drawRight(str, font: timeFont, y: barCY - timeFont.lineHeight / 2)
        }
    }

    /// Tint a UIImage to black (for white-on-transparent logos)
    private static func tintBlack(_ img: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = img.scale; format.opaque = false
        return UIGraphicsImageRenderer(size: img.size, format: format).image { ctx in
            let c = ctx.cgContext
            c.translateBy(x: 0, y: img.size.height); c.scaleBy(x: 1, y: -1)
            if let cg = img.cgImage {
                c.clip(to: CGRect(origin: .zero, size: img.size), mask: cg)
                c.setFillColor(UIColor.black.cgColor)
                c.fill(CGRect(origin: .zero, size: img.size))
            }
        }
    }

    private static func applyVivoIqoo(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgW = CGFloat(bitmap.width); let imgH = CGFloat(bitmap.height)
        let shortSide = min(imgW, imgH)
        let barHF = max(shortSide * VIVO_BAR_RATIO, 80.0)
        let barH = round(barHF); let dp = barHF / VIVO_BAR_DP
        let totalH = imgH + barH

        let format = UIGraphicsImageRendererFormat(); format.scale = 1.0; format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: imgW, height: totalH), format: format).image { ctx in
            let c = ctx.cgContext
            image.draw(in: CGRect(x: 0, y: 0, width: imgW, height: imgH))
            c.setFillColor(UIColor.white.cgColor)
            c.fill(CGRect(x: 0, y: imgH, width: imgW, height: barH))

            let barCY = imgH + barHF / 2
            let marginL = 16.0 * dp; let marginR = 14.0 * dp
            var curX = marginL

            // iQOO logo (white, tinted black)
            if let raw = loadVivoLogo("iqoo_logo_special_white.png") ?? loadVivoLogo("iqoo_logo_wm_xml.png") {
                let logo = tintBlack(raw)
                let lH = 12.3 * dp; let lW = lH * logo.size.width / logo.size.height
                logo.draw(in: CGRect(x: curX, y: barCY - lH / 2, width: lW, height: lH))
                curX += lW + 3.5 * dp
            }
            // Device name
            if let dev = config.deviceName, !dev.isEmpty {
                let font = getVivoFont("VivoSimpleBold", size: 15.3 * dp)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
                let as1 = NSAttributedString(string: dev, attributes: attrs)
                as1.draw(at: CGPoint(x: curX, y: barCY - as1.size().height / 2))
            }
            let rightX = imgW - marginR
            let infoFont = getVivoFont("VivoSansExp", size: 9.7 * dp)
            let timeFont = getVivoFont("VivoSansExp", size: 7.5 * dp)
            vivoDrawRightInfo(c, imgW: imgW, barCY: barCY, rightX: rightX,
                               lensText: config.lensInfo ?? "", timeText: config.timeText ?? "",
                               locText: config.locationText ?? "",
                               infoFont: infoFont, timeFont: timeFont, dp: dp)
        }
    }

    private static func applyVivoZeissV1(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgW = CGFloat(bitmap.width); let imgH = CGFloat(bitmap.height)
        let shortSide = min(imgW, imgH)
        let barHF = max(shortSide * VIVO_BAR_RATIO, 80.0)
        let barH = round(barHF); let dp = barHF / VIVO_BAR_DP
        let totalH = imgH + barH

        let format = UIGraphicsImageRendererFormat(); format.scale = 1.0; format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: imgW, height: totalH), format: format).image { ctx in
            let c = ctx.cgContext
            image.draw(in: CGRect(x: 0, y: 0, width: imgW, height: imgH))
            c.setFillColor(UIColor.white.cgColor); c.fill(CGRect(x: 0, y: imgH, width: imgW, height: barH))

            let barCY = imgH + barHF / 2
            let marginL = 11.0 * dp; let marginR = 11.0 * dp
            var curX = marginL

            // vivo logo tinted black
            if let raw = loadVivoLogo("vivo_logo.png") {
                let logo = tintBlack(raw)
                let lH = 11.0 * dp; let lW = lH * logo.size.width / logo.size.height
                logo.draw(in: CGRect(x: curX, y: barCY - lH / 2, width: lW, height: lH))
                curX += lW + 1.0 * dp
            }
            // Device name
            let dev = config.deviceName ?? ""
            if !dev.isEmpty {
                let font = getVivoFont("VivoRegular", size: 14.0 * dp)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
                let as1 = NSAttributedString(string: dev, attributes: attrs)
                as1.draw(at: CGPoint(x: curX, y: barCY - as1.size().height / 2))
                curX += as1.size().width + 7.0 * dp
            }
            // Thin divider
            let divW = max(1.0, 0.3 * dp)
            c.setFillColor(UIColor.black.cgColor)
            c.fill(CGRect(x: curX, y: barCY - 5.0 * dp, width: divW, height: 10.0 * dp))
            curX += divW + 2.0 * dp
            // ZEISS logo
            if let zeiss = loadVivoLogo("zeiss_logo.png") {
                let zH = 38.0 * dp; let zW = 38.0 * dp
                zeiss.draw(in: CGRect(x: curX, y: barCY - zH / 2, width: zW, height: zH))
            }
            let rightX = imgW - marginR
            let infoFont = getVivoFont("RobotoBold", size: 9.0 * dp)
            let timeFont = getVivoFont("RobotoBold", size: 7.0 * dp)
            vivoDrawRightInfo(c, imgW: imgW, barCY: barCY, rightX: rightX,
                               lensText: config.lensInfo ?? "", timeText: config.timeText ?? "",
                               locText: config.locationText ?? "",
                               infoFont: infoFont, timeFont: timeFont, dp: dp)
        }
    }

    private static func applyVivoZeissSonnar(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgW = CGFloat(bitmap.width); let imgH = CGFloat(bitmap.height)
        let shortSide = min(imgW, imgH)
        let barHF = max(shortSide * VIVO_BAR_RATIO, 80.0)
        let barH = round(barHF); let dp = barHF / VIVO_BAR_DP
        let totalH = imgH + barH

        let format = UIGraphicsImageRendererFormat(); format.scale = 1.0; format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: imgW, height: totalH), format: format).image { ctx in
            let c = ctx.cgContext
            image.draw(in: CGRect(x: 0, y: 0, width: imgW, height: imgH))
            c.setFillColor(UIColor.white.cgColor); c.fill(CGRect(x: 0, y: imgH, width: imgW, height: barH))

            let barCY = imgH + barHF / 2
            let marginL = 3.0 * dp; let marginR = 13.0 * dp
            var curX = marginL

            // Large ZEISS logo on left
            if let zeiss = loadVivoLogo("zeiss_logo.png") {
                let zH = 46.0 * dp; let zW = zH * zeiss.size.width / zeiss.size.height
                zeiss.draw(in: CGRect(x: curX, y: barCY - zH / 2, width: zW, height: zH))
                curX = max(curX + zW, 50.0 * dp)
            } else { curX = 50.0 * dp }

            let dev = config.deviceName ?? ""
            let zeissFont = getVivoFont("ZeissBold", size: 14.0 * dp)
            let modelRowY = barCY - 8.0 * dp
            if !dev.isEmpty {
                let attrs: [NSAttributedString.Key: Any] = [.font: zeissFont, .foregroundColor: UIColor.black]
                let as1 = NSAttributedString(string: dev, attributes: attrs)
                as1.draw(at: CGPoint(x: curX, y: modelRowY - as1.size().height / 2))
                let mw = as1.size().width
                let divX = curX + mw + 5.0 * dp; let divW = max(1.0, 2.0 * dp)
                c.setFillColor(UIColor.black.cgColor)
                c.fill(CGRect(x: divX, y: modelRowY - 4.5 * dp, width: divW, height: 9.0 * dp))
                let zeissAs = NSAttributedString(string: "ZEISS", attributes: attrs)
                zeissAs.draw(at: CGPoint(x: divX + divW + 5.0 * dp, y: modelRowY - zeissAs.size().height / 2))
            }
            let lens = config.lensInfo ?? ""
            if !lens.isEmpty {
                let threeFont = getVivoFont("VivoCamera", size: 8.0 * dp)
                let attrs: [NSAttributedString.Key: Any] = [.font: threeFont, .foregroundColor: VIVO_TIME_GRAY]
                let as2 = NSAttributedString(string: lens, attributes: attrs)
                let threeY = barCY + 8.0 * dp
                as2.draw(at: CGPoint(x: curX, y: threeY - as2.size().height / 2))
            }
            // Right: time + location
            let rightX = imgW - marginR
            let timeText = config.timeText ?? ""; let locText = config.locationText ?? ""
            let dateFont = getVivoFont("VivoSansExp", size: 12.0 * dp)
            let locFont = getVivoFont("VivoSansExp", size: 8.0 * dp)
            let dateColor = UIColor(red: 0.165, green: 0.220, blue: 0.267, alpha: 1)
            if !timeText.isEmpty && !locText.isEmpty {
                let dH = dateFont.lineHeight; let lH = locFont.lineHeight; let gap = 3.0 * dp
                let topY = barCY - (dH + gap + lH) / 2
                let dAttrs: [NSAttributedString.Key: Any] = [.font: dateFont, .foregroundColor: dateColor]
                let dAs = NSAttributedString(string: timeText, attributes: dAttrs)
                dAs.draw(at: CGPoint(x: rightX - dAs.size().width, y: topY))
                let lAttrs: [NSAttributedString.Key: Any] = [.font: locFont, .foregroundColor: VIVO_TIME_GRAY]
                let lAs = NSAttributedString(string: locText, attributes: lAttrs)
                lAs.draw(at: CGPoint(x: rightX - lAs.size().width, y: topY + dH + gap))
            } else if !timeText.isEmpty {
                let dAttrs: [NSAttributedString.Key: Any] = [.font: dateFont, .foregroundColor: dateColor]
                let dAs = NSAttributedString(string: timeText, attributes: dAttrs)
                dAs.draw(at: CGPoint(x: rightX - dAs.size().width, y: barCY - dAs.size().height / 2))
            } else if !locText.isEmpty {
                let lAttrs: [NSAttributedString.Key: Any] = [.font: locFont, .foregroundColor: VIVO_TIME_GRAY]
                let lAs = NSAttributedString(string: locText, attributes: lAttrs)
                lAs.draw(at: CGPoint(x: rightX - lAs.size().width, y: barCY - lAs.size().height / 2))
            }
        }
    }

    private static func applyVivoZeissHumanity(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgW = CGFloat(bitmap.width); let imgH = CGFloat(bitmap.height)
        let shortSide = min(imgW, imgH)
        let barHF = max(shortSide * VIVO_BAR_RATIO, 80.0)
        let barH = round(barHF); let dp = barHF / VIVO_BAR_DP
        let totalH = imgH + barH

        let format = UIGraphicsImageRendererFormat(); format.scale = 1.0; format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: imgW, height: totalH), format: format).image { ctx in
            let c = ctx.cgContext
            image.draw(in: CGRect(x: 0, y: 0, width: imgW, height: imgH))
            c.setFillColor(UIColor.white.cgColor); c.fill(CGRect(x: 0, y: imgH, width: imgW, height: barH))

            let barCY = imgH + barHF / 2; let marginL = 22.0 * dp
            let font = getVivoFont("VivoSansExp", size: 22.6 * dp)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: VIVO_3A_STD]
            let dev = config.deviceName ?? ""
            if !dev.isEmpty {
                let as1 = NSAttributedString(string: dev, attributes: attrs)
                let mw = as1.size().width
                let divW = max(2.0, 4.0 * dp); let divGap = 7.0 * dp
                as1.draw(at: CGPoint(x: marginL, y: barCY - as1.size().height / 2))
                let divX = marginL + mw + divGap
                c.setFillColor(UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1).cgColor)
                c.fill(CGRect(x: divX, y: barCY - 9.5 * dp, width: divW, height: 19.0 * dp))
                let zeissAs = NSAttributedString(string: "ZEISS", attributes: attrs)
                zeissAs.draw(at: CGPoint(x: divX + divW + divGap, y: barCY - zeissAs.size().height / 2))
            } else {
                let zeissAs = NSAttributedString(string: "ZEISS", attributes: attrs)
                zeissAs.draw(at: CGPoint(x: marginL, y: barCY - zeissAs.size().height / 2))
            }
        }
    }

    private static func applyVivoIqooV1(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgW = CGFloat(bitmap.width); let imgH = CGFloat(bitmap.height)
        let shortSide = min(imgW, imgH)
        let barHF = max(shortSide * VIVO_BAR_RATIO, 80.0)
        let barH = round(barHF); let dp = barHF / VIVO_BAR_DP
        let totalH = imgH + barH

        let format = UIGraphicsImageRendererFormat(); format.scale = 1.0; format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: imgW, height: totalH), format: format).image { ctx in
            let c = ctx.cgContext
            image.draw(in: CGRect(x: 0, y: 0, width: imgW, height: imgH))
            c.setFillColor(UIColor.white.cgColor); c.fill(CGRect(x: 0, y: imgH, width: imgW, height: barH))

            let barCY = imgH + barHF / 2
            let marginL = 13.0 * dp; let marginR = 12.0 * dp
            var curX = marginL

            if let raw = loadVivoLogo("iqoo_logo.png") {
                let logo = tintBlack(raw)
                let lH = 17.0 * dp; let lW = lH * logo.size.width / logo.size.height
                logo.draw(in: CGRect(x: curX, y: barCY - lH / 2, width: lW, height: lH))
                curX += lW + 1.0 * dp
            }
            let dev = config.deviceName ?? ""
            if !dev.isEmpty {
                let font = getVivoFont("IQOOBold", size: 13.0 * dp)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
                let as1 = NSAttributedString(string: dev, attributes: attrs)
                as1.draw(at: CGPoint(x: curX, y: barCY - as1.size().height / 2))
            }
            let rightX = imgW - marginR
            let infoFont = getVivoFont("RobotoBold", size: 10.0 * dp)
            let timeFont = getVivoFont("RobotoBold", size: 7.0 * dp)
            vivoDrawRightInfo(c, imgW: imgW, barCY: barCY, rightX: rightX,
                               lensText: config.lensInfo ?? "", timeText: config.timeText ?? "",
                               locText: config.locationText ?? "",
                               infoFont: infoFont, timeFont: timeFont, dp: dp)
        }
    }

    private static func applyVivoIqooHumanity(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgW = CGFloat(bitmap.width); let imgH = CGFloat(bitmap.height)
        let shortSide = min(imgW, imgH)
        let barHF = max(shortSide * VIVO_BAR_RATIO, 80.0)
        let barH = round(barHF); let dp = barHF / VIVO_BAR_DP
        let totalH = imgH + barH

        let format = UIGraphicsImageRendererFormat(); format.scale = 1.0; format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: imgW, height: totalH), format: format).image { ctx in
            let c = ctx.cgContext
            image.draw(in: CGRect(x: 0, y: 0, width: imgW, height: imgH))
            c.setFillColor(UIColor.white.cgColor); c.fill(CGRect(x: 0, y: imgH, width: imgW, height: barH))

            let barCY = imgH + barHF / 2; let marginL = 22.0 * dp
            let font = getVivoFont("VivoSansExp", size: 22.6 * dp)
            let dev = config.deviceName ?? "iQOO"
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: VIVO_3A_STD]
            let as1 = NSAttributedString(string: dev, attributes: attrs)
            as1.draw(at: CGPoint(x: marginL, y: barCY - as1.size().height / 2))
        }
    }

    private static func applyVivoZeissFrame(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let dev = config.deviceName ?? ""; let lens = config.lensInfo ?? ""
        let result = buildFrameComposite(image, frameName: "zeiss2.png",
                                          tmplW: 1080, tmplH: 1710, pL: 27, pT: 27, pR: 1053, pB: 1395) { c, rs in
            let photoW: CGFloat = 1053 - 27; let realScale = rs
            let cX = round(CGFloat(1080) * realScale / 2)
            let textCY = round(1552.5 * realScale)
            let modelFont = getVivoFont("ZeissBold", size: 14.0 * 3.0 * realScale)
            let threeFont = getVivoFont("VivoCamera", size: 8.0 * 3.0 * realScale)
            let modelStr = dev.isEmpty ? "ZEISS" : "\(dev)  |  ZEISS"
            let mAttrs: [NSAttributedString.Key: Any] = [.font: modelFont, .foregroundColor: UIColor.black]
            let as1 = NSAttributedString(string: modelStr, attributes: mAttrs)
            let mH = as1.size().height
            let hasLens = !lens.isEmpty
            let gap = 2.0 * 3.0 * realScale
            let totalTextH = mH + (hasLens ? gap + threeFont.lineHeight : 0)
            let topY = textCY - totalTextH / 2
            as1.draw(at: CGPoint(x: cX - as1.size().width / 2, y: topY))
            if hasLens {
                let lAttrs: [NSAttributedString.Key: Any] = [.font: threeFont, .foregroundColor: VIVO_TIME_GRAY]
                let as2 = NSAttributedString(string: lens, attributes: lAttrs)
                as2.draw(at: CGPoint(x: cX - as2.size().width / 2, y: topY + mH + gap))
            }
        }
        return result ?? image
    }

    private static func applyVivoZeissOverlay(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgW = CGFloat(bitmap.width); let imgH = CGFloat(bitmap.height)
        let isPortrait = imgH >= imgW
        let frameName = isPortrait ? "zeiss4.png" : "zeiss5_new.png"
        let shortSide = min(imgW, imgH); let dp = shortSide / 360.0

        let format = UIGraphicsImageRendererFormat(); format.scale = 1.0; format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: imgW, height: imgH), format: format).image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: imgW, height: imgH))
            // Draw frame overlay
            if let frame = loadVivoLogo(frameName) {
                frame.draw(in: CGRect(x: 0, y: 0, width: imgW, height: imgH))
            }
            let marginLR = 36.0 * dp; let topY = 21.0 * dp
            let dev = config.deviceName ?? ""
            let time = config.timeText ?? ""; let lens = config.lensInfo ?? ""

            let shadow = NSShadow(); shadow.shadowColor = UIColor.black.withAlphaComponent(0.3)
            shadow.shadowOffset = CGSize(width: 1, height: 1); shadow.shadowBlurRadius = 3

            if !dev.isEmpty {
                let font = getVivoFont("ZeissBold", size: 12.0 * dp)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white, .shadow: shadow]
                let as1 = NSAttributedString(string: dev, attributes: attrs)
                as1.draw(at: CGPoint(x: marginLR, y: topY))
            }
            if !time.isEmpty {
                let font = getVivoFont("VivoCamera", size: 11.0 * dp)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white, .shadow: shadow]
                let as1 = NSAttributedString(string: time, attributes: attrs)
                as1.draw(at: CGPoint(x: imgW - marginLR - as1.size().width, y: topY))
            }
            if !lens.isEmpty {
                let font = getVivoFont("VivoCamera", size: 11.0 * dp)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white, .shadow: shadow]
                let parts = lens.split(separator: " ").map(String.init).filter { !$0.isEmpty }
                let botY = isPortrait ? imgH - 29.0 * dp : imgH - 19.0 * dp
                switch parts.count {
                case 4...:
                    let as1 = NSAttributedString(string: parts[3], attributes: attrs)
                    as1.draw(at: CGPoint(x: marginLR, y: botY - font.lineHeight))
                    let as2 = NSAttributedString(string: parts[1], attributes: attrs)
                    as2.draw(at: CGPoint(x: imgW / 2 - as2.size().width / 2, y: botY - font.lineHeight))
                    let as3 = NSAttributedString(string: parts[2], attributes: attrs)
                    as3.draw(at: CGPoint(x: imgW - marginLR - as3.size().width, y: botY - font.lineHeight))
                case 3:
                    let as1 = NSAttributedString(string: parts[0], attributes: attrs)
                    as1.draw(at: CGPoint(x: marginLR, y: botY - font.lineHeight))
                    let as2 = NSAttributedString(string: parts[1], attributes: attrs)
                    as2.draw(at: CGPoint(x: imgW / 2 - as2.size().width / 2, y: botY - font.lineHeight))
                    let as3 = NSAttributedString(string: parts[2], attributes: attrs)
                    as3.draw(at: CGPoint(x: imgW - marginLR - as3.size().width, y: botY - font.lineHeight))
                default:
                    let as1 = NSAttributedString(string: lens, attributes: attrs)
                    as1.draw(at: CGPoint(x: imgW / 2 - as1.size().width / 2, y: botY - font.lineHeight))
                }
            }
        }
    }

    private static func applyVivoZeissCenter(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let dev = config.deviceName ?? ""; let lens = config.lensInfo ?? ""
        let result = buildFrameComposite(image, frameName: "zeiss6_new.png",
                                          tmplW: 1080, tmplH: 1476, pL: 279, pT: 300, pR: 801, pB: 996) { c, rs in
            let outW = round(CGFloat(1080) * rs)
            let cX = outW / 2; let textCY = round(1236.0 * rs)
            let modelFont = getVivoFont("ZeissBold", size: 14.0 * 3.0 * rs)
            let threeFont = getVivoFont("VivoCamera", size: 8.0 * 3.0 * rs)
            let modelStr = dev.isEmpty ? "ZEISS" : "\(dev)  |  ZEISS"
            let mAttrs: [NSAttributedString.Key: Any] = [.font: modelFont, .foregroundColor: UIColor.black]
            let as1 = NSAttributedString(string: modelStr, attributes: mAttrs)
            let mH = as1.size().height; let hasLens = !lens.isEmpty
            let gap = 2.0 * 3.0 * rs
            let totalTextH = mH + (hasLens ? gap + threeFont.lineHeight : 0)
            let topY = textCY - totalTextH / 2
            as1.draw(at: CGPoint(x: cX - as1.size().width / 2, y: topY))
            if hasLens {
                let lAttrs: [NSAttributedString.Key: Any] = [.font: threeFont, .foregroundColor: VIVO_TIME_GRAY]
                let as2 = NSAttributedString(string: lens, attributes: lAttrs)
                as2.draw(at: CGPoint(x: cX - as2.size().width / 2, y: topY + mH + gap))
            }
        }
        return result ?? image
    }

    private static func applyVivoFrameTime(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgW = CGFloat(bitmap.width); let imgH = CGFloat(bitmap.height)
        let ar = imgW / imgH
        let (frameName, tmplW, tmplH, pL, pT, pR, pB): (String, Int, Int, Int, Int, Int, Int)
        if ar > 1.2 {
            (frameName, tmplW, tmplH, pL, pT, pR, pB) = ("vivo3.png", 1596, 1080, 27, 27, 1569, 894)
        } else if ar < 0.85 {
            (frameName, tmplW, tmplH, pL, pT, pR, pB) = ("vivo2.png", 1080, 1590, 27, 27, 1053, 1395)
        } else {
            (frameName, tmplW, tmplH, pL, pT, pR, pB) = ("vivo4.png", 1080, 1413, 192, 291, 888, 987)
        }
        let dev = config.deviceName ?? ""; let time = config.timeText ?? ""
        let result = buildFrameComposite(image, frameName: frameName,
                                          tmplW: tmplW, tmplH: tmplH, pL: pL, pT: pT, pR: pR, pB: pB) { c, rs in
            let outW = round(CGFloat(tmplW) * rs)
            let textCY = round((CGFloat(pB) + CGFloat(tmplH)) / 2 * rs)
            let cX = outW / 2
            if let logo = loadVivoLogo("vivo_logo_new.png") ?? loadVivoLogo("vivo_logo_wm_xml.png") {
                let lH = 16.0 * 3.0 * rs; let lW = lH * logo.size.width / logo.size.height
                let font = getVivoFont("VivoCamera", size: 14.0 * 3.0 * rs)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
                let devAs = dev.isEmpty ? nil : NSAttributedString(string: dev, attributes: attrs)
                let devW = devAs?.size().width ?? 0
                let totalW = lW + devW
                let sx = cX - totalW / 2
                logo.draw(in: CGRect(x: sx, y: textCY - lH / 2, width: lW, height: lH))
                if let da = devAs { da.draw(at: CGPoint(x: sx + lW, y: textCY - da.size().height / 2)) }
            }
            if !time.isEmpty {
                let timeFont = getVivoFont("VivoCamera", size: 10.0 * 3.0 * rs)
                let timeAttrs: [NSAttributedString.Key: Any] = [.font: timeFont, .foregroundColor: VIVO_TIME_GRAY]
                let tas = NSAttributedString(string: time, attributes: timeAttrs)
                tas.draw(at: CGPoint(x: cX - tas.size().width / 2, y: textCY + 12.0 * 3.0 * rs))
            }
        }
        return result ?? image
    }

    private static func applyVivoIqooFrame(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let dev = config.deviceName ?? ""
        let result = buildFrameComposite(image, frameName: "vivo5.png",
                                          tmplW: 1080, tmplH: 1680, pL: 24, pT: 24, pR: 1056, pB: 1380) { c, rs in
            let outW = round(CGFloat(1080) * rs)
            let textCY = round((CGFloat(1380) + CGFloat(1680)) / 2 * rs)
            let cX = outW / 2
            if let raw = loadVivoLogo("iqoo_logo.png") {
                let logo = tintBlack(raw)
                let lH = 24.0 * 3.0 * rs; let lW = lH * logo.size.width / logo.size.height
                let font = getVivoFont("IQOOBold", size: 14.0 * 3.0 * rs)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
                let devAs = dev.isEmpty ? nil : NSAttributedString(string: dev, attributes: attrs)
                let devW = devAs?.size().width ?? 0
                let totalW = lW + (devW > 0 ? 4.0 * rs + devW : 0)
                let sx = cX - totalW / 2
                logo.draw(in: CGRect(x: sx, y: textCY - lH / 2, width: lW, height: lH))
                if let da = devAs { da.draw(at: CGPoint(x: sx + lW + 4.0 * rs, y: textCY - da.size().height / 2)) }
            }
        }
        return result ?? image
    }

    private static func applyVivoIqooFrameTime(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let dev = config.deviceName ?? ""; let time = config.timeText ?? ""
        let result = buildFrameComposite(image, frameName: "vivo5.png",
                                          tmplW: 1080, tmplH: 1680, pL: 24, pT: 24, pR: 1056, pB: 1380) { c, rs in
            let outW = round(CGFloat(1080) * rs)
            let textCY = round((CGFloat(1380) + CGFloat(1680)) / 2 * rs)
            let cX = outW / 2
            if let raw = loadVivoLogo("iqoo_logo.png") {
                let logo = tintBlack(raw)
                let lH = 24.0 * 3.0 * rs; let lW = lH * logo.size.width / logo.size.height
                let font = getVivoFont("IQOOBold", size: 14.0 * 3.0 * rs)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
                let devAs = dev.isEmpty ? nil : NSAttributedString(string: dev, attributes: attrs)
                let devW = devAs?.size().width ?? 0
                let totalW = lW + (devW > 0 ? 4.0 * rs + devW : 0)
                let sx = cX - totalW / 2
                logo.draw(in: CGRect(x: sx, y: textCY - lH / 2, width: lW, height: lH))
                if let da = devAs { da.draw(at: CGPoint(x: sx + lW + 4.0 * rs, y: textCY - da.size().height / 2)) }
            }
            if !time.isEmpty {
                let tf = getVivoFont("VivoCamera", size: 10.0 * 3.0 * rs)
                let ta: [NSAttributedString.Key: Any] = [.font: tf, .foregroundColor: VIVO_TIME_GRAY]
                let tas = NSAttributedString(string: time, attributes: ta)
                tas.draw(at: CGPoint(x: cX - tas.size().width / 2, y: textCY + 12.0 * 3.0 * rs))
            }
        }
        return result ?? image
    }

    private static func applyVivoOS(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgW = CGFloat(bitmap.width); let imgH = CGFloat(bitmap.height)
        let isPortrait = imgH >= imgW
        let (frameName, tmplW, tmplH, pL, pT, pR, pB): (String, Int, Int, Int, Int, Int, Int)
        if isPortrait {
            (frameName, tmplW, tmplH, pL, pT, pR, pB) = ("os1.png", 1080, 1620, 162, 153, 918, 1161)
        } else {
            (frameName, tmplW, tmplH, pL, pT, pR, pB) = ("os2.png", 1350, 1056, 51, 51, 1299, 753)
        }
        let lens = config.lensInfo ?? ""; let loc = config.locationText ?? ""; let time = config.timeText ?? ""
        let textColor = UIColor(red: 0.137, green: 0.098, blue: 0.086, alpha: 1)
        let result = buildFrameComposite(image, frameName: frameName,
                                          tmplW: tmplW, tmplH: tmplH, pL: pL, pT: pT, pR: pR, pB: pB) { c, rs in
            let outW = round(CGFloat(tmplW) * rs)
            let marginL = (isPortrait ? 54.0 : 18.0) * 3.0 * rs
            let textAreaTop = CGFloat(pB) * rs
            let areaH = CGFloat(tmplH) * rs - textAreaTop
            let textCY = textAreaTop + areaH * 0.45

            let infoFont = getVivoFont("VivoSansExp", size: 12.0 * 3.0 * rs)
            let subFont = getVivoFont("VivoSansExp", size: 8.0 * 3.0 * rs)

            if !lens.isEmpty {
                let attrs: [NSAttributedString.Key: Any] = [.font: infoFont, .foregroundColor: textColor]
                let as1 = NSAttributedString(string: lens, attributes: attrs)
                as1.draw(at: CGPoint(x: marginL, y: textCY - infoFont.lineHeight / 2 - 8.0 * rs))
            }
            if !loc.isEmpty || !time.isEmpty {
                let line2Y = textCY + 12.0 * rs
                var x = marginL
                let attrs: [NSAttributedString.Key: Any] = [.font: subFont, .foregroundColor: VIVO_TIME_GRAY]
                if !loc.isEmpty {
                    let as1 = NSAttributedString(string: loc, attributes: attrs)
                    as1.draw(at: CGPoint(x: x, y: line2Y - subFont.lineHeight / 2))
                    x += as1.size().width + 10.0 * rs
                }
                if !time.isEmpty {
                    let as2 = NSAttributedString(string: time, attributes: attrs)
                    as2.draw(at: CGPoint(x: x, y: line2Y - subFont.lineHeight / 2))
                }
            }
            // Origin OS logo at right
            if let logo = loadVivoLogo("origin_os_logo.png") {
                let lH = 24.0 * 3.0 * rs; let lW = lH * logo.size.width / logo.size.height
                let lX = outW - marginL - lW
                let lY = textAreaTop + areaH * 0.7 - lH / 2
                logo.draw(in: CGRect(x: lX, y: lY, width: lW, height: lH))
            }
        }
        return result ?? image
    }

    private static func applyVivoOSCorner(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgW = CGFloat(bitmap.width); let imgH = CGFloat(bitmap.height)
        let isPortrait = imgH >= imgW
        let (frameName, tmplW, tmplH, pL, pT, pR, pB): (String, Int, Int, Int, Int, Int, Int)
        if isPortrait {
            (frameName, tmplW, tmplH, pL, pT, pR, pB) = ("os3.png", 1080, 1590, 153, 165, 927, 1197)
        } else {
            (frameName, tmplW, tmplH, pL, pT, pR, pB) = ("os4.png", 1461, 1080, 111, 123, 1350, 819)
        }
        return buildFrameComposite(image, frameName: frameName,
                                    tmplW: tmplW, tmplH: tmplH, pL: pL, pT: pT, pR: pR, pB: pB) ?? image
    }

    private static func applyVivoOSSimple(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgW = CGFloat(bitmap.width); let imgH = CGFloat(bitmap.height)
        let isPortrait = imgH >= imgW
        let (frameName, tmplW, tmplH, pL, pT, pR, pB): (String, Int, Int, Int, Int, Int, Int)
        if isPortrait {
            (frameName, tmplW, tmplH, pL, pT, pR, pB) = ("os5.png", 1080, 1614, 36, 36, 1044, 1380)
        } else {
            (frameName, tmplW, tmplH, pL, pT, pR, pB) = ("os6.png", 1677, 1155, 36, 36, 1641, 939)
        }
        return buildFrameComposite(image, frameName: frameName,
                                    tmplW: tmplW, tmplH: tmplH, pL: pL, pT: pT, pR: pR, pB: pB) ?? image
    }

    private static func applyVivoEvent(_ image: UIImage, bitmap: CGImage, config: WatermarkConfig) -> UIImage {
        let imgW = CGFloat(bitmap.width); let imgH = CGFloat(bitmap.height)
        let isPortrait = imgH >= imgW
        let (frameName, tmplW, tmplH, pL, pT, pR, pB): (String, Int, Int, Int, Int, Int, Int)
        if isPortrait {
            (frameName, tmplW, tmplH, pL, pT, pR, pB) = ("event1.webp", 1080, 1620, 0, 0, 1080, 1355)
        } else {
            (frameName, tmplW, tmplH, pL, pT, pR, pB) = ("event2.webp", 1350, 1056, 0, 0, 1350, 856)
        }
        let dev = config.deviceName ?? ""; let lens = config.lensInfo ?? ""
        let loc = config.locationText ?? ""; let time = config.timeText ?? ""
        let result = buildFrameComposite(image, frameName: frameName,
                                          tmplW: tmplW, tmplH: tmplH, pL: pL, pT: pT, pR: pR, pB: pB) { c, rs in
            let marginL = 16.0 * 3.0 * rs
            let textAreaTop = CGFloat(pB) * rs
            var curY = textAreaTop + 20.0 * 3.0 * rs

            let modelFont = getVivoFont("VivoSansExp", size: 19.0 * 3.0 * rs)
            let threeFont = getVivoFont("VivoSansExp", size: 7.0 * 3.0 * rs)
            let locFont = getVivoFont("VivoSansExp", size: 5.0 * 3.0 * rs)
            let subColor = UIColor(red: 0.373, green: 0.373, blue: 0.373, alpha: 1)

            if !dev.isEmpty {
                let attrs: [NSAttributedString.Key: Any] = [.font: modelFont, .foregroundColor: UIColor.black]
                let as1 = NSAttributedString(string: dev, attributes: attrs)
                as1.draw(at: CGPoint(x: marginL + 10.0 * 3.0 * rs, y: curY))
                curY += modelFont.lineHeight + 2.0 * 3.0 * rs
            }
            if !lens.isEmpty {
                let attrs: [NSAttributedString.Key: Any] = [.font: threeFont, .foregroundColor: subColor]
                let as1 = NSAttributedString(string: lens, attributes: attrs)
                as1.draw(at: CGPoint(x: marginL, y: curY)); curY += threeFont.lineHeight + 1.0 * 3.0 * rs
            }
            if !loc.isEmpty || !time.isEmpty {
                let attrs: [NSAttributedString.Key: Any] = [.font: locFont, .foregroundColor: subColor]
                var x = marginL
                if !loc.isEmpty {
                    let as1 = NSAttributedString(string: loc, attributes: attrs)
                    as1.draw(at: CGPoint(x: x, y: curY)); x += as1.size().width + 3.0 * 3.0 * rs
                }
                if !time.isEmpty {
                    let as2 = NSAttributedString(string: time, attributes: attrs)
                    as2.draw(at: CGPoint(x: x, y: curY))
                }
            }
        }
        return result ?? image
    }
}

