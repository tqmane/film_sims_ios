import Foundation
import UIKit

class TecnoWatermarkConfigParser {
    
    func parseConfig(assetPath: String = "watermark/TECNO/TranssionWM.json") -> TecnoWatermarkTemplate? {
        guard let url = Bundle.module.url(forResource: assetPath, withExtension: nil) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return parseContent(data: data)
    }

    private func parseContent(data: Data) -> TecnoWatermarkTemplate? {
        guard let jsonResult = try? JSONSerialization.jsonObject(with: data, options: []),
              let root = jsonResult as? [String: Any],
              let watermark = root["WATERMARK"] as? [String: Any],
              let layouts = watermark["WM_LAYOUTS"] as? [[String]] else {
            return nil
        }
        
        let portraitModes = layouts.count > 0 ? parseModeList(array: layouts[0]) : []
        let landscapeModes = layouts.count > 1 ? parseModeList(array: layouts[1]) : []
        
        return TecnoWatermarkTemplate(portraitModes: portraitModes, landscapeModes: landscapeModes)
    }

    private func parseModeList(array: [String]) -> [TecnoMode] {
        return array.map { TecnoMode(name: $0) }
    }

    func getMode(template: TecnoWatermarkTemplate, modeName: String, isLandscape: Bool) -> TecnoModeConfig? {
        guard let url = Bundle.module.url(forResource: "watermark/TECNO/TranssionWM.json", withExtension: nil),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let watermark = root["WATERMARK"] as? [String: Any],
              let modeObj = watermark[modeName] as? [String: Any] else {
            return nil
        }
        return parseModeConfig(mode: modeObj)
    }

    private func parseModeConfig(mode: [String: Any]) -> TecnoModeConfig {
        let barColorArray = mode["BAR_COLOR"] as? [Int] ?? [255, 255, 255]
        let barSizeArray = mode["BAR_SIZE"] as? [Int] ?? [1080, 113]
        
        let barColor = UIColor(red: CGFloat(barColorArray.indices.contains(0) ? barColorArray[0] : 255) / 255.0,
                               green: CGFloat(barColorArray.indices.contains(1) ? barColorArray[1] : 255) / 255.0,
                               blue: CGFloat(barColorArray.indices.contains(2) ? barColorArray[2] : 255) / 255.0,
                               alpha: 1.0)
                               
        let backdropValid = mode["BACKDROP_IS_VALID"] as? Bool ?? true
        let backdrop = (mode["BACKDROP_PROFILE"] as? [String: Any]).map { parseBackdropProfile(obj: $0) }
        
        let brand = (mode["BRAND_PROFILE"] as? [String: Any]).map { parseBrandProfile(obj: $0) }
        
        var icons = [TecnoIconProfile]()
        if let iconArray = mode["ICON_PROFILES"] as? [[String: Any]] {
            icons = iconArray.map { parseIconProfile(obj: $0) }
        }
        
        var texts = [TecnoTextProfile]()
        if let textArray = mode["TEXT_PROFILES"] as? [[String: Any]] {
            texts = textArray.map { parseTextProfile(obj: $0) }
        }
        
        return TecnoModeConfig(
            barColor: barColor,
            barWidth: barSizeArray.indices.contains(0) ? barSizeArray[0] : 1080,
            barHeight: barSizeArray.indices.contains(1) ? barSizeArray[1] : 113,
            backdropValid: backdropValid,
            backdrop: backdrop,
            brand: brand,
            brandName: brand?.textBrandName ?? "",
            iconProfiles: icons,
            textProfiles: texts
        )
    }

    private func parseBackdropProfile(obj: [String: Any]) -> TecnoBackdropProfile {
        return TecnoBackdropProfile(
            iconFileName: obj["ICON_FILE_NAME"] as? String ?? "",
            iconCoordinate: parseFloatPair(array: obj["ICON_COORDINATE"] as? [Double]),
            iconSize: parseFloatPair(array: obj["ICON_SIZE"] as? [Double]),
            tuningCoordinate: parseFloatPair(array: obj["TUNING_COORDINATE"] as? [Double])
        )
    }

