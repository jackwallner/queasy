// Draws the Google Play feature graphic (1024 x 500, no alpha) from the app
// icon and the Tide palette, in the bundled Newsreader italic.
// swift scripts/make-play-feature-graphic.swift <repo root>
import AppKit
import CoreText

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let fontURL = root.appendingPathComponent("android/app/src/main/res/font/newsreader_italic.ttf")
CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
let descriptors = CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as! [CTFontDescriptor]
func serif(_ size: CGFloat) -> NSFont { CTFontCreateWithFontDescriptor(descriptors[0], size, nil) as NSFont }

let width = 1024, height = 500
let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let colors = [CGColor(red: 24/255, green: 60/255, blue: 66/255, alpha: 1), CGColor(red: 85/255, green: 181/255, blue: 169/255, alpha: 1)]
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])

let icon = NSImage(contentsOf: root.appendingPathComponent("Queasy/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))!
var rect = CGRect(x: 80, y: 100, width: 300, height: 300)
let cgIcon = icon.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 66, cornerHeight: 66, transform: nil))
ctx.clip()
ctx.draw(cgIcon, in: rect)
ctx.restoreGState()

NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
let white = NSColor.white
let seafoam = NSColor(red: 0.918, green: 0.953, blue: 0.949, alpha: 1)
("Queasy" as NSString).draw(at: CGPoint(x: 440, y: 255), withAttributes: [.font: serif(104), .foregroundColor: white])
("Four drug-free things to try" as NSString).draw(at: CGPoint(x: 444, y: 200), withAttributes: [.font: serif(40), .foregroundColor: seafoam])
("when you feel queasy" as NSString).draw(at: CGPoint(x: 444, y: 152), withAttributes: [.font: serif(40), .foregroundColor: seafoam])

let out = root.appendingPathComponent("android/play-assets/feature-graphic.png")
let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("wrote \(out.path)")
