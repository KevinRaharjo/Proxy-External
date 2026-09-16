import SwiftUI

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Accent Preset (bisa ganti warna)
// ═══════════════════════════════════════════════════════════════════════

enum AccentPreset: String, CaseIterable, Identifiable {
    case cyan   = "cyan"
    case blue   = "blue"
    case green  = "green"
    case amber  = "amber"
    case red    = "red"
    case purple = "purple"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cyan:   return "Cyan"
        case .blue:   return "Blue"
        case .green:  return "Green"
        case .amber:  return "Amber"
        case .red:    return "Red"
        case .purple: return "Purple"
        }
    }

    var color: Color {
        switch self {
        case .cyan:   return Color(red: 0.133, green: 0.827, blue: 0.933) // #22D3EE
        case .blue:   return Color(red: 0.310, green: 0.557, blue: 0.969) // #4F8EFF
        case .green:  return Color(red: 0.290, green: 0.780, blue: 0.510) // #4AC782
        case .amber:  return Color(red: 0.984, green: 0.749, blue: 0.141) // #FBBF24
        case .red:    return Color(red: 0.937, green: 0.267, blue: 0.267) // #EF4444
        case .purple: return Color(red: 0.659, green: 0.333, blue: 0.969) // #A855F7
        }
    }

    var dim: Color { color.opacity(0.15) }
    var glow: Color { color.opacity(0.35) }
}

// Global accent — dibaca dari @AppStorage, fallback ke cyan
enum AccentStore {
    static let storageKey = "app.accentPreset"
    static var current: AccentPreset {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? AccentPreset.cyan.rawValue
        return AccentPreset(rawValue: raw) ?? .cyan
    }
    static var color: Color { current.color }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Blueprint Theme
// ═══════════════════════════════════════════════════════════════════════

enum BP {
    // ─── Canvas ──────────────────────────────
    static let bg           = Color(red: 0.039, green: 0.055, blue: 0.078) // #0A0E14
    static let panel        = Color(red: 0.055, green: 0.075, blue: 0.102) // #0E131A
    static let panelHi      = Color(red: 0.075, green: 0.098, blue: 0.129) // #131921
    static let line         = Color(red: 0.133, green: 0.169, blue: 0.216) // #222B37
    static let lineBright   = Color(red: 0.200, green: 0.251, blue: 0.322) // #334052

    // ─── Text ────────────────────────────────
    static let text         = Color(red: 0.898, green: 0.918, blue: 0.937) // #E5EAF0
    static let textDim      = Color(red: 0.541, green: 0.580, blue: 0.647) // #8A94A5
    static let textFaint    = Color(red: 0.365, green: 0.400, blue: 0.463) // #5D6676

    // ─── Semantic ────────────────────────────
    static let success      = Color(red: 0.290, green: 0.780, blue: 0.510)
    static let warning      = Color(red: 0.984, green: 0.749, blue: 0.141)
    static let danger       = Color(red: 0.937, green: 0.267, blue: 0.267)
    static let info         = Color(red: 0.310, green: 0.557, blue: 0.969)
}

// Dynamic accent — pake ini di view baru
extension BP {
    static var accent: Color { AccentStore.color }
    static var accentDim: Color { AccentStore.color.opacity(0.15) }
    static var accentGlow: Color { AccentStore.color.opacity(0.35) }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Announcement Type Color (per-item)
// ═══════════════════════════════════════════════════════════════════════

enum AnnouncementType: String, Codable {
    case info
    case warning
    case update
    case maintenance

    var color: Color {
        switch self {
        case .info:        return BP.accent
        case .warning:     return BP.warning
        case .update:      return BP.success
        case .maintenance: return BP.danger
        }
    }

