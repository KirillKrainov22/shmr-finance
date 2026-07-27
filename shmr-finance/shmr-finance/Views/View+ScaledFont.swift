import SwiftUI

// Размеры из макета, которые растут вместе с системной настройкой размера текста.
//
// Обычный .font(.system(size: 16)) на неё не реагирует вовсе. Семантические стили
// (.body, .title) реагируют, но задают свои размеры и увели бы вёрстку от макета.
// @ScaledMetric — компромисс: при стандартной настройке размер ровно наш,
// при увеличенной растёт пропорционально.

private struct ScaledFont: ViewModifier {

    @ScaledMetric private var size: CGFloat

    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design, relativeTo textStyle: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

// То же самое для квадратных элементов: кружков с эмодзи, круглых кнопок.
// Без этого значок внутри вырастет, а рамка останется прежней, и он обрежется.
private struct ScaledSquare: ViewModifier {

    @ScaledMetric private var side: CGFloat

    init(side: CGFloat, relativeTo textStyle: Font.TextStyle) {
        _side = ScaledMetric(wrappedValue: side, relativeTo: textStyle)
    }

    func body(content: Content) -> some View {
        content.frame(width: side, height: side)
    }
}

extension View {

    func scaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design, relativeTo: textStyle))
    }

    func scaledSquare(_ side: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> some View {
        modifier(ScaledSquare(side: side, relativeTo: textStyle))
    }
}
