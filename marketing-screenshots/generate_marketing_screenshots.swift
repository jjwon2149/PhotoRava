import AppKit
import Foundation

struct ShotSpec {
    let input: String
    let output: String
    let title: String
    let subtitle: String
    let badge: String
    let accent: NSColor
    let backgroundTop: NSColor
    let backgroundBottom: NSColor
    let shell: NSColor
    let raisePhone: CGFloat
}

let scriptDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let inputDirectory = CommandLine.arguments.dropFirst().first
    .map { URL(fileURLWithPath: $0, isDirectory: true) }
    ?? scriptDirectory.appendingPathComponent("raw", isDirectory: true)
let outputDirectory = CommandLine.arguments.dropFirst(2).first
    .map { URL(fileURLWithPath: $0, isDirectory: true) }
    ?? scriptDirectory
let canvasSize = NSSize(width: 1242, height: 2688)
let phoneWidth: CGFloat = 940
let phoneHeight = phoneWidth * 2532.0 / 1170.0

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

let specs = [
    ShotSpec(
        input: "01-route-list-source.png",
        output: "01-route-list.png",
        title: "사진으로 정리되는 나의 경로",
        subtitle: "날짜와 사진 수, 이동 기록을 한눈에 확인하세요.",
        badge: "Route Library",
        accent: color(59, 130, 246),
        backgroundTop: color(246, 248, 252),
        backgroundBottom: color(225, 241, 255),
        shell: color(255, 255, 255),
        raisePhone: 0
    ),
    ShotSpec(
        input: "02-route-map-source.png",
        output: "02-route-map.png",
        title: "사진이 남긴 길을 지도 위에",
        subtitle: "흩어진 사진을 따라 이동 흐름을 복원합니다.",
        badge: "Route Map",
        accent: color(34, 197, 94),
        backgroundTop: color(247, 251, 247),
        backgroundBottom: color(226, 247, 232),
        shell: color(255, 255, 255),
        raisePhone: 0
    ),
    ShotSpec(
        input: "03-timeline-source.png",
        output: "03-timeline.png",
        title: "여정은 타임라인으로 선명하게",
        subtitle: "거리, 시간, 사진 위치를 자연스럽게 이어 보세요.",
        badge: "Timeline",
        accent: color(124, 58, 237),
        backgroundTop: color(249, 247, 255),
        backgroundBottom: color(235, 229, 255),
        shell: color(255, 255, 255),
        raisePhone: -20
    ),
    ShotSpec(
        input: "04-exif-frame-source.png",
        output: "04-exif-frame.png",
        title: "촬영 정보를 감각적인 프레임으로",
        subtitle: "기기, 렌즈, 노출값을 사진 아래에 정갈하게 남깁니다.",
        badge: "EXIF Frame",
        accent: color(14, 165, 233),
        backgroundTop: color(247, 250, 252),
        backgroundBottom: color(225, 243, 255),
        shell: color(255, 255, 255),
        raisePhone: -10
    ),
    ShotSpec(
        input: "05-exif-theme-source.png",
        output: "05-exif-theme.png",
        title: "원하는 분위기로 바꾸는 EXIF 스탬프",
        subtitle: "프레임과 테마를 고르고 결과를 바로 미리보세요.",
        badge: "Themes",
        accent: color(239, 68, 68),
        backgroundTop: color(255, 248, 248),
        backgroundBottom: color(255, 232, 228),
        shell: color(255, 255, 255),
        raisePhone: -6
    ),
    ShotSpec(
        input: "06-original-preview-source.png",
        output: "06-original-preview.png",
        title: "내보내기 전 원본까지 크게 확인",
        subtitle: "스탬프 결과와 원본 미리보기를 빠르게 오가세요.",
        badge: "Preview",
        accent: color(17, 24, 39),
        backgroundTop: color(248, 248, 248),
        backgroundBottom: color(229, 232, 237),
        shell: color(22, 22, 24),
        raisePhone: -10
    )
]

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawText(_ text: String, in rect: NSRect, size: CGFloat, weight: NSFont.Weight, color: NSColor, alignment: NSTextAlignment = .center, lineHeight: CGFloat? = nil) {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    if let lineHeight {
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
    }

    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: style
    ]
    (text as NSString).draw(in: rect, withAttributes: attributes)
}

