import SwiftUI
import AppKit
import ClipBoardCore
import Carbon

// MARK: - 快捷键设置主视图

struct ShortcutSettingsView: View {
    let store: KeyBindingStore
    let onChanged: (KeyBinding) -> Void

    @State private var bindings: [KeyBinding]
    @State private var recordingId: String?

    init(store: KeyBindingStore, onChanged: @escaping (KeyBinding) -> Void) {
        self.store = store
        self.onChanged = onChanged
        self._bindings = State(initialValue: Array(store.config.bindings.values).sorted { $0.id < $1.id })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "keyboard")
                    .foregroundColor(.secondary)
                Text("快捷键设置")
                    .font(.headline)
                Spacer()
                Button("恢复默认") {
                    store.resetToDefaults()
                    bindings = Array(store.config.bindings.values).sorted { $0.id < $1.id }
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            List {
                ForEach($bindings) { $binding in
                    ShortcutRow(
                        binding: binding,
                        isRecording: recordingId == binding.id
                    ) {
                        // 开始录制
                        recordingId = binding.id
                    } onCapture: { newKeyCode, newModifiers in
                        // 录制完成
                        binding.keyCode = newKeyCode
                        binding.carbonModifiers = newModifiers
                        recordingId = nil
                        store.updateBinding(binding)
                        onChanged(binding)
                    }
                }
            }
            .listStyle(.plain)

            Divider()

            HStack {
                Text("点击快捷键开始录制，按下新的组合键完成修改")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(bindings.count) 个快捷键")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 400, height: 400)
        .onDisappear {
            recordingId = nil
        }
    }
}

// MARK: - 单行

struct ShortcutRow: View {
    let binding: KeyBinding
    let isRecording: Bool
    let onStartRecording: () -> Void
    let onCapture: (Int, Int) -> Void

    @State private var monitor: Any?

    var body: some View {
        HStack {
            // 操作名称
            Text(binding.label)
                .font(.system(size: 13))

            Spacer()

            // 快捷键按钮
            Button(action: {
                guard !isRecording else { return }
                onStartRecording()
                installMonitor()
            }) {
                HStack(spacing: 4) {
                    if isRecording {
                        Text("按下新快捷键...")
                            .foregroundColor(.orange)
                            .font(.system(size: 12, design: .monospaced))
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    } else {
                        Text(binding.displayString)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isRecording ? Color.orange.opacity(0.12) : Color.secondary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isRecording ? Color.orange : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .onDisappear {
            removeMonitor()
        }
    }

    private func installMonitor() {
        removeMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // 只录制至少带一个修饰键的组合（排除纯字母）
            let hasModifier = mods.contains(.command) || mods.contains(.shift)
                              || mods.contains(.option) || mods.contains(.control)
            guard hasModifier else { return nil }

            // 转换 NSEvent modifierFlags → Carbon modifier flags
            var carbonMods: Int = 0
            if mods.contains(.command)  { carbonMods |= cmdKey }
            if mods.contains(.shift)    { carbonMods |= shiftKey }
            if mods.contains(.option)   { carbonMods |= optionKey }
            if mods.contains(.control)  { carbonMods |= controlKey }

            let keyCode = Int(event.keyCode)

            DispatchQueue.main.async {
                self.onCapture(keyCode, carbonMods)
                self.removeMonitor()
            }

            return nil // 消费事件
        }
    }

    private func removeMonitor() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
}
