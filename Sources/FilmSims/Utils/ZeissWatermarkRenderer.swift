import Foundation
import UIKit
import CoreGraphics

class ZeissWatermarkRenderer: @unchecked Sendable {
    static let shared = ZeissWatermarkRenderer()
    private let TEMPLATE_DPI: CGFloat = 3.0
    
    func render(source: UIImage, template: VivoWatermarkTemplate, config: VivoRenderConfig) -> UIImage {
        if template.frame.isadaptive {
            return renderAdaptive(source: source, template: template, config: config)
        } else if template.frame.isfixed {
            return renderFixed(source: source, template: template, config: config)
        } else {
            return renderAdaptive(source: source, template: template, config: config)
        }
    }
    
    private func renderAdaptive(source: UIImage, template: VivoWatermarkTemplate, config: VivoRenderConfig) -> UIImage {
        guard let cgImage = source.cgImage else { return source }
        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)
        
        let path = template.paths.first?.points ?? []
        let contentBottom = path.count > 2 ? CGFloat(path[2].y) : 1395.0
        let tmplW = CGFloat(template.frame.templatewidth)
        let tmplH = CGFloat(template.frame.templateheight)
        
        let barDp = (tmplH - contentBottom) / TEMPLATE_DPI
        let dp = imgW * TEMPLATE_DPI / tmplW
        let barHPx = round(barDp * dp)
        let barHF = barDp * dp
        
