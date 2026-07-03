import SwiftUI
import ClipBoardCore

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let onTap: () -> Void
    let onDelete: () -> Void
    let onPin: (() -> Void)?

    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 10) {
            // 左侧：图标或缩略图
            Group {
                switch item.type {
                case .text:
                    Image(systemName: "doc.text")
                        .frame(width: 36, height: 36)
                        .foregroundColor(.secondary)
                case .image:
                    if let thumbnail = thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        Image(systemName: "photo")
                            .frame(width: 36, height: 36)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // 中间：内容预览 + 时间
            VStack(alignment: .leading, spacing: 4) {
                Text(previewText)
                    .lineLimit(1)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)

                Text(timeAgo)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 右侧：操作按钮
            HStack(spacing: 4) {
                // 图片条目显示钉按钮
                if item.type == .image, let onPin = onPin {
                    Button(action: onPin) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("钉到屏幕")
                }

                // 删除按钮
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(0.6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onAppear {
            loadThumbnail()
        }
    }

    // MARK: - 辅助

    private var previewText: String {
        switch item.type {
        case .text:
            return item.content ?? ""
        case .image:
            return "图片"
        }
    }

    private var timeAgo: String {
        let interval = Date().timeIntervalSince(item.createdAt)
        switch interval {
        case ..<60:
            return "刚刚"
        case ..<3600:
            return "\(Int(interval / 60)) 分钟前"
        case ..<86400:
            return "\(Int(interval / 3600)) 小时前"
        default:
            return "\(Int(interval / 86400)) 天前"
        }
    }

    private func loadThumbnail() {
        guard item.type == .image, let fileName = item.imageFileName else { return }
        let url = ClipboardManager.imagesDirectory.appendingPathComponent(fileName)
        thumbnail = NSImage(contentsOf: url)
    }
}
