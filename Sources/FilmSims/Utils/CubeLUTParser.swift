import Foundation
import UIKit

class CubeLUTParser {
    
    static func parse(assetPath: String) -> CubeLUT? {
        let lowercasePath = assetPath.lowercased()
        let pathExtension = URL(fileURLWithPath: assetPath).pathExtension.lowercased()
        
        if lowercasePath.hasSuffix(".png") {
            return parsePngLut(assetPath: assetPath)
        } else if lowercasePath.hasSuffix(".webp") || lowercasePath.hasSuffix(".jpg") || lowercasePath.hasSuffix(".jpeg") {
            // iOS cannot decode WebP via UIImage on all OS versions without additional decoders.
            // Keep parity with Android by attempting to load through UIImage; if it fails, return nil.
            return parsePngLut(assetPath: assetPath)
        } else if lowercasePath.hasSuffix(".cube") {
            return parseCubeLut(assetPath: assetPath)
        } else if lowercasePath.hasSuffix(".bin") {
            return parseBinLut(assetPath: assetPath)
        } else if pathExtension.isEmpty {
            // Some vendors ship raw binary LUTs without an extension.
            return parseBinLut(assetPath: assetPath)
        }
        
        return nil
    }
    
    // MARK: - Binary LUT Parser
    private static func parseBinLut(assetPath: String) -> CubeLUT? {
        guard let data = FileManager.default.contents(atPath: assetPath) else {
            return nil
        }
        
        let bytes = [UInt8](data)
        if bytes.isEmpty { return nil }
        
        var lutSize = 32
        var channels = 3
        var dataOffset = 0
        var isBgr = false
        var isFloatFormat = false
        
        // Check for known headers
        let magic8 = bytes.count >= 8 ? String(bytes: bytes[0..<8], encoding: .ascii) ?? "" : ""
        let magic4 = bytes.count >= 4 ? String(bytes: bytes[0..<4], encoding: .ascii) ?? "" : ""
        let hasMsLutHeader = magic8 == ".MS-LUT "
        let hasLut3Header = magic4 == "LUT3"
        
        if hasLut3Header && bytes.count >= 12 {
            // LUT3 header (Huawei format) — ported from Android's CubeLUTParser.kt
            // 0x00-0x03: "LUT3"
            // 0x04-0x07: LUT size (little endian uint32)
            // 0x08-0x0B: entry count (little endian uint32) = lutSize^3
            // 0x0C..   : RGB data, 3 bytes per entry
            lutSize = Int(readUInt32LE(bytes: bytes, offset: 0x04))
            let entryCount = Int(readUInt32LE(bytes: bytes, offset: 0x08))
            dataOffset = 12
            channels = 3
            isFloatFormat = false

            let expectedEntries = lutSize * lutSize * lutSize
            if !(lutSize >= 8 && lutSize <= 128 && entryCount == expectedEntries) {
                // Fallback: attempt brute force from file size, but keep LUT3 offset.
                (lutSize, channels, _) = detectLutSizeFromFileSize(bytes.count - dataOffset)
                channels = 3
                isFloatFormat = false
                if lutSize < 8 || lutSize > 128 {
                    return nil
                }
            }
        } else if hasMsLutHeader {
            // Parse MS-LUT header
            if bytes.count > 0x30 {
                lutSize = Int(bytes[0x0C]) | (Int(bytes[0x0D]) << 8) | (Int(bytes[0x0E]) << 16) | (Int(bytes[0x0F]) << 24)
                dataOffset = Int(bytes[0x28]) | (Int(bytes[0x29]) << 8) | (Int(bytes[0x2A]) << 16) | (Int(bytes[0x2B]) << 24)
                
                if lutSize < 8 || lutSize > 128 || dataOffset < 48 || dataOffset > 4096 {
                    // Invalid header, use brute force
                    (lutSize, channels, dataOffset) = detectLutSizeFromFileSize(bytes.count)
                } else {
                    let dataSize = bytes.count - dataOffset
                    let expectedPixels = lutSize * lutSize * lutSize
                    
                    if dataSize == expectedPixels * 4 {
                        channels = 4
                    } else if dataSize >= expectedPixels * 12 {
                        isFloatFormat = true
                        channels = 3
                    } else {
                        channels = 3
                    }
                }
                
                // Check format hint
                if bytes.count > 0x14 {
                    let formatHint = Int(bytes[0x10])
                    let dataSize = bytes.count - dataOffset
                    let expectedBytesPerPixel = dataSize / (lutSize * lutSize * lutSize)
                    
                    if formatHint == 3 || expectedBytesPerPixel >= 12 {
                        isFloatFormat = true
                        channels = 3
                    }
                }
            }
        } else {
            // Raw binary — try float32 (3-ch) first for Leica FOTOS and similar formats
            let fileSize = bytes.count
            var detected = false
            if fileSize % 12 == 0 {
                let sizeF3 = Int(round(pow(Double(fileSize / 12), 1.0/3.0)))
                if sizeF3 >= 8 && sizeF3 <= 128 && sizeF3 * sizeF3 * sizeF3 * 12 == fileSize {
                    lutSize = sizeF3; channels = 3; isFloatFormat = true; dataOffset = 0
                    detected = true
                }
            }
            if !detected {
                let result = detectLutSizeFromFileSize(fileSize)
                lutSize = result.0
                channels = result.1
                dataOffset = result.2
            }
        }
        
        // Auto-detect BGR from data pattern
        isBgr = detectBgrOrder(bytes: bytes, dataOffset: dataOffset, lutSize: lutSize, channels: channels, isFloatFormat: isFloatFormat)
        
        // Extract data
        let totalPixels = lutSize * lutSize * lutSize
        var floatData: [Float] = []
        floatData.reserveCapacity(totalPixels * 3)
        
        var index = dataOffset
        
        let bytesPerPixel = isFloatFormat ? 12 : channels
        let requiredBytes = dataOffset + totalPixels * bytesPerPixel
        guard requiredBytes <= bytes.count else {
            return nil
        }

        for _ in 0..<totalPixels {
            if isFloatFormat {
                if index + 12 > bytes.count { break }
                
                let v1 = readFloat(bytes: bytes, offset: index)
                let v2 = readFloat(bytes: bytes, offset: index + 4)
                let v3 = readFloat(bytes: bytes, offset: index + 8)
                
                if isBgr {
                    floatData.append(min(max(v3, 0), 1))
                    floatData.append(min(max(v2, 0), 1))
                    floatData.append(min(max(v1, 0), 1))
                } else {
                    floatData.append(min(max(v1, 0), 1))
                    floatData.append(min(max(v2, 0), 1))
                    floatData.append(min(max(v3, 0), 1))
                }
                index += 12
            } else {
                if index + channels > bytes.count { break }
                
                let v1 = Float(bytes[index]) / 255.0
                let v2 = Float(bytes[index + 1]) / 255.0
                let v3 = Float(bytes[index + 2]) / 255.0
                
                if isBgr {
                    floatData.append(v3)
                    floatData.append(v2)
                    floatData.append(v1)
                } else {
                    floatData.append(v1)
                    floatData.append(v2)
                    floatData.append(v3)
                }
                index += channels
            }
        }

        guard floatData.count == totalPixels * 3 else {
            return nil
        }

        return CubeLUT(size: lutSize, data: floatData)
    }