    private func parseBrandProfile(obj: [String: Any]) -> TecnoBrandProfile {
        let isText = obj["TYPE_TEXT"] as? Bool ?? true
        let brandName = isText ? (obj["TEXT_BRAND_NAME"] as? String ?? "TECNO") : ""
        return TecnoBrandProfile(typeText: isText, textBrandName: brandName)
    }

    private func parseIconProfile(obj: [String: Any]) -> TecnoIconProfile {
        return TecnoIconProfile(
            iconFileName: obj["ICON_FILE_NAME"] as? String ?? "",
            iconCoordinate: parseFloatPair(array: obj["ICON_COORDINATE"] as? [Double]),
            iconSize: parseFloatPair(array: obj["ICON_SIZE"] as? [Double]),
            tuningCoordinate: parseFloatPair(array: obj["TUNING_COORDINATE"] as? [Double]),
            relyOnElem: obj["RELY_ON_ELEM"] as? Bool ?? false,
            relyProfile: (obj["RELY_PROFILE"] as? [String: Any]).map { parseRelyProfile(obj: $0) }
        )
    }
    
    private func parseRelyProfile(obj: [String: Any]) -> TecnoRelyProfile {
        return TecnoRelyProfile(
            relyType: obj["RELY_TYPE"] as? Int ?? 0,
            relyIndex: obj["RELY_INDEX"] as? Int ?? 0,
            reltOnLeftX: obj["RELT_ON_LEFT_X"] as? Bool ?? false
        )
    }
    
    private func parseTextProfile(obj: [String: Any]) -> TecnoTextProfile {
        return TecnoTextProfile(
            fontProfile: (obj["FONT_PROFILE"] as? [String: Any]).map { parseFontProfile(obj: $0) },
            spaceRatio: CGFloat(obj["SPACE_RATIO"] as? Double ?? 0.42),
            characterDistanceRatio: CGFloat(obj["CHARACTER_DISTANCE_RATIO"] as? Double ?? 0.0),
            textCoordinate: parseFloatPair(array: obj["TEXT_COORDINATE"] as? [Double]),
            tuningCoordinate: parseFloatPair(array: obj["TUNING_COORDINATE"] as? [Double]),
            renderDirection: obj["RENDER_DIRECTION"] as? Int ?? 0,
            relyOnElem: obj["RELY_ON_ELEM"] as? Bool ?? false,
            relyProfile: (obj["RELY_PROFILE"] as? [String: Any]).map { parseRelyProfile(obj: $0) }
        )
    }
    
    private func parseFontProfile(obj: [String: Any]) -> TecnoFontProfile {
        let colorArr = obj["FONT_COLOR"] as? [Int] ?? [0, 0, 0]
        let fontColor = UIColor(red: CGFloat(colorArr.indices.contains(0) ? colorArr[0] : 0) / 255.0,
                                green: CGFloat(colorArr.indices.contains(1) ? colorArr[1] : 0) / 255.0,
                                blue: CGFloat(colorArr.indices.contains(2) ? colorArr[2] : 0) / 255.0,
                                alpha: 1.0)
        return TecnoFontProfile(
            fontFileName: obj["FONT_FILE_NAME"] as? String ?? "",
            fontSize: CGFloat(obj["FONT_SIZE"] as? Double ?? 29.0),
            fontColor: fontColor,
            fontIntensity: CGFloat(obj["FONT_INTENSITY"] as? Double ?? 1.0)
        )
    }
    
    private func parseFloatPair(array: [Double]?) -> (CGFloat, CGFloat) {
        guard let arr = array, arr.count >= 2 else { return (0, 0) }
        return (CGFloat(arr[0]), CGFloat(arr[1]))
    }
}
