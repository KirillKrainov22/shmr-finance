import SwiftUI

extension View {
    // Liquid Glass на iOS 26, серая капсула как фолбэк на более старых версиях.
    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: .capsule)
        } else {
            self.background(Capsule().fill(Color(.systemGray6)))
        }
    }
}
