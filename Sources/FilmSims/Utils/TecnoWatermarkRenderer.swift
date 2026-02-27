import Foundation
import UIKit
import CoreGraphics
import CoreText

class TecnoWatermarkRenderer: @unchecked Sendable {
    static let shared = TecnoWatermarkRenderer()
    static let TEMPLATE_REF_WIDTH: CGFloat = 1080.0
    private var typefaceCache = [String: UIFont]()
    
    func render(source: UIImage, template: TecnoWatermarkTemplate, modeName: String, isLandscape: Bool, config: TecnoRenderConfig) -> UIImage {
        let parser = TecnoWatermarkConfigParser()
        if let modeConfig = parser.getMode(template: template, modeName: modeName, isLandscape: isLandscape) {
            return renderFromConfig(source: source, modeConfig: modeConfig, isLandscape: isLandscape, config: config)
        } else {
            return renderBasic(source: source, config: config)
        }
    }
    
    private func renderFromConfig(source: UIImage, modeConfig: TecnoModeConfig, isLandscape: Bool, config: TecnoRenderConfig) -> UIImage {
        guard let cgImage = source.cgImage else { return source }
        let imgWidth = CGFloat(cgImage.width)
        let imgHeight = CGFloat(cgImage.height)
        
        let scale = imgWidth / Self.TEMPLATE_REF_WIDTH
        let barHeight = round(CGFloat(modeConfig.barHeight) * scale)
        let totalHeight = imgHeight + barHeight
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        
        return UIGraphicsImageRenderer(size: CGSize(width: imgWidth, height: totalHeight), format: format).image { context in
            let ctx = context.cgContext
            
            source.draw(in: CGRect(x: 0, y: 0, width: imgWidth, height: imgHeight))
            
            ctx.setFillColor(modeConfig.barColor.cgColor)
            ctx.fill(CGRect(x: 0, y: imgHeight, width: imgWidth, height: barHeight))
            
            if modeConfig.backdropValid, let backdrop = modeConfig.backdrop {
                drawBackdrop(ctx: ctx, backdrop: backdrop, barTop: imgHeight, scale: scale)
            }
            
            for iconProfile in modeConfig.iconProfiles {
                drawIcon(ctx: ctx, iconProfile: iconProfile, barTop: imgHeight, scale: scale, config: config, textProfiles: modeConfig.textProfiles)
            }
            
            for (index, textProfile) in modeConfig.textProfiles.enumerated() {
                drawText(ctx: ctx, textProfile: textProfile, barTop: imgHeight, scale: scale, config: config, textIndex: index, fallbackBrandName: modeConfig.brandName, allTextProfiles: modeConfig.textProfiles)
            }
        }
    }
    
    private func drawBackdrop(ctx: CGContext, backdrop: TecnoBackdropProfile, barTop: CGFloat, scale: CGFloat) {
        let iconName = backdrop.iconFileName
        if iconName.isEmpty { return }
        if let bmp = loadTecnoImage(imageName: iconName) {
            let x = backdrop.iconCoordinate.x * scale
            let y = barTop + backdrop.iconCoordinate.y * scale
            let w = backdrop.iconSize.width * scale
            let h = backdrop.iconSize.height * scale
            bmp.draw(in: CGRect(x: x, y: y, width: w, height: h))
        }
    }
    