    var icon: String {
        switch self {
        case .info:        return "info.circle"
        case .warning:     return "exclamationmark.triangle"
        case .update:      return "arrow.down.circle"
        case .maintenance: return "wrench.and.screwdriver"
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Legacy AppTheme (biar view lama tetap kompil)
// ═══════════════════════════════════════════════════════════════════════

enum AppTheme {
    static let pageBackground     = BP.bg
    static let consoleBackground  = Color(red: 0.043, green: 0.055, blue: 0.086)
    static let surface            = BP.panel
    static let surfaceElevated    = BP.panelHi
    static let surfaceHighlight   = BP.lineBright

    static let borderSubtle       = BP.line
    static let borderHighlight    = BP.lineBright
    static let borderAccent       = BP.accent

    static var accent: Color { BP.accent }
    static var accentBright: Color { BP.accent }
    static var accentDeep: Color { BP.accent.opacity(0.6) }
    static var accentGlow: Color { BP.accentGlow }

    static let silver             = BP.text
    static let silverBright       = Color.white
    static let silverDim          = BP.textDim
    static let silverMuted        = BP.textFaint

    static let success            = BP.success
    static let warning            = BP.warning
    static let danger             = BP.danger
    static let info               = BP.info

    static let secondaryAccent    = Color.white
    static let referenceCard      = BP.panelHi.opacity(0.78)

    static let pageInset: CGFloat           = 18
    static let cardCorner: CGFloat          = 14
    static let cardCornerSmall: CGFloat     = 8
    static let rowIconSize: CGFloat         = 18
    static let rowIconFrame: CGFloat        = 30
    static let fileRowIconSize: CGFloat     = 18
    static let fileRowIconFrame: CGFloat    = 32
    static let fileRowHeight: CGFloat       = 62
    static let appIconSize: CGFloat         = 34
    static let emptyIconSize: CGFloat       = 34
    static let selectionIconSize: CGFloat   = 20

    static var pageGradient: LinearGradient {
        LinearGradient(
            colors: [BP.bg, Color(red: 0.055, green: 0.075, blue: 0.102), BP.bg],
            startPoint: .top, endPoint: .bottom
        )
    }
    static var cardGradient: LinearGradient {
        LinearGradient(colors: [BP.panel, BP.panelHi], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [BP.accent, BP.accent.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var silverGradient: LinearGradient {
        LinearGradient(colors: [Color.white, BP.text, BP.textDim], startPoint: .top, endPoint: .bottom)
    }
    static var glowGradient: RadialGradient {
        RadialGradient(colors: [BP.accent.opacity(0.25), BP.accent.opacity(0.0)],
                       center: .center, startRadius: 0, endRadius: 180)
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Backdrop (legacy — tetap ada)
// ═══════════════════════════════════════════════════════════════════════

struct AnimatedHyperBackdrop: View {
    var body: some View {
        ZStack {
            AppTheme.pageGradient.ignoresSafeArea()
            Canvas { ctx, size in
                var path = Path()
                let spacing: CGFloat = 46
                stride(from: CGFloat(0), through: size.width, by: spacing).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
                }
                stride(from: CGFloat(0), through: size.height, by: spacing).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
                }
                ctx.stroke(path, with: .color(BP.line.opacity(0.25)), lineWidth: 0.4)
            }
            .ignoresSafeArea()
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Blueprint Components
// ═══════════════════════════════════════════════════════════════════════

/// Section card dengan nomor ala blueprint
struct BPSection<Content: View>: View {
    let index: Int
    let title: String
    var accentColor: Color = BP.accent
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("─ \(String(format: "%02d", index)) ─")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(accentColor.opacity(0.5))
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(accentColor)
                Spacer()
                Circle()
                    .fill(accentColor.opacity(0.6))
                    .frame(width: 5, height: 5)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(BP.panel)
            .overlay(alignment: .bottom) { Rectangle().fill(BP.line).frame(height: 0.5) }

            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BP.bg)
        }
        .overlay(Rectangle().stroke(BP.line, lineWidth: 0.5))
    }
}

/// Card simple (tanpa nomor)
struct BPCard<Content: View>: View {
    var accentColor: Color = BP.accent
    var showAccentBar: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BP.panel)
            .overlay(Rectangle().stroke(BP.line, lineWidth: 0.5))
            .overlay(alignment: .leading) {
                if showAccentBar {
                    Rectangle().fill(accentColor).frame(width: 2)
                }
            }
    }
}

/// Badge dengan warna custom (buat status/type)
struct BPBadge: View {
    let text: String
    var color: Color = BP.accent
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon).font(.system(size: 9, weight: .bold))
            }
            Text(text.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.0)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .overlay(Rectangle().stroke(color.opacity(0.4), lineWidth: 0.5))
    }
}

/// Button blueprint
struct BPButtonStyle: ButtonStyle {
    var color: Color = BP.accent
    var filled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(filled ? BP.bg : color)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(filled ? color : BP.bg)
            .overlay(Rectangle().stroke(color, lineWidth: filled ? 0 : 0.8))
            .overlay(alignment: .leading) {
                if !filled { Rectangle().fill(color).frame(width: 2) }
            }
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

/// Status bar dengan cursor blink + clock
struct BPStatusBar: View {
    let message: String
    var accentColor: Color = BP.accent
    @State private var cursor = true
    @State private var time = Date()
    let cursorTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            Text("▸").foregroundStyle(accentColor)
            Text(message)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(BP.textDim)
            Text("_")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(accentColor)
                .opacity(cursor ? 1 : 0)
            Spacer()
            Text(formatTime(time))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(BP.textFaint)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(BP.panel)
        .overlay(alignment: .top) { Rectangle().fill(BP.line).frame(height: 0.5) }
        .onReceive(cursorTimer) { _ in
            withAnimation(.linear(duration: 0.05)) { cursor.toggle() }
        }
        .onReceive(clockTimer) { time = $0 }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Legacy Components (tetap ada biar gak rusak)
// ═══════════════════════════════════════════════════════════════════════

struct AppSurfaceCard<Content: View>: View {
    var corner: CGFloat = AppTheme.cardCorner
    var glowColor: Color? = nil
    var glowActive: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .background(RoundedRectangle(cornerRadius: corner, style: .continuous).fill(AppTheme.cardGradient))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(glowActive ? (glowColor ?? BP.accent).opacity(0.75) : AppTheme.borderSubtle,
                            lineWidth: glowActive ? 1.2 : 0.8)
            )
            .shadow(color: glowActive ? (glowColor ?? BP.accent).opacity(0.22) : Color.black.opacity(0.35),
                    radius: glowActive ? 18 : 12, x: 0, y: 6)
    }
}

struct AppRowIcon: View {
    let systemName: String
    var tint: Color = BP.accent
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = AppTheme.rowIconFrame

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0.06)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(tint.opacity(0.35), lineWidth: 0.8))
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: frameSize, height: frameSize)
        .accessibilityHidden(true)
    }
}

