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
                    .scaledFont(size: 18, relativeTo: .body)
                    .foregroundColor(check.status.color)
                    .shadow(color: check.status.color.opacity(0.6), radius: 4)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(check.title)
                    .scaledFont(size: 14, weight: .semibold, relativeTo: .subheadline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    SeverityDot(severity: check.severity)
                    Text(check.shortDescription)
                        .scaledFont(size: 12, relativeTo: .footnote)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            // Detected value or chevron
            VStack(alignment: .trailing, spacing: 2) {
                if let value = check.detectedValue {
                    if let versions = check.osVersionComponents {
                        HStack(spacing: 3) {
                            Text(versions.current)
                                .foregroundColor(AppColors.red)
                            Image(systemName: "arrow.right")
                                .scaledFont(size: 7, relativeTo: .caption2)
                                .foregroundColor(AppColors.textSecondary)
                            Text(versions.latest)
                                .foregroundColor(AppColors.green)
                        }
                        .scaledFont(size: 10, weight: .medium, design: .monospaced, relativeTo: .caption)
                        .lineLimit(1)
                    } else {
                        Text(value)
                            .scaledFont(size: 10, design: .monospaced, relativeTo: .caption)
                            .foregroundColor(AppColors.textMono)
                            .lineLimit(1)
                    }
                }
                Image(systemName: "chevron.right")
                    .scaledFont(size: 11, weight: .semibold, relativeTo: .caption)
                    .foregroundColor(AppColors.textSecondary)
                    .accessibilityHidden(true)
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