    private static func readUInt32LE(bytes: [UInt8], offset: Int) -> UInt32 {
        guard offset + 4 <= bytes.count else { return 0 }
        return UInt32(bytes[offset]) |
            (UInt32(bytes[offset + 1]) << 8) |
            (UInt32(bytes[offset + 2]) << 16) |
            (UInt32(bytes[offset + 3]) << 24)
    }
    
    private static func detectLutSizeFromFileSize(_ fileSize: Int) -> (Int, Int, Int) {
        switch fileSize {
        case 16384: return (16, 4, 0)
        case 131072: return (32, 4, 0)
        case 98304: return (32, 3, 0)
        case 12288: return (16, 3, 0)
        default:
            // Try 4 channels
            let sizeC4 = Int(round(pow(Double(fileSize / 4), 1.0/3.0)))
            if sizeC4 * sizeC4 * sizeC4 * 4 == fileSize {
                return (sizeC4, 4, 0)
            }
            // Try 3 channels
            let sizeC3 = Int(round(pow(Double(fileSize / 3), 1.0/3.0)))
            return (sizeC3, 3, 0)
        }
    }
    
    private static func detectBgrOrder(bytes: [UInt8], dataOffset: Int, lutSize: Int, channels: Int, isFloatFormat: Bool) -> Bool {
        var b0Vals: [Float] = []
        var b2Vals: [Float] = []
        
        for r in 0..<min(4, lutSize) {
            if isFloatFormat {
                let idx = dataOffset + r * 12
                if idx + 12 <= bytes.count {
                    b0Vals.append(readFloat(bytes: bytes, offset: idx))
                    b2Vals.append(readFloat(bytes: bytes, offset: idx + 8))
                }
            } else {
                let idx = dataOffset + r * channels
                if idx + 3 <= bytes.count {
                    b0Vals.append(Float(bytes[idx]))
                    b2Vals.append(Float(bytes[idx + 2]))
                }
            }
        }
        
        if b0Vals.count >= 2 && b2Vals.count >= 2 {
            let b0Diff = b0Vals.last! - b0Vals.first!
            let b2Diff = b2Vals.last! - b2Vals.first!
            return b2Diff > b0Diff
        }
        
        return false
    }
    
