import Foundation
import SwiftUI
import Combine

// MARK: - AuditViewModel

@MainActor
final class AuditViewModel: ObservableObject {

    // MARK: Published State
    @Published var checks: [SecurityCheck] = SecurityChecker.allChecks()
    @Published var isScanning: Bool = false
    @Published var lastScanDate: Date? = nil
    @Published var scanProgress: Double = 0
    @Published var completionTrigger: UUID? = nil
    @Published var showCompletionCelebration = false
    @Published var scrollToCategory: CheckCategory? = nil
    @Published var navigateToCheckId: String? = nil

    private let checker = SecurityChecker()
    private static let manualResultsKey = "manualCheckResults"

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

    var scoreGrade: String {
        switch scorePercent {
        case 0.9...:  return "A"
        case 0.75...: return "B"
        case 0.6...:  return "C"
        case 0.4...:  return "D"
        default:      return "F"
        }
    }

    var scoreColor: Color {
        switch scorePercent {
        case 0.85...: return AppColors.teal
        case 0.65...: return AppColors.green
        case 0.45...: return AppColors.orange
        default:      return AppColors.red
        }
    }

    // MARK: Computed — Stats

    var isScoreKnown: Bool { pendingCount == 0 }

    var passingCount:  Int { checks.filter { $0.status.isPassing }.count }
    var failingCount:  Int { checks.filter { $0.status.isFailing || $0.status == .warning }.count }
    var pendingCount:  Int { checks.filter { $0.status == .manualRequired }.count }
    var criticalIssues:[SecurityCheck] {
        checks.filter { $0.status.isFailing && $0.severity == .critical }
    }

    // MARK: Computed — Grouping

    var checksByCategory: [(category: CheckCategory, checks: [SecurityCheck])] {
        CheckCategory.allCases.compactMap { category in
            let filtered = checks
                .filter { $0.category == category }
                .sorted { $0.severity > $1.severity }
            return filtered.isEmpty ? nil : (category: category, checks: filtered)
        }
    }

    // MARK: Actions

    func runScan() async {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0

        // Reset auto-checkable to "checking"
        for i in checks.indices where checks[i].isAutoCheckable {
            checks[i].status = .checking
            checks[i].detectedValue = nil
        }

        let autoIndices = checks.indices.filter { checks[$0].isAutoCheckable }
        for (step, idx) in autoIndices.enumerated() {
            try? await Task.sleep(nanoseconds: 200_000_000)
            let (status, value) = await checker.runCheck(id: checks[idx].id)
            checks[idx].status = status
            checks[idx].detectedValue = value
            scanProgress = Double(step + 1) / Double(autoIndices.count)
        }

        lastScanDate = Date()
        isScanning = false
        scanProgress = 1
    }

    func markCheck(id: String, passed: Bool) {
        guard let i = checks.firstIndex(where: { $0.id == id }) else { return }
        checks[i].status = passed ? .manualPassed : .manualFailed
        saveManualResults()

        // All manual reviews done?
        if pendingCount == 0 {
            completionTrigger = UUID()
            if scorePercent >= 0.65 {
                showCompletionCelebration = true
            }
        }
    }

    func resetManualCheck(id: String) {
        guard let i = checks.firstIndex(where: { $0.id == id }) else { return }
        checks[i].status = .manualRequired
        saveManualResults()
    }

    func resetAllManualChecks() {
        for i in checks.indices where checks[i].status.isManuallyReviewed {
            checks[i].status = .manualRequired
        }
        completionTrigger = nil
        showCompletionCelebration = false
        saveManualResults()
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
