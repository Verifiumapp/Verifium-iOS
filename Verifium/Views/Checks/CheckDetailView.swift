import SwiftUI
import AudioToolbox

struct CheckDetailView: View {
    let check: SecurityCheck
    var vm: AuditViewModel
    var onMarkCompleted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showConfirmPass = false
    @State private var showConfirmFail = false
    @State private var isNavigating = false
    @State private var floatingPoints: Int? = nil

    private var liveCheck: SecurityCheck {
        vm.check(id: check.id) ?? check
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Status hero
                    statusHero

                    // Explanation
                    section(title: NSLocalizedString("detail.why", comment: ""),
                            icon: "questionmark.circle.fill",
                            color: AppColors.blue) {
                        Text(liveCheck.explanation)
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Guidance steps — shown for any non-passing, non-checking status
                    if !liveCheck.guidanceSteps.isEmpty && liveCheck.status != .passed && liveCheck.status != .checking {
                        section(title: NSLocalizedString("detail.how_to", comment: ""),
                                icon: "list.number",
                                color: AppColors.orange) {
                            guidanceSteps
                        }
                    }

                    // Detected value (auto checks)
                    if let value = liveCheck.detectedValue {
                        section(title: NSLocalizedString("detail.detected", comment: ""),
                                icon: "cpu.fill",
                                color: AppColors.teal) {
                            detectedValueContent(value: value, check: liveCheck)
                        }
                    }

                    // Detected value (auto checks) or Settings shortcut (manual checks)
                    if liveCheck.showsSettingsLink {
                        openSettingsButton
                    }

                    // Sources
                    if !liveCheck.sources.isEmpty {
                        section(title: NSLocalizedString("detail.sources", comment: ""),
                                icon: "link.badge.plus",
                                color: AppColors.purple) {
                            sourcesSection
                        }
                    }

                    // Manual action buttons — shown when manual review is needed/done
                    if liveCheck.status == .manualRequired || liveCheck.status.isManuallyReviewed {
                        manualActionButtons
                    }

                    Spacer(minLength: 32)
                }
                .padding(20)
            }
        }
        .overlay {
            if let pts = floatingPoints {
                FloatingPointsView(points: pts) {
                    floatingPoints = nil
                }
            }
        }
        .navigationTitle(liveCheck.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Sub-Views

    private var statusHero: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(liveCheck.status.color.opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: liveCheck.status.icon)
                    .scaledFont(size: 28, relativeTo: .title)
                    .foregroundColor(liveCheck.status.color)
                    .shadow(color: liveCheck.status.color.opacity(0.5), radius: 8)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(liveCheck.status.localizedLabel.uppercased())
                    .scaledFont(size: 10, weight: .bold, design: .monospaced, relativeTo: .caption)
                    .foregroundColor(liveCheck.status.color)
                    .tracking(2)

                Text(liveCheck.shortDescription)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    SeverityBadge(severity: liveCheck.severity)
                    CategoryBadge(category: liveCheck.category)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(liveCheck.status.color.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: liveCheck.status.color.opacity(0.15), radius: 12)
        .overlay(alignment: .topTrailing) {
            PointsBadge(
                points: liveCheck.earnedPoints > 0 ? liveCheck.earnedPoints : liveCheck.points,
                isEarned: liveCheck.status.isPassing
            )
                .offset(x: 6, y: -10)
        }
    }

    private var guidanceSteps: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(liveCheck.guidanceSteps.enumerated()), id: \.offset) { idx, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(idx + 1)")
                        .scaledFont(size: 12, weight: .bold, design: .monospaced, relativeTo: .footnote)
                        .foregroundColor(AppColors.background)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(AppColors.orange))

                    Text(step)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(liveCheck.sources) { source in
                if let url = source.url {
                    Link(destination: url) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square")
                                .scaledFont(size: 10, relativeTo: .caption)
                                .foregroundColor(AppColors.purple)
                            Text(source.name)
                                .scaledFont(size: 11, relativeTo: .caption)
                                .foregroundColor(AppColors.purple)
                                .underline()
                                .lineLimit(2)
                            Spacer()
                        }
                    }
                } else {
                    Text(source.name)
                        .scaledFont(size: 11, relativeTo: .caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    private var manualActionButtons: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString("detail.manual_prompt", comment: ""))
                .scaledFont(size: 11, design: .monospaced, relativeTo: .caption)
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 12) {
                VerificationButton(
                    label: NSLocalizedString("detail.mark_fail", comment: ""),
                    icon: "xmark.shield.fill",
                    activeColor: AppColors.red,
                    isSelected: liveCheck.status == .manualFailed,
                    isDisabled: liveCheck.status == .manualFailed
                ) {
                    triggerFeedback(passed: false)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                        vm.markCheck(id: liveCheck.id, passed: false)
                    }
                    scheduleAutoNavigation()
                }

                VerificationButton(
                    label: NSLocalizedString("detail.mark_pass", comment: ""),
                    icon: "checkmark.shield.fill",
                    activeColor: AppColors.teal,
                    isSelected: liveCheck.status == .manualPassed,
                    isDisabled: liveCheck.status == .manualPassed
                ) {
                    floatingPoints = liveCheck.points
                    triggerFeedback(passed: true)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                        vm.markCheck(id: liveCheck.id, passed: true)
                    }
                    scheduleAutoNavigation()
                }
            }

            // Reset link — only visible after a choice is made
            if liveCheck.status.isManuallyReviewed {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        vm.resetManualCheck(id: liveCheck.id)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .scaledFont(size: 11, relativeTo: .caption)
                        Text(NSLocalizedString("detail.reset", comment: ""))
                            .scaledFont(size: 12, relativeTo: .footnote)
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                )
        )
    }

    /// After marking pass/fail, wait briefly for the points animation, then auto-navigate.
    private func scheduleAutoNavigation() {
        guard let onMarkCompleted = onMarkCompleted, !isNavigating else { return }
        isNavigating = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1200))
            onMarkCompleted()
        }
    }

    /// Haptic impact + system sound based on pass/fail choice.
    private func triggerFeedback(passed: Bool) {
        // Haptic
        let generator = UIImpactFeedbackGenerator(style: passed ? .heavy : .medium)
        generator.prepare()
        generator.impactOccurred()
        // System sound: 1057 = "Tock" (satisfying confirm), 1053 = subtle tap for fail
        AudioServicesPlaySystemSound(passed ? 1057 : 1053)
    }

    private var openSettingsButton: some View {
        VStack(spacing: 6) {
            Button {
                if let url = URL(string: "App-Prefs:") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text(NSLocalizedString("detail.open_settings", comment: ""))
                        .scaledFont(size: 14, weight: .semibold, relativeTo: .subheadline)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .foregroundColor(AppColors.teal)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.teal.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.teal.opacity(0.3), lineWidth: 1)
                        )
                )
            }

            Text(NSLocalizedString("detail.settings_disclaimer", comment: ""))
                .scaledFont(size: 11, relativeTo: .caption)
                .foregroundColor(AppColors.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func detectedValueContent(value: String, check: SecurityCheck) -> some View {
        if let versions = check.osVersionComponents {
            HStack(spacing: 8) {
                Text("iOS \(versions.current)")
                    .scaledFont(size: 14, weight: .semibold, design: .monospaced, relativeTo: .subheadline)
                    .foregroundColor(AppColors.red)
                Image(systemName: "arrow.right")
                    .scaledFont(size: 12, relativeTo: .footnote)
                    .foregroundColor(AppColors.textSecondary)
                Text("iOS \(versions.latest)")
                    .scaledFont(size: 14, weight: .semibold, design: .monospaced, relativeTo: .subheadline)
                    .foregroundColor(AppColors.green)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.teal.opacity(0.08))
            )
        } else {
            Text(value)
                .scaledFont(size: 14, design: .monospaced, relativeTo: .subheadline)
                .foregroundColor(AppColors.textMono)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.teal.opacity(0.08))
                )
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .scaledFont(size: 12, weight: .semibold, design: .monospaced, relativeTo: .footnote)
                .foregroundColor(color)
                .tracking(1)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Verification Button

