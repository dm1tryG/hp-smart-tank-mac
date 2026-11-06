// Rotates landscape PDF pages 90° onto portrait pages (the hpcups path doesn't rotate).
import Foundation
import CoreGraphics
let a = CommandLine.arguments
guard a.count == 3, let doc = CGPDFDocument(URL(fileURLWithPath: a[1]) as CFURL) else { print("usage: portraitize in.pdf out.pdf"); exit(1) }
var box = CGRect.zero
guard let ctx = CGContext(URL(fileURLWithPath: a[2]) as CFURL, mediaBox: &box, nil) else { exit(1) }
for i in 1...doc.numberOfPages {
    guard let p = doc.page(at: i) else { continue }
    let r = p.getBoxRect(.mediaBox)
    let land = r.width > r.height
    var out = land ? CGRect(x: 0, y: 0, width: r.height, height: r.width) : CGRect(origin: .zero, size: r.size)
    let info = [kCGPDFContextMediaBox as String: NSData(bytes: &out, length: MemoryLayout<CGRect>.size)] as CFDictionary
    ctx.beginPDFPage(info)
    if land { ctx.translateBy(x: r.height, y: 0); ctx.rotate(by: .pi / 2) }
    ctx.translateBy(x: -r.minX, y: -r.minY)
    ctx.drawPDFPage(p)
    ctx.endPDFPage()
}
ctx.closePDF()
