import Foundation
import CommonCrypto
#if canImport(UIKit)
import UIKit
import CoreGraphics
import CoreText
#endif

/// Loads encrypted LUT and watermark resources from the app bundle.
///
/// Current envelope format: [magic(7 bytes)][16-byte IV][ciphertext][32-byte HMAC-SHA256]
/// Encryption: AES-256-CBC with PKCS#7 padding
/// Integrity: HMAC-SHA256 over [magic || IV || ciphertext]
///
/// Legacy support remains for older AES-256-CTR assets.
enum AssetDecryptor {

    private static let envelopeMagic = Data("FSAES01".utf8)
    private static let masterKey = SecretKeys.masterKey
#if canImport(UIKit)
    nonisolated(unsafe) private static var registeredFonts = Set<String>()
    private static let fontRegistrationLock = NSLock()
#endif

    /// Decrypt data from an encrypted asset.
    /// Returns the original data if it is not a recognized encrypted envelope.
    static func decryptData(_ data: Data) -> Data {
        if let decrypted = decryptEnvelope(data) {
            return decrypted
        }
        if let decrypted = decryptLegacyCTRData(data) {
            return decrypted
        }
        return data
    }

    /// Open a potentially encrypted asset from the bundle.
    /// Handles both .enc files and unencrypted fallback.
    static func openAsset(path: String) -> Data? {
        for candidate in candidatePaths(for: path) {
            guard let data = loadResourceData(path: candidate) else { continue }

            if candidate.lowercased().hasSuffix(".enc") {
                if let decrypted = decryptEnvelope(data) ?? decryptLegacyCTRData(data) {
                    return decrypted
                }
                continue
            }

            return data
        }

        return nil
    }

    static func openStringAsset(path: String, encoding: String.Encoding = .utf8) -> String? {
        guard let data = openAsset(path: path) else { return nil }
        return String(data: data, encoding: encoding)
    }

    static func openJSONObject(path: String, options: JSONSerialization.ReadingOptions = []) -> Any? {
        guard let data = openAsset(path: path) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: options)
    }

#if canImport(UIKit)
    static func openImageAsset(path: String) -> UIImage? {
        guard let data = openAsset(path: path) else { return nil }
        return UIImage(data: data)
    }

    static func openFont(path: String, size: CGFloat) -> UIFont? {
        guard let data = openAsset(path: path),
              let provider = CGDataProvider(data: data as CFData),
              let cgFont = CGFont(provider),
              let postScriptName = cgFont.postScriptName as String? else {
            return nil
        }

        fontRegistrationLock.lock()
        defer { fontRegistrationLock.unlock() }

        if !registeredFonts.contains(postScriptName) {
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterGraphicsFont(cgFont, &error)
            registeredFonts.insert(postScriptName)
        }

        return UIFont(name: postScriptName, size: size)
    }
