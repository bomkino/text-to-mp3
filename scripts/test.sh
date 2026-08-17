#!/bin/zsh
set -euo pipefail

if [[ "$(xcode-select -p)" == "/Library/Developer/CommandLineTools" ]]; then
    testing_frameworks="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
    testing_libraries="/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
    testing_macros="/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"

    if [[ -f "$testing_frameworks/Testing.framework/Versions/A/Testing" && -f "$testing_macros" ]]; then
        DYLD_FRAMEWORK_PATH="$testing_frameworks" \
        DYLD_LIBRARY_PATH="$testing_libraries" \
        swift test \
            -Xswiftc -load-plugin-library \
            -Xswiftc "$testing_macros"
        exit
    fi
fi

swift test