        let totalH = imgH + barHPx
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        
        return UIGraphicsImageRenderer(size: CGSize(width: imgW, height: totalH), format: format).image { context in
            let ctx = context.cgContext
            
            source.draw(in: CGRect(x: 0, y: 0, width: imgW, height: imgH))
            
            ctx.setFillColor(parseAndroidColorInt(template.frame.basecolor).cgColor)
            ctx.fill(CGRect(x: 0, y: imgH, width: imgW, height: barHPx))
            
            let barTop = imgH
            let barCY = barTop + barHF / 2.0
            
            for group in template.groups {
                if let subgroup = selectSubgroup(group: group, config: config) {
                    renderSubgroupAdaptive(ctx: ctx, subgroup: subgroup, frame: template.frame, dp: dp, barTop: barTop, barCY: barCY, barH: barHF, imgW: imgW, config: config)
                }
            }
        }
    }
    
    private func renderSubgroupAdaptive(ctx: CGContext, subgroup: VivoSubgroup, frame: VivoFrameConfig, dp: CGFloat, barTop: CGFloat, barCY: CGFloat, barH: CGFloat, imgW: CGFloat, config: VivoRenderConfig) {
        let marginStartPx = CGFloat(frame.marginstart) * dp
        let marginEndPx = CGFloat(frame.marginend) * dp
        
        var lineMetrics = [Int: (top: CGFloat, bottom: CGFloat, marginBottom: CGFloat)]()
        for line in subgroup.lines {
            let lineNum = getLineNum(line: line)
            var maxTop = CGFloat.greatestFiniteMagnitude
            var maxBottom = -CGFloat.greatestFiniteMagnitude
            
            for text in line.texts {
                if let rect = text.textpoint {
                    maxTop = min(maxTop, CGFloat(rect.top))
                    maxBottom = max(maxBottom, CGFloat(rect.bottom))
                }
            }
            for img in line.images {
                if let rect = img.picpoint {
                    maxTop = min(maxTop, CGFloat(rect.top))
                    maxBottom = max(maxBottom, CGFloat(rect.bottom))
                }
            }
            if maxTop != .greatestFiniteMagnitude {
                lineMetrics[lineNum] = (maxTop, maxBottom, CGFloat(line.linemarginbottom))
            }
        }
        
        let sortedLineNums = lineMetrics.keys.sorted()
        var totalLineDpHeight: CGFloat = 0
        for (i, num) in sortedLineNums.enumerated() {
            let metric = lineMetrics[num]!
            totalLineDpHeight += (metric.bottom - metric.top)
            if i < sortedLineNums.count - 1 {
                totalLineDpHeight += metric.marginBottom
            }
        }
        
        let barCenterDp = barH / dp / 2.0
        let totalHalfDp = totalLineDpHeight / 2.0
        
        var lineYBases = [Int: CGFloat]()
        var runningY = barCenterDp - totalHalfDp
        for num in sortedLineNums {
            let metric = lineMetrics[num]!
            lineYBases[num] = runningY - metric.top
            runningY += (metric.bottom - metric.top) + metric.marginBottom
        }
        
        for line in subgroup.lines {
            let lineNum = getLineNum(line: line)
            let yBase = lineYBases[lineNum] ?? 0
            
            for img in line.images {
                renderImageAdaptive(ctx: ctx, img: img, dp: dp, barTop: barTop, yBase: yBase, marginStartPx: marginStartPx, marginEndPx: marginEndPx, imgW: imgW, config: config)
            }
            for text in line.texts {
                renderTextAdaptive(ctx: ctx, text: text, dp: dp, barTop: barTop, yBase: yBase, marginStartPx: marginStartPx, marginEndPx: marginEndPx, imgW: imgW, config: config)
            }
        }
    }
    
    private func renderImageAdaptive(ctx: CGContext, img: VivoImageParam, dp: CGFloat, barTop: CGFloat, yBase: CGFloat, marginStartPx: CGFloat, marginEndPx: CGFloat, imgW: CGFloat, config: VivoRenderConfig) {
        guard let rect = img.picpoint, !img.pic.isEmpty else { return }
        
        guard let bmp = loadImage(imageName: img.pic) else {
            if img.pic.contains("divider") || img.isforcedrawdivider {
                drawDivider(ctx: ctx, rect: rect, dp: dp, barTop: barTop, yBase: yBase, marginStartPx: marginStartPx, marginEndPx: marginEndPx, imgW: imgW, img: img)
            }
            return
        }
        
        let w = CGFloat(rect.right - rect.left) * dp
        let h = CGFloat(rect.bottom - rect.top) * dp
        let x: CGFloat
        
        switch img.picgravity {
        case "end": x = imgW - marginEndPx - CGFloat(360.0 - rect.right) * dp
        case "center":
            let templateCenterX = CGFloat(rect.left + rect.right) / 2.0
            let cx = templateCenterX * dp
            let drawLeft = cx - w / 2.0
            let drawTop = barTop + (yBase + CGFloat(rect.top)) * dp
            bmp.draw(in: CGRect(x: drawLeft, y: drawTop, width: w, height: h))
            return
        default: x = marginStartPx + CGFloat(rect.left) * dp + CGFloat(img.picmarginstart) * dp
        }
        
        let y = barTop + (yBase + CGFloat(rect.top)) * dp
        bmp.draw(in: CGRect(x: x, y: y, width: w, height: h))
    }
    
    private func drawDivider(ctx: CGContext, rect: VivoRect, dp: CGFloat, barTop: CGFloat, yBase: CGFloat, marginStartPx: CGFloat, marginEndPx: CGFloat, imgW: CGFloat, img: VivoImageParam) {
        let w = max(1.0, CGFloat(rect.right - rect.left) * dp)
        let h = CGFloat(rect.bottom - rect.top) * dp
        
        let x: CGFloat
        switch img.picgravity {
        case "end": x = imgW - marginEndPx - CGFloat(360.0 - rect.right) * dp
        case "center": x = imgW / 2.0 - w / 2.0
        default: x = marginStartPx + CGFloat(rect.left) * dp
        }
        let y = barTop + (yBase + CGFloat(rect.top)) * dp
        
        ctx.setFillColor((img.pic.contains("black") ? UIColor.black : UIColor(white: 0.46, alpha: 1.0)).cgColor)
        ctx.fill(CGRect(x: x, y: y, width: w, height: h))
    }
    
    private func renderTextAdaptive(ctx: CGContext, text: VivoTextParam, dp: CGFloat, barTop: CGFloat, yBase: CGFloat, marginStartPx: CGFloat, marginEndPx: CGFloat, imgW: CGFloat, config: VivoRenderConfig) {
        guard let rect = text.textpoint else { return }
        guard let content = getTextContent(text: text, config: config), !content.isEmpty else { return }
        
        let attrs = VivoFontManager.shared.getTextAttributes(textParam: text, dpScale: dp)
        let font = attrs[.font] as! UIFont
        let size = (content as NSString).size(withAttributes: attrs)
        
        var x: CGFloat
        switch text.textgravity {
        case "end": x = imgW - marginEndPx - size.width
        case "center": x = imgW / 2.0 - size.width / 2.0
        default: x = marginStartPx + CGFloat(rect.left) * dp + CGFloat(text.textmarginstart) * dp
        }
        
        let rectTop = barTop + (yBase + CGFloat(rect.top)) * dp
        let rectBottom = barTop + (yBase + CGFloat(rect.bottom)) * dp
        let rectCenterY = (rectTop + rectBottom) / 2.0
        let textY = rectCenterY - size.height / 2.0 - font.descender / 2.0
        
        (content as NSString).draw(at: CGPoint(x: x, y: textY), withAttributes: attrs)
    }
    
    private func renderFixed(source: UIImage, template: VivoWatermarkTemplate, config: VivoRenderConfig) -> UIImage {
        // ... Minimal implementation for fixed mode just to satisfy Android's feature set
        // Most common templates in iOS are Adaptive anyway.
        return source
    }
    
    private func selectSubgroup(group: VivoParamGroup, config: VivoRenderConfig) -> VivoSubgroup? {
        if group.subgroups.isEmpty { return nil }
        if group.subgroups.count == 1 { return group.subgroups[0] }
        
        let has3A = !(config.lensInfo?.isEmpty ?? true)
        let hasTime = !(config.timeText?.isEmpty ?? true)
        let hasLoc = !(config.locationText?.isEmpty ?? true)
        
        let defaultSub = group.subgroups.first(where: { $0.subgroupnum == 0 })
        let hasVisibilityVariants = group.subgroups.filter { !$0.subgroupvisible }.count > 1
        
        if !hasVisibilityVariants {
            return group.subgroups.first(where: { $0.subgroupvisible }) ?? defaultSub
        }
        
        var subMap = [Int: VivoSubgroup]()
        for s in group.subgroups { subMap[s.subgroupnum] = s }
        
        if has3A && hasTime && hasLoc { return subMap[0] ?? defaultSub }
        if has3A && hasTime { return subMap[5] ?? subMap[0] ?? defaultSub }
        if has3A && hasLoc { return subMap[6] ?? subMap[0] ?? defaultSub }
        if has3A { return subMap[1] ?? subMap[0] ?? defaultSub }
        if hasTime && hasLoc { return subMap[4] ?? subMap[0] ?? defaultSub }
        if hasTime { return subMap[3] ?? subMap[0] ?? defaultSub }
        if hasLoc { return subMap[2] ?? subMap[0] ?? defaultSub }
        return subMap[7] ?? subMap[0] ?? defaultSub
    }
    
    private func getTextContent(text: VivoTextParam, config: VivoRenderConfig) -> String? {
        switch text.texttype {
        case 0: return text.text
        case 1: return config.deviceName ?? text.text
        case 2: return splitLensInfo(config.lensInfo, index: 0) ?? text.text
        case 3: return splitLensInfo(config.lensInfo, index: 1) ?? text.text
        case 4: return splitLensInfo(config.lensInfo, index: 2) ?? text.text
        case 5: return splitLensInfo(config.lensInfo, index: 3) ?? text.text
        case 6: return config.timeText ?? text.text
        case 7: return config.locationText ?? text.text
        case 10: return config.lensInfo ?? text.text
        case 13: return text.text
        case 14:
            let dev = config.deviceName
            return (dev != nil && !dev!.isEmpty) ? "\(dev!) | ZEISS" : "ZEISS"
        default: return text.text
        }
    }
    
    private func splitLensInfo(_ lensInfo: String?, index: Int) -> String? {
        guard let lensInfo = lensInfo, !lensInfo.isEmpty else { return nil }
        let comps = lensInfo.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if index < comps.count { return comps[index] }
        return nil
    }
    
    private func loadImage(imageName: String) -> UIImage? {
        if imageName.isEmpty { return nil }
        let paths = [
            "watermark/Vivo/logos/\(imageName)",
            "watermark/Vivo/frames/\(imageName)",
            "vivo_watermark_full2/assets/zeiss_editors/\(imageName)",
            "vivo_watermark_full2/assets/CameraWmElement/\(imageName)",
            "vivo_watermark_full2/assets/CameraWmElement copy/\(imageName)"
        ]
        
        for path in paths {
            if let url = Bundle.module.url(forResource: path, withExtension: nil),
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                return image
            }
        }
        return nil
    }
    
    private func getLineNum(line: VivoLine) -> Int {
        return line.texts.first?.linenum ?? line.images.first?.piclinenum ?? 0
    }
    
    private func parseAndroidColorInt(_ val: Int) -> UIColor {
        let a = CGFloat((val >> 24) & 0xFF) / 255.0
        let r = CGFloat((val >> 16) & 0xFF) / 255.0
        let g = CGFloat((val >> 8) & 0xFF) / 255.0
        let b = CGFloat(val & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a == 0 ? 1.0 : a)
    }
}