#endif

    // MARK: - Private Helpers

    private static func candidatePaths(for originalPath: String) -> [String] {
        var candidates: [String] = []

        func append(_ value: String) {
            guard !value.isEmpty, !candidates.contains(value) else { return }
            candidates.append(value)
        }

        if originalPath.lowercased().hasSuffix(".enc") {
            append(originalPath)
        } else {
            append(originalPath + ".enc")
            append(originalPath)
        }

        let replacements = [
            ("watermark/Vivo/", "watermark/vivo/"),
            ("watermark/vivo/", "watermark/Vivo/")
        ]

        for candidate in Array(candidates) {
            for (from, to) in replacements where candidate.contains(from) {
                append(candidate.replacingOccurrences(of: from, with: to))
            }
        }

        return candidates
    }

    private static func decryptEnvelope(_ data: Data) -> Data? {
        let minimumCount = envelopeMagic.count + kCCBlockSizeAES128 + Int(CC_SHA256_DIGEST_LENGTH)
        guard data.count > minimumCount,
              data.prefix(envelopeMagic.count) == envelopeMagic else {
            return nil
        }

        let ivStart = envelopeMagic.count
        let cipherStart = ivStart + kCCBlockSizeAES128
        let macStart = data.count - Int(CC_SHA256_DIGEST_LENGTH)
        guard macStart > cipherStart else { return nil }

        let header = data.prefix(macStart)
        let expectedMAC = data.suffix(Int(CC_SHA256_DIGEST_LENGTH))
        let computedMAC = hmacSHA256(data: header, key: messageAuthenticationKey)
        guard Data(expectedMAC) == computedMAC else { return nil }

        let iv = data.subdata(in: ivStart..<cipherStart)
        let cipherText = data.subdata(in: cipherStart..<macStart)
        return aesCBCDecrypt(data: cipherText, key: encryptionKey, iv: iv)
    }

    private static func decryptLegacyCTRData(_ data: Data) -> Data? {
        guard data.count > kCCBlockSizeAES128 else { return nil }

        let iv = data.prefix(kCCBlockSizeAES128)
        let payload = data.suffix(from: kCCBlockSizeAES128)
        let fileKey = deriveLegacyCTRKey(masterKey, iv: iv)
        return aesCTRDecrypt(data: Data(payload), key: fileKey, iv: Data(iv))
    }

    private static var encryptionKey: Data {
        sha256(data: Data(("enc:" + masterKey).utf8))
    }

    private static var messageAuthenticationKey: Data {
        sha256(data: Data(("mac:" + masterKey).utf8))
    }

    /// Derive a 32-byte key from the master key and per-file IV.
    /// Algorithm: SHA-256(masterKeyBytes || IV)
    private static func deriveLegacyCTRKey(_ masterKey: String, iv: Data) -> Data {
        var context = CC_SHA256_CTX()
        CC_SHA256_Init(&context)

        let keyBytes = Array(masterKey.utf8)
        CC_SHA256_Update(&context, keyBytes, CC_LONG(keyBytes.count))
        CC_SHA256_Update(&context, (iv as NSData).bytes, CC_LONG(iv.count))

        var digest = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = digest.withUnsafeMutableBytes { ptr in
            CC_SHA256_Final(ptr.bindMemory(to: UInt8.self).baseAddress, &context)
        }
        return digest
    }

    private static func sha256(data: Data) -> Data {
        var digest = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = digest.withUnsafeMutableBytes { outputPtr in
            data.withUnsafeBytes { inputPtr in
                CC_SHA256(
                    inputPtr.bindMemory(to: UInt8.self).baseAddress,
                    CC_LONG(data.count),
                    outputPtr.bindMemory(to: UInt8.self).baseAddress
                )
            }
        }
        return digest
    }

    private static func hmacSHA256(data: Data, key: Data) -> Data {
        var digest = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = digest.withUnsafeMutableBytes { digestPtr in
            key.withUnsafeBytes { keyPtr in
                data.withUnsafeBytes { dataPtr in
                    CCHmac(
                        CCHmacAlgorithm(kCCHmacAlgSHA256),
                        keyPtr.bindMemory(to: UInt8.self).baseAddress,
                        key.count,
                        dataPtr.bindMemory(to: UInt8.self).baseAddress,
                        data.count,
                        digestPtr.bindMemory(to: UInt8.self).baseAddress
                    )
                }
            }
        }
        return digest
    }

    /// AES-256-CTR decryption (CTR mode = same as encryption).
    private static func aesCTRDecrypt(data: Data, key: Data, iv: Data) -> Data? {
        // Use CCCryptorCreateWithMode for CTR support.
        var cryptorRef: CCCryptorRef?
        let createResult = key.withUnsafeBytes { keyPtr in
            iv.withUnsafeBytes { ivPtr in
                CCCryptorCreateWithMode(
                    CCOperation(kCCDecrypt),
                    CCMode(kCCModeCTR),
                    CCAlgorithm(kCCAlgorithmAES),
                    CCPadding(ccNoPadding),
                    ivPtr.baseAddress,
                    keyPtr.baseAddress, key.count,
                    nil, 0, 0,
                    CCModeOptions(kCCModeOptionCTR_BE),
                    &cryptorRef
                )
            }
        }

        guard createResult == kCCSuccess, let cryptor = cryptorRef else {
            return nil
        }
        defer { CCCryptorRelease(cryptor) }

        let outputCapacity = data.count
        var output = Data(count: outputCapacity)
        var outputMoved = 0

        let updateResult: CCCryptorStatus = output.withUnsafeMutableBytes { outPtr in
            data.withUnsafeBytes { inPtr in
                CCCryptorUpdate(
                    cryptor,
                    inPtr.baseAddress, data.count,
                    outPtr.baseAddress, outputCapacity,
                    &outputMoved
                )
            }
        }

        guard updateResult == kCCSuccess else { return nil }
        output.count = outputMoved

        let finalCapacity = kCCBlockSizeAES128
        var finalBuf = Data(count: finalCapacity)
        var finalMoved = 0
        let finalResult: CCCryptorStatus = finalBuf.withUnsafeMutableBytes { ptr in
            CCCryptorFinal(cryptor, ptr.baseAddress, finalCapacity, &finalMoved)
        }

        if finalResult == kCCSuccess && finalMoved > 0 {
            output.append(finalBuf.prefix(finalMoved))
        }

        return output
    }

    private static func aesCBCDecrypt(data: Data, key: Data, iv: Data) -> Data? {
        let outputCapacity = data.count + kCCBlockSizeAES128
        var output = Data(count: outputCapacity)
        var outputMoved = 0

        let status = output.withUnsafeMutableBytes { outPtr in
            data.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.bindMemory(to: UInt8.self).baseAddress,
                            key.count,
                            ivPtr.bindMemory(to: UInt8.self).baseAddress,
                            dataPtr.bindMemory(to: UInt8.self).baseAddress,
                            data.count,
                            outPtr.bindMemory(to: UInt8.self).baseAddress,
                            outputCapacity,
                            &outputMoved
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else { return nil }
        output.count = outputMoved
        return output
    }

    /// Load a resource from the Bundle.module.
    private static func loadResourceData(path: String) -> Data? {
        if path.hasPrefix("/") {
            return try? Data(contentsOf: URL(fileURLWithPath: path))
        }

        let nsPath = (path as NSString)
        let ext = nsPath.pathExtension
        let name = nsPath.deletingPathExtension

        if let url = Bundle.module.url(forResource: name, withExtension: ext) {
            return try? Data(contentsOf: url)
        }

        // Try as subdirectory path
        let components = path.split(separator: "/")
        if components.count > 1 {
            let fileName = String(components.last!)
            let dir = components.dropLast().joined(separator: "/")
            let fileExt = (fileName as NSString).pathExtension
            let fileBase = (fileName as NSString).deletingPathExtension
            if let url = Bundle.module.url(forResource: fileBase, withExtension: fileExt, subdirectory: dir) {
                return try? Data(contentsOf: url)
            }
        }

        return nil
    }
}
