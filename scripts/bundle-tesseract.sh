#!/bin/zsh
set -euo pipefail

if [[ $# -ne 1 ]]; then
    print -u2 -- "usage: $0 <OCR resources directory>"
    exit 64
fi

ocr_dir="$1"
bin_dir="$ocr_dir/bin"
lib_dir="$ocr_dir/lib"
tessdata_dir="$ocr_dir/tessdata"
license_dir="$ocr_dir/licenses"

if [[ -e "$ocr_dir" ]]; then
    print -u2 -- "OCR destination already exists: $ocr_dir"
    exit 73
fi

if ! command -v brew >/dev/null 2>&1; then
    print -u2 -- "Homebrew is required to assemble the bundled Tesseract runtime."
    exit 69
fi

tesseract_prefix="${TESSERACT_PREFIX:-$(brew --prefix tesseract 2>/dev/null || true)}"
brew_prefix="$(brew --prefix)"
tesseract_source="$tesseract_prefix/bin/tesseract"
traineddata_source="$tesseract_prefix/share/tessdata/eng.traineddata"

if [[ ! -x "$tesseract_source" || ! -f "$traineddata_source" ]]; then
    print -u2 -- "Tesseract with English data was not found. Run: brew install tesseract"
    exit 69
fi

mkdir -p "$bin_dir" "$lib_dir" "$tessdata_dir" "$license_dir"
cp -L "$tesseract_source" "$bin_dir/tesseract"
cp -L "$traineddata_source" "$tessdata_dir/eng.traineddata"
chmod 755 "$bin_dir/tesseract"
codesign --remove-signature "$bin_dir/tesseract" 2>/dev/null || true

typeset -A library_sources
typeset -a queue
queue=("$tesseract_source")

resolve_dependency() {
    local dependency="$1"
    local loader="$2"
    local basename="${dependency:t}"
    local candidate=""

    if [[ "$dependency" == /* && -f "$dependency" ]]; then
        print -r -- "${dependency:A}"
        return 0
    fi

    case "$dependency" in
        @loader_path/*|@rpath/*)
            candidate="${loader:h}/$basename"
            ;;
        @executable_path/*)
            candidate="${tesseract_source:h}/${dependency#@executable_path/}"
            ;;
    esac

    if [[ -n "$candidate" && -f "$candidate" ]]; then
        print -r -- "${candidate:A}"
        return 0
    fi

    for candidate in \
        "$tesseract_prefix/lib/$basename" \
        "$brew_prefix/lib/$basename"
    do
        if [[ -f "$candidate" ]]; then
            print -r -- "${candidate:A}"
            return 0
        fi
    done

    print -u2 -- "Could not resolve OCR dependency $dependency from $loader"
    return 1
}

while (( ${#queue[@]} > 0 )); do
    current="${queue[1]}"
    queue=("${queue[@]:1}")

    dependencies=("${(@f)$(otool -L "$current" | tail -n +2 | awk '{print $1}')}")
    for dependency in "${dependencies[@]}"; do
        case "$dependency" in
            /System/Library/*|/usr/lib/*)
                continue
                ;;
        esac

        basename="${dependency:t}"
        if [[ -n "${library_sources[$basename]-}" ]]; then
            continue
        fi

        resolved="$(resolve_dependency "$dependency" "$current")"
        library_sources[$basename]="$resolved"
        queue+=("$resolved")
    done
done

for basename source in ${(kv)library_sources}; do
    cp -L "$source" "$lib_dir/$basename"
    chmod 644 "$lib_dir/$basename"
    codesign --remove-signature "$lib_dir/$basename" 2>/dev/null || true
done

rewrite_dependencies() {
    local source="$1"
    local destination="$2"
    local prefix="$3"
    local dependency=""
    local basename=""

    dependencies=("${(@f)$(otool -L "$source" | tail -n +2 | awk '{print $1}')}")
    for dependency in "${dependencies[@]}"; do
        case "$dependency" in
            /System/Library/*|/usr/lib/*)
                continue
                ;;
        esac
        basename="${dependency:t}"
        install_name_tool -change "$dependency" "$prefix/$basename" "$destination"
    done
}

rewrite_dependencies "$tesseract_source" "$bin_dir/tesseract" "@executable_path/../lib"

for basename source in ${(kv)library_sources}; do
    destination="$lib_dir/$basename"
    install_name_tool -id "@loader_path/$basename" "$destination"
    rewrite_dependencies "$source" "$destination" "@loader_path"
done

formulae=(
    tesseract leptonica libarchive libpng jpeg-turbo giflib libtiff
    webp openjpeg xz zstd lz4 libb2
)

for formula in "${formulae[@]}"; do
    formula_prefix="$(brew --prefix "$formula" 2>/dev/null || true)"
    [[ -n "$formula_prefix" ]] || continue

    for notice in "$formula_prefix"/(LICENSE*|COPYING*|COPYRIGHT*)(N); do
        cp -L "$notice" "$license_dir/$formula--${notice:t}"
    done
    if [[ "$formula" == "leptonica" && -f "$formula_prefix/README.md" ]]; then
        cp -L "$formula_prefix/README.md" "$license_dir/leptonica--README.md"
    fi
    if [[ -f "$formula_prefix/sbom.spdx.json" ]]; then
        cp -L "$formula_prefix/sbom.spdx.json" "$license_dir/$formula--sbom.spdx.json"
    fi
done

{
    print -- "Bundled OCR runtime"
    print -- "Built from Homebrew bottles for this app's architecture."
    print -- ""
    for formula in "${formulae[@]}"; do
        brew list --versions "$formula" 2>/dev/null || true
    done
} > "$ocr_dir/VERSIONS.txt"

print -r -- "$ocr_dir"
