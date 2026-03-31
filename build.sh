#!/bin/sh
# Builds the Pinger menu bar app for macOS 26 (requires CLT 26.4+)
swiftc \
  -strict-concurrency=minimal \
  Sources/Pinger/*.swift \
  -framework AppKit \
  -o Pinger
