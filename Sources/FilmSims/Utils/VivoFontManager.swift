import Foundation
import UIKit
import CoreGraphics
import CoreText

class VivoFontManager: @unchecked Sendable {
    static let shared = VivoFontManager()
    
    private var fontCache = [Int: UIFont]()
    
    private let FONT_PATH = "watermark/Vivo/fonts/"
    private let FONT_PATH_ALT = "vivo_watermark_full2/assets/fonts/"
    
    private let FONT_MAP: [Int: String] = [
        0: "Roboto-Bold.ttf",
        1: "vivotype-Heavy.ttf",
        2: "vivoCameraVF.ttf",
        3: "vivo-Regular.otf",
        4: "ZEISSFrutigerNextW1G-Bold.ttf",
        5: "Roboto-Bold.ttf",
        6: "IQOOTYPE-Bold.ttf",
        7: "vivoSansExpVF.ttf",
        8: "vivoCameraVF.ttf",
        9: "IQOOTYPE-Bold.ttf",
        10: "vivotypeSimple-Bold.ttf"
    ]
    
    func getTypeface(typeface: Int, size: CGFloat, weight: Int) -> UIFont {
        let file = FONT_MAP[typeface] ?? "Roboto-Bold.ttf"
        let key = typeface * 1000 + Int(size * 10) + weight
        if let cached = fontCache[key] { return cached }

        var font: UIFont? = nil
        let paths = [FONT_PATH + file, FONT_PATH_ALT + file]
        
        for path in paths {
            if let url = Bundle.module.url(forResource: path, withExtension: nil) {
                var error: Unmanaged<CFError>?
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
                if let data = try? Data(contentsOf: url),
                   let provider = CGDataProvider(data: data as CFData),
                   let cgFont = CGFont(provider),
                   let name = cgFont.postScriptName as String? {
                    font = UIFont(name: name, size: size)
                    break
                }
            }
        }
        
        // Apply synthesis for weights if possible
        if let f = font {
            if weight >= 700 {
                fontCache[key] = applyBoldTrait(f)
            } else {
                fontCache[key] = f
            }
            return fontCache[key]!
        }
        
        return weight >= 700 ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size)
    }
    
    private func applyBoldTrait(_ font: UIFont) -> UIFont {
        if let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) {
            return UIFont(descriptor: descriptor, size: font.pointSize)
        }
        return font
    }
    
    func parseColor(colorStr: String) -> UIColor {
        var hex = colorStr.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            a = 255; r = (int >> 16) & 0xFF; g = (int >> 8) & 0xFF; b = int & 0xFF
        case 8:
            a = (int >> 24) & 0xFF; r = (int >> 16) & 0xFF; g = (int >> 8) & 0xFF; b = int & 0xFF
        default:
            a = 255; r = 0; g = 0; b = 0
        }
        return UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
    
    func getTextAttributes(textParam: VivoTextParam, dpScale: CGFloat) -> [NSAttributedString.Key: Any] {
        let size = CGFloat(textParam.textsize) * dpScale
        let font = getTypeface(typeface: textParam.typeface, size: size, weight: textParam.textfontweight)
        let color = parseColor(colorStr: textParam.textcolor)
        
        return [
            .font: font,
            .foregroundColor: color,
            .kern: CGFloat(textParam.letterspacing) * dpScale
        ]
    }
    
    func parseColorInt(_ val: Int) -> UIColor {
        let r = CGFloat((val >> 16) & 0xFF) / 255.0
        let g = CGFloat((val >> 8) & 0xFF) / 255.0
        let b = CGFloat(val & 0xFF) / 255.0
        // Wait, Android Color is ARGB.
        let a = CGFloat((val >> 24) & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a == 0 ? 1.0 : a)
    }
}
