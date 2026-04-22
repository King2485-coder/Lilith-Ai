import SwiftUI
import Combine

/// Tracks keyboard height to avoid overlays on input views.
final class KeyboardObserver: ObservableObject {
    @Published var height: CGFloat = 0

    private var cancellables: Set<AnyCancellable> = []

    init() {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
        let willChange = NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)

        willShow.merge(with: willChange)
            .compactMap { notification -> CGFloat? in
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                    return nil
                }
                return frame.height
            }
            .receive(on: RunLoop.main)
            .assign(to: &self.$height)

        willHide
            .map { _ in CGFloat(0) }
            .receive(on: RunLoop.main)
            .assign(to: &self.$height)
    }
}

struct KeyboardAdaptive: ViewModifier {
    @StateObject private var keyboard = KeyboardObserver()

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboard.height)
            .animation(.easeOut(duration: 0.2), value: keyboard.height)
    }
}

extension View {
    func keyboardAdaptive() -> some View {
        self.modifier(KeyboardAdaptive())
    }
}
