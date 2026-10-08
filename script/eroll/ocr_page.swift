import Foundation
import Vision
import AppKit

let args = CommandLine.arguments
guard args.count >= 2 else {
    fputs("usage: ocr_page <image> [--serials]\n", stderr)
    exit(1)
}

let url = URL(fileURLWithPath: args[1])
let serialMode = args.contains("--serials")
let linesMode = args.contains("--lines")

guard let image = NSImage(contentsOf: url),
      let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let cgImage = bitmap.cgImage else {
    fputs("failed to load image\n", stderr)
    exit(1)
}

func makeRequest() -> VNRecognizeTextRequest {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    request.recognitionLanguages = ["en-US"]
    request.revision = 1
    return request
}

struct Hit {
    var y: CGFloat
    var text: String
}

func recognizeHits(_ image: CGImage) -> [Hit] {
    let request = makeRequest()
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    do {
        try handler.perform([request])
    } catch {
        fputs("ocr failed: \(error)\n", stderr)
        return []
    }
    return (request.results ?? []).compactMap { obs in
        guard let text = obs.topCandidates(1).first?.string else { return nil }
        return Hit(y: obs.boundingBox.origin.y, text: text)
    }
}

func recognize(_ image: CGImage) -> [String] {
    recognizeHits(image).map(\.text)
}

func pureSerial(_ lines: [String]) -> String? {
    for line in lines {
        let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: #"^\d{1,4}$"#, options: .regularExpression) != nil else { continue }
        if text == "0" { continue }
        return text
    }
    return nil
}

func crop(visionX: CGFloat, visionY: CGFloat, visionW: CGFloat, visionH: CGFloat) -> CGImage? {
    let width = CGFloat(cgImage.width)
    let height = CGFloat(cgImage.height)
    var rect = CGRect(
        x: visionX * width,
        y: (1 - visionY - visionH) * height,
        width: visionW * width,
        height: visionH * height
    ).integral
    let bounds = CGRect(x: 0, y: 0, width: width, height: height)
    rect = rect.intersection(bounds)
    guard rect.width > 2, rect.height > 2 else { return nil }
    return cgImage.cropping(to: rect)
}

func upscale(_ image: CGImage, factor: CGFloat) -> CGImage? {
    let width = Int((CGFloat(image.width) * factor).rounded())
    let height = Int((CGFloat(image.height) * factor).rounded())
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()
}

if serialMode {
    while let line = readLine() {
        if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
        let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 5,
              let vx = Double(parts[1]),
              let vy = Double(parts[2]),
              let vw = Double(parts[3]),
              let vh = Double(parts[4]),
              let cropped = crop(
                visionX: CGFloat(vx),
                visionY: CGFloat(vy),
                visionW: CGFloat(vw),
                visionH: CGFloat(vh)
              ) else {
            print("\(parts.first ?? "")\t")
            continue
        }
        var serial = pureSerial(recognize(cropped))
        if serial == nil, let bigger = upscale(cropped, factor: 3) {
            serial = pureSerial(recognize(bigger))
        }
        print("\(parts[0])\t\(serial ?? "")")
    }
} else if linesMode {
    while let line = readLine() {
        if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
        let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 5,
              let vx = Double(parts[1]),
              let vy = Double(parts[2]),
              let vw = Double(parts[3]),
              let vh = Double(parts[4]),
              let cropped = crop(
                visionX: CGFloat(vx),
                visionY: CGFloat(vy),
                visionW: CGFloat(vw),
                visionH: CGFloat(vh)
              ),
              let bigger = upscale(cropped, factor: 2) else {
            continue
        }
        let hits = recognizeHits(bigger).sorted { $0.y > $1.y }
        if hits.isEmpty {
            print("\(parts[0])\t")
            continue
        }
        for hit in hits {
            let clean = hit.text.replacingOccurrences(of: "\t", with: " ")
            print("\(parts[0])\t\(clean)")
        }
    }
} else {
    let request = makeRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
        try handler.perform([request])
    } catch {
        fputs("ocr failed: \(error)\n", stderr)
        exit(1)
    }
    for obs in request.results ?? [] {
        guard let text = obs.topCandidates(1).first?.string else { continue }
        let box = obs.boundingBox
        let line = String(
            format: "%.5f\t%.5f\t%.5f\t%.5f\t%@",
            box.origin.x, box.origin.y, box.size.width, box.size.height, text as NSString
        )
        print(line)
    }
}
