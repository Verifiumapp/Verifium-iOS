import SwiftUI
import UIKit

/// Full-screen confetti particle effect using CAEmitterLayer.
struct ConfettiView: UIViewRepresentable {

    func makeUIView(context: Context) -> UIView {
        let host = UIView()
        host.backgroundColor = .clear
        host.isUserInteractionEnabled = false

        let emitter = CAEmitterLayer()
        emitter.emitterShape = .line
        emitter.renderMode = .additive

        let colors: [UIColor] = [
            UIColor(AppColors.teal),
            UIColor(AppColors.blue),
            UIColor(AppColors.purple),
            UIColor(AppColors.green),
            UIColor(AppColors.orange),
            UIColor(AppColors.yellow),
        ]

        let image = Self.confettiImage()

        emitter.emitterCells = colors.map { color in
            let cell = CAEmitterCell()
            cell.birthRate = 12
            cell.lifetime = 20
            cell.velocity = 180
            cell.velocityRange = 80
            cell.emissionLongitude = .pi / 2       // downward
            cell.emissionRange = .pi / 4            // +/-45 deg
            cell.spin = 3
            cell.spinRange = 6
            cell.scale = 0.15
            cell.scaleRange = 0.03
            cell.scaleSpeed = -0.005
            cell.alphaSpeed = -0.2
            cell.color = color.cgColor
            cell.contents = image?.cgImage
            cell.yAcceleration = 60                 // gentle gravity
            return cell
        }

        host.layer.addSublayer(emitter)
        context.coordinator.emitter = emitter

        // Stop emitting after 2s, let remaining particles fall
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            emitter.birthRate = 0
        }

        return host
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update emitter position to match current view bounds
        if let emitter = context.coordinator.emitter {
            let bounds = uiView.bounds
            emitter.emitterPosition = CGPoint(x: bounds.midX, y: -10)
            emitter.emitterSize = CGSize(width: bounds.width * 1.2, height: 1)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var emitter: CAEmitterLayer?
    }

    /// Small rounded-rect image used as confetti piece (tinted by CAEmitterCell.color).
    private static func confettiImage() -> UIImage? {
        let size = CGSize(width: 12, height: 8)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 1.5).fill(with: .normal, alpha: 1)
        }
    }
}
