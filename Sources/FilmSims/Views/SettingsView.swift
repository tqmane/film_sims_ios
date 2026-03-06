import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: FilmSimsViewModel
    @ObservedObject private var authViewModel = AuthViewModel.shared
    @ObservedObject private var proRepo = ProUserRepository.shared

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.openURL) private var openURL

    private static let purchaseURL = URL(string: "https://tqmane.booth.pm/")!

    private var appVersionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case let (version?, build?):
            return "\(version) (\(build))"
        case let (version?, nil):
            return version
        case let (nil, build?):
            return build
        default:
            return "—"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let metrics = LayoutMetrics.from(
                size: geometry.size,
                horizontalSizeClass: horizontalSizeClass
            )
            let horizontalInset = metrics.category == .compact ? 16.0 : 20.0
            let topPadding = max(geometry.safeAreaInsets.top, metrics.category == .compact ? 8 : 24)
            let bottomPadding = max(geometry.safeAreaInsets.bottom, metrics.category == .compact ? 16 : 24)
            let cardWidth = min(geometry.size.width - (horizontalInset * 2), metrics.usesSidebar ? 560 : 520)

            ZStack {
                Color.black.opacity(0.42)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack {
                        settingsCard(metrics: metrics)
                            .frame(width: max(280, cardWidth))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, horizontalInset)
                    .padding(.top, topPadding)
                    .padding(.bottom, bottomPadding)
                }
            }
            .environment(\.layoutMetrics, metrics)
        }
        .onDisappear {
            viewModel.saveSettings()
        }
    }

    private func settingsCard(metrics: LayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.category == .compact ? 18 : 20) {
            header(metrics: metrics)

            qualitySection(metrics: metrics)

            Rectangle()
                .fill(Color.white.opacity(0.094))
                .frame(height: 1)

            accountSection(metrics: metrics)

            versionSection(metrics: metrics)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)

            closeButton(metrics: metrics)
        }
        .padding(metrics.category == .compact ? 20 : 28)
        .background(
            RoundedRectangle(
                cornerRadius: metrics.category == .compact ? 26 : 32,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [Color(hex: "#1A1A22"), Color(hex: "#0A0A10")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: metrics.category == .compact ? 26 : 32,
                    style: .continuous
                )
                .stroke(Color.white.opacity(0.11), lineWidth: 1)
            )
        )
    }

    private func header(metrics: LayoutMetrics) -> some View {
        HStack(spacing: metrics.category == .compact ? 12 : 16) {
            ZStack {
                RoundedRectangle(cornerRadius: metrics.category == .compact ? 12 : 13, style: .continuous)
                    .fill(Color.accentPrimary.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: metrics.category == .compact ? 12 : 13, style: .continuous)
                            .stroke(Color.accentPrimary.opacity(0.25), lineWidth: 1)
                    )

                Image(systemName: "gearshape.fill")
                    .font(.system(size: metrics.category == .compact ? 18 : 22, weight: .medium))
                    .foregroundColor(.accentPrimary)
            }
            .frame(width: metrics.category == .compact ? 38 : 42, height: metrics.category == .compact ? 38 : 42)

            Text(L10n.tr("title_settings"))
                .font(.system(size: metrics.category == .compact ? 20 : 22, weight: .semibold))
                .foregroundColor(.textPrimary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: metrics.category == .compact ? 14 : 16, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.086))
                            .overlay(Circle().stroke(Color.white.opacity(0.102), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func qualitySection(metrics: LayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("label_quality", metrics: metrics)

            HStack(alignment: .center) {
                Spacer()
                Text("\(viewModel.saveQuality)%")
                    .font(.system(size: metrics.category == .compact ? 15 : 16, weight: .semibold))
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
                    .font(.system(size: metrics.category == .compact ? 11 : 12))
                    .foregroundColor(.textTertiary)
                    .padding(.leading, 4)
            }
        }
    }

    private func accountSection(metrics: LayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("label_account", metrics: metrics)

            if authViewModel.isSignedIn {
                signedInView(metrics: metrics)
            } else {
                signedOutView(metrics: metrics)
            }

            if let mismatchVersion = proRepo.licenseMismatchVersion {
                warningCard(
                    text: L10n.tr("label_license_version_mismatch", mismatchVersion),
                    metrics: metrics
                )
            }

            if !proRepo.isPermanentLicense {
                purchaseLinkCard(metrics: metrics)
            }
        }
    }

    private func signedInView(metrics: LayoutMetrics) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.accentPrimary.opacity(0.18))
                        .overlay(Circle().stroke(Color.accentPrimary.opacity(0.45), lineWidth: 2))
                        .frame(width: metrics.category == .compact ? 42 : 46, height: metrics.category == .compact ? 42 : 46)

                    Text(String(authViewModel.userName?.first?.uppercased() ?? "?"))
                        .font(.system(size: metrics.category == .compact ? 16 : 18, weight: .bold))
                        .foregroundColor(.accentPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let name = authViewModel.userName {
                        Text(name)
                            .font(.system(size: metrics.category == .compact ? 14 : 15, weight: .medium))
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)
                    }

                    if let email = authViewModel.userEmail {
                        Text(email)
                            .font(.system(size: metrics.category == .compact ? 12 : 13))
                            .foregroundColor(.textTertiary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if proRepo.isProUser {
                    Text(proRepo.isPermanentLicense ? L10n.tr("label_license_permanent") : L10n.tr("label_pro"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#0C0C10"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
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
                    .fill(Color.white.opacity(0.071))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.102), lineWidth: 1)
                    )
            )

            Button {
                authViewModel.signOut()
            } label: {
                Text(L10n.tr("btn_sign_out"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.078))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.118), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func signedOutView(metrics: LayoutMetrics) -> some View {
        VStack(spacing: 14) {
            Text(L10n.tr("sign_in_description"))
                .font(.system(size: metrics.category == .compact ? 13 : 14))
                .foregroundColor(.textTertiary)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                authViewModel.signInWithGoogle()
            } label: {
                Text(L10n.tr("btn_sign_in_google"))
                    .font(.system(size: metrics.category == .compact ? 14 : 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AndroidAccentGradientButtonBackground(cornerRadius: 16))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(authViewModel.isLoading)
            .opacity(authViewModel.isLoading ? 0.6 : 1)
        }
    }

    private func warningCard(text: String, metrics: LayoutMetrics) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: metrics.category == .compact ? 12 : 13))
                .foregroundColor(.accentPrimary)

            Text(text)
                .font(.system(size: metrics.category == .compact ? 12 : 13))
                .foregroundColor(.accentPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentPrimary.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.accentPrimary.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private func purchaseLinkCard(metrics: LayoutMetrics) -> some View {
        Button {
            openURL(Self.purchaseURL)
        } label: {
            Text(L10n.tr("label_purchase_license"))
                .font(.system(size: metrics.category == .compact ? 12 : 13, weight: .medium))
                .foregroundColor(.accentPrimary)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentPrimary.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.accentPrimary.opacity(0.20), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func versionSection(metrics: LayoutMetrics) -> some View {
        VStack(spacing: 4) {
            Text("FilmSims")
                .font(.system(size: metrics.category == .compact ? 12 : 13, weight: .medium))
                .foregroundColor(.textSecondary)

            Text(appVersionString)
                .font(.system(size: metrics.category == .compact ? 11 : 12))
                .foregroundColor(.textTertiary)
        }
    }

    private func closeButton(metrics: LayoutMetrics) -> some View {
        Button {
            dismiss()
        } label: {
            Text(L10n.tr("btn_close"))
                .font(.system(size: metrics.category == .compact ? 15 : 16, weight: .medium))
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.078))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.118), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ key: String, metrics: LayoutMetrics) -> some View {
        Text(L10n.tr(key).uppercased())
            .font(.system(size: metrics.category == .compact ? 10 : 11, weight: .semibold))
            .foregroundColor(.textTertiary)
            .tracking(0.18)
            .padding(.leading, 2)
    }
}
