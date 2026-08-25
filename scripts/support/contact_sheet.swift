import AppKit
import Foundation

private func fail(_ message: String) -> Never {
    fputs("contact-sheet: \(message)\n", stderr)
    exit(1)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 2 else {
    fail("usage: contact_sheet.swift OUTPUT INPUT... | --output-fd FD --input-fd FD LABEL...")
}

let outputURL: URL?
let outputFileDescriptor: Int32?
let images: [(String, NSImage)]
if arguments[0] == "--output-fd" {
    guard arguments.count >= 5, let descriptor = Int32(arguments[1]), descriptor >= 3 else {
        fail("--output-fd requires an open descriptor and descriptor-bound inputs")
    }
    outputURL = nil
    outputFileDescriptor = descriptor
    var parsedImages: [(String, NSImage)] = []
    var index = 2
    while index < arguments.count {
        guard index + 2 < arguments.count,
              arguments[index] == "--input-fd",
              let inputDescriptor = Int32(arguments[index + 1]),
              inputDescriptor >= 3
        else {
            fail("each descriptor-bound input requires --input-fd FD LABEL")
        }
        do {
            let handle = FileHandle(fileDescriptor: inputDescriptor, closeOnDealloc: false)
            try handle.seek(toOffset: 0)
            guard let data = try handle.readToEnd(),
                  let image = NSImage(data: data),
                  image.size.width > 0,
                  image.size.height > 0
            else {
                fail("could not decode descriptor-bound input")
            }
            let label = URL(fileURLWithPath: arguments[index + 2])
                .deletingPathExtension()
                .lastPathComponent
            parsedImages.append((label, image))
        } catch {
            fail("could not read descriptor-bound input: \(error)")
        }
        index += 3
    }
    images = parsedImages
} else {
    outputURL = URL(fileURLWithPath: arguments[0])
    outputFileDescriptor = nil
    images = arguments.dropFirst().map { argument -> (String, NSImage) in
        let url = URL(fileURLWithPath: argument)
        guard let image = NSImage(contentsOf: url), image.size.width > 0, image.size.height > 0 else {
            fail("could not decode \(url.path)")
        }
        return (url.deletingPathExtension().lastPathComponent, image)
    }
}

let thumbnailSize = NSSize(width: 460, height: 322)
let labelHeight: CGFloat = 76
let padding: CGFloat = 18
let columns = min(3, max(1, images.count))
let rows = (images.count + columns - 1) / columns
let canvasSize = NSSize(
    width: CGFloat(columns) * thumbnailSize.width + CGFloat(columns + 1) * padding,
    height: CGFloat(rows) * (thumbnailSize.height + labelHeight) + CGFloat(rows + 1) * padding,
)
let canvas = NSImage(size: canvasSize)
canvas.lockFocus()
NSColor.white.setFill()
NSRect(origin: .zero, size: canvasSize).fill()
NSGraphicsContext.current?.imageInterpolation = .high

let paragraph = NSMutableParagraphStyle()
paragraph.lineBreakMode = .byTruncatingTail
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11),
    .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 1),
    .paragraphStyle: paragraph,
]

for (index, item) in images.enumerated() {
    let row = index / columns
    let column = index % columns
    let x = padding + CGFloat(column) * (thumbnailSize.width + padding)
    let cellBottom = canvasSize.height
        - padding
        - CGFloat(row + 1) * (thumbnailSize.height + labelHeight)
        - CGFloat(row) * padding
    let frame = NSRect(
        x: x,
        y: cellBottom + labelHeight,
        width: thumbnailSize.width,
        height: thumbnailSize.height,
    )
    NSColor(calibratedWhite: 0.965, alpha: 1).setFill()
    frame.fill()

    let scale = min(frame.width / item.1.size.width, frame.height / item.1.size.height)
    let drawSize = NSSize(width: item.1.size.width * scale, height: item.1.size.height * scale)
    let drawRect = NSRect(
        x: frame.midX - drawSize.width / 2,
        y: frame.midY - drawSize.height / 2,
        width: drawSize.width,
        height: drawSize.height,
    )
    item.1.draw(in: drawRect)

    item.0.draw(
        with: NSRect(x: x, y: cellBottom + 8, width: thumbnailSize.width, height: labelHeight - 12),
        options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
        attributes: attributes,
    )
}

canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let representation = NSBitmapImageRep(data: tiff),
      let png = representation.representation(using: .png, properties: [:])
else {
    fail("could not encode the contact sheet")
}

do {
    if let outputFileDescriptor {
        try FileHandle(fileDescriptor: outputFileDescriptor, closeOnDealloc: false)
            .write(contentsOf: png)
    } else if let outputURL {
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        try png.write(to: outputURL, options: .atomic)
    } else {
        fail("no output destination")
    }
    print("\(Int(canvasSize.width))x\(Int(canvasSize.height))")
} catch {
    fail("could not write contact sheet: \(error)")
}
