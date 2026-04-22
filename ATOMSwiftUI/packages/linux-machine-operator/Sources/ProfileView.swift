import SwiftUI

struct AboutView: View {
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: theme.spacingL) {
                        if let homepageURL = Bundle.main.infoDictionary?["AppMetadataURLs"] as? [String: String],
                           let homepage = homepageURL["HomepageURL"],
                           let url = URL(string: homepage) {
                            Link(destination: url) {
                                HStack {
                                    Text("Homepage")
                                        .font(.system(size: 17, design: .rounded))
                                        .foregroundColor(theme.primaryText)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundColor(theme.tertiaryText)
                                }
                                .padding(theme.spacingL)
                                .background(
                                    RoundedRectangle(cornerRadius: theme.radiusLarge)
                                        .fill(theme.cardBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: theme.radiusLarge)
                                        .stroke(theme.border, lineWidth: 1)
                                )
                            }
                        }
                        
                        if let supportURL = Bundle.main.infoDictionary?["AppMetadataURLs"] as? [String: String],
                           let support = supportURL["SupportURL"],
                           let url = URL(string: support) {
                            Link(destination: url) {
                                HStack {
                                    Text("Support")
                                        .font(.system(size: 17, design: .rounded))
                                        .foregroundColor(theme.primaryText)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundColor(theme.tertiaryText)
                                }
                                .padding(theme.spacingL)
                                .background(
                                    RoundedRectangle(cornerRadius: theme.radiusLarge)
                                        .fill(theme.cardBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: theme.radiusLarge)
                                        .stroke(theme.border, lineWidth: 1)
                                )
                            }
                        }
                        
                        if let privacyURL = Bundle.main.infoDictionary?["AppMetadataURLs"] as? [String: String],
                           let privacy = privacyURL["PrivacyPolicyURL"],
                           let url = URL(string: privacy) {
                            Link(destination: url) {
                                HStack {
                                    Text("Privacy Policy")
                                        .font(.system(size: 17, design: .rounded))
                                        .foregroundColor(theme.primaryText)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundColor(theme.tertiaryText)
                                }
                                .padding(theme.spacingL)
                                .background(
                                    RoundedRectangle(cornerRadius: theme.radiusLarge)
                                        .fill(theme.cardBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: theme.radiusLarge)
                                        .stroke(theme.border, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .frame(maxWidth: 450)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingL)
                }
            }
            .navigationTitle("About & Legal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(theme.accent)
                }
            }
        }
    }
}