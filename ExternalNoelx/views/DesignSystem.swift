import SwiftUI

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Theme
// ═══════════════════════════════════════════════════════════════════════

enum AppTheme {

    // ─── Background palette ───────────────────────────────────────────
    static let pageBackground     = Color(red: 0.024, green: 0.031, blue: 0.059) // #06080F
    static let consoleBackground  = Color(red: 0.043, green: 0.055, blue: 0.086) // #0B0E16
    static let surface            = Color(red: 0.059, green: 0.086, blue: 0.149) // #0F1626
    static let surfaceElevated    = Color(red: 0.102, green: 0.137, blue: 0.220) // #1A2338
    static let surfaceHighlight   = Color(red: 0.161, green: 0.208, blue: 0.310) // #29354F

    // ─── Border palette ───────────────────────────────────────────────
    static let borderSubtle       = Color(red: 0.165, green: 0.208, blue: 0.282) // #2A3548
    static let borderHighlight    = Color(red: 0.278, green: 0.333, blue: 0.412) // #475569
    static let borderAccent       = Color(red: 0.231, green: 0.510, blue: 0.965) // #3B82F6

    // ─── Accent (electric blue) ───────────────────────────────────────
    static let accent             = Color(red: 0.231, green: 0.510, blue: 0.965) // #3B82F6
    static let accentBright       = Color(red: 0.376, green: 0.647, blue: 0.980) // #60A5FA
    static let accentDeep         = Color(red: 0.118, green: 0.251, blue: 0.686) // #1E40AF
    static let accentGlow         = Color(red: 0.231, green: 0.510, blue: 0.965).opacity(0.35)

    // ─── Silver palette ───────────────────────────────────────────────
    static let silver             = Color(red: 0.886, green: 0.910, blue: 0.941) // #E2E8F0
    static let silverBright       = Color.white
    static let silverDim          = Color(red: 0.580, green: 0.639, blue: 0.722) // #94A3B8
    static let silverMuted        = Color(red: 0.392, green: 0.455, blue: 0.545) // #64748B

    // ─── Semantic ─────────────────────────────────────────────────────
    static let success            = Color(red: 0.063, green: 0.725, blue: 0.506) // #10B981
    static let warning            = Color(red: 0.961, green: 0.620, blue: 0.043) // #F59E0B
    static let danger             = Color(red: 0.937, green: 0.267, blue: 0.267) // #EF4444
    static let info               = Color(red: 0.231, green: 0.510, blue: 0.965) // #3B82F6

    // ─── Legacy aliases (biar view lama tetap kompil) ─────────────────
    static let secondaryAccent    = silverBright
    static let referenceCard      = surfaceElevated.opacity(0.78)

    // ─── Spacing & sizes ──────────────────────────────────────────────
    static let pageInset: CGFloat           = 18
    static let cardCorner: CGFloat          = 22
    static let cardCornerSmall: CGFloat     = 16
    static let rowIconSize: CGFloat         = 18
    static let rowIconFrame: CGFloat        = 30
    static let fileRowIconSize: CGFloat     = 18
    static let fileRowIconFrame: CGFloat    = 32
    static let fileRowHeight: CGFloat       = 62
    static let appIconSize: CGFloat         = 34
    static let emptyIconSize: CGFloat       = 34
    static let selectionIconSize: CGFloat   = 20

    // ─── Gradients ────────────────────────────────────────────────────
    static var pageGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.024, green: 0.031, blue: 0.059),   // #06080F
                Color(red: 0.043, green: 0.071, blue: 0.129),   // #0B1221
                Color(red: 0.024, green: 0.031, blue: 0.059)    // #06080F
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [surface, surfaceElevated],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accentBright, accent, accentDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var silverGradient: LinearGradient {
        LinearGradient(
            colors: [silverBright, silver, silverDim],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var glowGradient: RadialGradient {
        RadialGradient(
            colors: [accent.opacity(0.25), accent.opacity(0.0)],
            center: .center,
            startRadius: 0,
            endRadius: 180
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Animated Backdrop (particle + grid + orb)
// ═══════════════════════════════════════════════════════════════════════

struct AnimatedHyperBackdrop: View {
    @State private var orbPhase: Bool = false
    @State private var particlePhase: Bool = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppTheme.pageGradient.ignoresSafeArea()
                BackdropGrid()
                BackdropOrbs(phase: orbPhase, size: proxy.size)
                ParticleField(phase: particlePhase)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    orbPhase = true
                }
                withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                    particlePhase = true
                }
            }
        }
        .ignoresSafeArea()
    }
}

