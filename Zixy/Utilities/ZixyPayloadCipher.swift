import CommonCrypto
import Foundation

final class ZixyPayloadCipher {

    enum Configuration {
//        static let applicationIdentifier = "30417288"
//        fileprivate static let secretKey = Data("ltvj9of9ix0ychk9".utf8)
//        fileprivate static let vector = Data("x3vxl0pi76r94vlv".utf8)
        static let applicationIdentifier = "44332211"
        fileprivate static let secretKey = Data("518486he8pzgbjsk".utf8)
        fileprivate static let vector = Data("614436p28qzhkjsl".utf8)
    }

    private enum CipherFailure: Error {
        case malformedSecret
        case malformedVector
        case commonCrypto(CCCryptorStatus)
    }

    private init() {}

    static func encrypt(_ plaintext: String) throws -> String {
        let encryptedData = try transform(
            Data(plaintext.utf8),
            operation: CCOperation(kCCEncrypt)
        )
        return encryptedData.zixyHexPayload
    }

    static func decrypt(_ cipherHex: String) -> String {
        guard
            let cipherData = Data(zixyHexPayload: cipherHex),
            !cipherData.isEmpty,
            let decryptedData = try? transform(
                cipherData,
                operation: CCOperation(kCCDecrypt)
            )
        else {
            return ""
        }

        return String(data: decryptedData, encoding: .utf8) ?? ""
    }

    private static func transform(
        _ input: Data,
        operation: CCOperation
    ) throws -> Data {
        let key = Configuration.secretKey
        let initializationVector = Configuration.vector

        guard key.count == kCCKeySizeAES128 else {
            throw CipherFailure.malformedSecret
        }
        guard initializationVector.count == kCCBlockSizeAES128 else {
            throw CipherFailure.malformedVector
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
            throw CipherFailure.commonCrypto(status)
        }

        return Data(output.prefix(outputLength))
    }
}

private extension Data {

    var zixyHexPayload: String {
        map { String(format: "%02x", $0) }.joined()
    }

    init?(zixyHexPayload: String) {
        guard zixyHexPayload.count.isMultiple(of: 2) else {
            return nil
        }

        var bytes = [UInt8]()
        bytes.reserveCapacity(zixyHexPayload.count / 2)

        var index = zixyHexPayload.startIndex
        while index < zixyHexPayload.endIndex {
            let nextIndex = zixyHexPayload.index(index, offsetBy: 2)
            guard let byte = UInt8(
                zixyHexPayload[index..<nextIndex],
                radix: 16
            ) else {
                return nil
            }
            bytes.append(byte)
            index = nextIndex
        }

        self.init(bytes)
    }
}
