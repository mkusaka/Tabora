#!/usr/bin/swift
import AppKit

// MARK: - Configuration

let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "."

// macOS app icon sizes: (point size, scale)
let iconSizes: [(Int, Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]

// MARK: - Drawing

func drawIcon(in context: CGContext, size: CGFloat) {
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)

    // --- Background: macOS Big Sur super-ellipse approximation ---
    let inset = size * 0.02
    let bgRect = bounds.insetBy(dx: inset, dy: inset)
    let cornerRadius = size * 0.22
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Blue-to-purple gradient
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        CGColor(red: 0.30, green: 0.50, blue: 0.95, alpha: 1.0),  // Blue
        CGColor(red: 0.55, green: 0.30, blue: 0.90, alpha: 1.0),  // Purple
    ] as CFArray
    let gradientLocations: [CGFloat] = [0.0, 1.0]
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: gradientLocations)!

    context.saveGState()
    context.addPath(bgPath)
    context.clip()
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )
    context.restoreGState()

    // Subtle inner shadow / border
    context.saveGState()
    context.addPath(bgPath)
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.15))
    context.setLineWidth(size * 0.01)
    context.strokePath()
    context.restoreGState()

    // --- Window motif: two overlapping windows ---
    let windowColor1 = CGColor(red: 1, green: 1, blue: 1, alpha: 0.90)
    let windowColor2 = CGColor(red: 1, green: 1, blue: 1, alpha: 0.55)
    let titleBarColor1 = CGColor(red: 0.93, green: 0.93, blue: 0.95, alpha: 0.95)
    let titleBarColor2 = CGColor(red: 0.93, green: 0.93, blue: 0.95, alpha: 0.60)
    let shadowColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0.25)

    let winCorner = size * 0.06
    let titleBarHeight = size * 0.08
    let dotRadius = size * 0.015
    let dotY = titleBarHeight * 0.5

    // Back window (slightly offset up-left)
    let backWin = CGRect(
        x: size * 0.16,
        y: size * 0.22,
        width: size * 0.52,
        height: size * 0.48
    )

    // Front window (offset down-right, overlapping)
    let frontWin = CGRect(
        x: size * 0.32,
        y: size * 0.14,
        width: size * 0.52,
        height: size * 0.48
    )

    // Draw back window
    drawWindow(
        in: context,
        rect: backWin,
        cornerRadius: winCorner,
        bodyColor: windowColor2,
        titleBarColor: titleBarColor2,
        titleBarHeight: titleBarHeight,
        dotRadius: dotRadius,
        dotCenterY: dotY,
        shadowColor: shadowColor,
        size: size,
        isFront: false
    )

    // Draw front window
    drawWindow(
        in: context,
        rect: frontWin,
        cornerRadius: winCorner,
        bodyColor: windowColor1,
        titleBarColor: titleBarColor1,
        titleBarHeight: titleBarHeight,
        dotRadius: dotRadius,
        dotCenterY: dotY,
        shadowColor: shadowColor,
        size: size,
        isFront: true
    )

    // --- Selection indicator: rounded rect border around front window ---
    let selectionInset = size * -0.02
    let selectionRect = frontWin.insetBy(dx: selectionInset, dy: selectionInset)
    let selectionPath = CGPath(roundedRect: selectionRect, cornerWidth: winCorner * 1.3, cornerHeight: winCorner * 1.3, transform: nil)

    context.saveGState()
    context.addPath(selectionPath)
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.85))
    context.setLineWidth(size * 0.025)
    context.strokePath()
    context.restoreGState()
}

