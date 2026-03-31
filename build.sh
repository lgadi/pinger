#!/bin/sh
# Workaround: shadow CLT's module.modulemap to fix SwiftBridging redefinition
# on macOS 26 beta (CLT bug — both module.modulemap and bridging.modulemap
# define SwiftBridging identically).
swiftc \
  -Xcc -I./compat \
  -strict-concurrency=minimal \
  Sources/Pinger/*.swift \
  -framework AppKit \
  -o Pinger
