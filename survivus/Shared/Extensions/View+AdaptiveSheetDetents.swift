import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private struct AdaptiveFractionalSheetDetentModifier: ViewModifier {
    let defaultFraction: CGFloat
    let iPadFraction: CGFloat

    private var resolvedFraction: CGFloat {
        #if canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return iPadFraction
        }
        #endif
        return defaultFraction
    }

    func body(content: Content) -> some View {
        content.presentationDetents([.fraction(resolvedFraction)])
    }
}