// ─── Grid overlay ─────────────────────────────────────────────────────

private struct BackdropGrid: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let spacing: CGFloat = 46
            stride(from: CGFloat(0), through: size.width, by: spacing).forEach { x in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            stride(from: CGFloat(0), through: size.height, by: spacing).forEach { y in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(AppTheme.borderSubtle.opacity(0.18)), lineWidth: 0.5)
        }
        .ignoresSafeArea()
    }
}

// ─── Blue orbs ────────────────────────────────────────────────────────

private struct BackdropOrbs: View {
    let phase: Bool
    let size: CGSize

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.accent.opacity(0.16))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(
                    x: phase ? size.width * 0.35 : -size.width * 0.35,
                    y: -size.height * 0.28
                )
            Circle()
                .fill(AppTheme.accentBright.opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 100)
                .offset(
                    x: phase ? -size.width * 0.30 : size.width * 0.30,
                    y: size.height * 0.30
                )
            Circle()
                .fill(AppTheme.accentDeep.opacity(0.14))
                .frame(width: 200, height: 200)
                .blur(radius: 80)
                .offset(
                    x: phase ? size.width * 0.20 : -size.width * 0.20,
                    y: size.height * 0.05
                )
        }
    }
}

// ─── Particle field ───────────────────────────────────────────────────

private struct ParticleField: View {
    let phase: Bool
    private let particles: [ParticleSeed] = ParticleSeed.spawn(count: 42)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(particles) { seed in
                    Circle()
                        .fill(seed.color)
                        .frame(width: seed.size, height: seed.size)
                        .position(
                            x: seed.x * proxy.size.width,
                            y: phase
                                ? (seed.y + 1.0).truncatingRemainder(dividingBy: 1.0) * proxy.size.height
                                : seed.y * proxy.size.height
                        )
                        .opacity(seed.opacity)
                        .blur(radius: seed.blur)
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct ParticleSeed: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
    let blur: CGFloat
    let color: Color

    static func spawn(count: Int) -> [ParticleSeed] {
        (0..<count).map { _ in
            ParticleSeed(
                x: .random(in: 0...1),
                y: .random(in: 0...1),
                size: .random(in: 1.2...3.2),
                opacity: .random(in: 0.25...0.75),
                blur: .random(in: 0.2...1.0),
                color: Bool.random()
                    ? AppTheme.accentBright
                    : AppTheme.silver
            )
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Surfaces (card / panel)
// ═══════════════════════════════════════════════════════════════════════

struct AppSurfaceCard<Content: View>: View {
    var corner: CGFloat = AppTheme.cardCorner
    var glowColor: Color? = nil
    var glowActive: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(AppTheme.cardGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(
                        glowActive
                            ? (glowColor ?? AppTheme.accent).opacity(0.75)
                            : AppTheme.borderSubtle,
                        lineWidth: glowActive ? 1.2 : 0.8
                    )
            )
            .overlay(
                Group {
                    if glowActive, let glowColor {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .stroke(glowColor.opacity(0.35), lineWidth: 3)
                            .blur(radius: 6)
                            .opacity(0.9)
                    }
                }
            )
            .shadow(
                color: glowActive
                    ? (glowColor ?? AppTheme.accent).opacity(0.22)
                    : Color.black.opacity(0.35),
                radius: glowActive ? 18 : 12,
                x: 0,
                y: 6
            )
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Row Icon
// ═══════════════════════════════════════════════════════════════════════

struct AppRowIcon: View {
    let systemName: String
    var tint: Color = AppTheme.accent
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = AppTheme.rowIconFrame

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.22), tint.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(tint.opacity(0.35), lineWidth: 0.8)
                )
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: frameSize, height: frameSize)
        .accessibilityHidden(true)
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Search field
// ═══════════════════════════════════════════════════════════════════════

struct AppSearchField: View {
    @Binding var text: String
    let prompt: String
    let clearLabel: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.silverDim)
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .foregroundStyle(AppTheme.silver)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.silverMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearLabel)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 40)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.borderSubtle, lineWidth: 0.8)
                )
        )
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.4))
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Logo
// ═══════════════════════════════════════════════════════════════════════

struct AppLogo: View {
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let icon = UIImage(named: "AppIcon60x60")
                ?? Bundle.main.path(forResource: "AppIcon60x60@2x", ofType: "png").flatMap(UIImage.init(contentsOfFile:))
                ?? UIImage(named: "AppIcon") {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    AppTheme.accentGradient
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: size * 0.45, weight: .black))
                        .foregroundStyle(AppTheme.silverBright)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .stroke(AppTheme.silverBright.opacity(0.18), lineWidth: 0.8)
        )
        .shadow(color: AppTheme.accentGlow, radius: 8, y: 3)
        .accessibilityHidden(true)
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Notch Slider Toggle  (Style D)
// ═══════════════════════════════════════════════════════════════════════

