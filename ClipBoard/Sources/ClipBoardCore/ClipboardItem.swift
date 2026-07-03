import Foundation

public enum ItemType: String, Codable {
    case text
    case image
}

public struct ClipboardItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let type: ItemType
    public let createdAt: Date
    public var content: String?
    public var imageFileName: String?

    public init(text: String) {
        self.id = UUID()
        self.type = .text
        self.createdAt = Date()
        self.content = text
        self.imageFileName = nil
    }

    public init(imageFileName: String) {
        self.id = UUID()
        self.type = .image
        self.createdAt = Date()
        self.content = nil
        self.imageFileName = imageFileName
    }
}
