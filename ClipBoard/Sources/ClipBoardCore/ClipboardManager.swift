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
        case .richText, .fileURL, .color, .link, .code, .contact:
            if let content = item.content {
                pasteboard.setString(content, forType: .string)
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

        let availableTypes = pasteboard.types ?? []

        // 1. 文件 URL 检测 (最高优先级 — 从 Finder 复制文件时也附带图片缩略图)
        if availableTypes.contains(.fileContents) || availableTypes.contains(NSPasteboard.PasteboardType("NSFilenamesPboardType")) {
            if let urlStr = pasteboard.string(forType: .fileURL) {
                let url = URL(string: urlStr)
                let path = url?.path ?? urlStr
                let filename = url?.lastPathComponent ?? path
                addItem(ClipboardItem(type: .fileURL, content: path, metadata: ["path": path, "filename": filename]))
                return
            }
        }

        // 2. 图片检测
        let hasImage = availableTypes.contains(where: { $0 == .tiff || $0 == .png })
        if hasImage {
            if let image = NSImage(pasteboard: pasteboard) {
                let fileName = "\(UUID().uuidString).png"
                if saveImage(image, fileName: fileName) {
                    addItem(ClipboardItem(imageFileName: fileName))
                    return
                }
            }
        }

        // 2. 颜色检测 (P0)
        if availableTypes.contains(.color) {
            if let color = NSColor(from: pasteboard) {
                var hex = "#"
                if let srgb = color.usingColorSpace(.sRGB) {
                    let r = Int(srgb.redComponent * 255)
                    let g = Int(srgb.greenComponent * 255)
                    let b = Int(srgb.blueComponent * 255)
                    hex += String(format: "%02X%02X%02X", r, g, b)
                }
                let metadata = ["hex": hex]
                addItem(ClipboardItem(type: .color, content: hex, metadata: metadata))
                return
            }
        }

        // 4. 富文本检测 (P0)
        if availableTypes.contains(.rtf) {
            if let rtfData = pasteboard.data(forType: .rtf) {
                if let plainText = NSAttributedString(rtf: rtfData, documentAttributes: nil)?.string {
                    addItem(ClipboardItem(type: .richText, content: plainText))
                    return
                }
            }
        }

        // 5. 纯文本检测 (已有逻辑 + P1 扩展)
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            // P1: URL 检测
            if let url = detectURL(in: text) {
                addItem(ClipboardItem(type: .link, content: text, metadata: ["url": url]))
                return
            }
            // P1: 代码检测
            if let language = detectCodeLanguage(in: text) {
                let firstLine = text.components(separatedBy: "\n").first ?? text
                addItem(ClipboardItem(type: .code, content: text, metadata: ["language": language, "firstLine": firstLine]))
                return
            }
            // 默认纯文本
            addItem(ClipboardItem(text: text))
            return
        }

        // 6. 联系人检测 (P2)
        if #available(macOS 14.0, *) {
            if availableTypes.contains(.vCard) {
                if let vCardData = pasteboard.data(forType: .vCard) {
                    // 简化为检测到 vCard 类型就存储
                    addItem(ClipboardItem(type: .contact, content: "联系人", metadata: nil))
                    return
                }
            }
        }
    }

    // MARK: - 文本智能检测 (P1)

    /// 检测文本是否为 URL
    private func detectURL(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let matches = detector.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))
        return matches.first?.url?.absoluteString
    }

    /// 检测文本是否为代码片段，返回语言名称 (nil 表示不是代码)
    private func detectCodeLanguage(in text: String) -> String? {
        let lines = text.components(separatedBy: "\n")
        guard lines.count > 1 else { return nil }  // 至少 2 行才可能是代码

        let totalLength = text.count
        guard totalLength > 40 else { return nil } // 太短不判断

        let joined = text

        // 语言特征关键词
        let languagePatterns: [(String, [String])] = [
            ("swift", ["import ", "func ", "var ", "let ", "class ", "struct ", "enum ", "protocol ", "extension "]),
            ("python", ["import ", "from ", "def ", "class ", "print(", "if __name__", "self."]),
            ("javascript", ["function ", "const ", "let ", "var ", "=>", "import ", "export ", "console."]),
            ("typescript", [": string", ": number", ": void", "interface ", "type ", "as const"]),
            ("java", ["public class", "private ", "protected ", "import java.", "@Override"]),
            ("go", ["package ", "func ", "import (", "defer ", "go "]),
            ("rust", ["fn ", "let mut", "impl ", "pub ", "use std::"]),
            ("cpp", ["#include", "using namespace", "int main", "std::", "->"]),
            ("shell", ["#!/bin", "export ", "echo ", "$HOME", "chmod "]),
            ("html", ["<!DOCTYPE", "<html", "<div", "<script", "<style"]),
            ("css", ["{", ":", ";", "}"]), // 仅当有较多大括号和分号
        ]

        for (lang, patterns) in languagePatterns {
            let matchCount = patterns.filter { joined.contains($0) }.count
            if matchCount >= 2 {
                return lang
            }
        }

        return nil
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
