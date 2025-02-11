#!/bin/env bash
weight=Medium

mkdir -vp fonts

# fetch from the newest github resources
for v in SimplifiedChinese,sc TraditionalChinese,tc TraditionalChineseHK,hk Jananese,jp Korean,kr; do
    curl -o "fonts/NotoSansCJK${v#*,}-${weight}.otf" \
        "https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/OTF/${v%,*}/NotoSansCJK${v#*,}-${weight}.otf"
done

# move jp variant as the default
mv "fonts/NotoSansCJKjp-${weight}.otf" "fonts/NotoSansCJK-${weight}.otf"

