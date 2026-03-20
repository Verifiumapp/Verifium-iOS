import SwiftUI

struct DashboardView: View {
    private static let topID = "dashboard_top"

    var vm: AuditViewModel
    @Binding var selectedTab: Int
    @State private var animateScore = false
    @State private var pulseShield = false
    @State private var showCelebration = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                MatrixBackground()
                    .opacity(0.12)
                    .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 24) {

                            // Header
                            headerSection
                                .id(Self.topID)

                            // Score Ring
                            scoreSection
                                .overlay {
                                    if showCelebration {
                                        CelebrationView(color: vm.scoreColor) {
                                            showCelebration = false
                                        }
                                    }
                                }

                            // Stats Row
                            statsRow

                            // Critical Issues
                            if !vm.criticalIssues.isEmpty {
                                criticalIssuesSection
                            }

                            // Category summary
                            categorySummary

                            Spacer(minLength: 32)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
                    .onChange(of: selectedTab) { _, tab in
                        if tab == 0 {
                            withAnimation(.easeOut(duration: 0.4)) {
                                proxy.scrollTo(Self.topID, anchor: .top)
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onChange(of: vm.showCompletionCelebration) { _, celebrate in
            guard celebrate else { return }
            // Wait for the tab transition to settle before firing the burst.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                showCelebration = true
                vm.showCompletionCelebration = false
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("dashboard.title", comment: ""))
                    .scaledFont(size: 11, weight: .semibold, design: .monospaced, relativeTo: .caption)
                    .foregroundColor(AppColors.textMono)
                    .tracking(3)

                Text(NSLocalizedString("dashboard.subtitle", comment: ""))
                    .scaledFont(size: 22, weight: .bold, relativeTo: .title2)
                    .foregroundColor(AppColors.textPrimary)
            }
            Spacer()

            // Last scan badge
            if let date = vm.lastScanDate {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(NSLocalizedString("dashboard.last_scan", comment: ""))
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                    Text(date, style: .time)
                        .scaledFont(size: 11, design: .monospaced, relativeTo: .caption)
                        .foregroundColor(AppColors.teal)
                }
            }
        }
        .padding(.top, 8)
    }

    private var scoreSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(AppColors.cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                )
                .shadow(color: vm.scoreColor.opacity(0.2), radius: 20)

            HStack(spacing: 32) {
                // Ring gauge
                ScoreRingView(
                    progress: animateScore ? vm.scorePercent : 0,
                    color: vm.scoreColor,
                    grade: vm.scoreGrade,
                    isKnown: vm.isScoreKnown,
                    isScanning: vm.isScanning
                )
                .frame(width: 130, height: 130)
                .onAppear {
                    withAnimation(.easeOut(duration: 1.2)) { animateScore = true }
                }
                .onChange(of: vm.scorePercent) {
                    animateScore = false
                    withAnimation(.easeOut(duration: 0.8)) { animateScore = true }
                }

                // Score details
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("dashboard.score_label", comment: ""))
                        .scaledFont(size: 10, design: .monospaced, relativeTo: .caption)
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(vm.earnedPoints)")
                            .scaledFont(size: 28, weight: .bold, design: .monospaced, relativeTo: .title)
                            .foregroundColor(AppColors.textPrimary)
                        Text(NSLocalizedString("points.unit", comment: ""))
                            .scaledFont(size: 14, weight: .semibold, design: .monospaced, relativeTo: .subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                    Text(vm.isScanning
                         ? NSLocalizedString("dashboard.scanning", comment: "")
                         : (vm.isScoreKnown ? scoreDescription : NSLocalizedString("score.incomplete", comment: "")))
                        .font(.caption)
                        .foregroundColor(vm.scoreColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .onTapGesture {
            if !vm.isScoreKnown {
                vm.checkListPopToRoot = UUID()
                withAnimation(.spring(response: 0.3)) { selectedTab = 1 }
            }
        }
    }

    private var scoreDescription: String {
        switch vm.scorePercent {
        case 0.9...:  return NSLocalizedString("score.excellent", comment: "")
        case 0.7...:  return NSLocalizedString("score.good", comment: "")
        case 0.5...:  return NSLocalizedString("score.moderate", comment: "")
        default:      return NSLocalizedString("score.critical", comment: "")
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatTile(value: vm.passingCount,
                     label: NSLocalizedString("stats.passing", comment: ""),
                     color: AppColors.teal,
                     icon: "checkmark.shield.fill")
                .onTapGesture {
                    if vm.passingCount > 0 {
                        vm.preselectedFilter = "filter.passing"
                        vm.checkListPopToRoot = UUID()
                        withAnimation(.spring(response: 0.3)) { selectedTab = 1 }
                    }
                }

            StatTile(value: vm.failingCount,
                     label: NSLocalizedString("stats.failing", comment: ""),
                     color: AppColors.red,
                     icon: "xmark.shield.fill")
                .onTapGesture {
                    if vm.failingCount > 0 {
                        vm.preselectedFilter = "filter.failing"
                        vm.checkListPopToRoot = UUID()
                        withAnimation(.spring(response: 0.3)) { selectedTab = 1 }
                    }
                }

            StatTile(value: vm.pendingCount,
                     label: NSLocalizedString("stats.pending", comment: ""),
                     color: AppColors.blue,
                     icon: "hand.tap.fill")
                .onTapGesture {
                    if vm.pendingCount > 0 {
                        vm.preselectedFilter = "filter.pending"
                        vm.checkListPopToRoot = UUID()
                        withAnimation(.spring(response: 0.3)) { selectedTab = 1 }
                    }
                }
        }
    }

    private var criticalIssuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(NSLocalizedString("dashboard.critical_issues", comment: ""),
                  systemImage: "exclamationmark.triangle.fill")
                .scaledFont(size: 12, weight: .semibold, design: .monospaced, relativeTo: .footnote)
                .foregroundColor(AppColors.red)
                .tracking(1)

            ForEach(vm.criticalIssues) { check in
                Button {
                    vm.navigateToCheckId = check.id
                    vm.checkListPopToRoot = UUID()
                    withAnimation(.spring(response: 0.3)) { selectedTab = 1 }
                } label: {
                    CriticalIssueRow(check: check)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.red.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppColors.red.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var categorySummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("dashboard.categories", comment: ""))
                .scaledFont(size: 11, weight: .semibold, design: .monospaced, relativeTo: .caption)
                .foregroundColor(AppColors.textSecondary)
                .tracking(2)

            ForEach(vm.checksByCategory, id: \.category.id) { group in
                Button {
                    vm.preselectedFilter = "filter.all"
                    vm.scrollToCategory = group.category
                    vm.checkListPopToRoot = UUID()
                    withAnimation(.spring(response: 0.3)) { selectedTab = 1 }
                } label: {
                    CategorySummaryRow(category: group.category, checks: group.checks)
                }
                .buttonStyle(.plain)
            }
        }
    }

}

