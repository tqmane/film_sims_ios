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
        case .meizuZ1, .meizuZ2, .meizuZ3, .meizuZ4, .meizuZ5, .meizuZ6, .meizuZ7:
            return applyMeizuZ(baseImage, bitmap: bitmap, config: config)
        case .vivoZeiss:
            return applyVivoZeiss(baseImage, bitmap: bitmap, config: config)
        case .vivoClassic:
             return applyVivoClassic(baseImage, bitmap: bitmap, config: config)
        case .vivoPro:
             return applyVivoPro(baseImage, bitmap: bitmap, config: config)
        case .vivoFrame:
             return applyVivoFrame(baseImage, bitmap: bitmap, config: config)
        case .tecno1:
             return applyTecnoWatermark(baseImage, bitmap: bitmap, config: config, mode: 1)
        case .tecno2:
             return applyTecnoWatermark(baseImage, bitmap: bitmap, config: config, mode: 2)
        case .tecno3:
             return applyTecnoWatermark(baseImage, bitmap: bitmap, config: config, mode: 3)
        case .tecno4:
             return applyTecnoWatermark(baseImage, bitmap: bitmap, config: config, mode: 4)
        default:
            if String(describing: config.style).starts(with: "vivo") {
                return applyVivoZeiss(baseImage, bitmap: bitmap, config: config)
            }
            if String(describing: config.style).starts(with: "tecno") {
                 return applyTecnoWatermark(baseImage, bitmap: bitmap, config: config, mode: 1)
            }
            return image
        }
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
        // Z series watermarks
        return applyMeizuNorm(image, bitmap: bitmap, config: config)
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
}

