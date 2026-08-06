import CommonCrypto
import Foundation

final class ZixyPayloadCipher {

    enum Configuration {
        static let applicationIdentifier = ZixyCipherSeed.unseal(
            [122, 106, 95, 77, 186, 172, 151, 248],
            seed: 73
        )
        fileprivate static let secretKey = Data(
            ZixyCipherSeed.unseal(
                [
                    21, 254, 237, 198, 132, 161, 185, 201,
                    104, 106, 19, 77, 38, 62, 12, 65
                ],
                seed: 121
            ).utf8
        )
        fileprivate static let vector = Data(
            ZixyCipherSeed.unseal(
                [
                    84, 14, 56, 39, 28, 177, 226, 202,
                    131, 243, 164, 222, 204, 127, 118, 93
                ],
                seed: 44
            ).utf8
        )
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

private enum ZixyCipherSeed {

    static func unseal(_ payload: [UInt8], seed: UInt8) -> String {
        let clearBytes = payload.enumerated().map { offset, byte in
            let stride = UInt8(truncatingIfNeeded: offset &* 17)
            return byte ^ (seed &+ stride)
        }
        return String(decoding: clearBytes, as: UTF8.self)
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