func drawWindow(
    in context: CGContext,
    rect: CGRect,
    cornerRadius: CGFloat,
    bodyColor: CGColor,
    titleBarColor: CGColor,
    titleBarHeight: CGFloat,
    dotRadius: CGFloat,
    dotCenterY: CGFloat,
    shadowColor: CGColor,
    size: CGFloat,
    isFront: Bool
) {
    let winPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Shadow
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -size * 0.01), blur: size * 0.04, color: shadowColor)
    context.addPath(winPath)
    context.setFillColor(bodyColor)
    context.fillPath()
    context.restoreGState()

    // Window body
    context.saveGState()
    context.addPath(winPath)
    context.setFillColor(bodyColor)
    context.fillPath()
    context.restoreGState()

    // Title bar
    let titleBarRect = CGRect(
        x: rect.minX,
        y: rect.maxY - titleBarHeight,
        width: rect.width,
        height: titleBarHeight
    )

    context.saveGState()
    context.addPath(winPath)
    context.clip()
    context.setFillColor(titleBarColor)
    context.fill(titleBarRect)

    // Title bar separator line
    context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.08))
    context.setLineWidth(size * 0.003)
    context.move(to: CGPoint(x: titleBarRect.minX, y: titleBarRect.minY))
    context.addLine(to: CGPoint(x: titleBarRect.maxX, y: titleBarRect.minY))
    context.strokePath()
    context.restoreGState()

    // Traffic light dots (only for front window at larger sizes)
    if isFront {
        let colors: [CGColor] = [
            CGColor(red: 0.95, green: 0.30, blue: 0.25, alpha: 0.9),  // red
            CGColor(red: 0.95, green: 0.75, blue: 0.20, alpha: 0.9),  // yellow
            CGColor(red: 0.30, green: 0.85, blue: 0.35, alpha: 0.9),  // green
        ]
        let dotSpacing = size * 0.04
        let startX = rect.minX + size * 0.04

        for (i, color) in colors.enumerated() {
            let cx = startX + CGFloat(i) * dotSpacing
            let cy = titleBarRect.minY + titleBarHeight * 0.5
            context.saveGState()
            context.setFillColor(color)
            context.fillEllipse(in: CGRect(
                x: cx - dotRadius,
                y: cy - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            ))
            context.restoreGState()
        }
    }

    // Content lines (placeholder for window content)
    let lineColor = isFront
        ? CGColor(red: 0, green: 0, blue: 0, alpha: 0.08)
        : CGColor(red: 0, green: 0, blue: 0, alpha: 0.04)
    let lineHeight = size * 0.02
    let lineSpacing = size * 0.055
    let lineInset = size * 0.04
    let contentTop = titleBarRect.minY - size * 0.05

    context.saveGState()
    context.addPath(winPath)
    context.clip()

    for i in 0..<3 {
        let y = contentTop - CGFloat(i) * lineSpacing
        let lineWidth = rect.width * (i == 2 ? 0.45 : (i == 1 ? 0.65 : 0.75))
        let lineRect = CGRect(
            x: rect.minX + lineInset,
            y: y - lineHeight,
            width: lineWidth,
            height: lineHeight
        )
        let linePath = CGPath(roundedRect: lineRect, cornerWidth: lineHeight * 0.5, cornerHeight: lineHeight * 0.5, transform: nil)
        context.addPath(linePath)
        context.setFillColor(lineColor)
        context.fillPath()
    }

    context.restoreGState()
}

// MARK: - Export

func generateIcon(pointSize: Int, scale: Int) {
    let pixelSize = pointSize * scale
    let size = CGFloat(pixelSize)

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    ) else {
        print("Failed to create context for \(pixelSize)x\(pixelSize)")
        return
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    drawIcon(in: context, size: size)

    guard let cgImage = context.makeImage() else {
        print("Failed to create image for \(pixelSize)x\(pixelSize)")
        return
    }

    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    bitmapRep.size = NSSize(width: pointSize, height: pointSize)

    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(pixelSize)x\(pixelSize)")
        return
    }

    let filename = "icon_\(pointSize)x\(pointSize)@\(scale)x.png"
    let url = URL(fileURLWithPath: outputDir).appendingPathComponent(filename)

    do {
        try pngData.write(to: url)
        print("Generated: \(filename) (\(pixelSize)x\(pixelSize) pixels)")
    } catch {
        print("Failed to write \(filename): \(error)")
    }
}

// MARK: - Main

print("Generating Tabora app icons in: \(outputDir)")

for (pointSize, scale) in iconSizes {
    generateIcon(pointSize: pointSize, scale: scale)
}

// Generate updated Contents.json
let contentsJSON = """
{
  "images" : [
    {
      "filename" : "icon_16x16@1x.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32@1x.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128@1x.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256@1x.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512@1x.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

let contentsURL = URL(fileURLWithPath: outputDir).appendingPathComponent("Contents.json")
do {
    try contentsJSON.write(to: contentsURL, atomically: true, encoding: .utf8)
    print("Updated: Contents.json")
} catch {
    print("Failed to write Contents.json: \(error)")
}

print("Done!")
