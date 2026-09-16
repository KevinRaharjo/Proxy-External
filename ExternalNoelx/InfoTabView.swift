import SwiftUI

struct InfoTabView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var announcements: [Announcement] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            ZStack {
                BP.bg.ignoresSafeArea()

                if isLoading && announcements.isEmpty {
                    ProgressView().tint(BP.accent)
                } else if let error = errorMessage, announcements.isEmpty {
                    errorView(error)
                } else if announcements.isEmpty {
                    emptyView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(announcements.enumerated()), id: \.element.id) { idx, ann in
                                announcementCard(ann, index: idx + 1)
                            }
                        }
                        .padding(12)
                    }
                    .refreshable { await load(force: true) }
                }
            }
            .navigationTitle("ANNOUNCEMENTS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await load(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .disabled(isLoading)
                    .foregroundStyle(BP.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("DONE") { dismiss() }
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(BP.accent)
                }
            }
            .task {
                guard !hasLoaded else { return }
                hasLoaded = true
                await load()
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func announcementCard(_ ann: Announcement, index: Int) -> some View {
        let typeColor = ann.type.color
        BPSection(index: index, title: ann.type.rawValue, accentColor: typeColor) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    if ann.pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(typeColor)
                    }
                    if ann.priority == .high {
                        BPBadge(text: "HIGH", color: BP.danger, icon: "exclamationmark")
                    }
                    Spacer()
                    if let date = ann.publishedAt {
                        Text(timeAgo(date))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(BP.textFaint)
                    }
                }

                Text(ann.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(BP.text)

                Text(ann.body)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(BP.textDim)
                    .fixedSize(horizontal: false, vertical: true)

                if let label = ann.actionLabel, let urlStr = ann.actionUrl, let url = URL(string: urlStr) {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Text(label.uppercased())
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .tracking(1.2)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(typeColor)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .overlay(Rectangle().stroke(typeColor.opacity(0.6), lineWidth: 0.8))
                    }
                }
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(BP.textFaint)
            Text("NO ANNOUNCEMENTS")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundStyle(BP.textDim)
            Text("Belum ada pengumuman dari server")
                .font(.system(size: 11))
                .foregroundStyle(BP.textFaint)
            Button {
                Task { await load(force: true) }
            } label: {
                Text("REFRESH")
            }
            .buttonStyle(BPButtonStyle())
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(BP.danger)
            Text("CONNECTION ERROR")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundStyle(BP.danger)
            Text(msg)
                .font(.system(size: 11))
                .foregroundStyle(BP.textFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await load(force: true) }
            } label: {
                Text("RETRY")
            }
            .buttonStyle(BPButtonStyle(color: BP.danger))
        }
    }

    private func load(force: Bool = false) async {
        isLoading = true
        errorMessage = nil
        do {
            announcements = try await AnnouncementService.shared.fetch(force: force)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func timeAgo(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 60 { return "just now" }
        let m = s / 60
        if m < 60 { return "\(m)m ago" }
        let h = m / 60
        if h < 24 { return "\(h)h ago" }
        return "\(h / 24)d ago"
    }
}
