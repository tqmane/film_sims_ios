import SwiftUI

// MARK: - Watermark Controls (matches Android LiquidWatermarkControls exactly)

struct WatermarkView: View {
    @ObservedObject var viewModel: FilmSimsViewModel

    // Local editable state — initialized from EXIF and synced to/from ViewModel
    // Matches Android's `remember(watermarkState.deviceName) { mutableStateOf(...) }` pattern
    @State private var localDevice   = ""
    @State private var localLens     = ""
    @State private var localTime     = ""
    @State private var localLocation = ""

    // Styles available per brand (matches Android)
    private let honorStyles: [(String, WatermarkProcessor.WatermarkStyle)] = [
        ("watermark_frame",    .frame),
        ("watermark_text",     .text),
        ("watermark_frame_yg", .frameYG),
        ("watermark_text_yg",  .textYG),
    ]
    private let meizuStyles: [(String, WatermarkProcessor.WatermarkStyle)] = [
        ("meizu_norm", .meizuNorm),
        ("meizu_pro",  .meizuPro),
        ("meizu_z1",   .meizuZ1),
        ("meizu_z2",   .meizuZ2),
        ("meizu_z3",   .meizuZ3),
        ("meizu_z4",   .meizuZ4),
        ("meizu_z5",   .meizuZ5),
        ("meizu_z6",   .meizuZ6),
        ("meizu_z7",   .meizuZ7),
    ]
    private let vivoStyles: [(String, WatermarkProcessor.WatermarkStyle)] = [
        ("vivo_zeiss",          .vivoZeiss),
        ("vivo_classic",        .vivoClassic),
        ("vivo_pro",            .vivoPro),
        ("vivo_iqoo",           .vivoIqoo),
        ("vivo_zeiss_v1",       .vivoZeissV1),
        ("vivo_zeiss_sonnar",   .vivoZeissSonnar),
        ("vivo_zeiss_humanity", .vivoZeissHumanity),
        ("vivo_iqoo_v1",        .vivoIqooV1),
        ("vivo_iqoo_humanity",  .vivoIqooHumanity),
        ("vivo_zeiss_frame",    .vivoZeissFrame),
        ("vivo_zeiss_overlay",  .vivoZeissOverlay),
        ("vivo_zeiss_center",   .vivoZeissCenter),
        ("vivo_frame",          .vivoFrame),
        ("vivo_frame_time",     .vivoFrameTime),
        ("vivo_iqoo_frame",     .vivoIqooFrame),
        ("vivo_iqoo_frame_time",.vivoIqooFrameTime),
        ("vivo_os",             .vivoOS),
        ("vivo_os_corner",      .vivoOSCorner),
        ("vivo_os_simple",      .vivoOSSimple),
        ("vivo_event",          .vivoEvent),
        ("vivo_zeiss_0",        .vivoZeiss0),
        ("vivo_zeiss_1",        .vivoZeiss1),
        ("vivo_zeiss_2",        .vivoZeiss2),
        ("vivo_zeiss_3",        .vivoZeiss3),
        ("vivo_zeiss_4",        .vivoZeiss4),
        ("vivo_zeiss_5",        .vivoZeiss5),
        ("vivo_zeiss_6",        .vivoZeiss6),
        ("vivo_zeiss_7",        .vivoZeiss7),
        ("vivo_zeiss_8",        .vivoZeiss8),
        ("vivo_iqoo_4",         .vivoIqoo4),
        ("vivo_common_iqoo4",   .vivoCommonIqoo4),
        ("vivo_1",              .vivo1),
        ("vivo_2",              .vivo2),
        ("vivo_3",              .vivo3),
        ("vivo_4",              .vivo4),
        ("vivo_5",              .vivo5),
    ]
    private let tecnoStyles: [(String, WatermarkProcessor.WatermarkStyle)] = [
        ("tecno_1", .tecno1),
        ("tecno_2", .tecno2),
        ("tecno_3", .tecno3),
        ("tecno_4", .tecno4),
    ]

    // Styles that hide specific input fields (matches Android noDeviceStyles/noLensStyles/noTimeStyles)
    private let noDeviceStyles: Set<WatermarkProcessor.WatermarkStyle> = [
        .meizuZ6, .meizuZ7, .vivoOSCorner, .vivoOSSimple
    ]
    private let noLensStyles: Set<WatermarkProcessor.WatermarkStyle> = [
        .frameYG, .textYG, .vivoClassic, .vivoZeissHumanity, .vivoIqooHumanity,
        .vivoFrame, .vivoIqooFrame, .vivoOSCorner, .vivoOSSimple, .tecno1
    ]
    private let noTimeStyles: Set<WatermarkProcessor.WatermarkStyle> = [
        .frameYG, .textYG, .vivoZeissHumanity, .vivoIqooHumanity,
        .vivoFrame, .vivoIqooFrame, .vivoOSCorner, .vivoOSSimple
    ]

