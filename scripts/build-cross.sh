#!/bin/sh
# Cross-build SwiftHaiku, the Counter and Gallery examples and the SwiftHaikuChecks program for
# RenkuOS arm64 on this Mac, with RenkuOS-Swift's scripts/swiftc-haiku.sh and Xcode's clang++, into
# .build/haiku-arm64/app (with the Swift runtime libraries in app/lib, where the programs look).
# Usage: build-cross.sh. Needs RenkuOS-Swift (RENKUOS_SWIFT, default ../RenkuOS-Swift) with its
# SDK built (scripts/build-stdlib-haiku.sh).
#
# Native build on RenkuOS (no SwiftPM there), from the package root:
#   c++ -std=c++17 -fPIC -I Sources/CHaikuBridge/include -c Sources/CHaikuBridge/Bridge.cpp -o Bridge.o
#   swiftc -cxx-interoperability-mode=default -swift-version 6 -parse-as-library -enable-testing \
#     -module-name SwiftHaiku -I Sources/CHaikuBridge/include -wmo -emit-module -c \
#     Sources/SwiftHaiku/*.swift -o SwiftHaiku.o
#   swiftc -cxx-interoperability-mode=default -swift-version 6 -parse-as-library -I . \
#     -I Sources/CHaikuBridge/include Sources/Counter/Counter.swift SwiftHaiku.o Bridge.o -lbe -o Counter
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
rs=$(cd "${RENKUOS_SWIFT:-$here/../RenkuOS-Swift}" && pwd)
. "$rs/scripts/haiku-arm64-flags.sh"
sdk=$rs/build/haiku-arm64$haiku_variant-sdk/usr
out=$here/.build/haiku-arm64
inc=$here/Sources/CHaikuBridge/include
swiftc() { "$rs/scripts/swiftc-haiku.sh" -cxx-interoperability-mode=default -swift-version 6 -I "$inc" "$@"; }

rm -rf "$out"
mkdir -p "$out/app/lib"
echo "+ xcrun clang++ ... Bridge.cpp" >&2
xcrun clang++ --target=aarch64-unknown-haiku --sysroot="$rs/sysroot/haiku-arm64" "$haiku_tls" \
	-std=c++17 -O1 -fPIC -I"$inc" -I"$sdk/include" \
	-c "$here/Sources/CHaikuBridge/Bridge.cpp" -o "$out/Bridge.o"
swiftc -parse-as-library -enable-testing -module-name SwiftHaiku -wmo -emit-module \
	-emit-module-path "$out/SwiftHaiku.swiftmodule" -c "$here"/Sources/SwiftHaiku/*.swift \
	-o "$out/SwiftHaiku.o"
swiftc -parse-as-library -I "$out" "$here/Sources/Counter/Counter.swift" \
	"$out/SwiftHaiku.o" "$out/Bridge.o" -lbe -o "$out/app/Counter"
swiftc -parse-as-library -I "$out" "$here/Sources/Gallery/Gallery.swift" \
	"$out/SwiftHaiku.o" "$out/Bridge.o" -lbe -o "$out/app/Gallery"
swiftc -I "$out" "$here/Tests/SwiftHaikuChecks/main.swift" \
	"$out/SwiftHaiku.o" "$out/Bridge.o" -lbe -o "$out/app/SwiftHaikuChecks"
cp "$sdk"/lib/swift/haiku/*.so "$out/app/lib/"
