#!/usr/bin/env swift

import AppKit
import Foundation

// Generate Qube app icon - a stylized 3D cube
func generateIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    
    image.lockFocus()
    
    let context = NSGraphicsContext.current!.cgContext
    
    // Background - rounded square with gradient
    let bgRect = NSRect(x: size * 0.1, y: size * 0.1, width: size * 0.8, height: size * 0.8)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: size * 0.18, yRadius: size * 0.18)
    
    // Gradient from coral/orange to deeper orange
    let gradient = NSGradient(colors: [
        NSColor(red: 1.0, green: 0.6, blue: 0.4, alpha: 1.0),  // Light coral
        NSColor(red: 0.95, green: 0.45, blue: 0.25, alpha: 1.0) // Deeper orange
    ])!
    gradient.draw(in: bgPath, angle: -45)
    
    // Draw a 3D cube in the center
    let centerX = size * 0.5
    let centerY = size * 0.5
    let cubeSize = size * 0.35
    
    // Cube vertices (isometric projection)
    let topY = centerY + cubeSize * 0.5
    let bottomY = centerY - cubeSize * 0.5
    let leftX = centerX - cubeSize * 0.45
    let rightX = centerX + cubeSize * 0.45
    let midTopY = centerY + cubeSize * 0.15
    let midBottomY = centerY - cubeSize * 0.15
    
    // Top face (lightest)
    let topFace = NSBezierPath()
    topFace.move(to: NSPoint(x: centerX, y: topY))
    topFace.line(to: NSPoint(x: rightX, y: midTopY))
    topFace.line(to: NSPoint(x: centerX, y: centerY * 0.95))
    topFace.line(to: NSPoint(x: leftX, y: midTopY))
    topFace.close()
    NSColor(white: 1.0, alpha: 0.95).setFill()
    topFace.fill()
    
    // Left face (medium)
    let leftFace = NSBezierPath()
    leftFace.move(to: NSPoint(x: leftX, y: midTopY))
    leftFace.line(to: NSPoint(x: centerX, y: centerY * 0.95))
    leftFace.line(to: NSPoint(x: centerX, y: bottomY + cubeSize * 0.35))
    leftFace.line(to: NSPoint(x: leftX, y: midBottomY))
    leftFace.close()
    NSColor(white: 0.85, alpha: 0.95).setFill()
    leftFace.fill()
    
    // Right face (darkest)
    let rightFace = NSBezierPath()
    rightFace.move(to: NSPoint(x: rightX, y: midTopY))
    rightFace.line(to: NSPoint(x: centerX, y: centerY * 0.95))
    rightFace.line(to: NSPoint(x: centerX, y: bottomY + cubeSize * 0.35))
    rightFace.line(to: NSPoint(x: rightX, y: midBottomY))
    rightFace.close()
    NSColor(white: 0.7, alpha: 0.95).setFill()
    rightFace.fill()
    
    // Subtle edge highlights
    NSColor(white: 1.0, alpha: 0.3).setStroke()
    topFace.lineWidth = size * 0.01
    topFace.stroke()
    
    image.unlockFocus()
    
    return image
}

func saveIcon(image: NSImage, size: Int, to directory: URL) {
    let filename = "icon_\(size)x\(size).png"
    let url = directory.appendingPathComponent(filename)
    
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for size \(size)")
        return
    }
    
    do {
        try pngData.write(to: url)
        print("Created \(filename)")
    } catch {
        print("Failed to write \(filename): \(error)")
    }
}

// Main
let sizes = [16, 32, 64, 128, 256, 512, 1024]
let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("AppIcon.appiconset")

// Create output directory
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

// Generate icons at all sizes
for size in sizes {
    let image = generateIcon(size: CGFloat(size))
    saveIcon(image: image, size: size, to: outputDir)
    
    // Also create @2x versions for smaller sizes
    if size <= 512 {
        let image2x = generateIcon(size: CGFloat(size * 2))
        // Resize to target size
        let resized = NSImage(size: NSSize(width: size, height: size))
        resized.lockFocus()
        image2x.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        resized.unlockFocus()
        
        let filename = "icon_\(size)x\(size)@2x.png"
        let url = outputDir.appendingPathComponent(filename)
        if let tiffData = image2x.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: url)
            print("Created \(filename)")
        }
    }
}

// Create Contents.json
let contentsJson = """
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""

let contentsUrl = outputDir.appendingPathComponent("Contents.json")
try? contentsJson.write(to: contentsUrl, atomically: true, encoding: .utf8)
print("Created Contents.json")

print("\nIcon set created at: \(outputDir.path)")
print("Now run: iconutil -c icns AppIcon.appiconset")

