#!/usr/bin/env swift

import Foundation
import AppKit

// ========== ClipBoard App Icon Generator ==========
// 使用 Swift + AppKit 程序化绘制剪贴板图标
// 用法: swift gen-icon.swift

let size: CGFloat = 1024
let scale: CGFloat = 1
let imageSize = NSSize(width: size, height: size)

let image = NSImage(size: imageSize)
image.lockFocusFlipped(false)

// ---- 背景 ----
// 透明背景，让系统适配深浅模式

// ---- 剪贴板主体 ----
// 颜色
let bodyColor = NSColor(calibratedRed: 0.33, green: 0.55, blue: 0.82, alpha: 1.0)      // 蓝灰色
let bodyShadow = NSColor(calibratedRed: 0.25, green: 0.42, blue: 0.65, alpha: 1.0)      // 深蓝灰
let clipColor = NSColor(calibratedRed: 0.60, green: 0.60, blue: 0.62, alpha: 1.0)       // 金属灰
let clipShadow = NSColor(calibratedRed: 0.45, green: 0.45, blue: 0.47, alpha: 1.0)      // 深金属灰
let paperColor = NSColor(calibratedRed: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)      // 纸张白
let textColor = NSColor(calibratedRed: 0.20, green: 0.20, blue: 0.22, alpha: 1.0)       // 文字颜色
let accentColor = NSColor(calibratedRed: 0.20, green: 0.60, blue: 0.90, alpha: 1.0)     // 高亮蓝

// ---- 计算尺寸 ----
let inset: CGFloat = size * 0.12
let bodyRect = CGRect(
    x: inset + size * 0.08,
    y: inset,
    width: size - (inset + size * 0.08) * 2,
    height: size - inset * 1.5
)
let cornerRadius = bodyRect.width * 0.12

// ---- 画纸（背景白色层）- 放在剪贴板主体下一层 ----
let paperInset: CGFloat = bodyRect.width * 0.08
let paperRect = CGRect(
    x: bodyRect.minX + paperInset,
    y: bodyRect.minY + bodyRect.height * 0.15,
    width: bodyRect.width - paperInset * 2,
    height: bodyRect.height * 0.70
)
let paperPath = NSBezierPath(roundedRect: paperRect, xRadius: paperRect.width * 0.04, yRadius: paperRect.width * 0.04)
paperColor.setFill()
paperPath.fill()

// ---- 画纸上的文字线条 ----
let lineSpacing = paperRect.height * 0.16
let lineY = paperRect.minY + paperRect.height * 0.22
let lineInset = paperRect.width * 0.12
textColor.withAlphaComponent(0.3).setStroke()

for i in 0..<4 {
    let line = NSBezierPath()
    let y = lineY + CGFloat(i) * lineSpacing
    var lineWidth = paperRect.width - lineInset * 2
    if i == 1 {
        lineWidth = lineWidth * 0.85 // 第二行短一点
    } else if i == 2 {
        lineWidth = lineWidth * 0.65 // 第三行更短
    }
    let lineRect = CGRect(x: paperRect.minX + lineInset, y: y, width: lineWidth, height: 1)
    line.appendRoundedRect(lineRect, xRadius: 0.5, yRadius: 0.5)
    line.lineWidth = paperRect.width * 0.012
    line.stroke()
}

// ---- 高亮标注线（蓝色标记） ----
let highlightY = lineY + lineSpacing * 2
let highlightX = paperRect.minX + lineInset
let highlightWidth = paperRect.width * 0.45
let highlightRect = CGRect(x: highlightX, y: highlightY, width: highlightWidth, height: paperRect.width * 0.014)
let highlightPath = NSBezierPath(roundedRect: highlightRect, xRadius: highlightRect.height * 0.5, yRadius: highlightRect.height * 0.5)
accentColor.setFill()
highlightPath.fill()

// ---- 剪贴板主体 ----
// 阴影
let shadowPath = NSBezierPath(roundedRect: bodyRect.offsetBy(dx: 0, dy: size * 0.008),
                              xRadius: cornerRadius, yRadius: cornerRadius)
NSColor.black.withAlphaComponent(0.15).setFill()
shadowPath.fill()

// 主体渐变
let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: cornerRadius, yRadius: cornerRadius)
if let gradient = NSGradient(starting: bodyColor, ending: bodyShadow) {
    gradient.draw(in: bodyPath, angle: 90)
}

