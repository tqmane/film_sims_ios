import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: FilmSimsViewModel
    @StateObject private var authViewModel = AuthViewModel()
    @ObservedObject private var proRepo = ProUserRepository.shared
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
                // Android SettingsDialog background: 1A1A22 → 0A0A10
                LinearGradient(
                    colors: [Color(hex: "#1A1A22"), Color(hex: "#0A0A10")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Quality Section
                        VStack(alignment: .leading, spacing: 8) {
                            // Android: SettingsSectionLabel style (TextLowEmphasis, 11sp SemiBold, tracking 0.18)
                            HStack {
                                Text(L10n.tr("label_quality").uppercased())
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.textTertiary)
                                    .tracking(0.18)
                                    .padding(.leading, 2)
                                Spacer()
                                // Android: 16sp SemiBold AccentPrimary
                                Text("\(viewModel.saveQuality)%")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.accentPrimary)
                            }
                            
                            LiquidSlider(
                                value: Binding(
                                    get: { Float(viewModel.saveQuality) },
                                    set: {
                                        let maxQ: Int = proRepo.isProUser ? 100 : 60
                                        viewModel.saveQuality = max(10, min(maxQ, Int($0.rounded())))
                                    }
                                ),
                                range: 10...Float(proRepo.isProUser ? 100 : 60)
                            )

                            if !proRepo.isProUser {
                                Text(L10n.tr("pro_quality_limit"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.textTertiary)
                                    .padding(.leading, 4)
                                    .padding(.top, 2)
                            }
                        }
                        
                        // Android: HorizontalDivider (0x18FFFFFF)
                        Rectangle()
                            .fill(Color.white.opacity(0.094))
                            .frame(height: 1)

                        // Account Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.tr("label_account").uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.textTertiary)
                                .tracking(0.18)
                                .padding(.leading, 2)

                            if authViewModel.isSignedIn {
                                signedInView
                            } else {
                                signedOutView
                            }
                        }
                        
                        Spacer().frame(height: 4)
                        
                        // Version Info
                        VStack(spacing: 4) {
                            Text("FilmSims")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.textSecondary)
                            Text("Version \(appVersionString)")
                                .font(.system(size: 12))
                                .foregroundColor(.textTertiary)
                        }
                        .padding(.bottom, 4)
                        
                        // Close Button (Android: height 52, cornerRadius 16, 0x14FFFFFF bg, 0x1E border)
                        Button {
                            viewModel.saveSettings()
                            dismiss()
                        } label: {
                            Text(L10n.tr("btn_close"))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white.opacity(0.078)) // 0x14FFFFFF
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(Color.white.opacity(0.118), lineWidth: 1) // 0x1EFFFFFF
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(28)
                }
            }
            .navigationTitle(L10n.tr("title_settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#1A1A22"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    // MARK: - Signed In View (matches Android user info card)
    private var signedInView: some View {
        VStack(spacing: 12) {
            // User info card: RoundedRect(14dp), 0x12FFFFFF bg, 0x1A border, h=16/v=14
            HStack(spacing: 14) {
                // Avatar: 46dp circle, AccentPrimary 18% bg, 45% border, initial letter
                ZStack {
                    Circle()
                        .fill(Color.accentPrimary.opacity(0.18))
                        .overlay(Circle().stroke(Color.accentPrimary.opacity(0.45), lineWidth: 2))
                        .frame(width: 46, height: 46)
                    Text(String(authViewModel.userName?.first?.uppercased() ?? "?"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.accentPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let name = authViewModel.userName {
                        Text(name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)
                    }
                    if let email = authViewModel.userEmail {
                        Text(email)
                            .font(.system(size: 13))
                            .foregroundColor(.textTertiary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if proRepo.isProUser {
                    // Android: gradient badge (AccentStart→AccentEnd), 22dp corner, 11sp Bold, #0C0C10 text
                    Text(L10n.tr("label_pro"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#0C0C10"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.accentStart, .accentEnd],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.071)) // 0x12FFFFFF
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.102), lineWidth: 1) // 0x1AFFFFFF
                    )
            )

            // Sign out button (Android: height 48, cornerRadius 14, 0x14FFFFFF, 0x1E border)
            Button {
                authViewModel.signOut()
            } label: {
                Text(L10n.tr("btn_sign_out"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textSecondary) // TextMediumEmphasis
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.078)) // 0x14FFFFFF
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.118), lineWidth: 1) // 0x1EFFFFFF
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Signed Out View
    private var signedOutView: some View {
        VStack(spacing: 14) {
            Text(L10n.tr("sign_in_description"))
                .font(.system(size: 14))
                .foregroundColor(.textTertiary)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Google Sign-In button (Android: height 52, cornerRadius 16, gradient)
            Button {
                authViewModel.signInWithGoogle()
            } label: {
                Text(L10n.tr("btn_sign_in_google"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        AndroidAccentGradientButtonBackground(cornerRadius: 16)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(authViewModel.isLoading)
            .opacity(authViewModel.isLoading ? 0.6 : 1.0)
        }
    }
}
