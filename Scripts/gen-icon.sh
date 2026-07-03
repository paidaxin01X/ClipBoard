#!/bin/bash
# 生成简单的剪贴板应用图标（使用 Python 生成 PNG）

cd "$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p Resources/AppIcon.iconset

# 使用 Python 高效生成图标 PNG
python3 -c "
import struct, zlib, os, subprocess, tempfile

def create_png(width, height, color):
    \"\"\"Create a minimal valid PNG with given color (R,G,B) — efficient.\"\"\"
    def chunk(chunk_type, data):
        c = chunk_type + data
        crc = struct.pack('>I', zlib.crc32(c) & 0xffffffff)
        return struct.pack('>I', len(data)) + c + crc
    
    header = b'\x89PNG\r\n\x1a\n'
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    
    # Build raw data efficiently
    row = b'\x00' + bytes(color) * width  # filter byte + pixels
    raw = row * height
    
    compressed = zlib.compress(raw)
    return header + chunk(b'IHDR', ihdr_data) + chunk(b'IDAT', compressed) + chunk(b'IEND', b'')

# 创建基础 1024x1024 图标（蓝灰色 85, 140, 200）
iconset = 'Resources/AppIcon.iconset'
base = create_png(1024, 1024, (85, 140, 200))
with open(f'{iconset}/icon_1024x1024.png', 'wb') as f:
    f.write(base)

# 用 sips 缩放生成所有尺寸
# icon_16x16.png, icon_32x32.png, icon_128x128.png, icon_256x256.png, icon_512x512.png
# icon_32x32@2x.png (64), icon_256x256@2x.png (512)
sizes_src = [16, 32, 128, 256, 512]
for s in sizes_src:
    subprocess.run(['sips', '-z', str(s), str(s),
                    f'{iconset}/icon_1024x1024.png',
                    '--out', f'{iconset}/icon_{s}x{s}.png'],
                   capture_output=True, check=True)

# @2x variants: 16@2x=32, 32@2x=64, 128@2x=256, 256@2x=512
# We already have 32.png -> that's 16@2x too, but let's be explicit
# Actually sips can resize to any size, let's generate the @2x ones too
for s, actual in [(16, 32), (32, 64), (128, 256), (256, 512)]:
    subprocess.run(['sips', '-z', str(actual), str(actual),
                    f'{iconset}/icon_1024x1024.png',
                    '--out', f'{iconset}/icon_{s}x{s}@2x.png'],
                   capture_output=True, check=True)

print('Icon set created')
"

# 转换为 .icns
iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
rm -rf Resources/AppIcon.iconset
echo "✅ AppIcon.icns created"
