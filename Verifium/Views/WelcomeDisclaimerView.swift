import SwiftUI

struct WelcomeDisclaimerView: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(AppColors.teal.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 36))
                            .foregroundColor(AppColors.teal)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 20)

                    // Title
                    Text(NSLocalizedString("welcome.title", comment: ""))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 6)

                    Text(NSLocalizedString("welcome.subtitle", comment: ""))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppColors.teal)
                        .tracking(2)
                        .padding(.bottom, 28)

                    // Disclaimer card
                    VStack(alignment: .leading, spacing: 16) {
                        DisclaimerRow(
                            icon: "xmark.shield",
                            iconColor: AppColors.orange,
                            text: NSLocalizedString("welcome.not_antivirus", comment: "")
                        )
                        Divider()
                            .background(AppColors.cardBorder)
                        DisclaimerRow(
                            icon: "checklist",
                            iconColor: AppColors.teal,
                            text: NSLocalizedString("welcome.what_it_does", comment: "")
                        )
                        Divider()
                            .background(AppColors.cardBorder)
                        DisclaimerRow(
                            icon: "person.fill.checkmark",
                            iconColor: AppColors.blue,
                            text: NSLocalizedString("welcome.manual_review", comment: "")
                        )
                        Divider()
                            .background(AppColors.cardBorder)
                        DisclaimerRow(
                            icon: "exclamationmark.shield",
                            iconColor: AppColors.blue,
                            text: NSLocalizedString("welcome.disclaimer", comment: "")
                        )
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppColors.cardBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.cardBorder, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)

                    Spacer(minLength: 32)

                    // CTA button
                    Button(action: onDismiss) {
                        Text(NSLocalizedString("welcome.cta", comment: ""))
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
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
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
                }
            }
        }
    }
}

private struct DisclaimerRow: View {
    let icon: String
    let iconColor: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 24)
                .padding(.top, 1)
            Text(text)
                .font(.subheadline)
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