    private func drawIcon(ctx: CGContext, iconProfile: TecnoIconProfile, barTop: CGFloat, scale: CGFloat, config: TecnoRenderConfig, textProfiles: [TecnoTextProfile]) {
        let iconName = iconProfile.iconFileName
        if iconName.isEmpty { return }
        var baseX = iconProfile.iconCoordinate.x
        var baseY = iconProfile.iconCoordinate.y
        
        if iconProfile.relyOnElem, let relyProfile = iconProfile.relyProfile {
            let relyIdx = relyProfile.relyIndex
            if relyIdx < textProfiles.count {
                let textProfile = textProfiles[relyIdx]
                if let fontProfile = textProfile.fontProfile {
                    let font = getTecnoTypeface(fontProfile.fontFileName, size: fontProfile.fontSize * scale)
                    if let content = getTextContent(textProfile: textProfile, config: config, textIndex: relyIdx, fallbackBrandName: "") {
                        let textWidth = (content as NSString).size(withAttributes: [.font: font]).width
                        
                        if relyProfile.reltOnLeftX {
                            baseX = textProfile.textCoordinate.x - iconProfile.iconSize.width / 2.0 - 5.0
                        } else {
                            baseX = textProfile.textCoordinate.x + textWidth / scale + iconProfile.iconSize.width / 2.0 + 5.0
                        }
                        let textCenterOffset = (font.ascender + font.descender) / 2.0 // iOS coordinate compensation
                        let pngCircleCompensation = iconProfile.iconSize.height * 0.10
                        baseY = textProfile.textCoordinate.y + textCenterOffset / scale + pngCircleCompensation
                    }
                }
            }
        }
        
        if let bmp = loadTecnoImage(imageName: iconName) {
            let w = iconProfile.iconSize.width * scale
            let h = iconProfile.iconSize.height * scale
            let x = baseX * scale - w / 2.0
            let y = barTop + baseY * scale - h / 2.0
            bmp.draw(in: CGRect(x: x, y: y, width: w, height: h))
        }
    }
    
    private func drawText(ctx: CGContext, textProfile: TecnoTextProfile, barTop: CGFloat, scale: CGFloat, config: TecnoRenderConfig, textIndex: Int, fallbackBrandName: String, allTextProfiles: [TecnoTextProfile]) {
        guard let fontProfile = textProfile.fontProfile else { return }
        guard let content = getTextContent(textProfile: textProfile, config: config, textIndex: textIndex, fallbackBrandName: fallbackBrandName), !content.isEmpty else { return }
        
        let font = getTecnoTypeface(fontProfile.fontFileName, size: fontProfile.fontSize * scale)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: fontProfile.fontColor
        ]
        
        var x = textProfile.textCoordinate.x * scale
        let y = barTop + textProfile.textCoordinate.y * scale
        
        if textProfile.relyOnElem, let relyProfile = textProfile.relyProfile, !allTextProfiles.isEmpty {
            let relyIdx = relyProfile.relyIndex
            if relyIdx < allTextProfiles.count {
                let reliedText = allTextProfiles[relyIdx]
                if let reliedFontProfile = reliedText.fontProfile {
                    if let reliedContent = getTextContent(textProfile: reliedText, config: config, textIndex: relyIdx, fallbackBrandName: fallbackBrandName) {
                        let reliedFont = getTecnoTypeface(reliedFontProfile.fontFileName, size: reliedFontProfile.fontSize * scale)
                        let reliedTextWidth = (reliedContent as NSString).size(withAttributes: [.font: reliedFont]).width
                        
                        setupRelyX(relyProfile: relyProfile, textProfile: textProfile, reliedText: reliedText, reliedTextWidth: reliedTextWidth, scale: scale, destX: &x)
                    }
                }
            }
        }
        
