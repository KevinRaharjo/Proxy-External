import SwiftUI

struct TargetSelectionView: View {
    @Binding var selectedTarget: String
    
    var body: some View {
        ZStack {
            AnimatedHyperBackdrop()
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                VStack(spacing: 12) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(AppTheme.accent)
                    
                    Text("Select Target")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("Choose which game to patch")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                VStack(spacing: 16) {
                    targetButton(
                        title: "FF NORMAL",
                        subtitle: "Free Fire Normal",
                        icon: "flame.fill",
                        color: AppTheme.accent,
                        target: "freefireth"
                    )
                    
                    targetButton(
                        title: "FF MAX",
                        subtitle: "Free Fire Max",
                        icon: "flame.fill",
                        color: AppTheme.secondaryAccent,
                        target: "freefiremax"
                    )
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                Text("You can change this later in settings")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func targetButton(title: String, subtitle: String, icon: String, color: Color, target: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedTarget = target
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 56, height: 56)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(color)
            }
            .padding(16)
            .background(Color.black.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
