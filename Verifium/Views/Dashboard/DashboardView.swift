import SwiftUI

struct DashboardView: View {
    private static let topID = "dashboard_top"

    @ObservedObject var vm: AuditViewModel
    @Binding var selectedTab: Int
    @State private var animateScore = false
    @State private var pulseShield = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                MatrixBackground()
                    .opacity(0.12)
                    .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {

                            // Header
                            headerSection
                                .id(Self.topID)

                            // Score Ring
                            scoreSection

                            // Stats Row
                            statsRow

                            // Critical Issues
                            if !vm.criticalIssues.isEmpty {
                                criticalIssuesSection
                            }

                            // Category summary
                            categorySummary

                            // Scan button
                            scanButton

                            // Reset manual checks
                            if vm.hasCompletedManualChecks {
                                resetManualChecksButton
                            }

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
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("dashboard.title", comment: ""))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(AppColors.textMono)
                    .tracking(3)

                Text(NSLocalizedString("dashboard.subtitle", comment: ""))
                    .font(.system(size: 22, weight: .bold))
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
                        .font(.system(size: 11, design: .monospaced))
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
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(2)

                    Text(vm.isScoreKnown ? "\(vm.displayScore) / 100" : "? / 100")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(vm.isScoreKnown ? AppColors.textPrimary : AppColors.textPrimary.opacity(0.35))

                    Text(vm.isScanning
                         ? NSLocalizedString("dashboard.scanning", comment: "")
                         : (vm.isScoreKnown ? scoreDescription : NSLocalizedString("score.incomplete", comment: "")))
                        .font(.caption)
                        .foregroundColor(vm.scoreColor)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(24)
        }
        .onTapGesture {
            if !vm.isScoreKnown {
                withAnimation(.spring(response: 0.3)) { selectedTab = 1 }
            }
        }
    }

    private var scoreDescription: String {
        switch vm.scorePercent {
        case 0.85...: return NSLocalizedString("score.excellent", comment: "")
        case 0.65...: return NSLocalizedString("score.good", comment: "")
        case 0.45...: return NSLocalizedString("score.moderate", comment: "")
        default:      return NSLocalizedString("score.critical", comment: "")
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatTile(value: vm.passingCount,
                     label: NSLocalizedString("stats.passing", comment: ""),
                     color: AppColors.teal,
                     icon: "checkmark.shield.fill")

            StatTile(value: vm.failingCount,
                     label: NSLocalizedString("stats.failing", comment: ""),
                     color: AppColors.red,
                     icon: "xmark.shield.fill")

            StatTile(value: vm.pendingCount,
                     label: NSLocalizedString("stats.pending", comment: ""),
                     color: AppColors.blue,
                     icon: "hand.tap.fill")
                .onTapGesture {
                    if vm.pendingCount > 0 {
                        withAnimation(.spring(response: 0.3)) { selectedTab = 1 }
                    }
                }
        }
    }

    private var criticalIssuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(NSLocalizedString("dashboard.critical_issues", comment: ""),
                  systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(AppColors.red)
                .tracking(1)

            ForEach(vm.criticalIssues) { check in
                Button {
                    vm.navigateToCheckId = check.id
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
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(AppColors.textSecondary)
                .tracking(2)

            ForEach(vm.checksByCategory, id: \.category.id) { group in
                Button {
                    vm.scrollToCategory = group.category
                    withAnimation(.spring(response: 0.3)) { selectedTab = 1 }
                } label: {
                    CategorySummaryRow(category: group.category, checks: group.checks)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var scanButton: some View {
        Button {
            Task { await vm.runScan() }
        } label: {
            HStack(spacing: 12) {
                if vm.isScanning {
                    ProgressView()
                        .tint(AppColors.background)
                        .scaleEffect(0.85)
                    Text(NSLocalizedString("dashboard.scanning", comment: ""))
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                } else {
                    Image(systemName: "play.fill")
                    Text(NSLocalizedString("dashboard.run_scan", comment: ""))
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
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
    }

    private var resetManualChecksButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.3)) {
                vm.resetAllManualChecks()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12))
                Text(NSLocalizedString("dashboard.reset_manual", comment: ""))
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(AppColors.textSecondary)
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
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.textPrimary)

            Text(label)
                .font(.system(size: 10))
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
        }
        .padding(.vertical, 4)
    }
}

struct CategorySummaryRow: View {
    let category: CheckCategory
    let checks: [SecurityCheck]

    private var passing: Int { checks.filter { $0.status.isPassing }.count }
    private var progress: Double { Double(passing) / Double(checks.count) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 16))
                .foregroundColor(category.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(category.localizedTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text("\(passing)/\(checks.count)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColors.cardBorder)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(category.accentColor)
                            .frame(width: geo.size.width * progress)
                    }
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
    }
}