        let attrString = NSAttributedString(string: content, attributes: attrs)
        if textProfile.renderDirection == 1 {
            x -= attrString.size().width
        }
        attrString.draw(at: CGPoint(x: x, y: y - font.ascender))
    }
    
    private func setupRelyX(relyProfile: TecnoRelyProfile, textProfile: TecnoTextProfile, reliedText: TecnoTextProfile, reliedTextWidth: CGFloat, scale: CGFloat, destX: inout CGFloat) {
        if relyProfile.reltOnLeftX {
            if reliedText.renderDirection == 1 {
                destX = reliedText.textCoordinate.x * scale - reliedTextWidth + textProfile.textCoordinate.x * scale
            } else {
                destX = reliedText.textCoordinate.x * scale + textProfile.textCoordinate.x * scale
            }
        } else {
            if reliedText.renderDirection == 1 {
                destX = reliedText.textCoordinate.x * scale + textProfile.textCoordinate.x * scale
            } else {
                destX = reliedText.textCoordinate.x * scale + reliedTextWidth + textProfile.textCoordinate.x * scale
            }
        }
    }
    
    private func getTextContent(textProfile: TecnoTextProfile, config: TecnoRenderConfig, textIndex: Int, fallbackBrandName: String) -> String? {
        switch textIndex {
        case 0: return config.deviceName ?? (fallbackBrandName.isEmpty ? "TECNO" : fallbackBrandName)
        case 1: return config.timeText
        case 2: return config.lensInfo
        case 3: return config.locationText
        default: return config.deviceName
        }
    }
    
    private func loadTecnoImage(imageName: String) -> UIImage? {
        guard !imageName.isEmpty else { return nil }
        let baseName = (imageName as NSString).deletingPathExtension
        let searchPaths = [
            "watermark/TECNO/icons/\(baseName).png",
            "watermark/TECNO/icons/\(imageName)"
        ]
        
        for path in searchPaths {
            if let url = Bundle.module.url(forResource: path, withExtension: nil),
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                return image
            }
        }
        return nil
    }
    
    private func getTecnoTypeface(_ fontFileName: String, size: CGFloat) -> UIFont {
        let key = "\(fontFileName)-\(size)"
        if let cached = typefaceCache[key] { return cached }
        if let url = Bundle.module.url(forResource: "watermark/TECNO/fonts/\(fontFileName)", withExtension: nil) {
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            if let data = try? Data(contentsOf: url),
               let provider = CGDataProvider(data: data as CFData),
               let cgFont = CGFont(provider),
               let name = cgFont.postScriptName as String?,
               let font = UIFont(name: name, size: size) {
                typefaceCache[key] = font
                return font
            }
        }
        return UIFont.systemFont(ofSize: size)
    }
    
    private func renderBasic(source: UIImage, config: TecnoRenderConfig) -> UIImage {
        guard let cgImage = source.cgImage else { return source }
        let imgWidth = CGFloat(cgImage.width)
        let imgHeight = CGFloat(cgImage.height)
        let scale = imgWidth / Self.TEMPLATE_REF_WIDTH
        let barHeight = round(113.0 * scale)
        let totalHeight = imgHeight + barHeight
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        
        return UIGraphicsImageRenderer(size: CGSize(width: imgWidth, height: totalHeight), format: format).image { context in
            let ctx = context.cgContext
            source.draw(in: CGRect(x: 0, y: 0, width: imgWidth, height: imgHeight))
            
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(x: 0, y: imgHeight, width: imgWidth, height: barHeight))
            
            let deviceName = config.deviceName ?? "TECNO"
            let brandFont = getTecnoTypeface("Transota0226-Regular.ttf", size: 29.0 * scale)
            let brandAttrs: [NSAttributedString.Key: Any] = [.font: brandFont, .foregroundColor: UIColor.black]
            NSAttributedString(string: deviceName, attributes: brandAttrs).draw(at: CGPoint(x: 39.0 * scale, y: imgHeight + 72.0 * scale - brandFont.lineHeight))
            
            if let timeText = config.timeText, !timeText.isEmpty {
                let dateFont = getTecnoTypeface("tos_regular.ttf", size: 23.0 * scale)
                let dateAttrs: [NSAttributedString.Key: Any] = [.font: dateFont, .foregroundColor: UIColor(red: 2.0/255.0, green: 2.0/255.0, blue: 2.0/255.0, alpha: 1.0)]
                let attrStr = NSAttributedString(string: timeText, attributes: dateAttrs)
                attrStr.draw(at: CGPoint(x: 1041.0 * scale - attrStr.size().width, y: imgHeight + 70.0 * scale - dateFont.lineHeight))
            }
        }
    }
}
