// Renders the Notchfall app icon: a black island with an aurora rim hanging from the top edge, and a
// glowing spark falling out of it.
//   swift Icon/make_icon.swift   → writes Icon/AppIcon.icns and Icon/AppIcon.png
import AppKit

let size = 1024.0

func c(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor { NSColor(red: r, green: g, blue: b, alpha: a).cgColor }
let blue = c(0.25, 0.55, 1.0), violet = c(0.70, 0.35, 1.0), pink = c(1.0, 0.35, 0.65), amber = c(1.0, 0.62, 0.25), cyan = c(0.25, 0.85, 1.0)

func renderFull(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let cg = NSGraphicsContext.current!.cgContext
    cg.scaleBy(x: CGFloat(px) / size, y: CGFloat(px) / size)
    draw(cg)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// Every size is shrunk from one full-size drawing. Shadow and glow blur are measured in device pixels, so
// drawing straight at 16–64 px let them spill over the whole image as a faint grey square.
enum Full {
    static let png = renderFull(1024)
    static let image = NSBitmapImageRep(data: png)!.cgImage!
}

func render(_ px: Int) -> Data {
    if px == Full.image.width { return Full.png }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    ctx.interpolationQuality = .high
    ctx.draw(Full.image, in: CGRect(x: 0, y: 0, width: px, height: px))
    return rep.representation(using: .png, properties: [:])!
}

/// The same outline the app animates: flared ears along the top edge, rounded bottom corners (y up).
func island(_ r: CGRect, top t: CGFloat, bottom b: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: r.minX, y: r.maxY))
    p.addQuadCurve(to: CGPoint(x: r.minX + t, y: r.maxY - t), control: CGPoint(x: r.minX + t, y: r.maxY))
    p.addLine(to: CGPoint(x: r.minX + t, y: r.minY + b))
    p.addCurve(to: CGPoint(x: r.minX + t + b, y: r.minY), control1: CGPoint(x: r.minX + t, y: r.minY + b * 0.45),
               control2: CGPoint(x: r.minX + t + b * 0.45, y: r.minY))
    p.addLine(to: CGPoint(x: r.maxX - t - b, y: r.minY))
    p.addCurve(to: CGPoint(x: r.maxX - t, y: r.minY + b), control1: CGPoint(x: r.maxX - t - b * 0.45, y: r.minY),
               control2: CGPoint(x: r.maxX - t, y: r.minY + b * 0.45))
    p.addLine(to: CGPoint(x: r.maxX - t, y: r.maxY - t))
    p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.maxX - t, y: r.maxY))
    p.closeSubpath()
    return p
}

func gradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: nil, colors: colors as CFArray, locations: nil)!
}

