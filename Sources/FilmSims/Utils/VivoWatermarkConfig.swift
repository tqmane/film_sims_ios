import Foundation

struct VivoFrameConfig {
    var frametype: String = ""
    var subtype: Int = 0
    var isneedvivologo: Bool = false
    var iscameraborder: Bool = false
    var isadaptive: Bool = false
    var isfixed: Bool = false
    var isallwrap: Bool = false
    var isneeddefaultparam: Bool = false
    var basecolor: Int = -65794
    var baseboard: String = ""
    var templatewidth: Int = 1080
    var templateheight: Int = 1719
    var marginstart: Float = 0
    var marginend: Float = 0
}

struct VivoPath {
    var points: [VivoPoint] = []
}

struct VivoPoint {
    var x: Float = 0
    var y: Float = 0
}

struct VivoParamGroup {
    var groupgravity: String = "center_vertical"
    var groupmarginend: Float = 0
    var subgroups: [VivoSubgroup] = []
}

struct VivoSubgroup {
    var subgroupnum: Int = 0
    var subgroupvisible: Bool = true
    var debuginfo: String = ""
    var lines: [VivoLine] = []
}

struct VivoLine {
    var linemarginbottom: Float = 0
    var images: [VivoImageParam] = []
    var texts: [VivoTextParam] = []
}

struct VivoImageParam {
    var piclinenum: Int = 0
    var picgravity: String = "start"
    var picpoint: VivoRect? = nil
    var picmarginstart: Float = 0
    var picmarginend: Float = 0
    var pic: String = ""
    var issvg: Bool = false
    var iscamerapic: Bool = false
    var picparamsidetype: Int = 0
    var picid: Int = 0
    var isneedantialias: Bool = true
    var isforcedrawdivider: Bool = false
}

struct VivoTextParam {
    var linenum: Int = 0
    var textgravity: String = "start"
    var textpoint: VivoRect? = nil
    var textplanbpoint: VivoRect? = nil
    var text: String = ""
    var textsize: Float = 0
    var textfontweight: Int = 400
    var textcolor: String = "#FF000000"
    var letterspacing: Float = 0
    var typeface: Int = 0
    var texttype: Int = 0
    var iscustomtext: Int = 0
    var timetype: Int = -2
    var textmarginstart: Float = 0
    var textmarginend: Float = 0
}

struct VivoRect {
    var left: Float = 0
    var top: Float = 0
    var right: Float = 0
    var bottom: Float = 0
}

struct VivoWatermarkTemplate {
    var frame: VivoFrameConfig = VivoFrameConfig()
    var paths: [VivoPath] = []
    var groups: [VivoParamGroup] = []
}

struct VivoRenderConfig {
    var deviceName: String? = nil
    var timeText: String? = nil
    var locationText: String? = nil
    var lensInfo: String? = nil
}
