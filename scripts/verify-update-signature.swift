import Foundation
import CryptoKit
let args = CommandLine.arguments
guard args.count == 4,
      let pub = Data(base64Encoded: args[2]),
      let signature = Data(base64Encoded: args[3]) else { fatalError("Invalid verification arguments") }
let archive = try Data(contentsOf: URL(fileURLWithPath: args[1]))
let key = try Curve25519.Signing.PublicKey(rawRepresentation: pub)
guard key.isValidSignature(signature, for: archive) else { fatalError("Update signature mismatch") }
var modified = archive
modified[modified.startIndex] ^= 1
guard !key.isValidSignature(signature, for: modified) else { fatalError("Tampered update accepted") }
let wrongKey = Curve25519.Signing.PrivateKey().publicKey
guard !wrongKey.isValidSignature(signature, for: archive) else { fatalError("Wrong signing key accepted") }
print("Archive signature verified; tampering and wrong key rejected")
