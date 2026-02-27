import Foundation

class VivoWatermarkConfigParser: @unchecked Sendable {
    static let shared = VivoWatermarkConfigParser()
    
    func parseConfig(assetPath: String) -> VivoWatermarkTemplate? {
        guard let url = Bundle.module.url(forResource: assetPath, withExtension: nil) else { return nil }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return parseContent(content)
    }
    
    private func parseContent(_ content: String) -> VivoWatermarkTemplate? {
        var frameConfig = VivoFrameConfig()
        var paths = [VivoPath]()
        var groups = [VivoParamGroup]()
        
        var currentGroup: VivoParamGroup?
        var currentSubgroup: VivoSubgroup?
        var currentLine: VivoLine?
        var currentPicParam: VivoImageParam?
        var currentTextParam: VivoTextParam?
        
        var inPicParam = false
        var inTextParam = false
        
        let lines = content.components(separatedBy: .newlines)
        for lineText in lines {
            let line = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            
            if line == "SETIN" || line == "PATHSETIN" || line == "PARAMSETIN" { continue }
            if line == "PATHCLOSE" || line == "PARAMCLOSE" || line == "CLOSE" {
                if inPicParam { currentLine?.images.append(currentPicParam!); inPicParam = false; currentPicParam = nil }
                if inTextParam { currentLine?.texts.append(currentTextParam!); inTextParam = false; currentTextParam = nil }
                if let cl = currentLine { currentSubgroup?.lines.append(cl); currentLine = nil }
                if let cs = currentSubgroup { currentGroup?.subgroups.append(cs); currentSubgroup = nil }
                if let cg = currentGroup { groups.append(cg); currentGroup = nil }
                continue
            }
            
            if line.hasPrefix("<frametype>") { frameConfig.frametype = extractValue(line) }
            else if line.hasPrefix("<subtype>") { frameConfig.subtype = Int(extractValue(line)) ?? 0 }
            else if line.hasPrefix("<isneedvivologo>") { frameConfig.isneedvivologo = (extractValue(line).lowercased() == "true") }
            else if line.hasPrefix("<iscameraborder>") { frameConfig.iscameraborder = (extractValue(line).lowercased() == "true") }
            else if line.hasPrefix("<isadaptive>") { frameConfig.isadaptive = (extractValue(line).lowercased() == "true") }
            else if line.hasPrefix("<isfixed>") { frameConfig.isfixed = (extractValue(line).lowercased() == "true") }
            else if line.hasPrefix("<isallwrap>") { frameConfig.isallwrap = (extractValue(line).lowercased() == "true") }
            else if line.hasPrefix("<isneeddefaultparam>") { frameConfig.isneeddefaultparam = (extractValue(line).lowercased() == "true") }
            else if line.hasPrefix("<basecolor>") { frameConfig.basecolor = Int(extractValue(line)) ?? -65794 }
            else if line.hasPrefix("<baseboard>") { frameConfig.baseboard = extractValue(line) }
            else if line.hasPrefix("<templatewidth>") { frameConfig.templatewidth = Int(extractValue(line)) ?? 1080 }
            else if line.hasPrefix("<templateheight>") { frameConfig.templateheight = Int(extractValue(line)) ?? 1719 }
            else if line.hasPrefix("<marginstart>") { frameConfig.marginstart = Float(extractValue(line)) ?? 0 }
            else if line.hasPrefix("<marginend>") { frameConfig.marginend = Float(extractValue(line)) ?? 0 }
            else if line.hasPrefix("<point>") { paths.append(VivoPath(points: parsePoints(extractValue(line)))) }
            else if line == "<group>" { currentGroup = VivoParamGroup() }
            else if line == "</group>" {
                if let cs = currentSubgroup { currentGroup?.subgroups.append(cs); currentSubgroup = nil }
                if let cg = currentGroup { groups.append(cg); currentGroup = nil }
            }
            else if line.hasPrefix("<groupgravity>") { currentGroup?.groupgravity = extractValue(line) }
            else if line.hasPrefix("<groupmarginend>") { currentGroup?.groupmarginend = Float(extractValue(line)) ?? 0 }
            else if line == "<subgroup>" { currentSubgroup = VivoSubgroup() }
            else if line == "</subgroup>" {
                if let cl = currentLine { currentSubgroup?.lines.append(cl); currentLine = nil }
                if let cs = currentSubgroup { currentGroup?.subgroups.append(cs); currentSubgroup = nil }
            }
            else if line.hasPrefix("<subgroupnum>") { currentSubgroup?.subgroupnum = Int(extractValue(line)) ?? 0 }
            else if line.hasPrefix("<subgroupvisible>") { currentSubgroup?.subgroupvisible = (extractValue(line).lowercased() == "true") }
            else if line.hasPrefix("<debuginfo>") { currentSubgroup?.debuginfo = extractValue(line) }
            else if line == "<line>" { currentLine = VivoLine() }
            else if line == "</line>" {
                if let cl = currentLine { currentSubgroup?.lines.append(cl); currentLine = nil }
            }
            else if line.hasPrefix("<linemarginbottom>") { currentLine?.linemarginbottom = Float(extractValue(line)) ?? 0 }
            else if line == "<picparam>" { inPicParam = true; currentPicParam = VivoImageParam() }
            else if line == "</picparam>" {
                if let cp = currentPicParam { currentLine?.images.append(cp); inPicParam = false; currentPicParam = nil }
            }
            else if line.hasPrefix("<piclinenum>") { currentPicParam?.piclinenum = Int(extractValue(line)) ?? 0 }
            else if line.hasPrefix("<picgravity>") { currentPicParam?.picgravity = extractValue(line) }
            else if line.hasPrefix("<picpoint>") || line.hasPrefix("<picplanbpoint>") { currentPicParam?.picpoint = parseRect(extractValue(line)) }
            else if line.hasPrefix("<pic>") { currentPicParam?.pic = extractValue(line) }
            else if line.hasPrefix("<issvg>") { currentPicParam?.issvg = (extractValue(line).lowercased() == "true") }
            else if line.hasPrefix("<iscamerapic>") { currentPicParam?.iscamerapic = (extractValue(line).lowercased() == "true") }
            else if line.hasPrefix("<picparamsidetype>") { currentPicParam?.picparamsidetype = Int(extractValue(line)) ?? 0 }
            else if line.hasPrefix("<picid>") { currentPicParam?.picid = Int(extractValue(line)) ?? 0 }
            else if line.hasPrefix("<isneedantialias>") { currentPicParam?.isneedantialias = (extractValue(line).lowercased() == "true") }
            else if line.hasPrefix("<isforcedrawdivider>") { currentPicParam?.isforcedrawdivider = (extractValue(line).lowercased() == "true") }
            else if line.hasPrefix("<picmarginstart>") { currentPicParam?.picmarginstart = Float(extractValue(line)) ?? 0 }
            else if line == "<textparam>" { inTextParam = true; currentTextParam = VivoTextParam() }
            else if line == "</textparam>" {
                if let ct = currentTextParam { currentLine?.texts.append(ct); inTextParam = false; currentTextParam = nil }
            }
            else if line.hasPrefix("<linenum>") { currentTextParam?.linenum = Int(extractValue(line)) ?? 0 }
            else if line.hasPrefix("<textgravity>") { currentTextParam?.textgravity = extractValue(line) }
            else if line.hasPrefix("<textpoint>") { currentTextParam?.textpoint = parseRect(extractValue(line)) }
            else if line.hasPrefix("<textplanbpoint>") { currentTextParam?.textplanbpoint = parseRect(extractValue(line)) }
            else if line.hasPrefix("<text>") { currentTextParam?.text = extractValue(line) }
            else if line.hasPrefix("<textsize>") { currentTextParam?.textsize = Float(extractValue(line)) ?? 0 }
            else if line.hasPrefix("<textfontweight>") { currentTextParam?.textfontweight = Int(extractValue(line)) ?? 400 }
            else if line.hasPrefix("<textcolor>") { currentTextParam?.textcolor = extractValue(line) }
            else if line.hasPrefix("<letterspacing>") { currentTextParam?.letterspacing = Float(extractValue(line)) ?? 0 }
            else if line.hasPrefix("<typeface>") { currentTextParam?.typeface = Int(extractValue(line)) ?? 0 }
            else if line.hasPrefix("<texttype>") { currentTextParam?.texttype = Int(extractValue(line)) ?? 0 }
            else if line.hasPrefix("<iscustomtext>") { currentTextParam?.iscustomtext = Int(extractValue(line)) ?? 0 }
            else if line.hasPrefix("<timetype>") { currentTextParam?.timetype = Int(extractValue(line)) ?? -2 }
            else if line.hasPrefix("<textmarginstart>") { currentTextParam?.textmarginstart = Float(extractValue(line)) ?? 0 }
            else if line.hasPrefix("<textmarginend>") { currentTextParam?.textmarginend = Float(extractValue(line)) ?? 0 }
        }
        
        if paths.isEmpty && groups.isEmpty { return nil }
        return VivoWatermarkTemplate(frame: frameConfig, paths: paths, groups: groups)
    }
    
    private func extractValue(_ line: String) -> String {
        guard let start = line.firstIndex(of: ">"), let end = line.lastIndex(of: "<"), start < end else { return "" }
        let startIndex = line.index(after: start)
        return String(line[startIndex..<end])
    }
    
    private func parsePoints(_ str: String) -> [VivoPoint] {
        var points = [VivoPoint]()
        do {
            let regex = try NSRegularExpression(pattern: "\\((-?\\d+\\.?\\d*),(-?\\d+\\.?\\d*)\\)")
            let nsStr = str as NSString
            let matches = regex.matches(in: str, range: NSRange(location: 0, length: nsStr.length))
            for match in matches {
                let x = Float(nsStr.substring(with: match.range(at: 1))) ?? 0
                let y = Float(nsStr.substring(with: match.range(at: 2))) ?? 0
                points.append(VivoPoint(x: x, y: y))
            }
        } catch {}
        return points
    }
    
    private func parseRect(_ str: String) -> VivoRect? {
        let pts = parsePoints(str)
        if pts.count >= 2 {
            return VivoRect(left: pts.first!.x, top: pts.first!.y, right: pts.last!.x, bottom: pts.last!.y)
        }
        return nil
    }
}
