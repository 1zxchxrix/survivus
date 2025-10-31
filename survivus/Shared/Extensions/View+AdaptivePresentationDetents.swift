import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@available(iOS 16.0, *)
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

extension View {
    /// Applies a fractional sheet detent that expands to a taller height on iPad devices.
    /// - Parameters:
    ///   - defaultFraction: The fractional height to use on iPhone and other idioms.
    ///   - iPadFraction: The taller fractional height to use when running on iPad.
    @available(iOS 16.0, *)
    func adaptivePresentationDetents(defaultFraction: CGFloat, iPadFraction: CGFloat) -> some View {
        modifier(
            AdaptiveFractionalSheetDetentModifier(
                defaultFraction: defaultFraction,
                iPadFraction: iPadFraction
            )
        )
    }
}
