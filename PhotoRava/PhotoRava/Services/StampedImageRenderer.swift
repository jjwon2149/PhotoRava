//
//  StampedImageRenderer.swift
//  PhotoRava
//
//  Created by Codex on 1/27/26.
//

import UIKit

enum ExifStampTextAlignment: String, CaseIterable, Identifiable, Codable {
    case leading
    case center
    case trailing
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .leading: return "왼쪽"
        case .center: return "가운데"
        case .trailing: return "오른쪽"
        }
    }
    
    var nsAlignment: NSTextAlignment {
        switch self {
        case .leading: return .left
        case .center: return .center
        case .trailing: return .right
        }
    }
}

struct ExifStampPaddingFractions: Equatable {
    var top: CGFloat
    var bottom: CGFloat
    var left: CGFloat
    var right: CGFloat
}

struct ExifStampRenderSpec: Equatable {
    var layout: ExifStampLayout
    var paddingFractions: ExifStampPaddingFractions
    var backgroundColor: UIColor
    var textColor: UIColor
    var textAlignment: ExifStampTextAlignment
    /// Multiplier for caption font sizes (user-controlled).
    var textScale: CGFloat
    
    /// Normalized crop rect (0.0 to 1.0). nil means no crop.
    var cropRect: CGRect? = nil
    
    /// Target export size.
    var exportSize: ExifStampExportSize = .original
    
    /// Target final frame (canvas) ratio.
    var canvasRatio: ExifStampCanvasRatio = .original
}

final class StampedImageRenderer {
    static let shared = StampedImageRenderer()
    private init() {}
    
    func render(
        originalImage: UIImage,
        line1: String?,
        line2: String?,
        spec: ExifStampRenderSpec
    ) -> UIImage {
        var base = originalImage.normalizedOrientation()
        
        // Apply Crop if specified
        if let cropRect = spec.cropRect {
            base = base.cropped(to: cropRect)
        }
        
        let originalSize = base.size
        
        let shortestSide = min(originalSize.width, originalSize.height)
        let topPadding = shortestSide * spec.paddingFractions.top
        let bottomBasePadding = shortestSide * spec.paddingFractions.bottom
        let leftPadding = shortestSide * spec.paddingFractions.left
        let rightPadding = shortestSide * spec.paddingFractions.right

        let shouldDrawText = spec.layout.supportsCaption
        let maxTextWidth = max(1, originalSize.width + leftPadding + rightPadding)
        let (textBlockSize, attributedText) = shouldDrawText ? buildText(
            line1: line1,
            line2: line2,
            maxWidth: maxTextWidth,
            spec: spec,
            referenceWidth: shortestSide
        ) : (.zero, nil)

        // New Logic: Bottom padding is the sum of gap, text, and the base margin.
        // This ensures the space from the text to the bottom edge matches topPadding.
        let captionGap = (textBlockSize.height > 0) ? (bottomBasePadding * 0.6) : 0
        let bottomPadding = (textBlockSize.height > 0) 
            ? (captionGap + textBlockSize.height + bottomBasePadding) 
            : bottomBasePadding
        
        var canvasSize = CGSize(
            width: originalSize.width + leftPadding + rightPadding,
            height: originalSize.height + topPadding + bottomPadding
        )
        
        // Handle Final Canvas Ratio with symmetry compensation
        var finalImageOffset = CGPoint.zero
        if let targetRatio = spec.canvasRatio.ratio(originalSize: canvasSize) {
            let currentRatio = canvasSize.width / canvasSize.height
            if currentRatio > targetRatio {
                // Canvas is too wide, need more height
                let newHeight = canvasSize.width / targetRatio
                finalImageOffset.y = (newHeight - canvasSize.height) / 2
                canvasSize.height = newHeight
            } else if currentRatio < targetRatio {
                // Canvas is too tall, need more width
                let newWidth = canvasSize.height * targetRatio
                finalImageOffset.x = (newWidth - canvasSize.width) / 2
                canvasSize.width = newWidth
            }
        }
        
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = base.scale
        
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let stampedImage = renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(spec.backgroundColor.cgColor)
            cg.fill(CGRect(origin: .zero, size: canvasSize))
            
            let imageRect = CGRect(
                x: leftPadding + finalImageOffset.x,
                y: topPadding + finalImageOffset.y,
                width: originalSize.width,
                height: originalSize.height
            )
            base.draw(in: imageRect)
            
            guard textBlockSize.height > 0, let attributedText else { return }
            
            // Text is placed exactly 'captionGap' below the image
            let textRect = CGRect(
                x: finalImageOffset.x,
                y: imageRect.maxY + captionGap,
                width: canvasSize.width - (finalImageOffset.x * 2),
                height: textBlockSize.height
            )
            attributedText.draw(in: textRect.inset(by: UIEdgeInsets(top: 0, left: leftPadding, bottom: 0, right: rightPadding)))
        }
        
        // Apply final resize if requested
        if let targetSize = spec.exportSize.targetLongSide(original: max(canvasSize.width, canvasSize.height)) {
            let currentLongSide = max(canvasSize.width, canvasSize.height)
            if currentLongSide > targetSize {
                return stampedImage.resized(toLongSide: targetSize)
            }
        }
        
        return stampedImage
    }
    
    private func buildText(
        line1: String?,
        line2: String?,
        maxWidth: CGFloat,
        spec: ExifStampRenderSpec,
        referenceWidth: CGFloat
    ) -> (CGSize, NSAttributedString?) {
        let l1 = line1?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let l2 = line2?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasAny = !l1.isEmpty || !l2.isEmpty
        guard hasAny else { return (.zero, nil) }
        
        let scale = max(0.1, min(2.5, spec.textScale))
        let baseFontSize = (referenceWidth * 0.055) * scale
        let line1Font = UIFont.systemFont(ofSize: baseFontSize, weight: .semibold)
        let line2Font = UIFont.systemFont(ofSize: baseFontSize * 0.80, weight: .regular)
        
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = spec.textAlignment.nsAlignment
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = max(2, baseFontSize * 0.18)
        
        let result = NSMutableAttributedString()
        if !l1.isEmpty {
            result.append(NSAttributedString(
                string: l1,
                attributes: [
                    .font: line1Font,
                    .foregroundColor: spec.textColor,
                    .paragraphStyle: paragraph
                ]
            ))
        }
        if !l2.isEmpty {
            if !result.string.isEmpty { result.append(NSAttributedString(string: "\n")) }
            result.append(NSAttributedString(
                string: l2,
                attributes: [
                    .font: line2Font,
                    .foregroundColor: spec.textColor.withAlphaComponent(0.9),
                    .paragraphStyle: paragraph
                ]
            ))
        }
        
        let bounding = result.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).integral
        
        return (bounding.size, result)
    }
}

private extension UIImage {
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    func cropped(to rect: CGRect) -> UIImage {
        let normalizedRect = CGRect(
            x: rect.origin.x * size.width,
            y: rect.origin.y * size.height,
            width: rect.size.width * size.width,
            height: rect.size.height * size.height
        )
        guard let cgImage = cgImage?.cropping(to: normalizedRect) else { return self }
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
    
    func resized(toLongSide maxSide: CGFloat) -> UIImage {
        let aspect = size.width / size.height
        let newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: maxSide, height: maxSide / aspect)
        } else {
            newSize = CGSize(width: maxSide * aspect, height: maxSide)
        }
        
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