struct VerificationButton: View {
    let label: String
    let icon: String
    let activeColor: Color
    let isSelected: Bool
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    // Glow ring — only visible when selected
                    Circle()
                        .stroke(activeColor, lineWidth: 2)
                        .frame(width: 58, height: 58)
                        .opacity(isSelected ? 1 : 0)
                        .scaleEffect(isSelected ? 1.0 : 0.7)
                        .shadow(color: activeColor.opacity(0.8), radius: isSelected ? 10 : 0)

                    // Icon background circle
                    Circle()
                        .fill(isSelected ? activeColor : activeColor.opacity(0.12))
                        .frame(width: 52, height: 52)

                    Image(systemName: icon)
                        .scaledFont(size: 22, weight: .semibold, relativeTo: .title2)
                        .foregroundColor(isSelected ? .black : activeColor.opacity(0.6))
                        .scaleEffect(isSelected ? 1.15 : 1.0)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isSelected)

                Text(label)
                    .scaledFont(size: 13, weight: isSelected ? .bold : .medium, relativeTo: .footnote)
                    .foregroundColor(isSelected ? activeColor : AppColors.textSecondary)
                    .animation(.easeOut(duration: 0.2), value: isSelected)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected
                          ? activeColor.opacity(0.12)
                          : AppColors.cardBorder.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? activeColor.opacity(0.5) : Color.clear,
                                    lineWidth: 1.5)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isDisabled else { return }
                    withAnimation(.easeOut(duration: 0.1)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3)) { isPressed = false }
                }
        )
    }
}

