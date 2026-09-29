import Foundation
import CryptoKit

enum ClipKind: String, Codable { case text, image }

struct ClipItem: Codable, Identifiable, Hashable {
    let id: UUID
    var kind: ClipKind
    var createdAt: Date          // atualizado ao deduplicar
    var sourceBundleID: String?  // app de origem
    var text: String?            // .text
    var imageFile: String?       // "<uuid>.png" em blobs/ (.image)
    var imageWidth: Int?
    var imageHeight: Int?
    var hash: String             // SHA-256 do conteúdo (texto UTF-8 ou bytes PNG)

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func text(_ s: String, source: String? = nil) -> ClipItem {
        ClipItem(id: UUID(), kind: .text, createdAt: Date(), sourceBundleID: source, text: s,
                 imageFile: nil, imageWidth: nil, imageHeight: nil, hash: sha256(Data(s.utf8)))
    }

    static func image(png: Data, width: Int, height: Int, source: String? = nil) -> ClipItem {
        let id = UUID()
        return ClipItem(id: id, kind: .image, createdAt: Date(), sourceBundleID: source, text: nil,
                        imageFile: "\(id.uuidString).png", imageWidth: width, imageHeight: height,
                        hash: sha256(png))
    }
}