    private static func readFloat(bytes: [UInt8], offset: Int) -> Float {
        var value: UInt32 = 0
        value |= UInt32(bytes[offset])
        value |= UInt32(bytes[offset + 1]) << 8
        value |= UInt32(bytes[offset + 2]) << 16
        value |= UInt32(bytes[offset + 3]) << 24
        return Float(bitPattern: value)
    }
    
    // MARK: - PNG LUT Parser (HALD format)
    private static func parsePngLut(assetPath: String) -> CubeLUT? {
        guard let image = UIImage(contentsOfFile: assetPath),
              let cgImage = image.cgImage else {
            return nil
        }
        
        let width = cgImage.width
        let height = cgImage.height

        // Square HALD LUT: width == height == lutSize * sqrt(lutSize)
        // e.g. lutSize=16 -> 64x64, lutSize=64 -> 512x512
        if width == height {
            let estimated = Int(round(pow(Double(width), 2.0 / 3.0)))
            let candidates = [estimated, 16, 32, 64]
            for lutSize in candidates {
                guard lutSize > 1 else { continue }
                let tilesPerRowDouble = sqrt(Double(lutSize))
                let tilesPerRow = Int(round(tilesPerRowDouble))
                guard tilesPerRow * tilesPerRow == lutSize else { continue }
                let expected = lutSize * tilesPerRow
                if expected == width {
                    return parseHaldLut(cgImage: cgImage, lutSize: lutSize)
                }
            }
        }

        // Strip format A: width = N², height = N  (e.g. 1024×32, 256×16, 4096×64)
        // pixel(r + g*N, b) → output(r,g,b)
        if height >= 8, height <= 128, width == height * height {
            return parseStripLutA(cgImage: cgImage, lutSize: height)
        }

        // Strip format B: width = N, height = N²  (e.g. 33×1089)
        // pixel(r, b*N + g) → output(r,g,b)
        if width >= 8, width <= 128, height == width * width {
            return parseStripLutB(cgImage: cgImage, lutSize: width)
        }

        return nil
    }

    // Format A: row=B, col=R+G*N
    private static func parseStripLutA(cgImage: CGImage, lutSize: Int) -> CubeLUT? {
        guard let rgba = decodeToRGBA8(cgImage: cgImage) else { return nil }
        let pointer = rgba.bytes
        let bytesPerPixel = 4
        let bytesPerRow = rgba.bytesPerRow

        var dataList: [Float] = []
        dataList.reserveCapacity(lutSize * lutSize * lutSize * 3)

        for b in 0..<lutSize {
            for g in 0..<lutSize {
                for r in 0..<lutSize {
                    let offset = b * bytesPerRow + (r + g * lutSize) * bytesPerPixel
                    dataList.append(Float(pointer[offset])     / 255.0)
                    dataList.append(Float(pointer[offset + 1]) / 255.0)
                    dataList.append(Float(pointer[offset + 2]) / 255.0)
                }
            }
        }
        return CubeLUT(size: lutSize, data: dataList)
    }