struct SeverityBadge: View {
    let severity: CheckSeverity
    var body: some View {
        Text(severity.localizedLabel.uppercased())
            .scaledFont(size: 9, weight: .bold, relativeTo: .caption2)
            .foregroundColor(severity.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(severity.color.opacity(0.15))
            )
    }
}

struct CategoryBadge: View {
    let category: CheckCategory
    var body: some View {
        Text(category.localizedTitle)
            .scaledFont(size: 9, weight: .medium, relativeTo: .caption2)
            .foregroundColor(category.accentColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(category.accentColor.opacity(0.12))
            )
    }
}

// MARK: - Points Badge

struct PointsBadge: View {
    let points: Int
    let isEarned: Bool

    private let pointsColor = AppColors.yellow

    var body: some View {
        Text("+\(points) pts")
            .scaledFont(size: 10, weight: .heavy, design: .monospaced, relativeTo: .caption)
            .foregroundColor(isEarned ? .black : pointsColor.opacity(0.7))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isEarned ? pointsColor : AppColors.cardBg)
                    .overlay(
                        Capsule()
                            .stroke(pointsColor.opacity(isEarned ? 0.8 : 0.3), lineWidth: 1)
                    )
            )
            .shadow(color: isEarned ? pointsColor.opacity(0.5) : .clear, radius: 6)
    }
}

// MARK: - Floating Points Animation

/// A "+X pts" label that floats up and fades out, game-style.
struct FloatingPointsView: View {
    let points: Int
    let onComplete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 0.5

    private let pointsColor = AppColors.yellow

    var body: some View {
        Text("+\(points) pts")
            .scaledFont(size: 32, weight: .heavy, design: .monospaced, relativeTo: .largeTitle)
            .foregroundColor(pointsColor)
            .shadow(color: pointsColor.opacity(0.8), radius: 10)
            .shadow(color: pointsColor.opacity(0.4), radius: 20)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(y: offset)
            .allowsHitTesting(false)
            .onAppear {
                // Pop in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1.1
                }
                // Then float up + fade out
                withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                    offset = -100
                    opacity = 0
                    scale = 0.8
                }
                // Clean up
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1400))
                    onComplete()
                }
            }
    }
}
