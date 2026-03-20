import SwiftUI

struct ScoreRingView: View {
    let progress: Double
    let color: Color
    let grade: String
    var isKnown: Bool = true
    var isScanning: Bool = false

    private let lineWidth: CGFloat = 10
    private let glowRadius: CGFloat = 8

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(AppColors.cardBorder, lineWidth: lineWidth)

            if isScanning {
                // Spinning arc while scanning (own @State so animation resets cleanly)
                ScanningArc(lineWidth: lineWidth, glowRadius: glowRadius)
            } else {
                // Progress arc — solid color, no gradient seam
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.5), radius: glowRadius)
                    .animation(.easeOut(duration: 0.8), value: progress)
            }

            // Inner content
            if isScanning {
                ProgressView()
                    .tint(AppColors.teal)
                    .scaleEffect(1.2)
            } else if isKnown {
                VStack(spacing: 2) {
                    Text(grade)
                        .scaledFont(size: 36, weight: .black, design: .monospaced, relativeTo: .largeTitle)
                        .foregroundColor(color)
                        .shadow(color: color.opacity(0.6), radius: 8)

                    Text("\(Int(round(progress * 100)))%")
                        .scaledFont(size: 11, design: .monospaced, relativeTo: .caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            } else {
                Text("?")
                    .scaledFont(size: 44, weight: .black, design: .monospaced, relativeTo: .largeTitle)
                    .foregroundColor(color.opacity(0.35))
            }
        }
    }
}

// MARK: - Scanning Arc

/// Uses TimelineView so the rotation runs reliably even when the view
/// starts on a background tab (onAppear-based animations can be skipped
/// by SwiftUI when the view isn't visible at the time of appearance).
private struct ScanningArc: View {
    let lineWidth: CGFloat
    let glowRadius: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            let angle = seconds.remainder(dividingBy: 1.2) / 1.2 * 360

            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(
                    AppColors.teal.opacity(0.6),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(angle))
                .shadow(color: AppColors.teal.opacity(0.4), radius: glowRadius)
        }
    }
}
