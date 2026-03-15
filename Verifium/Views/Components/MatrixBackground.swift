import SwiftUI
import Combine

/// A subtle, randomly scrolling hex character background for the cyber aesthetic.
struct MatrixBackground: View {
    private let columns = 12
    private let rows = 20

    @State private var offsets: [[CGFloat]] = []
    @State private var chars: [[String]] = []
    @State private var opacities: [[Double]] = []

    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let colW = geo.size.width / CGFloat(columns)
            let rowH = geo.size.height / CGFloat(rows)

            Canvas { context, size in
                guard !chars.isEmpty else { return }
                for col in 0..<columns {
                    for row in 0..<rows {
                        guard col < chars.count, row < chars[col].count else { continue }
                        let x = CGFloat(col) * colW
                        let y = CGFloat(row) * rowH + (offsets.indices.contains(col) ? offsets[col][safe: row] ?? 0 : 0)
                        let opacity = opacities.indices.contains(col) ? (opacities[col][safe: row] ?? 0) : 0

                        let text = Text(chars[col][row])
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(AppColors.teal.opacity(opacity))
                        context.draw(text, at: CGPoint(x: x + colW / 2, y: y), anchor: .center)
                    }
                }
            }
            .onAppear { setup(colW: colW, rowH: rowH) }
            .onReceive(timer) { _ in
                guard !chars.isEmpty else { return }
                let hexChars = Array("0123456789ABCDEF")
                let ci = Int.random(in: 0..<columns)
                let ri = Int.random(in: 0..<rows)
                if ci < chars.count && ri < chars[ci].count {
                    chars[ci][ri] = String(hexChars.randomElement()!)
                    opacities[ci][ri] = Double.random(in: 0.05...0.4)
                }
            }
        }
    }

    private func setup(colW: CGFloat, rowH: CGFloat) {
        let hexChars = Array("0123456789ABCDEF")
        chars    = (0..<columns).map { _ in (0..<rows).map { _ in String(hexChars.randomElement()!) } }
        offsets  = (0..<columns).map { _ in (0..<rows).map { _ in CGFloat.random(in: -rowH...rowH) } }
        opacities = (0..<columns).map { _ in (0..<rows).map { _ in Double.random(in: 0.05...0.4) } }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
