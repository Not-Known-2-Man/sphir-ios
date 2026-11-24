import SwiftUI

/// Password input with an eye button that shows or hides the typed text.
struct PasswordField: View {
    let placeholder: String
    @Binding var text: String
    let id: String

    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isRevealed {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textContentType(.password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .accessibilityIdentifier(id)

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundColor(SphirColor.mutedText)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
            .accessibilityIdentifier("\(id)RevealButton")
        }
    }
}
