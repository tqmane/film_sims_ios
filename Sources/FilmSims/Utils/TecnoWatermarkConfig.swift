import Foundation
import UIKit

struct TecnoWatermarkTemplate {
    let portraitModes: [TecnoMode]
    let landscapeModes: [TecnoMode]
}

struct TecnoMode {
    let name: String
}

struct TecnoModeConfig {
    let barColor: UIColor
    let barWidth: Int
    let barHeight: Int
    let backdropValid: Bool
    let backdrop: TecnoBackdropProfile?
    let brand: TecnoBrandProfile?
    let brandName: String
    let iconProfiles: [TecnoIconProfile]
    let textProfiles: [TecnoTextProfile]
}

struct TecnoBackdropProfile {
    let iconFileName: String
    let iconCoordinate: (x: CGFloat, y: CGFloat)
    let iconSize: (width: CGFloat, height: CGFloat)
    let tuningCoordinate: (x: CGFloat, y: CGFloat)
}

struct TecnoBrandProfile {
    let typeText: Bool
    let textBrandName: String
}

struct TecnoIconProfile {
    let iconFileName: String
    let iconCoordinate: (x: CGFloat, y: CGFloat)
    let iconSize: (width: CGFloat, height: CGFloat)
    let tuningCoordinate: (x: CGFloat, y: CGFloat)
    let relyOnElem: Bool
    let relyProfile: TecnoRelyProfile?
}

struct TecnoRelyProfile {
    let relyType: Int
    let relyIndex: Int
    let reltOnLeftX: Bool
}

struct TecnoTextProfile {
    let fontProfile: TecnoFontProfile?
    let spaceRatio: CGFloat
    let characterDistanceRatio: CGFloat
    let textCoordinate: (x: CGFloat, y: CGFloat)
    let tuningCoordinate: (x: CGFloat, y: CGFloat)
    let renderDirection: Int
    let relyOnElem: Bool
    let relyProfile: TecnoRelyProfile?
}

struct TecnoFontProfile {
    let fontFileName: String
    let fontSize: CGFloat
    let fontColor: UIColor
    let fontIntensity: CGFloat
}

struct TecnoRenderConfig {
    var deviceName: String? = nil
    var timeText: String? = nil
    var locationText: String? = nil
    var lensInfo: String? = nil
    var brandName: String = ""
}
