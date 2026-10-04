import SwiftUI

extension View {
    /// A card floating over a chart that shows the values under the finger while scrubbing.
    func inspectorCardStyle() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.regularMaterial, in: .rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
            .transition(.opacity)
    }
}
