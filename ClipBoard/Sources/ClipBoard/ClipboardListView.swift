import SwiftUI
import AppKit
import ClipBoardCore

struct ClipboardListView: View {
    @EnvironmentObject var manager: ClipboardManager
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            if manager.items.isEmpty {
                emptyView
            } else {
                listView
            }

            Divider()

            footerView
        }
        .frame(width: 320)
    }

    // MARK: - 子视图

    private var headerView: some View {
        HStack {
            Label("剪贴板", systemImage: "clipboard")
                .font(.headline)
            Spacer()
            if !manager.items.isEmpty {
                Button("清空") {
                    showClearConfirmation = true
                }
                .font(.system(size: 12))
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .alert("确认清空", isPresented: $showClearConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                manager.clearAll()
            }
        } message: {
            Text("将删除全部 \(manager.items.count) 条剪贴板记录，此操作不可撤销。")
        }
    }

    private var listView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(manager.items.enumerated()), id: \.element.id) { index, item in
                        ClipboardItemRow(
                            item: item,
                            onTap: {
                                manager.writeToPasteboard(item)
                                NSApp.hide(nil)
                            },
                            onDelete: {
                                manager.deleteItem(item)
                                if manager.keyboardSelectedIndex >= manager.items.count {
                                    manager.keyboardSelectedIndex = max(0, manager.items.count - 1)
                                }
                            },
                            onPin: item.type == .image ? {
                                guard let fileName = item.imageFileName else { return }
                                let url = ClipboardManager.imagesDirectory.appendingPathComponent(fileName)
                                if let image = NSImage(contentsOf: url) {
                                    AppDelegate.shared?.pinManager.pin(image: image)
                                }
                            } : nil
                        )
                        .id(item.id)
                        .background(manager.keyboardSelectedIndex == index
                            ? Color.accentColor.opacity(0.15)
                            : Color.clear
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(manager.keyboardSelectedIndex == index ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
            .frame(maxHeight: 420)
            .onChange(of: manager.keyboardSelectedIndex) { _, newValue in
                guard newValue >= 0, newValue < manager.items.count else { return }
                let item = manager.items[newValue]
                withAnimation {
                    proxy.scrollTo(item.id)
                }
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clipboard")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            Text("暂无剪贴板记录")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("使用 Cmd+C 复制内容后将自动显示")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var footerView: some View {
        HStack {
            Text("共 \(manager.items.count) 条 · 最多 50 条")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Text("↑↓ 导航 · ↵ 粘贴")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
