import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: FilmSimsViewModel
    @Environment(\.dismiss) private var dismiss

    private var appVersionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let version, let build {
            return "\(version) (\(build))"
        }
        return version ?? "Unknown"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.surfaceDark.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Image Quality Setting
                    VStack(alignment: .leading, spacing: 12) {
                        Text("QUALITY")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.textTertiary)
                            .tracking(1.0)
                        
                        HStack {
                            Slider(value: Binding(
                                get: { Double(viewModel.saveQuality) },
                                set: { viewModel.saveQuality = max(10, Int($0)) }
                            ), in: 10...100, step: 1)
                            .tint(.accentPrimary)
                            
                            Text("\(viewModel.saveQuality)%")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.accentPrimary)
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                    
                    Spacer()
                    
                    // Version Info
                    VStack(spacing: 4) {
                        Text("FilmSims")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textSecondary)
                        Text("Version \(appVersionString)")
                            .font(.system(size: 12))
                            .foregroundColor(.textTertiary)
                    }
                    .padding(.bottom, 12)
                    
                    // Close Button
                    Button(action: {
                        viewModel.saveSettings()
                        dismiss()
                    }) {
                        Text("Close")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.surfaceLight)
                            )
                    }
                }
                .padding(24)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.surfaceDark, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
