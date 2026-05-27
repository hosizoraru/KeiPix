import SwiftUI

/// Platform-agnostic hover plumbing. Today the body just wraps
/// `.onHover` because that's the only viable signal on macOS; on
/// iPadOS the same modifier is the right place to layer
/// `.hoverEffect(_:)` so the system pointer gets its lift/highlight
/// treatment without each call site reaching into UIKit.
///
/// Why route through one modifier instead of leaving `.onHover`
/// inline at every card site:
/// - 9 cards across the app use the same `@State isHovering = false`
///   plus `.onHover { isHovering = $0 }` plus `.scaleEffect`/`.shadow`
///   pattern. A future iPadOS port needs to layer `.hoverEffect` on
///   exactly those nine sites; threading that through one modifier
///   keeps the iPadOS diff small and auditable.
/// - Lets us add a debug hook (count hover transitions in QA builds,
///   suppress hover during snapshot tests) in one place rather than
///   nine.
///
/// We intentionally do **not** bake scale/shadow into this modifier.
/// Each card's hover decoration is bespoke — Apple HIG treats hover
/// affordance as part of the card's visual language, not a one-size
/// system effect — so the modifier hands the boolean back to the
/// caller and lets the caller pick its own decoration. That mirrors
/// how Apple's own SwiftUI APIs (`.onHover`, `OnGeometryChangeAction`)
/// surface signals rather than dictate visuals.
extension View {
    /// Reports hover transitions to `onChange`. Drop-in replacement
    /// for `.onHover`. Callers decide what to do with the boolean —
    /// flip a `@State`, run an animation, log it.
    ///
    /// On macOS this is exactly `.onHover`. On iPadOS (when we get
    /// there) this is the place we'll layer `.hoverEffect(.automatic)`
    /// on top so the system draws the standard pointer affordance
    /// alongside whatever custom hover visuals the call site already
    /// owns.
    func keiPixHoverTracker(onChange: @escaping (Bool) -> Void) -> some View {
        onHover { isHovering in
            onChange(isHovering)
        }
    }
}
