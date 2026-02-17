import Foundation

// MARK: - LUT Item
struct LutItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let assetPath: String
    
    static func == (lhs: LutItem, rhs: LutItem) -> Bool {
        lhs.assetPath == rhs.assetPath
    }
}

// MARK: - LUT Category
struct LutCategory: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let displayName: String
    let items: [LutItem]
    
    static func == (lhs: LutCategory, rhs: LutCategory) -> Bool {
        lhs.name == rhs.name && lhs.items.count == rhs.items.count
    }
}

// MARK: - LUT Brand
struct LutBrand: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let displayName: String
    let categories: [LutCategory]
    
    static func == (lhs: LutBrand, rhs: LutBrand) -> Bool {
        lhs.name == rhs.name
    }
}

// MARK: - Cube LUT Data
struct CubeLUT {
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
