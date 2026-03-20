import SwiftUI

/// Radial starburst celebration that emanates from the center of its frame.
/// Particles expand outward, glow, then fade — like an Apple Watch ring completion.
struct CelebrationView: View {
    let color: Color
    var onComplete: (() -> Void)? = nil

    @State private var particles: [Particle] = []
    @State private var burst = false
    @State private var glowOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.6

    private static let count = 42
    private static let colors: [Color] = [
        AppColors.teal, AppColors.blue, AppColors.purple,
        AppColors.green, AppColors.yellow, AppColors.orange,
    ]

    struct Particle: Identifiable {
        let id: Int
        let angle: Double
        let distance: CGFloat
        let size: CGFloat
        let color: Color
        let delay: Double
        let rotationDir: Double
    }

    var body: some View {
        ZStack {
            // Central glow pulse — big and dramatic
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.6), color.opacity(0.15), color.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 260
                    )
                )
                .frame(width: 520, height: 520)
                .scaleEffect(glowScale)
                .opacity(glowOpacity)
                .blur(radius: 30)

            // Particles
            ForEach(particles) { p in
                RoundedRectangle(cornerRadius: p.size > 6 ? 2.5 : p.size / 2)
                    .fill(p.color)
                    .frame(width: p.size, height: p.size * 0.55)
                    .shadow(color: p.color.opacity(0.9), radius: 6)
                    .rotationEffect(.degrees(burst ? p.rotationDir * 420 : 0))
                    .offset(
                        x: burst ? cos(p.angle) * p.distance : 0,
                        y: burst ? sin(p.angle) * p.distance : 0
                    )
                    .scaleEffect(burst ? 0.05 : 1.2)
                    .opacity(burst ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.6).delay(p.delay),
                        value: burst
                    )
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            generateParticles()

            // Glow: punch in fast, expand, then fade
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                glowOpacity = 1
                glowScale = 1.15
            }
            withAnimation(.easeOut(duration: 1.4).delay(0.5)) {
                glowOpacity = 0
                glowScale = 1.3
            }

            // Burst particles outward
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                burst = true
            }

            // Cleanup
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.2))
                onComplete?()
            }
        }
    }

    private func generateParticles() {
        var result: [Particle] = []
        for i in 0..<Self.count {
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 140...340)
            let size = CGFloat.random(in: 4...11)
            let color = Self.colors[i % Self.colors.count]
            let delay = Double.random(in: 0...0.2)
            let dir: Double = Bool.random() ? 1 : -1
            result.append(Particle(
                id: i, angle: angle, distance: distance,
                size: size, color: color, delay: delay, rotationDir: dir
            ))
        }
        particles = result
    }
}