// 高光（顶部反光）
let highlightHeight = bodyRect.height * 0.35
let highlightBodyRect = CGRect(
    x: bodyRect.minX + bodyRect.width * 0.05,
    y: bodyRect.maxY - highlightHeight,
    width: bodyRect.width * 0.9,
    height: highlightHeight
)
let highlightBodyPath = NSBezierPath(roundedRect: highlightBodyRect,
                                     xRadius: cornerRadius * 0.5,
                                     yRadius: cornerRadius * 0.5)
NSColor.white.withAlphaComponent(0.10).setFill()
highlightBodyPath.fill()

// ---- 剪贴板夹子（顶部的金属夹） ----
let clipWidth = bodyRect.width * 0.35
let clipHeight = bodyRect.height * 0.10
let clipRect = CGRect(
    x: bodyRect.midX - clipWidth / 2,
    y: bodyRect.maxY - clipHeight * 0.4,
    width: clipWidth,
    height: clipHeight
)

// 夹子阴影
let clipShadowRect = clipRect.offsetBy(dx: 0, dy: size * 0.005)
let clipShadowPath = NSBezierPath(roundedRect: clipShadowRect,
                                  xRadius: clipHeight * 0.35, yRadius: clipHeight * 0.35)
NSColor.black.withAlphaComponent(0.12).setFill()
clipShadowPath.fill()

// 夹子主体
let clipPath = NSBezierPath(roundedRect: clipRect,
                            xRadius: clipHeight * 0.35, yRadius: clipHeight * 0.35)
clipShadow.setFill()
clipPath.fill()

// 夹子高光
let clipHighlightRect = CGRect(
    x: clipRect.minX + clipRect.width * 0.1,
    y: clipRect.minY + clipRect.height * 0.15,
    width: clipRect.width * 0.8,
    height: clipRect.height * 0.35
)
let clipHighlightPath = NSBezierPath(roundedRect: clipHighlightRect,
                                     xRadius: clipHighlightRect.height * 0.3,
                                     yRadius: clipHighlightRect.height * 0.3)
NSColor.white.withAlphaComponent(0.25).setFill()
clipHighlightPath.fill()

// ---- 关闭 ----
image.unlockFocus()

// ---- 保存为 PNG ----
let outputPath = "/tmp/AppIcon_1024.png"
guard let tiffData = image.tiffRepresentation,
      let bitmapRep = NSBitmapImageRep(data: tiffData),
      let pngData = bitmapRep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
    print("❌ 无法生成 PNG 数据")
    exit(1)
}

try? FileManager.default.removeItem(atPath: outputPath)
try pngData.write(to: URL(fileURLWithPath: outputPath))
print("✅ 1024x1024 PNG 生成成功: \(outputPath)")

// ---- 缩放到 iconset 所有尺寸 ----
let iconsetDir = "/tmp/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconsetDir)
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(size: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2),
    (128, 1), (128, 2), (256, 1), (256, 2),
    (512, 1), (512, 2)
]

for (s, scale) in sizes {
    let fileName = "icon_\(s)x\(s)" + (scale > 1 ? "@\(scale)x" : "") + ".png"
    let filePath = "\(iconsetDir)/\(fileName)"
    let task = Process()
    task.launchPath = "/usr/bin/sips"
    task.arguments = ["-z", "\(s * scale)", "\(s * scale)", outputPath, "--out", filePath]
    task.launch()
    task.waitUntilExit()
}

// ---- 转换为 .icns ----
let icnsPath = "/tmp/AppIcon.icns"
try? FileManager.default.removeItem(atPath: icnsPath)
let iconutil = Process()
iconutil.launchPath = "/usr/bin/iconutil"
iconutil.arguments = ["-c", "icns", iconsetDir, "-o", icnsPath]
iconutil.launch()
iconutil.waitUntilExit()

// 复制到项目
let projectDir = FileManager.default.currentDirectoryPath
let destPath = "\(projectDir)/Resources/AppIcon.icns"
try? FileManager.default.removeItem(atPath: destPath)
try FileManager.default.copyItem(atPath: icnsPath, toPath: destPath)

print("✅ 图标已更新: \(destPath)")
print("")

// 清理临时文件
try? FileManager.default.removeItem(atPath: outputPath)
try? FileManager.default.removeItem(atPath: iconsetDir)
try? FileManager.default.removeItem(atPath: icnsPath)
