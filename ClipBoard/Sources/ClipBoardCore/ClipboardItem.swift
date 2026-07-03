import Foundation

public enum ItemType: String, Codable {
    case text
    case image
    case richText
    case fileURL
    case color
    case link
    case code
    case contact
}

public struct ClipboardItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let type: ItemType
    public let createdAt: Date
    public var content: String?
    public var imageFileName: String?
    public var metadata: [String: String]?

    public init(text: String) {
        self.id = UUID()
        self.type = .text
        self.createdAt = Date()
        self.content = text
        self.imageFileName = nil
        self.metadata = nil
    }

    public init(imageFileName: String) {
        self.id = UUID()
        self.type = .image
        self.createdAt = Date()
        self.content = nil
        self.imageFileName = imageFileName
        self.metadata = nil
    }

    public init(type: ItemType, content: String?, imageFileName: String? = nil, metadata: [String: String]? = nil) {
        self.id = UUID()
        self.type = type
        self.createdAt = Date()
        self.content = content
        self.imageFileName = imageFileName
        self.metadata = metadata
    }
}
