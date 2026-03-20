import SwiftUI

struct SettingsView: View {
    var vm: AuditViewModel
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = true
    @State private var showWelcome = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    private var iosVersion: String {
        UIDevice.current.systemVersion
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // MARK: - Actions

                        actionsSection

                        // MARK: - About

                        aboutSection

                        // MARK: - Legal

                        legalSection

                        // MARK: - Copyright

                        Text(NSLocalizedString("settings.legal_notice", comment: ""))
                            .scaledFont(size: 11, relativeTo: .caption)
                            .foregroundColor(AppColors.textSecondary.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationTitle(NSLocalizedString("tab.settings", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $showWelcome) {
            WelcomeDisclaimerView {
                showWelcome = false
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: NSLocalizedString("settings.actions", comment: ""),
                          icon: "bolt.fill",
                          color: AppColors.teal)

            // Run Scan
            Button {
                Task { await vm.runScan() }
            } label: {
                HStack(spacing: 12) {
                    if vm.isScanning {
                        ProgressView()
                            .tint(AppColors.background)
                            .scaleEffect(0.85)
                        Text(NSLocalizedString("dashboard.scanning", comment: ""))
                            .scaledFont(size: 15, weight: .semibold, design: .monospaced, relativeTo: .subheadline)
                    } else {
                        Image(systemName: "play.fill")
                        Text(NSLocalizedString("dashboard.run_scan", comment: ""))
                            .scaledFont(size: 15, weight: .semibold, design: .monospaced, relativeTo: .subheadline)
                    }
                }
                .foregroundColor(AppColors.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [AppColors.teal, AppColors.blue],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: AppColors.teal.opacity(0.35), radius: 12, y: 4)
            }
            .disabled(vm.isScanning)

            // Reset manual checks
            Button {
                withAnimation(.easeOut(duration: 0.3)) {
                    vm.resetAllManualChecks()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.counterclockwise")
                    Text(NSLocalizedString("dashboard.reset_manual", comment: ""))
                        .scaledFont(size: 15, weight: .semibold, design: .monospaced, relativeTo: .subheadline)
                }
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.cardBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppColors.cardBorder, lineWidth: 1)
                        )
                )
            }
            .disabled(!vm.hasCompletedManualChecks)
            .opacity(vm.hasCompletedManualChecks ? 1.0 : 0.4)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: NSLocalizedString("settings.about", comment: ""),
                          icon: "info.circle.fill",
                          color: AppColors.blue)

            VStack(alignment: .leading, spacing: 16) {
                Text(NSLocalizedString("settings.about_description", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider().background(AppColors.cardBorder)

                infoRow(label: NSLocalizedString("settings.app_version", comment: ""),
                        value: appVersion)

                infoRow(label: NSLocalizedString("settings.ios_version", comment: ""),
                        value: "iOS \(iosVersion)")

                Divider().background(AppColors.cardBorder)

                // Show welcome disclaimer again
                Button {
                    showWelcome = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .scaledFont(size: 13, relativeTo: .footnote)
                        Text(NSLocalizedString("settings.show_welcome", comment: ""))
                            .scaledFont(size: 13, weight: .medium, relativeTo: .footnote)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .scaledFont(size: 11, relativeTo: .caption)
                    }
                    .foregroundColor(AppColors.textPrimary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.cardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Legal Section

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: NSLocalizedString("settings.legal", comment: ""),
                          icon: "lock.shield.fill",
                          color: AppColors.purple)

            VStack(spacing: 0) {
                if let url = URL(string: "https://verifium.app/privacy") {
                    Link(destination: url) {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.raised.fill")
                                .scaledFont(size: 13, relativeTo: .footnote)
                            Text(NSLocalizedString("settings.privacy_policy", comment: ""))
                                .scaledFont(size: 13, weight: .medium, relativeTo: .footnote)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .scaledFont(size: 11, relativeTo: .caption)
                        }
                        .foregroundColor(AppColors.textPrimary)
                        .padding(16)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.cardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .scaledFont(size: 12, weight: .semibold, design: .monospaced, relativeTo: .footnote)
            .foregroundColor(color)
            .tracking(1)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .scaledFont(size: 13, weight: .medium, relativeTo: .footnote)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .scaledFont(size: 13, design: .monospaced, relativeTo: .footnote)
                .foregroundColor(AppColors.textMono)
        }
    }
}
