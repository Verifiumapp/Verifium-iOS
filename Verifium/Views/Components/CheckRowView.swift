import SwiftUI

struct CheckRowView: View {
    let check: SecurityCheck

    var body: some View {
        HStack(spacing: 14) {

            // Status icon with glow
            ZStack {
                Circle()
                    .fill(check.status.color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: check.status.icon)
                    .font(.system(size: 18))
                    .foregroundColor(check.status.color)
                    .shadow(color: check.status.color.opacity(0.6), radius: 4)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(check.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    SeverityDot(severity: check.severity)
                    Text(check.shortDescription)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            // Detected value or chevron
            VStack(alignment: .trailing, spacing: 2) {
                if let value = check.detectedValue {
                    if check.id == "os_version", value.contains("|") {
                        let parts = value.split(separator: "|")
                        HStack(spacing: 3) {
                            Text(String(parts[0]))
                                .foregroundColor(AppColors.red)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 7))
                                .foregroundColor(AppColors.textSecondary)
                            Text(String(parts[1]))
                                .foregroundColor(AppColors.green)
                        }
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                    } else {
                        Text(value)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(AppColors.textMono)
                            .lineLimit(1)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(check.status.isFailing
                                ? AppColors.red.opacity(0.25)
                                : AppColors.cardBorder,
                                lineWidth: 1)
                )
        )
        .overlay(alignment: .topTrailing) {
            if check.status == .manualRequired {
                Circle()
                    .fill(AppColors.red)
                    .frame(width: 8, height: 8)
                    .offset(x: -6, y: 6)
            }
        }
    }
}

struct SeverityDot: View {
    let severity: CheckSeverity
    var body: some View {
        Circle()
            .fill(severity.color.opacity(0.40))
            .frame(width: 6, height: 6)
    }
}
