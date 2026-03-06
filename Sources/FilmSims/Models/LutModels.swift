import Foundation

// MARK: - LUT Item
struct LutItem: Identifiable, Equatable, Sendable {
    let id = UUID()
    let name: String
    let assetPath: String
    
    static func == (lhs: LutItem, rhs: LutItem) -> Bool {
        lhs.assetPath == rhs.assetPath
    }
}

// MARK: - LUT Category
struct LutCategory: Identifiable, Equatable, Sendable {
    let id = UUID()
    let name: String
    let displayName: String
    let items: [LutItem]
    
    static func == (lhs: LutCategory, rhs: LutCategory) -> Bool {
        lhs.name == rhs.name && lhs.items.count == rhs.items.count
    }
}

// MARK: - LUT Brand
struct LutBrand: Identifiable, Equatable, Sendable {
    let id = UUID()
    let name: String
    let displayName: String
    let categories: [LutCategory]
    
    static func == (lhs: LutBrand, rhs: LutBrand) -> Bool {
        lhs.name == rhs.name
    }
}

// MARK: - Cube LUT Data
struct CubeLUT: Sendable {
    let size: Int
    let data: [Float]
    
    // Convert to Data for CIColorCube filter (BGRA format)
    var cubeData: Data {
        var cubeArray: [Float] = []
        let totalEntries = size * size * size
        cubeArray.reserveCapacity(totalEntries * 4)

        guard data.count >= totalEntries * 3 else {
            // Fail-safe: return an identity cube (no color change) rather than crashing.
            // This should not happen if parsers validate lengths correctly.
            for b in 0..<size {
                for g in 0..<size {
                    for r in 0..<size {
                        cubeArray.append(Float(r) / Float(size - 1))
                        cubeArray.append(Float(g) / Float(size - 1))
                        cubeArray.append(Float(b) / Float(size - 1))
                        cubeArray.append(1.0)
                    }
                }
            }
            return cubeArray.withUnsafeBytes { Data($0) }
        }
        
        for i in 0..<totalEntries {
            let baseIndex = i * 3
            let r = data[baseIndex]
            let g = data[baseIndex + 1]
            let b = data[baseIndex + 2]
            
            // CIColorCube expects RGBA
            cubeArray.append(r)
            cubeArray.append(g)
            cubeArray.append(b)
            cubeArray.append(1.0) // Alpha
        }

        return cubeArray.withUnsafeBytes { Data($0) }
    }
}

// MARK: - Saved Preset
struct Preset: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let lutPath: String?
    let intensity: Float
    let overlayLutPath: String?
    let overlayIntensity: Float
    let grainEnabled: Bool
    let grainIntensity: Float
    let grainStyle: String
    let exposure: Float
    let contrast: Float
    let highlights: Float
    let shadows: Float
    let colorTemp: Float
    let watermarkStyleName: String
    let watermarkDeviceName: String
    let watermarkTimeText: String
    let watermarkLocationText: String
    let watermarkLensInfo: String

    init(
        id: String,
        name: String,
        lutPath: String?,
        intensity: Float = 1.0,
        overlayLutPath: String? = nil,
        overlayIntensity: Float = 0.35,
        grainEnabled: Bool = false,
        grainIntensity: Float = 0.5,
        grainStyle: String = "Xiaomi",
        exposure: Float = 0,
        contrast: Float = 0,
        highlights: Float = 0,
        shadows: Float = 0,
        colorTemp: Float = 0,
        watermarkStyleName: String = "none",
        watermarkDeviceName: String = "",
        watermarkTimeText: String = "",
        watermarkLocationText: String = "",
        watermarkLensInfo: String = ""
    ) {
        self.id = id
        self.name = name
        self.lutPath = lutPath
        self.intensity = intensity
        self.overlayLutPath = overlayLutPath
        self.overlayIntensity = overlayIntensity
        self.grainEnabled = grainEnabled
        self.grainIntensity = grainIntensity
        self.grainStyle = grainStyle
        self.exposure = exposure
        self.contrast = contrast
        self.highlights = highlights
        self.shadows = shadows
        self.colorTemp = colorTemp
        self.watermarkStyleName = watermarkStyleName
        self.watermarkDeviceName = watermarkDeviceName
        self.watermarkTimeText = watermarkTimeText
        self.watermarkLocationText = watermarkLocationText
        self.watermarkLensInfo = watermarkLensInfo
    }
}
