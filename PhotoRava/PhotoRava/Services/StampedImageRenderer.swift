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
        let base = originalImage.normalizedOrientation()
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
            referenceWidth: originalSize.width
        ) : (.zero, nil)

        let captionPaddingTop = (textBlockSize.height > 0) ? (bottomBasePadding * 0.8) : 0
        let captionPaddingBottom = (textBlockSize.height > 0) ? (bottomBasePadding * 0.9) : 0
        let bottomPadding = bottomBasePadding + captionPaddingTop + textBlockSize.height + captionPaddingBottom
        
        let canvasSize = CGSize(
            width: originalSize.width + leftPadding + rightPadding,
            height: originalSize.height + topPadding + bottomPadding
        )
        
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = base.scale
        
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(spec.backgroundColor.cgColor)
            cg.fill(CGRect(origin: .zero, size: canvasSize))
            
            let imageRect = CGRect(
                x: leftPadding,
                y: topPadding,
                width: originalSize.width,
                height: originalSize.height
            )
            base.draw(in: imageRect)
            
            guard textBlockSize.height > 0, let attributedText else { return }
            
            let textRect = CGRect(
                x: 0,
                y: imageRect.maxY + captionPaddingTop,
                width: canvasSize.width,
                height: textBlockSize.height
            )
            attributedText.draw(in: textRect.inset(by: UIEdgeInsets(top: 0, left: leftPadding, bottom: 0, right: rightPadding)))
        }
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
        
        let scale = max(0.7, min(2.5, spec.textScale))
        let baseFontSize = max(30, min(90, referenceWidth * 0.060)) * scale
        let line1Font = UIFont.systemFont(ofSize: baseFontSize, weight: .semibold)
        let line2Font = UIFont.systemFont(ofSize: max(14, baseFontSize * 0.80), weight: .regular)
        
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
}
