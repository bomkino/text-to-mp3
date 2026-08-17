import AppKit

guard CommandLine.arguments.count == 2 else {
    fatalError("Pass output PNG path.")
}

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

NSColor.clear.setFill()
NSRect(origin: .zero, size: size).fill()

let tile = NSBezierPath(
    roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880),
    xRadius: 210,
    yRadius: 210
)
NSColor(displayP3Red: 0.13, green: 0.31, blue: 0.80, alpha: 1).setFill()
tile.fill()

let innerHighlight = NSBezierPath(
    roundedRect: NSRect(x: 75, y: 75, width: 874, height: 874),
    xRadius: 207,
    yRadius: 207
)
NSColor.white.withAlphaComponent(0.20).setStroke()
innerHighlight.lineWidth = 3
innerHighlight.stroke()

let heights: [CGFloat] = [190, 335, 490, 630, 490, 335, 190]
let barWidth: CGFloat = 54
let gap: CGFloat = 38
let totalWidth = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
let startX = (size.width - totalWidth) / 2

for (index, height) in heights.enumerated() {
    let rect = NSRect(
        x: startX + CGFloat(index) * (barWidth + gap),
        y: (size.height - height) / 2,
        width: barWidth,
        height: height
    )
    let bar = NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2)
    NSColor.white.withAlphaComponent(index == 3 ? 1 : 0.84).setFill()
    bar.fill()
}

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Could not render app icon.")
}

try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
