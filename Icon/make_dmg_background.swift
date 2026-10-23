// Renders the background for the Notchfall.dmg installer window (640×400, plus @2x).
//   swift Icon/make_dmg_background.swift <out.tiff>
// build.sh --dist runs this; icons sit at (160, 190) and (480, 190) in Finder's top-left coordinates.
import AppKit

let w = 640.0, h = 400.0
func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(red: r, green: g, blue: b, alpha: a) }
let aurora = [c(0.25, 0.55, 1.0), c(0.70, 0.35, 1.0), c(1.0, 0.35, 0.65), c(1.0, 0.62, 0.25), c(0.25, 0.85, 1.0)]

func render(scale: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w) * scale, pixelsHigh: Int(h) * scale,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: w, height: h)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let cg = NSGraphicsContext.current!.cgContext
    cg.scaleBy(x: CGFloat(scale), y: CGFloat(scale))

    let bg = CGGradient(colorsSpace: nil, colors: [c(0.15, 0.11, 0.32).cgColor, c(0.03, 0.03, 0.09).cgColor] as CFArray,
                        locations: [0, 1])!
    cg.drawLinearGradient(bg, start: CGPoint(x: 0, y: h), end: .zero, options: [])

    var seed: UInt64 = 11
    func rnd() -> CGFloat {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(seed >> 33) / CGFloat(UInt32.max >> 1)
    }
    for _ in 0..<70 {
        let r = 0.6 + rnd() * 1.4
        cg.setFillColor(NSColor.white.withAlphaComponent(0.15 + rnd() * 0.45).cgColor)
        cg.fillEllipse(in: CGRect(x: rnd() * w, y: rnd() * h, width: r * 2, height: r * 2))
    }
    let rainbow = CGGradient(colorsSpace: nil, colors: aurora.map(\.cgColor) as CFArray, locations: nil)!

    // A small island hanging from the top edge, with its aurora rim.
    let island = CGPath(roundedRect: CGRect(x: w / 2 - 110, y: h - 44, width: 220, height: 64), cornerWidth: 22, cornerHeight: 22, transform: nil)
    for (blur, col) in [(26.0, aurora[1]), (10.0, aurora[0])] {
        cg.saveGState()
        cg.setShadow(offset: .zero, blur: blur, color: col.cgColor)
        cg.beginTransparencyLayer(auxiliaryInfo: nil)
        cg.addPath(island.copy(strokingWithWidth: 3, lineCap: .round, lineJoin: .round, miterLimit: 10))
        cg.clip()
        cg.drawLinearGradient(rainbow, start: CGPoint(x: w / 2 - 110, y: 0), end: CGPoint(x: w / 2 + 110, y: 0), options: [])
        cg.endTransparencyLayer()
        cg.restoreGState()
    }
    cg.addPath(island)
    cg.setFillColor(NSColor.black.cgColor)
    cg.fillPath()

    // Aurora arc from the app to Applications, ending in an arrowhead.
    let y = h - 190
    cg.saveGState()
    cg.setShadow(offset: .zero, blur: 12, color: aurora[1].cgColor)
    let arc = CGMutablePath()
    arc.move(to: CGPoint(x: 245, y: y))
    arc.addQuadCurve(to: CGPoint(x: 385, y: y), control: CGPoint(x: 315, y: y + 40))
    cg.beginTransparencyLayer(auxiliaryInfo: nil)
    cg.addPath(arc.copy(dashingWithPhase: 0, lengths: [2, 12]).copy(strokingWithWidth: 4, lineCap: .round, lineJoin: .round, miterLimit: 10))
    cg.move(to: CGPoint(x: 398, y: y - 4))
    cg.addLine(to: CGPoint(x: 376, y: y + 12))
    cg.addLine(to: CGPoint(x: 380, y: y - 12))
    cg.closePath()
    cg.clip()
    cg.drawLinearGradient(rainbow, start: CGPoint(x: 245, y: 0), end: CGPoint(x: 398, y: 0), options: [])
    cg.endTransparencyLayer()
    cg.restoreGState()

    // Finder draws icon labels in black (Light Mode) or white (Dark Mode); a mid-grey nameplate
    // under each label keeps both readable on the dark background.
    for x in [160.0, 480.0] {
        let plate = CGPath(roundedRect: CGRect(x: x - 75, y: h - 283, width: 150, height: 28),
                           cornerWidth: 14, cornerHeight: 14, transform: nil)
        cg.addPath(plate)
        cg.setFillColor(NSColor.white.withAlphaComponent(0.4).cgColor)
        cg.fillPath()
    }

    func text(_ s: String, _ size: CGFloat, _ weight: NSFont.Weight, _ color: NSColor, y: CGFloat, kern: CGFloat = 0) {
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        let str = NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight),
                                                             .foregroundColor: color, .paragraphStyle: para, .kern: kern])
        str.draw(in: CGRect(x: 0, y: y, width: w, height: size * 1.5))
    }
    text("NOTCHFALL", 13, .heavy, c(0.75, 0.8, 1.0), y: h - 92, kern: 3)
    text("Drag Notchfall into Applications to install", 17, .semibold, .white, y: 80)
    text("First launch blocked? System Settings → Privacy & Security → Open Anyway", 11, .regular,
         c(0.55, 0.75, 1.0, 0.85), y: 44)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "background.tiff"
// A multi-representation TIFF lets Finder pick the sharp 2x image on Retina screens.
let data = NSBitmapImageRep.tiffRepresentationOfImageReps(in: [render(scale: 1), render(scale: 2)], using: .lzw, factor: 0)!
try! data.write(to: URL(fileURLWithPath: out))
print("✓ wrote \(out)")
