import SwiftUI

struct RootTabView: View {
    @State private var selectedTab: Int = 0
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var licenseManager: LicenseManager

    var body: some View {
        ZStack {
            BP.bg.ignoresSafeArea()

            Group {
                switch selectedTab {
                case 0: InfoTabView()
                case 1: PatchProjectsView()
                default: InfoTabView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                Spacer()
                BPTabBar(selected: $selectedTab)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .preferredColorScheme(.dark)
    }
}

struct BPTabBar: View {
    @Binding var selected: Int
    private let items: [(icon: String, label: String)] = [
        ("megaphone", "INFO"),
        ("shippingbox", "PATCH")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                tabButton(index: idx, icon: item.icon, label: item.label)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background(
            BP.panel.overlay(alignment: .top) {
                Rectangle().fill(BP.line).frame(height: 0.5)
            }
        )
    }

    private func tabButton(index: Int, icon: String, label: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { selected = index }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: selected == index ? .semibold : .regular))
                    .foregroundStyle(selected == index ? BP.accent : BP.textFaint)
                Text(label)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(selected == index ? BP.accent : BP.textFaint)
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .top) {
                if selected == index {
                    Rectangle().fill(BP.accent).frame(width: 20, height: 1.5).offset(y: -8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
