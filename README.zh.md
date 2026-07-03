# ClipBoard

一个轻量级的 macOS 剪贴板管理器，支持钉图到屏幕和快捷键自定义。

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-brightgreen">
  <img src="https://img.shields.io/badge/Swift-6.0-orange">
  <img src="https://img.shields.io/badge/License-MIT-blue">
</p>

---

## 功能

- 📋 剪贴板历史（文本+图片，最多 50 条）
- 🖼️ 钉图到屏幕（Snipaste 风格的悬浮窗）
- ⌨️ 全局快捷键（面板切换、粘贴、钉图）
- 🔧 快捷键自定义，支持录制修改
- 🖱️ 滚轮缩放 & 触控板双指捏合缩放
- 🎯 焦点感知（只缩放鼠标所在的钉图）
- ⚡ 开机自启
- 🔒 纯菜单栏，无 Dock 图标

---

## 安装

### 方式一：下载预编译包

从 [Releases](https://github.com/paidaxin01X/ClipBoard/releases) 下载最新版 `ClipBoard.app`。

### 方式二：从源码构建

```bash
git clone https://github.com/paidaxin01X/ClipBoard.git
cd ClipBoard

cd ClipBoard
swift build -c release --product ClipBoard
bash ../Scripts/build-app.sh
open ../ClipBoard.app
```

> **注意**：需要 macOS 14+ 和 Xcode Command Line Tools。

---

## 使用说明

### 菜单栏

- **左键**点击菜单栏图标 → 打开剪贴板面板
- **右键**点击菜单栏图标 → 快捷菜单（开机自启、偏好设置、退出）

### 默认快捷键

| 快捷键 | 作用 |
|--------|------|
| `⌘⇧V` | 切换面板 |
| `⌥1` ~ `⌥9` | 粘贴第 1~9 条 |
| `⌘⇧P` | 钉图 |
| `⌘=` | 放大钉图 |
| `⌘-` | 缩小钉图 |
| `⌘R` | 复原钉图 |
| `↑` `↓` | 导航历史 |
| `⏎` | 粘贴选中 |
| `⎋` | 关闭面板或关闭钉图 |

> 除粘贴 (⌥1~9) 和导航外，所有快捷键均可在**偏好设置**中自定义。

### 钉图功能

1. 复制一张图片到剪贴板
2. 按 `⌘⇧P`（或点击面板中的钉图按钮）—— 图片以悬浮窗形式出现在屏幕上
3. **缩放**：`⌘=` / `⌘-` / 滚轮 / 触控板双指捏合
4. **复原**：`⌘R`
5. **移动**：拖拽窗口
6. **关闭**：按 `⎋`

当钉了多张图片时，缩放操作只作用于鼠标所在的窗口（焦点感知）。

---

## 自定义快捷键

右键菜单栏图标 → **偏好设置...** → 点击要修改的快捷键 → 按下新的组合键。

- 必须包含至少一个修饰键 (⌘/⌥/⇧/⌃)
- 修改立即生效，重启后保留
- 点击"恢复默认"可还原出厂设置

---

## 项目结构

```
ClipBoard/
├── ClipBoard/                  # Swift Package
│   ├── Package.swift
│   └── Sources/
│       ├── ClipBoardCore/      # 核心库
│       │   ├── ClipboardItem.swift      # 数据模型
│       │   ├── ClipboardManager.swift   # 剪贴板监听 + 持久化
│       │   ├── HotkeyManager.swift      # Carbon 全局热键
│       │   └── KeyBinding.swift         # 快捷键模型 + 存储
│       └── ClipBoard/          # 主 App
│           ├── main.swift               # PinApplication (NSApplication 子类)
│           ├── AppDelegate.swift         # 状态栏、面板、菜单
│           ├── PinManager.swift          # 钉图管理 + 焦点跟踪
│           ├── PinWindow.swift           # 钉图窗口 + 内容视图
│           ├── ShortcutSettingsView.swift # 偏好设置界面
│           ├── ClipboardListView.swift   # 历史面板
│           ├── ClipboardItemRow.swift    # 历史条目
│           ├── ClipBoardApp.swift        # SwiftUI 入口
│           └── Info.plist                # LSUIElement = YES
├── Scripts/
│   ├── build-app.sh
│   └── install.sh
├── Resources/
│   └── AppIcon.icns
├── README.md
└── README.zh.md
```

---

## 技术要点

- **LSUIElement = YES**：应用以菜单栏代理模式运行，无 Dock 图标。触控板捏合（magnify）事件无法通过标准响应链接收，需在 `PinApplication.sendEvent` 中拦截。
- **Carbon 热键**：使用 `RegisterEventHotKey` 注册全局热键（签名 `CLIB`）。缩放快捷键从 Carbon 迁移到 `sendEvent` 以提高可靠性。
- **Swift 6 并发**：所有管理器类标注 `@MainActor`，关键模型类型遵守 `Sendable`。
- **NSPasteboard 轮询**：每 500ms 通过 `Timer` + `changeCount` 检查剪贴板变化。
- **无 XCTest**：Command Line Tools 环境缺少 XCTest，使用手动 `assert()` 测试。

---

## 贡献

欢迎提交 Pull Request！重大变更请先开 Issue 讨论。

功能建议和 Bug 报告请随时[提交 Issue](https://github.com/paidaxin01X/ClipBoard/issues)。

---

## 许可证

MIT License。
