import SwiftUI

enum PrivacyPolicy {
    static let url = URL(string: "https://tyamada.github.io/MihirakiPDFViewer/privacy.html")
}

struct PrivacyPolicyLink: View {
    var body: some View {
        if let url = PrivacyPolicy.url {
            Link(destination: url) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
            .accessibilityIdentifier("privacyPolicyLink")
        }
    }
}
