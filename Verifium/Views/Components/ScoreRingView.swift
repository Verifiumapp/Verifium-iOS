import SwiftUI

struct ScoreRingView: View {
    let progress: Double
    let color: Color
    let grade: String
    var isKnown: Bool = true
    var isScanning: Bool = false

    private let lineWidth: CGFloat = 10
    private let glowRadius: CGFloat = 8

    @State private var spinAngle: Double = 0

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(AppColors.cardBorder, lineWidth: lineWidth)

            if isScanning {
                // Spinning arc while scanning
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(
                        AppColors.teal.opacity(0.6),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(spinAngle))
                    .shadow(color: AppColors.teal.opacity(0.4), radius: glowRadius)
                    .onAppear {
                        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                            spinAngle = 360
                        }
                    }
                    .onDisappear { spinAngle = 0 }
            } else {
                // Progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [color.opacity(0.6), color],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
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
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(color)
                        .shadow(color: color.opacity(0.6), radius: 8)

                    Text("\(Int(round(progress * 100)))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)
                }
            } else {
                Text("?")
                    .font(.system(size: 44, weight: .black, design: .monospaced))
                    .foregroundColor(color.opacity(0.35))
            }
        }
    }
}
