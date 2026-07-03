import SwiftUI
import AppKit
import ClipBoardCore

// MARK: - SwiftUI 包装（使用 AppKit 原生渲染）

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let onTap: () -> Void
    let onDelete: () -> Void
    let onPin: (() -> Void)?

    var body: some View {
        RowNSView(
            item: item,
            onTap: onTap,
            onDelete: onDelete,
            onPin: onPin
        )
        .frame(height: 52)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - AppKit 原生实现

struct RowNSView: NSViewRepresentable {
    let item: ClipboardItem
    let onTap: () -> Void
    let onDelete: () -> Void
    let onPin: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap, onDelete: onDelete, onPin: onPin)
    }

    func makeNSView(context: Context) -> NSView {
        let view = InteractiveRowView(frame: .zero)
        view.coordinator = context.coordinator
        view.wantsLayer = true

        // 图标
        if item.type == .image {
            let imgView = NSImageView()
            imgView.frame = NSRect(x: 12, y: 8, width: 36, height: 36)
            imgView.imageScaling = .scaleAxesIndependently
            imgView.wantsLayer = true
            imgView.layer?.cornerRadius = 4
            imgView.layer?.masksToBounds = true
            if let fileName = item.imageFileName {
                let url = ClipboardManager.imagesDirectory.appendingPathComponent(fileName)
                imgView.image = NSImage(contentsOf: url)
            }
            view.addSubview(imgView)
        } else {
            let imgView = NSImageView()
            imgView.frame = NSRect(x: 12, y: 8, width: 36, height: 36)
            imgView.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
            imgView.contentTintColor = .secondaryLabelColor
            view.addSubview(imgView)
        }

        // 文本
        let textField = NSTextField(labelWithString: previewText)
        textField.frame = NSRect(x: 56, y: 22, width: 180, height: 16)
        textField.font = .systemFont(ofSize: 13)
        textField.textColor = .labelColor
        view.addSubview(textField)

        // 时间
        let timeField = NSTextField(labelWithString: timeAgo)
        timeField.frame = NSRect(x: 56, y: 6, width: 180, height: 14)
        timeField.font = .systemFont(ofSize: 11)
        timeField.textColor = .secondaryLabelColor
        view.addSubview(timeField)

        // 删除按钮
        let deleteBtn = NSButton(frame: NSRect(x: 290, y: 14, width: 20, height: 20))
        deleteBtn.bezelStyle = .shadowlessSquare
        deleteBtn.isBordered = false
        deleteBtn.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "删除")
        deleteBtn.contentTintColor = .secondaryLabelColor
        deleteBtn.target = context.coordinator
        deleteBtn.action = #selector(Coordinator.deleteClicked)
        view.addSubview(deleteBtn)

        // 钉按钮（仅图片条目）
        if item.type == .image {
            let pinBtn = NSButton(frame: NSRect(x: 264, y: 14, width: 20, height: 20))
            pinBtn.bezelStyle = .shadowlessSquare
            pinBtn.isBordered = false
            pinBtn.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "钉到屏幕")
            pinBtn.contentTintColor = .controlAccentColor
            pinBtn.target = context.coordinator
            pinBtn.action = #selector(Coordinator.pinClicked)
            view.addSubview(pinBtn)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onDelete = onDelete
        context.coordinator.onPin = onPin
    }

    // MARK: - 辅助

    private var previewText: String {
        switch item.type {
        case .text: return item.content ?? ""
        case .image: return "图片"
        }
    }

    private var timeAgo: String {
        let interval = Date().timeIntervalSince(item.createdAt)
        switch interval {
        case ..<60: return "刚刚"
        case ..<3600: return "\(Int(interval / 60)) 分钟前"
        case ..<86400: return "\(Int(interval / 3600)) 小时前"
        default: return "\(Int(interval / 86400)) 天前"
        }
    }
}

// MARK: - 交互处理

extension RowNSView {
    final class Coordinator: NSObject {
        var onTap: () -> Void
        var onDelete: () -> Void
        var onPin: (() -> Void)?

        init(onTap: @escaping () -> Void, onDelete: @escaping () -> Void, onPin: (() -> Void)?) {
            self.onTap = onTap
            self.onDelete = onDelete
            self.onPin = onPin
        }

        @objc func deleteClicked() { onDelete() }
        @objc func pinClicked() { onPin?() }
    }
}

// MARK: - 自定义 NSView（捕捉空白区域点击）

final class InteractiveRowView: NSView {
    weak var coordinator: RowNSView.Coordinator?

    override func hitTest(_ point: NSPoint) -> NSView? {
        // 检查点击的是不是 NSButton（删除/钉按钮）
        if let hitView = super.hitTest(point), hitView is NSButton {
            return hitView  // 按钮自己处理
        }
        // NSTextField、NSImageView 等子视图的点击都交由行视图处理
        return self
    }

    override func mouseDown(with event: NSEvent) {
        coordinator?.onTap()
    }
}
