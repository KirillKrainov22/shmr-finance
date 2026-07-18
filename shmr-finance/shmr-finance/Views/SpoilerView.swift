import SwiftUI

// Анимированный спойлер как в Telegram: мерцающие частицы.
// Сид генератора завязан на время кадра — поэтому Canvas перерисовывается
// каждый кадр и точки каждый раз новые (эффект «шума»).
struct SpoilerView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let seed = UInt64(timeline.date.timeIntervalSinceReferenceDate * 60)
                var generator = SeededGenerator(seed: seed)
                let particleCount = Int(size.width * size.height / 20)

                for _ in 0..<particleCount {
                    let x = CGFloat.random(in: 0...size.width, using: &generator)
                    let y = CGFloat.random(in: 0...size.height, using: &generator)
                    let opacity = Double.random(in: 0.2...1.0, using: &generator)
                    let dot = CGRect(x: x, y: y, width: 1.4, height: 1.4)
                    context.fill(Path(ellipseIn: dot), with: .color(.primary.opacity(opacity)))
                }
            }
        }
    }
}

// Простой генератор со сменным сидом, чтобы частицы менялись от кадра к кадру.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

