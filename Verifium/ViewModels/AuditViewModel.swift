import Foundation
import SwiftUI
import UserNotifications

// MARK: - AuditViewModel

@MainActor
@Observable
final class AuditViewModel {

    // MARK: State
    var checks: [SecurityCheck] = SecurityChecker.allChecks()
    var isScanning: Bool = false
    var lastScanDate: Date? = nil
    var scanProgress: Double = 0
    var completionTrigger: UUID? = nil
    var showCompletionCelebration = false
    var scrollToCategory: CheckCategory? = nil
    var navigateToCheckId: String? = nil
    var checkListPopToRoot: UUID? = nil
    var preselectedFilter: String? = nil

    @ObservationIgnored
    private let checker = SecurityChecker()
    @ObservationIgnored
    private static let manualResultsKey = "manualCheckResults"
    @ObservationIgnored
    private var badgeAllowed = false

    // MARK: Init

    init() {
        restoreManualResults()
    }

    // MARK: Computed — Score

    var totalScore: Int { checks.reduce(0) { $0 + $1.scoreValue } }
    var maxScore:   Int { checks.reduce(0) { $0 + $1.maxScore } }
    var scorePercent: Double {
        guard maxScore > 0 else { return 0 }
        return Double(totalScore) / Double(maxScore)
    }

    /// Score normalized to 0–100 for display.
    var displayScore: Int { Int(round(scorePercent * 100)) }

    /// Total points earned (weight × 10 for each passing check).
    var earnedPoints: Int { checks.reduce(0) { $0 + $1.earnedPoints } }
    /// Maximum attainable points.
    var maxPoints: Int { checks.reduce(0) { $0 + $1.points } }

    var scoreGrade: String {
        switch scorePercent {
        case 0.9...:  return "A"
        case 0.7...:  return "B"
        case 0.5...:  return "C"
        case 0.3...:  return "D"
        default:      return "F"
        }
    }

    var scoreColor: Color {
        switch scorePercent {
        case 0.9...:  return AppColors.teal
        case 0.7...:  return AppColors.green
        case 0.5...:  return AppColors.orange
        default:      return AppColors.red
        }
    }

    // MARK: Computed — Stats

    var isScoreKnown: Bool { pendingCount == 0 }

    var passingCount:  Int { checks.count(where: { $0.status.isPassing }) }
    var failingCount:  Int { checks.count(where: { $0.status.isFailing || $0.status == .warning }) }
    var pendingCount:  Int { checks.count(where: { $0.status == .manualRequired }) }
    var criticalIssues:[SecurityCheck] {
        checks.filter { $0.status.isFailing && $0.severity == .critical }
    }

    // MARK: Computed — Grouping

    private var _cachedChecksByCategory: [(category: CheckCategory, checks: [SecurityCheck])]?
    private var _cachedChecksSnapshot: [CheckStatus] = []

    var checksByCategory: [(category: CheckCategory, checks: [SecurityCheck])] {
        let snapshot = checks.map(\.status)
        if let cached = _cachedChecksByCategory, snapshot == _cachedChecksSnapshot {
            return cached
        }
        let result = CheckCategory.allCases.compactMap { category in
            let filtered = checks
                .filter { $0.category == category }
                .sorted { $0.severity > $1.severity }
            return filtered.isEmpty ? nil : (category: category, checks: filtered)
        }
        _cachedChecksSnapshot = snapshot
        _cachedChecksByCategory = result
        return result
    }

    // MARK: Actions

    func runScan() async {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0

        // Reset auto-checkable to "checking", but preserve manually reviewed results
        for i in checks.indices where checks[i].isAutoCheckable && !checks[i].status.isManuallyReviewed {
            checks[i].status = .checking
            checks[i].detectedValue = nil
        }

        let autoIndices = checks.indices.filter { checks[$0].isAutoCheckable }
        for (step, idx) in autoIndices.enumerated() {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { break }
            let (status, value) = await checker.runCheck(id: checks[idx].id)
            // If the scan returns .manualRequired but the user already reviewed
            // this check, keep their answer.
            if status == .manualRequired && checks[idx].status.isManuallyReviewed {
                checks[idx].detectedValue = value
            } else {
                checks[idx].status = status
                checks[idx].detectedValue = value
            }
            scanProgress = Double(step + 1) / Double(autoIndices.count)
        }

        lastScanDate = .now
        isScanning = false
        scanProgress = 1
        updateAppBadge()
    }

    func markCheck(id: String, passed: Bool) {
        guard let i = checks.firstIndex(where: { $0.id == id }) else { return }
        checks[i].status = passed ? .manualPassed : .manualFailed
        saveManualResults()
        updateAppBadge()

        // All manual reviews done? Delay for the "+X pts" animation if passed,
        // otherwise transition quickly.
        if pendingCount == 0 {
            let delay: Duration = passed ? .milliseconds(1500) : .milliseconds(600)
            Task { @MainActor in
                try? await Task.sleep(for: delay)
                completionTrigger = UUID()
                if scorePercent >= 0.7 {
                    showCompletionCelebration = true
                }
            }
        }
    }

    func resetManualCheck(id: String) {
        guard let i = checks.firstIndex(where: { $0.id == id }) else { return }
        checks[i].status = .manualRequired
        saveManualResults()
        updateAppBadge()
    }

    func resetAllManualChecks() {
        for i in checks.indices where checks[i].status.isManuallyReviewed {
            checks[i].status = .manualRequired
        }
        completionTrigger = nil
        showCompletionCelebration = false
        saveManualResults()
        updateAppBadge()
    }

    // MARK: Badge

    /// Request badge permission, then immediately set the badge.
    /// Called once from the App's .task — blocks until the user responds.
    func requestBadgePermission() async {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: .badge)) ?? false
        badgeAllowed = granted
        if granted { updateAppBadge() }
    }

    /// Public entry point for refreshing the badge (e.g. on scene phase changes).
    func refreshAppBadge() { updateAppBadge() }

    private func updateAppBadge() {
        guard badgeAllowed else { return }
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(pendingCount)
        }
    }

    // MARK: Persistence

    private func saveManualResults() {
        var dict: [String: String] = [:]
        for check in checks where check.status.isManuallyReviewed {
            dict[check.id] = check.status == .manualPassed ? "passed" : "failed"
        }
        UserDefaults.standard.set(dict, forKey: Self.manualResultsKey)
    }

    private func restoreManualResults() {
        guard let dict = UserDefaults.standard.dictionary(forKey: Self.manualResultsKey) as? [String: String] else { return }
        for (id, value) in dict {
            guard let i = checks.firstIndex(where: { $0.id == id }) else { continue }
            checks[i].status = value == "passed" ? .manualPassed : .manualFailed
        }
    }

    var hasCompletedManualChecks: Bool {
        checks.contains { $0.status.isManuallyReviewed }
    }

    func check(id: String) -> SecurityCheck? {
        checks.first(where: { $0.id == id })
    }

    /// Returns the ID of the next manual check still pending, following the displayed order
    /// (grouped by category, sorted by severity within each category).
    func nextManualCheckId(after currentId: String) -> String? {
        let displayOrder = checksByCategory.flatMap { $0.checks }
        guard let idx = displayOrder.firstIndex(where: { $0.id == currentId }) else { return nil }
        // Search forward
        if let next = displayOrder[(idx + 1)...].first(where: { $0.status == .manualRequired }) {
            return next.id
        }
        // Wrap around
        return displayOrder[..<idx].first(where: { $0.status == .manualRequired })?.id
    }
}