    // Format B: col=R, row=B*N+G
    private static func parseStripLutB(cgImage: CGImage, lutSize: Int) -> CubeLUT? {
        guard let rgba = decodeToRGBA8(cgImage: cgImage) else { return nil }
        let pointer = rgba.bytes
        let bytesPerPixel = 4
        let bytesPerRow = rgba.bytesPerRow

        var dataList: [Float] = []
        dataList.reserveCapacity(lutSize * lutSize * lutSize * 3)

        for b in 0..<lutSize {
            for g in 0..<lutSize {
                for r in 0..<lutSize {
                    let offset = (b * lutSize + g) * bytesPerRow + r * bytesPerPixel
                    dataList.append(Float(pointer[offset])     / 255.0)
                    dataList.append(Float(pointer[offset + 1]) / 255.0)
                    dataList.append(Float(pointer[offset + 2]) / 255.0)
                }
            }
        }
        return CubeLUT(size: lutSize, data: dataList)
    }
    
    private static func parseHaldLut(cgImage: CGImage, lutSize: Int) -> CubeLUT? {
        let width = cgImage.width
        let height = cgImage.height

        // Decode into a predictable RGBA8 buffer (PNG decoding often yields BGRA/ARGB depending on source).
        guard let rgba = decodeToRGBA8(cgImage: cgImage) else { return nil }
        let pointer = rgba.bytes
        let bytesPerPixel = 4
        let bytesPerRow = rgba.bytesPerRow
        
        let tilesPerRow = Int(sqrt(Double(lutSize)))
        let tileWidth = width / tilesPerRow
        let tileHeight = height / tilesPerRow
        
        var dataList: [Float] = []
        dataList.reserveCapacity(lutSize * lutSize * lutSize * 3)
        
        // HALD LUT format: iterate B, then G, then R
        for b in 0..<lutSize {
            let tileX = b % tilesPerRow
            let tileY = b / tilesPerRow
            
            for g in 0..<lutSize {
                for r in 0..<lutSize {
                    let pixelX = tileX * tileWidth + r
                    let pixelY = tileY * tileHeight + g
                    
                    let offset = pixelY * bytesPerRow + pixelX * bytesPerPixel
                    
                    let red = Float(pointer[offset]) / 255.0
                    let green = Float(pointer[offset + 1]) / 255.0
                    let blue = Float(pointer[offset + 2]) / 255.0
                    
                    dataList.append(red)
                    dataList.append(green)
                    dataList.append(blue)
                }
            }
        }
        
        return CubeLUT(size: lutSize, data: dataList)
    }

    private struct RGBA8Buffer {
        let bytes: UnsafePointer<UInt8>
        let bytesPerRow: Int
        let backing: Data
    }

    private static func decodeToRGBA8(cgImage: CGImage) -> RGBA8Buffer? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var data = Data(count: bytesPerRow * height)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue))

        let ok = data.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress else { return false }
            guard let ctx = CGContext(
                data: base,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) else { return false }

            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard ok else { return nil }
        return data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
            return RGBA8Buffer(bytes: base, bytesPerRow: bytesPerRow, backing: data)
        }
    }
    
    // MARK: - Cube File Parser
    private static func parseCubeLut(assetPath: String) -> CubeLUT? {
        guard let content = try? String(contentsOfFile: assetPath, encoding: .utf8) else {
            return nil
        }
        
        var size = -1
        var dataList: [Float] = []
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix("TITLE") || trimmed.hasPrefix("DOMAIN_") {
                continue
            }
            
            if trimmed.hasPrefix("LUT_3D_SIZE") {
                let parts = trimmed.split(whereSeparator: { $0.isWhitespace })
                if parts.count >= 2, let parsedSize = Int(parts[1]) {
                    size = parsedSize
                }
            } else {
                let parts = trimmed.split(whereSeparator: { $0.isWhitespace })
                if parts.count >= 3,
                   let r = Float(String(parts[0])),
                   let g = Float(String(parts[1])),
                   let b = Float(String(parts[2])) {
                    dataList.append(min(max(r, 0), 1))
                    dataList.append(min(max(g, 0), 1))
                    dataList.append(min(max(b, 0), 1))
                }
            }
        }
        
        if size == -1 || dataList.isEmpty {
            return nil
        }
        
        let expected = size * size * size * 3
        guard dataList.count == expected else {
            return nil
        }

        return CubeLUT(size: size, data: dataList)
    }
}
