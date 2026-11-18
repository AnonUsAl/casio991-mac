#!/bin/bash
# fx-991CN X 科学计算器 macOS 版一键构建脚本
set -e
MAC="$(cd "$(dirname "$0")" && pwd)"
SRC="/Users/anonusal/Developer/casio991-apk/assets/site"
cd "$MAC"

echo "==> [1/5] 复制站点资源"
rm -rf "$MAC/SwiftApp/Contents/Resources/site"
mkdir -p "$MAC/SwiftApp/Contents/Resources"
cp -R "$SRC" "$MAC/SwiftApp/Contents/Resources/site"

echo "==> [2/5] 生成 icns 图标"
ICONSET="$MAC/AppIcon.iconset"
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
python3 - "$ICONSET" <<'PY'
from PIL import Image, ImageDraw, ImageFont
import os, sys
out=sys.argv[1]
fp="/System/Library/Fonts/Helvetica.ttc"
def make(sz,path):
    img=Image.new("RGBA",(sz,sz),(0,0,0,0)); d=ImageDraw.Draw(img)
    d.rounded_rectangle([0,0,sz-1,sz-1],radius=int(sz*0.22),fill=(255,106,43,255))
    fs=int(sz*0.42); f=ImageFont.truetype(fp,fs)
    try: f=ImageFont.truetype(fp,fs,index=1)
    except: pass
    b=d.textbbox((0,0),"991",font=f); tw,th=b[2]-b[0],b[3]-b[1]
    d.text(((sz-tw)/2-b[0],(sz-th)/2-b[1]-sz*0.01),"991",font=f,fill=(255,255,255,255))
    img.save(path)
sizes={"icon_16x16.png":16,"icon_16x16@2x.png":32,"icon_32x32.png":32,"icon_32x32@2x.png":64,
       "icon_128x128.png":128,"icon_128x128@2x.png":256,"icon_256x256.png":256,"icon_256x256@2x.png":512,
       "icon_512x512.png":512,"icon_512x512@2x.png":1024}
for n,s in sizes.items(): make(s,os.path.join(out,n))
PY
iconutil -c icns "$ICONSET" -o "$MAC/SwiftApp/Contents/Resources/AppIcon.icns"

echo "==> [3/5] swiftc 编译"
swiftc -parse-as-library -O main.swift -o "$MAC/SwiftApp/Contents/MacOS/Casio991" \
  -framework Cocoa -framework WebKit 2>/dev/null

echo "==> [4/5] 组装 .app 并签名"
rm -rf "$MAC/Casio991.app"
cp -R "$MAC/SwiftApp" "$MAC/Casio991.app"
codesign --force --deep --sign - "$MAC/Casio991.app"
xattr -dr com.apple.quarantine "$MAC/Casio991.app" 2>/dev/null || true

echo "==> [5/5] 打包 zip"
rm -f "$MAC/Casio991-mac.zip"
zip -q -r Casio991-mac.zip Casio991.app

echo ""
echo "构建完成: $MAC/Casio991.app  +  $MAC/Casio991-mac.zip"
/bin/ls -lh "$MAC/Casio991-mac.zip"
