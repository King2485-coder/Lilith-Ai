import SwiftUI

struct SplashScreenView: View {
    @ObservedObject var theme = ThemeManager.shared
    @State private var isActive = false
    @State private var opacity = 0.0
    @State private var scale = 0.8
    
    var body: some View {
        ZStack {
            theme.primaryBackground
                .ignoresSafeArea()
            
            VStack(spacing: theme.spacingXXL) {
                Image(systemName: "server.rack")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(theme.accent)
                    .scaleEffect(scale)
                
                VStack(spacing: theme.spacingS) {
                    Text("Linux Machine Operator")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(theme.primaryText)
                    
                    Text("Remote System Management")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(theme.secondaryText)
                }
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                    .scaleEffect(1.2)
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(theme.springSmooth) {
                opacity = 1.0
                scale = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(theme.springSnappy) {
                    isActive = true
                }
            }
        }
        .fullScreenCover(isPresented: $isActive) {
            MachineConnectionView()
        }
    }
}