#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
app_dir="$project_dir/dist/Text to MP3.app"
zip_path="$project_dir/dist/Text to MP3.zip"
contents_dir="$app_dir/Contents"
binary_dir="$contents_dir/MacOS"
resources_dir="$contents_dir/Resources"
icon_png="$project_dir/.build/AppIcon-1024.png"
iconset_dir="$project_dir/.build/AppIcon.iconset"

cd "$project_dir"
swift build -c release -Xswiftc -disable-batch-mode
binary_path="$(swift build -c release -Xswiftc -disable-batch-mode --show-bin-path)/TextToMP3"

if [[ -d "$app_dir" ]]; then
    rm -rf "$app_dir"
fi

mkdir -p "$binary_dir" "$resources_dir"
cp "$binary_path" "$binary_dir/TextToMP3"
cp "$project_dir/Packaging/Info.plist" "$contents_dir/Info.plist"
cp "$project_dir/Sources/TextToMP3App/Resources/edge_helper.py" "$resources_dir/edge_helper.py"
cp "$project_dir/THIRD_PARTY_NOTICES.md" "$resources_dir/THIRD_PARTY_NOTICES.md"
"$project_dir/scripts/bundle-tesseract.sh" "$resources_dir/OCR"

swift "$project_dir/scripts/make-icon.swift" "$icon_png"
if [[ -d "$iconset_dir" ]]; then
    rm -rf "$iconset_dir"
fi
mkdir -p "$iconset_dir"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$icon_png" --out "$iconset_dir/icon_${size}x${size}.png" >/dev/null
    doubled=$((size * 2))
    sips -z "$doubled" "$doubled" "$icon_png" --out "$iconset_dir/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset_dir" -o "$resources_dir/AppIcon.icns"

chmod 755 "$binary_dir/TextToMP3"
plutil -lint "$contents_dir/Info.plist"

while IFS= read -r nested_code; do
    if file "$nested_code" | grep -q "Mach-O"; then
        codesign --force --sign - --options runtime "$nested_code"
    fi
done < <(find "$resources_dir/OCR" -type f -print)

codesign --force --sign - --options runtime "$app_dir"
codesign --verify --strict --verbose=2 "$app_dir"

if [[ -f "$zip_path" ]]; then
    rm -f "$zip_path"
fi
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$zip_path"

print -r -- "$app_dir"
print -r -- "$zip_path"
