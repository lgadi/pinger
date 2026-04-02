#!/usr/bin/swift
// Generates Resources/Pinger.icns
// Run: swift make_icon.swift

import AppKit
import CoreGraphics

func renderIcon(size: Int) -> Data? {
    let s = CGFloat(size)
    guard
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
        let ctx = CGContext(
            data: nil, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    else { return nil }

    // CG origin is bottom-left; flip so (0,0) is top-left
    ctx.translateBy(x: 0, y: s)
    ctx.scaleBy(x: 1, y: -1)

    // --- Background: squircle + blue gradient ---
    let radius = s * 0.2237          // macOS Big Sur squircle approximation
    let bgPath = CGPath(
        roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
        cornerWidth: radius, cornerHeight: radius, transform: nil
    )
    ctx.addPath(bgPath)
    ctx.clip()

    let c = { (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) -> CGColor in
        CGColor(colorSpace: colorSpace, components: [r, g, b, a])!
    }
    let topColor    = c(0.11, 0.42, 0.98, 1)   // #1C6BFA  bright blue
    let bottomColor = c(0.03, 0.18, 0.58, 1)   // #082E94  deep navy
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [topColor, bottomColor] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: s * 0.30, y: 0),
        end:   CGPoint(x: s * 0.70, y: s),
        options: []
    )

    // --- Concentric rings (sonar / ping waves) ---
    let center = CGPoint(x: s / 2, y: s / 2)
    // three rings: outermost faintest, innermost brightest
    let rings: [(relRadius: CGFloat, alpha: CGFloat)] = [
        (0.41, 0.20),
        (0.28, 0.45),
        (0.16, 0.75),
    ]
    for ring in rings {
        ctx.setStrokeColor(c(1, 1, 1, ring.alpha))
        ctx.setLineWidth(max(1, s * 0.026))
        ctx.addArc(center: center, radius: s * ring.relRadius,
                   startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.strokePath()
    }

    // --- Centre dot ---
    ctx.setFillColor(c(1, 1, 1, 1))
    let dotR = s * 0.072
    ctx.addArc(center: center, radius: dotR,
               startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.fillPath()

    guard let cgImage = ctx.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
}

// iconutil expects these exact filenames
let entries: [(size: Int, name: String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

let fm = FileManager.default
let iconsetURL = URL(fileURLWithPath: "Resources/Pinger.iconset")
try? fm.removeItem(at: iconsetURL)
try! fm.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

var rendered: [Int: Data] = [:]
for entry in entries {
    let data = rendered[entry.size] ?? renderIcon(size: entry.size)!
    rendered[entry.size] = data
    let dest = iconsetURL.appendingPathComponent(entry.name)
    try! data.write(to: dest)
    print("  wrote \(entry.name) (\(entry.size)px)")
}

// Convert iconset → icns
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetURL.path, "-o", "Resources/Pinger.icns"]
try! task.run()
task.waitUntilExit()

try? fm.removeItem(at: iconsetURL)

if task.terminationStatus == 0 {
    print("Created Resources/Pinger.icns")
} else {
    fputs("iconutil failed\n", stderr)
    exit(1)
}