    private var availableStyles: [(String, WatermarkProcessor.WatermarkStyle)] {
        switch viewModel.watermarkBrand {
        case "Honor":  return honorStyles
        case "Meizu":  return meizuStyles
        case "Vivo":   return vivoStyles
        case "TECNO":  return tecnoStyles
        default:       return []
        }
    }

    var body: some View {
        let style = viewModel.watermarkStyle
        let hasStyle = style != .none
        let showDevice = hasStyle && !noDeviceStyles.contains(style)
        let showLens   = hasStyle && !noLensStyles.contains(style)
        let showTime   = hasStyle && !noTimeStyles.contains(style)

        VStack(alignment: .leading, spacing: 0) {
            // Section header "WATERMARK"
            Text(L10n.tr("header_watermark").uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.accentPrimary)
                .tracking(0.15)
                .padding(.bottom, 4)

            // Brand row
            HStack(spacing: 0) {
                Image(systemName: "seal.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.accentSecondary)
                    .frame(width: 18)
                Spacer().frame(width: 12)
                Text(L10n.tr("label_watermark_brand"))
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .padding(.trailing, 12)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(["None", "Honor", "Meizu", "Vivo", "TECNO"], id: \.self) { brand in
                            let labelKey = brand == "None" ? "brand_none"
                                        : brand == "Vivo" ? "brand_vivo"
                                        : "brand_\(brand.lowercased())"
                            ChipButton(
                                title: L10n.tr(labelKey),
                                isSelected: viewModel.watermarkBrand == brand
                            ) {
                                viewModel.watermarkBrand = brand
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)

            // Style row (only when brand is selected)
            if !availableStyles.isEmpty {
                HStack(spacing: 0) {
                    Spacer().frame(width: 30)
                    Text(L10n.tr("label_watermark_style"))
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                        .padding(.trailing, 12)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(availableStyles, id: \.0) { (key, wStyle) in
                                ChipButton(
                                    title: L10n.tr(key),
                                    isSelected: viewModel.watermarkStyle == wStyle
                                ) {
                                    viewModel.watermarkStyle = wStyle
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Conditional input fields
            if showDevice {
                WatermarkInputRow(label: L10n.tr("label_watermark_device"),
                                  text: $localDevice)
            }
            if showLens {
                WatermarkInputRow(label: L10n.tr("label_watermark_lens"),
                                  text: $localLens)
            }
            if showTime {
                WatermarkInputRow(label: L10n.tr("label_watermark_time"),
                                  text: $localTime)
                WatermarkInputRow(label: L10n.tr("label_watermark_location"),
                                  text: $localLocation)
            }
        }
        .onAppear {
            localDevice   = viewModel.watermarkDeviceName
            localLens     = viewModel.watermarkLensInfo
            localTime     = viewModel.watermarkTimeText
            localLocation = viewModel.watermarkLocationText
        }
        // Sync FROM ViewModel when a new image is loaded (EXIF update)
        .onChange(of: viewModel.watermarkDeviceName)   { _, v in if localDevice   != v { localDevice   = v } }
        .onChange(of: viewModel.watermarkLensInfo)     { _, v in if localLens     != v { localLens     = v } }
        .onChange(of: viewModel.watermarkTimeText)     { _, v in if localTime     != v { localTime     = v } }
        .onChange(of: viewModel.watermarkLocationText) { _, v in if localLocation != v { localLocation = v } }
        // Sync TO ViewModel on user edits (triggers watermark re-render with debounce)
        .onChange(of: localDevice)   { _, v in if viewModel.watermarkDeviceName   != v { viewModel.watermarkDeviceName   = v } }
        .onChange(of: localLens)     { _, v in if viewModel.watermarkLensInfo     != v { viewModel.watermarkLensInfo     = v } }
        .onChange(of: localTime)     { _, v in if viewModel.watermarkTimeText     != v { viewModel.watermarkTimeText     = v } }
        .onChange(of: localLocation) { _, v in if viewModel.watermarkLocationText != v { viewModel.watermarkLocationText = v } }
    }
}

// MARK: - Input row matching Android LiquidWatermarkInputRow
struct WatermarkInputRow: View {
    let label: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: 30)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.textTertiary)
                .frame(width: 56, alignment: .leading)
            Spacer().frame(width: 8)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.glassSurfaceDark)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.glassBorderAndroid, lineWidth: 1)
                    )
                    .frame(height: 34)
                TextField("", text: $text)
                    .font(.system(size: 11))
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 8)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 4)
    }
}

// Keep CustomTextField for backward-compat but it's no longer used in WatermarkView.
struct CustomTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.accentPrimary)
                .tracking(0.12)
                .textCase(.uppercase)
            TextField(placeholder, text: $text)
                .font(.system(size: 14))
                .foregroundColor(.textPrimary)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.glassSurfaceDark)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.glassBorderAndroid, lineWidth: 1)
                        )
                )
        }
    }
}

