import CommonCrypto
import Foundation

final class ZixyPayloadCipher {

    enum Configuration {
//        static let applicationIdentifier = "44332211"
//        static let key = Data("518486he8pzgbjsk".utf8)
//        static let initializationVector = Data("614436p28qzhkjsl".utf8)
        static let applicationIdentifier = "30417288"
        static let key = Data("ltvj9of9ix0ychk9".utf8)
        static let initializationVector = Data("x3vxl0pi76r94vlv".utf8)
    }
 
    private enum CryptographyError: Error {
        case invalidKeyLength
        case invalidInitializationVectorLength
        case operationFailed(CCCryptorStatus)
    }

    private init() {}

    static func encrypt(_ plaintext: String) throws -> String {
        let encryptedData = try crypt(
            Data(plaintext.utf8),
            operation: CCOperation(kCCEncrypt)
        )
        return encryptedData.hexString
    }

    static func decrypt(_ cipherHex: String) -> String {
        guard
            let cipherData = Data(hexString: cipherHex),
            !cipherData.isEmpty,
            let decryptedData = try? crypt(
                cipherData,
                operation: CCOperation(kCCDecrypt)
            )
        else {
            return ""
        }

        return String(data: decryptedData, encoding: .utf8) ?? ""
    }

    private static func crypt(
        _ input: Data,
        operation: CCOperation
    ) throws -> Data {
        let key = Configuration.key
        let initializationVector = Configuration.initializationVector

        guard key.count == kCCKeySizeAES128 else {
            throw CryptographyError.invalidKeyLength
        }
        guard initializationVector.count == kCCBlockSizeAES128 else {
            throw CryptographyError.invalidInitializationVectorLength
        }

        let outputCapacity = input.count + kCCBlockSizeAES128
        var output = Data(count: outputCapacity)
        var outputLength = 0

        let status = output.withUnsafeMutableBytes { outputBuffer in
            input.withUnsafeBytes { inputBuffer in
                key.withUnsafeBytes { keyBuffer in
                    initializationVector.withUnsafeBytes { vectorBuffer in
                        CCCrypt(
                            operation,
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBuffer.baseAddress,
                            key.count,
                            vectorBuffer.baseAddress,
                            inputBuffer.baseAddress,
                            input.count,
                            outputBuffer.baseAddress,
                            outputCapacity,
                            &outputLength
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else {
            throw CryptographyError.operationFailed(status)
        }

        output.removeSubrange(outputLength..<output.count)
        return output
    }
}

private extension Data {

    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }

    init?(hexString: String) {
        guard hexString.count.isMultiple(of: 2) else {
            return nil
        }

        var bytes = [UInt8]()
        bytes.reserveCapacity(hexString.count / 2)

        var index = hexString.startIndex
        while index < hexString.endIndex {
            let nextIndex = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<nextIndex], radix: 16) else {
                return nil
            }
            bytes.append(byte)
            index = nextIndex
        }

        self.init(bytes)
    }
}
