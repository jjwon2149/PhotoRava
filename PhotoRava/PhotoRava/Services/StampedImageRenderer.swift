//
//  StampedImageRenderer.swift
//  PhotoRava
//
//  Created by Codex on 1/27/26.
//

import UIKit

enum ExifStampTextAlignment: String, CaseIterable, Identifiable {
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

struct ExifStampStyle: Equatable {
    enum PaddingPreset: String, CaseIterable, Identifiable {
        case none
        case small
        case medium
        case large
        
        var id: String { rawValue }
        
        var label: String {
            switch self {
            case .none: return "없음"
            case .small: return "작게"
            case .medium: return "중간"
            case .large: return "크게"
            }
        }
        
        /// Base padding as a fraction of the shortest image side.
        var baseFraction: CGFloat {
            switch self {
            case .none: return 0
            case .small: return 0.04
            case .medium: return 0.07
            case .large: return 0.10
            }
        }
    }
    
    var paddingPreset: PaddingPreset = .medium
    var backgroundColor: UIColor = .white
    var textColor: UIColor = .black
    var textAlignment: ExifStampTextAlignment = .center
    /// Multiplier for caption font sizes (user-controlled).
    var textScale: CGFloat = 1.25
}

final class StampedImageRenderer {
    static let shared = StampedImageRenderer()
    private init() {}
    
    func render(
        originalImage: UIImage,
        line1: String?,
        line2: String?,
        style: ExifStampStyle
    ) -> UIImage {
        let base = originalImage.normalizedOrientation()
        let originalSize = base.size
        
        let shortestSide = min(originalSize.width, originalSize.height)
        let basePadding = shortestSide * style.paddingPreset.baseFraction
        
        let maxTextWidth = max(1, originalSize.width + (basePadding * 2))
        let (textBlockSize, attributedText) = buildText(
            line1: line1,
            line2: line2,
            maxWidth: maxTextWidth,
            style: style,
            referenceWidth: originalSize.width
        )
        
        let topPadding = basePadding
        let sidePadding = basePadding
        let captionPaddingTop = (textBlockSize.height > 0) ? (basePadding * 0.8) : 0
        let captionPaddingBottom = (textBlockSize.height > 0) ? (basePadding * 0.9) : basePadding
        let bottomPadding = basePadding + captionPaddingTop + textBlockSize.height + captionPaddingBottom
        
        let canvasSize = CGSize(
            width: originalSize.width + sidePadding * 2,
            height: originalSize.height + topPadding + bottomPadding
        )
        
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = base.scale
        
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(style.backgroundColor.cgColor)
            cg.fill(CGRect(origin: .zero, size: canvasSize))
            
            let imageRect = CGRect(
                x: sidePadding,
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
            attributedText.draw(in: textRect.insetBy(dx: sidePadding, dy: 0))
        }
    }
    
    private func buildText(
        line1: String?,
        line2: String?,
        maxWidth: CGFloat,
        style: ExifStampStyle,
        referenceWidth: CGFloat
    ) -> (CGSize, NSAttributedString?) {
        let l1 = line1?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let l2 = line2?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasAny = !l1.isEmpty || !l2.isEmpty
        guard hasAny else { return (.zero, nil) }
        
        let scale = max(0.7, min(2.5, style.textScale))
        let baseFontSize = max(30, min(90, referenceWidth * 0.060)) * scale
        let line1Font = UIFont.systemFont(ofSize: baseFontSize, weight: .semibold)
        let line2Font = UIFont.systemFont(ofSize: max(14, baseFontSize * 0.80), weight: .regular)
        
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = style.textAlignment.nsAlignment
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = max(2, baseFontSize * 0.18)
        
        let result = NSMutableAttributedString()
        if !l1.isEmpty {
            result.append(NSAttributedString(
                string: l1,
                attributes: [
                    .font: line1Font,
                    .foregroundColor: style.textColor,
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
                    .foregroundColor: style.textColor.withAlphaComponent(0.9),
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
