import SwiftUI

struct WatermarkView: View {
    @ObservedObject var viewModel: FilmSimsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.and.pencil.and.ellipsis")
                    .foregroundColor(.accentPrimary)

                Text(L10n.tr("header_watermark"))
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)

                Spacer()

                Toggle("", isOn: $viewModel.watermarkEnabled)
                    .labelsHidden()
                    .tint(.accentPrimary)
                    .scaleEffect(0.8)
            }
            .padding(.vertical, 6)
            
            if viewModel.watermarkEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    LiquidSectionHeader(text: L10n.tr("label_watermark_style"))
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ChipButton(title: L10n.tr("watermark_none"), isSelected: viewModel.watermarkStyle == .none) {
                                viewModel.watermarkStyle = .none
                            }
                            
                            // Honor styles
                            ChipButton(title: "Honor Frame", isSelected: viewModel.watermarkStyle == .frame) {
                                viewModel.watermarkStyle = .frame
                            }
                            ChipButton(title: "Honor Text", isSelected: viewModel.watermarkStyle == .text) {
                                viewModel.watermarkStyle = .text
                            }
                            
                            // Meizu styles
                            ChipButton(title: "Meizu Normal", isSelected: viewModel.watermarkStyle == .meizuNorm) {
                                viewModel.watermarkStyle = .meizuNorm
                            }
                            ChipButton(title: "Meizu Pro", isSelected: viewModel.watermarkStyle == .meizuPro) {
                                viewModel.watermarkStyle = .meizuPro
                            }
                            
                            // Vivo styles
                            ChipButton(title: "Vivo Zeiss", isSelected: viewModel.watermarkStyle == .vivoZeiss) {
                                viewModel.watermarkStyle = .vivoZeiss
                                viewModel.watermarkDeviceName = "X100 Pro"
                            }
                            ChipButton(title: "Vivo Classic", isSelected: viewModel.watermarkStyle == .vivoClassic) {
                                viewModel.watermarkStyle = .vivoClassic
                                viewModel.watermarkDeviceName = "X100 Pro"
                            }
                            ChipButton(title: "Vivo Pro", isSelected: viewModel.watermarkStyle == .vivoPro) {
                                viewModel.watermarkStyle = .vivoPro
                                viewModel.watermarkDeviceName = "X100 Pro"
                            }
                            ChipButton(title: "Vivo Frame", isSelected: viewModel.watermarkStyle == .vivoFrame) {
                                viewModel.watermarkStyle = .vivoFrame
                                viewModel.watermarkDeviceName = "X100 Pro"
                            }
                            
                            // Tecno styles
                            ChipButton(title: "Tecno 1", isSelected: viewModel.watermarkStyle == .tecno1) {
                                viewModel.watermarkStyle = .tecno1
                                viewModel.watermarkDeviceName = "TECNO"
                            }
                        }
                    }
                }
                
                // Input Fields
                VStack(spacing: 12) {
                    // Device Name
                    CustomTextField(
                        label: L10n.tr("label_watermark_device"),
                        placeholder: "HONOR Magic6 Pro",
                        text: $viewModel.watermarkDeviceName
                    )
                    
                    // Lens Info
                    CustomTextField(
                        label: L10n.tr("label_watermark_lens"),
                        placeholder: "27mm  f/1.9  1/100s  ISO1600",
                        text: $viewModel.watermarkLensInfo
                    )
                    
                    // Time
                    CustomTextField(
                        label: L10n.tr("label_watermark_time"),
                        placeholder: "2024-02-18 00:30",
                        text: $viewModel.watermarkTimeText
                    )
                    
                    // Location
                    CustomTextField(
                        label: L10n.tr("label_watermark_location"),
                        placeholder: "Tokyo, Japan",
                        text: $viewModel.watermarkLocationText
                    )
                }
            }
        }
        .padding(.bottom, 8)
    }
}

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