func drawSoftCard(_ rect: NSRect, radius: CGFloat, fill: NSColor, shadowBlur: CGFloat, shadowAlpha: CGFloat) {
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(shadowAlpha)
    shadow.shadowBlurRadius = shadowBlur
    shadow.shadowOffset = NSSize(width: 0, height: -18)
    shadow.set()
    fill.setFill()
    roundedRect(rect, radius: radius).fill()
    NSGraphicsContext.current?.restoreGraphicsState()
}

func drawBadge(_ text: String, accent: NSColor, canvasHeight: CGFloat) {
    let rect = NSRect(x: 433, y: canvasHeight - 252, width: 424, height: 64)
    accent.withAlphaComponent(0.12).setFill()
    roundedRect(rect, radius: 32).fill()
    drawText(text, in: NSRect(x: rect.minX, y: rect.minY + 13, width: rect.width, height: 36), size: 27, weight: .semibold, color: accent)
}

func drawAccentBand(accent: NSColor, canvas: NSSize) {
    NSGraphicsContext.current?.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: canvas.width / 2, yBy: canvas.height / 2)
    transform.rotate(byDegrees: -10)
    transform.translateX(by: -canvas.width / 2, yBy: -canvas.height / 2)
    transform.concat()

    accent.withAlphaComponent(0.10).setFill()
    let band = NSRect(x: -160, y: 240, width: canvas.width + 320, height: 420)
    roundedRect(band, radius: 120).fill()

    accent.withAlphaComponent(0.08).setFill()
    let slimBand = NSRect(x: -120, y: 686, width: canvas.width + 240, height: 90)
    roundedRect(slimBand, radius: 45).fill()
    NSGraphicsContext.current?.restoreGraphicsState()
}

func render(_ spec: ShotSpec) throws {
    let inputURL = inputDirectory.appendingPathComponent(spec.input)
    guard let screenshot = NSImage(contentsOf: inputURL) else {
        throw NSError(domain: "MarketingScreenshots", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot load \(inputURL.path)"])
    }

    let image = NSImage(size: canvasSize)
    image.lockFocus()

    let bounds = NSRect(origin: .zero, size: canvasSize)
    NSGradient(colors: [spec.backgroundBottom, spec.backgroundTop])?.draw(in: bounds, angle: 90)
    drawAccentBand(accent: spec.accent, canvas: canvasSize)

    drawBadge(spec.badge, accent: spec.accent, canvasHeight: canvasSize.height)
    drawText(
        spec.title,
        in: NSRect(x: 92, y: canvasSize.height - 390, width: canvasSize.width - 184, height: 100),
        size: 62,
        weight: .bold,
        color: color(16, 24, 40),
        lineHeight: 76
    )
    drawText(
        spec.subtitle,
        in: NSRect(x: 118, y: canvasSize.height - 486, width: canvasSize.width - 236, height: 88),
        size: 35,
        weight: .medium,
        color: color(91, 99, 116),
        lineHeight: 48
    )

    let screenRect = NSRect(
        x: (canvasSize.width - phoneWidth) / 2,
        y: 216 + spec.raisePhone,
        width: phoneWidth,
        height: phoneHeight
    )
    let shellRect = screenRect.insetBy(dx: -24, dy: -24)
    drawSoftCard(shellRect, radius: 86, fill: spec.shell, shadowBlur: 44, shadowAlpha: 0.18)

    NSGraphicsContext.current?.saveGraphicsState()
    roundedRect(screenRect, radius: 64).addClip()
    screenshot.draw(in: screenRect, from: NSRect(origin: .zero, size: screenshot.size), operation: .copy, fraction: 1)
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGraphicsContext.current?.saveGraphicsState()
    spec.accent.withAlphaComponent(0.25).setStroke()
    let strokePath = roundedRect(screenRect.insetBy(dx: -1, dy: -1), radius: 66)
    strokePath.lineWidth = 2
    strokePath.stroke()
    NSGraphicsContext.current?.restoreGraphicsState()

    drawText(
        "PhotoRava",
        in: NSRect(x: 0, y: 76, width: canvasSize.width, height: 42),
        size: 26,
        weight: .semibold,
        color: color(91, 99, 116).withAlphaComponent(0.72)
    )

    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "MarketingScreenshots", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot encode \(spec.output)"])
    }

    try data.write(to: outputDirectory.appendingPathComponent(spec.output), options: .atomic)
}

do {
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    for spec in specs {
        try render(spec)
    }
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