func draw(_ cg: CGContext) {
    // Body follows Apple's icon grid: 824pt squircle centred in a 1024 canvas.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: c(0, 0, 0, 0.5))
    cg.addPath(squircle)
    cg.setFillColor(c(0, 0, 0))
    cg.fillPath()
    cg.restoreGState()

    cg.saveGState()
    cg.addPath(squircle)
    cg.clip()
    cg.drawLinearGradient(gradient([c(0.17, 0.13, 0.36), c(0.06, 0.05, 0.16), c(0.02, 0.02, 0.06)]),
                          start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: [])
    cg.drawRadialGradient(gradient([c(0.45, 0.3, 1.0, 0.35), c(0.45, 0.3, 1.0, 0)]),
                          startCenter: CGPoint(x: 512, y: 640), startRadius: 0,
                          endCenter: CGPoint(x: 512, y: 640), endRadius: 470, options: [])

    // A few stars.
    var seed: UInt64 = 11
    func rnd() -> CGFloat {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(seed >> 33) / CGFloat(UInt32.max >> 1)
    }
    for _ in 0..<26 {
        let p = CGPoint(x: 130 + rnd() * 764, y: 130 + rnd() * 470)
        let r = 1.5 + rnd() * 3
        cg.setFillColor(c(1, 1, 1, 0.2 + rnd() * 0.45))
        cg.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
    }

    // The island, hanging from the top edge.
    let rect = CGRect(x: 512 - 330, y: 924 - 300, width: 660, height: 300)
    let shape = island(rect, top: 46, bottom: 92)
    let rim = shape.copy(strokingWithWidth: 16, lineCap: .round, lineJoin: .round, miterLimit: 10)
    let rainbow = gradient([blue, violet, pink, amber, cyan])

    // Aurora glow: the gradient rim, drawn twice inside shadowed layers so it blooms.
    for (blur, col) in [(70.0, violet), (34.0, pink), (14.0, blue)] {
        cg.saveGState()
        cg.setShadow(offset: .zero, blur: blur, color: col)
        cg.beginTransparencyLayer(auxiliaryInfo: nil)
        cg.addPath(rim)
        cg.clip()
        cg.drawLinearGradient(rainbow, start: CGPoint(x: rect.minX, y: 0), end: CGPoint(x: rect.maxX, y: 0), options: [])
        cg.endTransparencyLayer()
        cg.restoreGState()
    }
    cg.addPath(shape)
    cg.setFillColor(c(0, 0, 0))
    cg.fillPath()

    // A miniature alert inside: countdown ring, two lines of text, a Join pill.
    let ring = CGRect(x: rect.minX + 110, y: rect.minY + 70, width: 110, height: 110)
    cg.setLineWidth(14)
    cg.setStrokeColor(c(1, 1, 1, 0.1))
    cg.strokeEllipse(in: ring)
    cg.saveGState()
    cg.setShadow(offset: .zero, blur: 16, color: blue)
    cg.setStrokeColor(c(0.35, 0.65, 1.0))
    cg.setLineCap(.round)
    cg.addArc(center: CGPoint(x: ring.midX, y: ring.midY), radius: 55, startAngle: .pi / 2, endAngle: .pi / 2 - .pi * 1.4, clockwise: true)
    cg.strokePath()
    cg.restoreGState()
    cg.setFillColor(c(1, 1, 1, 0.92))
    cg.addPath(CGPath(roundedRect: CGRect(x: ring.maxX + 40, y: ring.midY + 12, width: 230, height: 30), cornerWidth: 15, cornerHeight: 15, transform: nil))
    cg.fillPath()
    cg.setFillColor(c(1, 1, 1, 0.35))
    cg.addPath(CGPath(roundedRect: CGRect(x: ring.maxX + 40, y: ring.midY - 36, width: 150, height: 22), cornerWidth: 11, cornerHeight: 11, transform: nil))
    cg.fillPath()

    // The fall: a four-point spark dropping out of the island on a comet trail.
    let star = CGPoint(x: 512, y: 400)
    cg.saveGState()
    let trail = CGMutablePath()
    trail.move(to: CGPoint(x: star.x - 26, y: star.y))
    trail.addLine(to: CGPoint(x: star.x - 5, y: rect.minY - 18))
    trail.addLine(to: CGPoint(x: star.x + 5, y: rect.minY - 18))
    trail.addLine(to: CGPoint(x: star.x + 26, y: star.y))
    trail.closeSubpath()
    cg.addPath(trail)
    cg.clip()
    cg.drawLinearGradient(gradient([c(0.55, 0.85, 1.0, 0.75), c(0.7, 0.4, 1.0, 0)]),
                          start: CGPoint(x: 0, y: star.y), end: CGPoint(x: 0, y: rect.minY - 18), options: [])
    cg.restoreGState()

    /// Four points joined by curves pulled in towards the centre (`waist` sets how thin the arms are).
    func spark(_ p: CGPoint, _ r: CGFloat, waist: CGFloat) -> CGPath {
        let w = r * waist
        let t = CGMutablePath()
        t.move(to: CGPoint(x: p.x, y: p.y + r))
        t.addQuadCurve(to: CGPoint(x: p.x + r, y: p.y), control: CGPoint(x: p.x + w, y: p.y + w))
        t.addQuadCurve(to: CGPoint(x: p.x, y: p.y - r), control: CGPoint(x: p.x + w, y: p.y - w))
        t.addQuadCurve(to: CGPoint(x: p.x - r, y: p.y), control: CGPoint(x: p.x - w, y: p.y - w))
        t.addQuadCurve(to: CGPoint(x: p.x, y: p.y + r), control: CGPoint(x: p.x - w, y: p.y + w))
        t.closeSubpath()
        return t
    }

    cg.drawRadialGradient(gradient([c(0.5, 0.8, 1.0, 0.55), c(0.5, 0.8, 1.0, 0)]), startCenter: star, startRadius: 0,
                          endCenter: star, endRadius: 190, options: [])
    let big = spark(star, 118, waist: 0.16)
    cg.saveGState()
    cg.setShadow(offset: .zero, blur: 50, color: cyan)
    cg.addPath(big)
    cg.clip()
    cg.drawRadialGradient(gradient([c(1, 1, 1), c(0.7, 0.9, 1.0), c(0.55, 0.6, 1.0)]), startCenter: star, startRadius: 0,
                          endCenter: star, endRadius: 118, options: [])
    cg.restoreGState()
    cg.setFillColor(c(1, 1, 1, 0.9))
    cg.addPath(spark(CGPoint(x: 660, y: 470), 26, waist: 0.18))
    cg.fillPath()
    cg.setFillColor(c(1, 1, 1, 0.6))
    cg.addPath(spark(CGPoint(x: 372, y: 300), 18, waist: 0.18))
    cg.fillPath()

    // Glass sheen across the top of the squircle.
    cg.drawLinearGradient(gradient([c(1, 1, 1, 0.08), c(1, 1, 1, 0)]), start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 560), options: [])
    cg.restoreGState()

    cg.addPath(squircle)
    cg.setStrokeColor(c(1, 1, 1, 0.12))
    cg.setLineWidth(3)
    cg.strokePath()
}

let dir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let iconset = dir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for pt in [16, 32, 128, 256, 512] {
    try! render(pt).write(to: iconset.appendingPathComponent("icon_\(pt)x\(pt).png"))
    try! render(pt * 2).write(to: iconset.appendingPathComponent("icon_\(pt)x\(pt)@2x.png"))
}
try! render(1024).write(to: dir.appendingPathComponent("AppIcon.png"))

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", dir.appendingPathComponent("AppIcon.icns").path]
try! p.run()
p.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print(p.terminationStatus == 0 ? "✓ wrote \(dir.path)/AppIcon.icns" : "✗ iconutil failed")