struct AppSearchField: View {
    @Binding var text: String
    let prompt: String
    let clearLabel: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BP.textDim)
            TextField(prompt, text: $text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .foregroundStyle(BP.text)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BP.textFaint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearLabel)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 40)
        .background(BP.panel)
        .overlay(Rectangle().stroke(BP.line, lineWidth: 0.5))
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, 10)
    }
}

struct AppLogo: View {
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let icon = UIImage(named: "AppIcon60x60")
                ?? Bundle.main.path(forResource: "AppIcon60x60@2x", ofType: "png").flatMap(UIImage.init(contentsOfFile:))
                ?? UIImage(named: "AppIcon") {
                Image(uiImage: icon).resizable().scaledToFill()
            } else {
                ZStack {
                    BP.accent
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: size * 0.45, weight: .black))
                        .foregroundStyle(BP.bg)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .stroke(Color.white.opacity(0.18), lineWidth: 0.8))
    }
}

struct NotchSliderToggle: View {
    @Binding var isOn: Bool
    var tint: Color = BP.accent
    var isBusy: Bool = false
    var onChange: ((Bool) -> Void)? = nil
    @Namespace private var knobNS
    private let trackHeight: CGFloat = 30
    private let trackWidth: CGFloat  = 62
    private let knobSize: CGFloat    = 24
    private let notchCount = 5

    var body: some View {
        ZStack { track; knob }
            .frame(width: trackWidth, height: trackHeight)
            .opacity(isBusy ? 0.55 : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isOn)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isBusy else { return }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { isOn.toggle() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onChange?(isOn)
            }
    }

    private var track: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(isOn ? AnyShapeStyle(tint.opacity(0.85)) : AnyShapeStyle(BP.panelHi))
                .overlay(Capsule(style: .continuous).stroke(isOn ? tint : BP.lineBright, lineWidth: 0.8))
            HStack(spacing: 0) {
                ForEach(0..<notchCount, id: \.self) { i in
                    Rectangle()
                        .fill(isOn ? Color.white.opacity(0.30) : BP.lineBright.opacity(0.55))
                        .frame(width: 1, height: 8)
                    if i < notchCount - 1 { Spacer(minLength: 0) }
                }
            }.padding(.horizontal, 9)
        }
    }

    private var knob: some View {
        HStack(spacing: 0) {
            if isOn { Spacer(minLength: 0) }
            Circle()
                .fill(BP.text)
                .overlay(Circle().stroke(isOn ? tint : BP.lineBright, lineWidth: 0.8))
                .overlay(Image(systemName: isOn ? "bolt.fill" : "power")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(isOn ? BP.bg : BP.textFaint))
                .frame(width: knobSize, height: knobSize)
                .padding(.horizontal, 3)
            if !isOn { Spacer(minLength: 0) }
        }
    }
}

struct GlowPulse: ViewModifier {
    var active: Bool
    var color: Color = BP.accent
    @State private var pulse: Bool = false

    func body(content: Content) -> some View {
        content
            .shadow(color: active ? color.opacity(pulse ? 0.45 : 0.15) : .clear, radius: pulse ? 16 : 8)
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
            }
    }
}

extension View {
    func glowPulse(active: Bool, color: Color = BP.accent) -> some View {
        modifier(GlowPulse(active: active, color: color))
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    var tint: Color = BP.accent
    var fullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(BP.bg)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 52)
            .padding(.horizontal, 18)
            .background(tint)
            .overlay(Rectangle().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(BP.text)
            .frame(minHeight: 46)
            .padding(.horizontal, 16)
            .background(BP.panelHi)
            .overlay(Rectangle().stroke(BP.lineBright, lineWidth: 0.8))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct AppStatCard: View {
    let value: String
    let label: String
    var tint: Color = BP.accent
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let icon {
                    Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(tint)
                }
                Spacer()
            }
            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(BP.text)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(BP.textFaint)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BP.panel)
        .overlay(Rectangle().stroke(BP.line, lineWidth: 0.5))
        .overlay(alignment: .leading) { Rectangle().fill(tint).frame(width: 3) }
    }
}
