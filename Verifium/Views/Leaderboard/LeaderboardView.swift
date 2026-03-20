import SwiftUI
import UIKit
import Darwin

// MARK: - Entry Model

fileprivate struct LBEntry: Identifiable {
    var id: String { isUser ? "user" : name }
    let rank: Int
    let emoji: String
    let name: String
    let score: Int
    let isUser: Bool
}

// MARK: - LeaderboardView

struct LeaderboardView: View {
    var vm: AuditViewModel
    @State private var animateProgress = false

    private static let personas: [(emoji: String, nameKey: String, score: Int)] = [
        ("👵", "persona.grandma",         10),
        ("🌍", "persona.flat_earther",    80),
        ("👴", "persona.boomer",         150),
        ("🤯", "persona.ignorant",       270),
        ("🧐", "persona.nosy_neighbor",  390),
        ("😐", "persona.average_joe",    560),
        ("🕶️", "persona.cool_uncle",     640),
        ("🧑‍💼", "persona.manager",        710),
        ("💻", "persona.tech_bro",       860),
        ("🎭", "persona.wannabe_hacker", 970),
        ("🦅", "persona.whistleblower", 1160),
        ("🥷", "persona.paranoid_ninja",1390),
    ]

    private var entries: [LBEntry] {
        let model = currentDeviceModel()
        var raw: [(emoji: String, name: String, score: Int, isUser: Bool)] =
            Self.personas.map { ($0.emoji, NSLocalizedString($0.nameKey, comment: ""), $0.score, false) }
        raw.append(("📱", model, vm.earnedPoints, true))

        return raw
            .sorted { $0.score > $1.score }
            .enumerated()
            .map { idx, item in
                LBEntry(rank: idx + 1,
                        emoji: item.emoji,
                        name: item.name,
                        score: item.score,
                        isUser: item.isUser)
            }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        headerRow

                        ForEach(entries) { entry in
                            LeaderboardRowView(
                                entry: entry,
                                maxScore: vm.maxPoints,
                                animateProgress: animateProgress
                            )
                        }

                        disclaimerView
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(NSLocalizedString("tab.leaderboard", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            animateProgress = false
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                withAnimation { animateProgress = true }
            }
        }
    }

    // MARK: - Sub-views

    private var headerRow: some View {
        HStack {
            Text(NSLocalizedString("leaderboard.subtitle", comment: ""))
                .scaledFont(size: 11, weight: .semibold, design: .monospaced, relativeTo: .caption)
                .foregroundColor(AppColors.textSecondary)
                .tracking(2)

            Spacer()

            if let user = entries.first(where: { $0.isUser }) {
                HStack(spacing: 3) {
                    Image(systemName: "trophy.fill")
                        .scaledFont(size: 10, relativeTo: .caption)
                        .foregroundColor(AppColors.teal)
                    Text("\(NSLocalizedString("leaderboard.your_rank", comment: "")) #\(user.rank)")
                        .scaledFont(size: 11, weight: .semibold, design: .monospaced, relativeTo: .caption)
                        .foregroundColor(AppColors.teal)
                }
            }
        }
        .padding(.bottom, 2)
    }

    private var disclaimerView: some View {
        Text(NSLocalizedString("leaderboard.disclaimer", comment: ""))
            .scaledFont(size: 10, relativeTo: .caption2)
            .foregroundColor(AppColors.textSecondary.opacity(0.5))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
    }

    // MARK: - Device Model Detection

    private func currentDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        let modelMap: [String: String] = [
            "iPhone14,4": "iPhone 13 mini",
            "iPhone14,5": "iPhone 13",
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone17,1": "iPhone 16 Pro",
            "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,3": "iPhone 16",
            "iPhone17,4": "iPhone 16 Plus",
            "iPhone18,1": "iPhone 17",
            "iPhone18,2": "iPhone 17 Air",
            "iPhone18,3": "iPhone 17 Pro",
            "iPhone18,4": "iPhone 17 Pro Max",
            "x86_64":     "Simulator",
            "arm64":      "Simulator",
        ]
        return modelMap[identifier] ?? identifier
    }
}

// MARK: - LeaderboardRowView

fileprivate struct LeaderboardRowView: View {
    let entry: LBEntry
    let maxScore: Int
    let animateProgress: Bool

    private var progressFraction: Double {
        guard maxScore > 0 else { return 0 }
        return min(1, Double(entry.score) / Double(maxScore))
    }

    /// Color based on score fraction — same thresholds as ScoreRingView / AuditViewModel.scoreColor.
    private var barColor: Color {
        switch progressFraction {
        case 0.9...:  return AppColors.teal
        case 0.7...:  return AppColors.green
        case 0.5...:  return AppColors.orange
        default:      return AppColors.red
        }
    }

    /// Accent color for the user row (name, badge, score text) — follows barColor dynamically.
    private var userAccent: Color { barColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                // Rank — medal emoji for top 3, text for others
                if entry.rank <= 3 {
                    Text(entry.rank == 1 ? "🥇" : entry.rank == 2 ? "🥈" : "🥉")
                        .font(.system(size: 20))
                        .frame(width: 32, height: 26)
                } else {
                    Text("#\(entry.rank)")
                        .scaledFont(size: 12, weight: .semibold, design: .monospaced, relativeTo: .footnote)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 32, alignment: .center)
                }

                // Persona emoji
                Text(entry.emoji)
                    .font(.system(size: 22))
                    .frame(width: 28, height: 28)

                // Name + YOU badge
                HStack(spacing: 6) {
                    Text(entry.name)
                        .scaledFont(size: 13,
                                    weight: entry.isUser ? .semibold : .regular,
                                    relativeTo: .footnote)
                        .foregroundColor(entry.isUser ? userAccent : AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    if entry.isUser {
                        Text(NSLocalizedString("leaderboard.you_badge", comment: ""))
                            .scaledFont(size: 9, weight: .heavy, design: .monospaced, relativeTo: .caption2)
                            .foregroundColor(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(userAccent))
                    }
                }

                Spacer(minLength: 4)

                // Score
                Text("\(entry.score) \(NSLocalizedString("points.unit", comment: ""))")
                    .scaledFont(size: 12, weight: .semibold, design: .monospaced, relativeTo: .footnote)
                    .foregroundColor(entry.isUser ? userAccent : AppColors.textSecondary)
                    .lineLimit(1)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.cardBorder)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(width: animateProgress ? geo.size.width * progressFraction : 0)
                        .animation(
                            .easeOut(duration: 0.8).delay(Double(entry.rank - 1) * 0.05),
                            value: animateProgress
                        )
                }
            }
            .frame(height: 4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(entry.isUser ? userAccent.opacity(0.08) : AppColors.cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            entry.isUser ? userAccent.opacity(0.5) : AppColors.cardBorder,
                            lineWidth: entry.isUser ? 1.5 : 1
                        )
                )
                // Glow on the border outline for the user row
                .overlay(
                    entry.isUser
                    ? RoundedRectangle(cornerRadius: 12)
                        .stroke(userAccent.opacity(0.4), lineWidth: 3)
                        .blur(radius: 6)
                    : nil
                )
        )
    }
}
