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
                Color.surfaceDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Quality Section (matches Android SettingsDialog quality slider)
                        VStack(alignment: .leading, spacing: 12) {
                            LiquidSectionHeader(text: L10n.tr("label_quality"))
                            
                            HStack {
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
                                
                                Text("\(viewModel.saveQuality)%")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.accentPrimary)
                                    .frame(width: 44, alignment: .trailing)
                            }

                            if !proRepo.isProUser {
                                Text(L10n.tr("quality_limit_notice"))
                                    .font(.system(size: 11))
                                    .foregroundColor(.textTertiary)
                            }
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.063))

                        // Account Section (matches Android SettingsDialog account section)
                        VStack(alignment: .leading, spacing: 12) {
                            LiquidSectionHeader(text: L10n.tr("label_account"))

                            if authViewModel.isSignedIn {
                                // Signed-in state
                                VStack(spacing: 12) {
                                    HStack(spacing: 12) {
                                        // User avatar placeholder
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.accentPrimary)

                                        VStack(alignment: .leading, spacing: 2) {
                                            if let name = authViewModel.userName {
                                                Text(name)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.textPrimary)
                                            }
                                            if let email = authViewModel.userEmail {
                                                Text(email)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.textSecondary)
                                            }
                                        }

                                        Spacer()

                                        // License badge
                                        if proRepo.isProUser {
                                            Text("PRO")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.accentPrimary)
                                                )
                                        }
                                    }

                                    // Sign out button
                                    Button(action: {
                                        authViewModel.signOut()
                                    }) {
                                        Text(L10n.tr("btn_sign_out"))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.textPrimary)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 40)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.surfaceLight)
                                            )
                                    }
                                }
                            } else {
                                // Signed-out state — Google Sign-In
                                VStack(spacing: 12) {
                                    Text(L10n.tr("sign_in_description"))
                                        .font(.system(size: 13))
                                        .foregroundColor(.textTertiary)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)

                                    Button(action: {
                                        authViewModel.signInWithGoogle()
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "g.circle.fill")
                                                .font(.system(size: 16))
                                            Text(L10n.tr("btn_sign_in_google"))
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 48)
                                        .background(
                                            AndroidAccentGradientButtonBackground(cornerRadius: 12)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                    .disabled(authViewModel.isLoading)
                                    .opacity(authViewModel.isLoading ? 0.6 : 1.0)
                                }
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
                            Text(L10n.tr("btn_close"))
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
            }
            .navigationTitle(L10n.tr("title_settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.surfaceDark, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

