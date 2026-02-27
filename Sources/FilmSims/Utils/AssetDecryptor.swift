import Foundation
import CommonCrypto

/// iOS equivalent of Android's AssetDecryptor.
/// Decrypts AES-256-CTR encrypted asset files on-the-fly.
///
/// Format: [16-byte IV][AES-CTR encrypted payload]
/// Key derivation: SHA-256(masterKey || IV)
///
/// This must match the scheme used on Android when the .enc assets were produced.
enum AssetDecryptor {

    // Master key – in production, this should come from a secure build config.
    // Matches Android's BuildConfig.ASSET_KEY.
    private static let masterKey: String = {
        // Read from Info.plist or fallback to placeholder
        if let key = Bundle.main.object(forInfoDictionaryKey: "ASSET_KEY") as? String, !key.isEmpty {
            return key
        }
        return "placeholder_key"
    }()

    /// Decrypt data from an encrypted asset.
    /// Returns the original data if not encrypted or if the master key is a placeholder.
    static func decryptData(_ data: Data) -> Data {
        if masterKey == "placeholder_key" || masterKey.isEmpty {
            return data
        }
        guard data.count > 16 else { return data }

        // Extract 16-byte IV
        let iv = data.prefix(16)
        let payload = data.suffix(from: 16)

        // Derive 32-byte key: SHA-256(masterKeyBytes || IV)
        let fileKey = deriveKey(masterKey, iv: iv)

        // Decrypt with AES-256-CTR
        guard let decrypted = aesCTRDecrypt(data: Data(payload), key: fileKey, iv: Data(iv)) else {
            return data
        }
        return decrypted
    }

    /// Open a potentially encrypted asset from the bundle.
    /// Handles both .enc files and unencrypted fallback (matches Android AssetUtil).
    static func openAsset(path: String) -> Data? {
        // If the path already has .enc, open and decrypt
        if path.hasSuffix(".enc") {
            if let data = loadBundleResource(path: path) {
                return decryptData(data)
            }
            return nil
        }

        // Try adding .enc for hardcoded paths
        if let data = loadBundleResource(path: path + ".enc") {
            return decryptData(data)
        }

        // Fallback to unencrypted path
        return loadBundleResource(path: path)
    }

    // MARK: - Private Helpers

    /// Derive a 32-byte key from the master key and per-file IV.
    /// Algorithm: SHA-256(masterKeyBytes || IV)
    private static func deriveKey(_ masterKey: String, iv: Data) -> Data {
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

    /// Load a resource from the Bundle.module.
    private static func loadBundleResource(path: String) -> Data? {
        // Try direct URL from bundle
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
