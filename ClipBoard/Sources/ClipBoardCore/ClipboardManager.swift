import Foundation
import AppKit
import Combine

@MainActor
public class ClipboardManager: ObservableObject {
    @Published public var items: [ClipboardItem] = []
    @Published public var keyboardSelectedIndex: Int = 0
    private let maxItemCount = 50
    private let defaultsKey = "clipboardItems"
    private var lastChangeCount: Int = 0
    private var suppressNextChange = false
    private var monitorTimer: Timer?
    public init() {
        loadItems()
        lastChangeCount = NSPasteboard.general.changeCount
    }

    // MARK: - 数据操作

    public func addItem(_ item: ClipboardItem) {
        // 文本去重：与最新条目内容相同则跳过
        if item.type == .text, let content = item.content,
           let firstItem = items.first,
           firstItem.type == .text,
           firstItem.content == content {
            return
        }

        items.insert(item, at: 0)

        // 超出上限则删除最旧条目
        while items.count > maxItemCount {
            if let last = items.last {
                removeImageFile(for: last)
                items.removeLast()
            }
        }

        saveItems()
    }

    public func deleteItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        removeImageFile(for: item)
        saveItems()
    }

    public func clearAll() {
        for item in items {
            removeImageFile(for: item)
        }
        items.removeAll()
        saveItems()
    }

    public func writeToPasteboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .text:
            if let content = item.content {
                pasteboard.setString(content, forType: .string)
            }
        case .image:
            if let fileName = item.imageFileName,
               let image = loadImage(fileName: fileName) {
                pasteboard.writeObjects([image])
            }
        }
        suppressNextChange = true
    }

    /// 获取最近一张图片
    public var latestImage: NSImage? {
        for item in items {
            if item.type == .image, let fileName = item.imageFileName {
                return loadImage(fileName: fileName)
            }
        }
        return nil
    }

    // MARK: - 剪贴板监听

    public func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkPasteboard()
            }
        }
    }

    public func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    private func checkPasteboard() {
        if suppressNextChange {
            suppressNextChange = false
            lastChangeCount = NSPasteboard.general.changeCount
            return
        }

        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // 根据剪贴板中的实际类型决定检测顺序
        let availableTypes = pasteboard.types ?? []
        let hasImage = availableTypes.contains(where: {
            $0 == .tiff || $0 == .png
        })

        if hasImage {
            // 有图片类型 → 优先存为图片
            if let image = NSImage(pasteboard: pasteboard) {
                let fileName = "\(UUID().uuidString).png"
                if saveImage(image, fileName: fileName) {
                    addItem(ClipboardItem(imageFileName: fileName))
                    return
                }
            }
        }

        // 没有图片或图片解析失败 → 检查文本
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            addItem(ClipboardItem(text: text))
        }
    }

    // MARK: - 持久化（文本/元数据 → UserDefaults）

    private func saveItems() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            return
        }
        // 过滤掉图片文件已被删除的条目（悬空引用）
        items = decoded.filter { item in
            guard item.type == .image, let fileName = item.imageFileName else { return true }
            let fileURL = Self.imagesDirectory.appendingPathComponent(fileName)
            return FileManager.default.fileExists(atPath: fileURL.path)
        }
    }

    // MARK: - 图片文件管理

    /// 图片文件存储目录
    public static var imagesDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ClipBoard/Images")
    }

    private func ensureImagesDirectory() {
        try? FileManager.default.createDirectory(at: Self.imagesDirectory, withIntermediateDirectories: true)
    }

    private func saveImage(_ image: NSImage, fileName: String) -> Bool {
        ensureImagesDirectory()

        // 如果图片尺寸超过屏幕分辨率，等比缩放
        var imageToSave = image
        let imageSize = image.size
        if let screenSize = NSScreen.main?.frame.size,
           (imageSize.width > screenSize.width || imageSize.height > screenSize.height) {
            let scale = min(screenSize.width / imageSize.width, screenSize.height / imageSize.height)
            let newSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let resized = NSImage(size: newSize)
            resized.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: newSize),
                       from: NSRect(origin: .zero, size: imageSize),
                       operation: .copy, fraction: 1.0)
            resized.unlockFocus()
            imageToSave = resized
        }

        guard let tiffData = imageToSave.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return false
        }
        let fileURL = Self.imagesDirectory.appendingPathComponent(fileName)
        do {
            try pngData.write(to: fileURL)
            return true
        } catch {
            return false
        }
    }

    private func loadImage(fileName: String) -> NSImage? {
        let fileURL = Self.imagesDirectory.appendingPathComponent(fileName)
        return NSImage(contentsOf: fileURL)
    }

    private func removeImageFile(for item: ClipboardItem) {
        guard let fileName = item.imageFileName else { return }
        let fileURL = Self.imagesDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
}