/// Slider toggle with notch — pill track, 5 notches, sliding knob.
/// Passive component: bind `isOn`, receive `onChange` callback.
struct NotchSliderToggle: View {
    @Binding var isOn: Bool
    var tint: Color = AppTheme.accent
    var isBusy: Bool = false
    var onChange: ((Bool) -> Void)? = nil

    @Namespace private var knobNS

    private let trackHeight: CGFloat = 30
    private let trackWidth: CGFloat  = 62
    private let knobSize: CGFloat    = 24
    private let notchCount = 5

    var body: some View {
        ZStack {
            track
            knob
        }
        .frame(width: trackWidth, height: trackHeight)
        .opacity(isBusy ? 0.55 : 1)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isOn)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isBusy else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                isOn.toggle()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onChange?(isOn)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }

    // ─── Track ────────────────────────────────────────────────────────
    private var track: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(
                    isOn
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [tint.opacity(0.85), AppTheme.accentDeep],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                          )
                        : AnyShapeStyle(AppTheme.surfaceElevated)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            isOn ? tint.opacity(0.9) : AppTheme.borderHighlight,
                            lineWidth: 0.8
                        )
                )
                .overlay(
                    Group {
                        if isOn {
                            Capsule(style: .continuous)
                                .stroke(tint.opacity(0.55), lineWidth: 4)
                                .blur(radius: 6)
                                .opacity(0.9)
                        }
                    }
                )

            // Notches
            HStack(spacing: 0) {
                ForEach(0..<notchCount, id: \.self) { i in
                    Rectangle()
                        .fill(
                            isOn
                                ? AppTheme.silverBright.opacity(0.30)
                                : AppTheme.borderHighlight.opacity(0.55)
                        )
                        .frame(width: 1, height: 8)
                    if i < notchCount - 1 {
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 9)
        }
        .shadow(
            color: isOn ? tint.opacity(0.35) : Color.black.opacity(0.35),
            radius: isOn ? 10 : 5,
            y: 3
        )
    }

    // ─── Knob ─────────────────────────────────────────────────────────
    private var knob: some View {
        HStack(spacing: 0) {
            if isOn { Spacer(minLength: 0) }
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppTheme.silverBright, AppTheme.silver],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Circle().stroke(
                        isOn ? tint.opacity(0.9) : AppTheme.borderHighlight,
                        lineWidth: 0.8
                    )
                )
                .overlay(
                    Image(systemName: isOn ? "bolt.fill" : "power")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(
                            isOn
                                ? AppTheme.accentDeep
                                : AppTheme.silverMuted
                        )
                )
                .frame(width: knobSize, height: knobSize)
                .shadow(color: Color.black.opacity(0.45), radius: 3, y: 1)
                .padding(.horizontal, 3)
            if !isOn { Spacer(minLength: 0) }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Glow Pulse Modifier
// ═══════════════════════════════════════════════════════════════════════

struct GlowPulse: ViewModifier {
    var active: Bool
    var color: Color = AppTheme.accent
    @State private var pulse: Bool = false

    func body(content: Content) -> some View {
        content
            .shadow(
                color: active ? color.opacity(pulse ? 0.45 : 0.15) : .clear,
                radius: pulse ? 16 : 8
            )
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

extension View {
    func glowPulse(active: Bool, color: Color = AppTheme.accent) -> some View {
        modifier(GlowPulse(active: active, color: color))
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Buttons
// ═══════════════════════════════════════════════════════════════════════

struct AppPrimaryButtonStyle: ButtonStyle {
    var tint: Color = AppTheme.accent
    var fullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(AppTheme.silverBright)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 52)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.silverBright.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(color: tint.opacity(configuration.isPressed ? 0.15 : 0.4), radius: 14, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(AppTheme.silver)
            .frame(minHeight: 46)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.borderHighlight, lineWidth: 0.8)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Stat Card (dashboard / overview)
// ═══════════════════════════════════════════════════════════════════════

struct AppStatCard: View {
    let value: String
    let label: String
    var tint: Color = AppTheme.accent
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(tint)
                }
                Spacer()
            }
            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.silver)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(AppTheme.silverMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.borderSubtle, lineWidth: 0.8)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .padding(.vertical, 12)
        }
    }
}