// MARK: - Sub-components

struct StatTile: View {
    let value: Int
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text("\(value)")
                .scaledFont(size: 22, weight: .bold, design: .monospaced, relativeTo: .title2)
                .foregroundColor(AppColors.textPrimary)

            Text(label)
                .scaledFont(size: 10, relativeTo: .caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.25), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct CriticalIssueRow: View {
    let check: SecurityCheck

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundColor(AppColors.red)
                .frame(width: 28)
            Text(check.title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }
}

struct CategorySummaryRow: View {
    let category: CheckCategory
    let checks: [SecurityCheck]

    private var passing: Int { checks.count(where: { $0.status.isPassing }) }
    private var progress: Double { Double(passing) / Double(checks.count) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .scaledFont(size: 16, relativeTo: .body)
                .foregroundColor(category.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(category.localizedTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text("\(passing)/\(checks.count)")
                        .scaledFont(size: 12, design: .monospaced, relativeTo: .footnote)
                        .foregroundColor(AppColors.textSecondary)
                }

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppColors.cardBorder)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(category.accentColor)
                        .scaleEffect(x: progress, anchor: .leading)
                }
                .frame(height: 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.cardBorder, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.localizedTitle), \(passing) \(NSLocalizedString("stats.passing", comment: "")) \(checks.count)")
        .accessibilityHint(NSLocalizedString("dashboard.category_hint", comment: ""))
    }
}
