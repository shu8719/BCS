import UIKit

/// Waits until UIKit has nothing presented on top of the app's root view controller.
///
/// A fullScreenCover presented while a sheet or the photo picker is still animating away is laid out
/// without the top safe area (its top bar ends up under the status bar). The picker's dismissal time
/// varies, so instead of guessing a delay we poll the real presentation state.
@MainActor
enum PresentationIdle {
    static func whenIdle(timeout: TimeInterval = 3, _ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            let deadline = Date().addingTimeInterval(timeout)
            while !isIdle, Date() < deadline {
                try? await Task.sleep(for: .milliseconds(50))
            }
            action()
        }
    }
    
    /// True when the key window's root view controller presents nothing (not even one mid-dismissal).
    static var isIdle: Bool {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        return root?.presentedViewController == nil
    }
}
