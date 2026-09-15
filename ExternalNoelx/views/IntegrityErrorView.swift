import SwiftUI

struct IntegrityErrorView: View {
    let result: IntegrityResult
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            AnimatedHyperBackdrop()
                .ignoresSafeArea()

            Color.black.opacity(0.25).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer(minLength: 60)

                    // Warning icon
                    ZStack {
                        Circle()
                            .fill(AppTheme.danger.opacity(0.18))
                            .frame(width: 120, height: 120)
                            .blur(radius: 30)

                        Circle()
                            .fill(AppTheme.surfaceElevated)
                            .frame(width: 96, height: 96)
                            .overlay(
                                Circle().stroke(AppTheme.danger.opacity(0.6), lineWidth: 1.2)
                            )

                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(AppTheme.danger)
                    }

                    // Title
                    VStack(spacing: 8) {
                        Text("EXTERNAL NIXX")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .tracking(1.8)
                            .foregroundStyle(AppTheme.silverGradient)

                        Text(titleText)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppTheme.danger)
                            .multilineTextAlignment(.center)
                    }

                    // Message card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(AppTheme.danger)
                            Text("Details")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(AppTheme.silverDim)
                            Spacer()
                        }

                        Text(messageText)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.silver)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(AppTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(AppTheme.danger.opacity(0.4), lineWidth: 1)
                            )
                    )

                    // Actions
                    VStack(spacing: 12) {
                        Button {
                            onRetry()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.clockwise")
                                Text("RETRY CHECK")
                            }
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(AppTheme.accent)
                            )
                        }
                        .buttonStyle(.plain)

                        Text("If this keeps happening, contact support or reinstall from the official source.")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.silverMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 24)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var titleText: String {
        switch result {
        case .ok:                       return "OK"
        case .tamperedExecutable:       return "TAMPERED BINARY"
        case .tamperedInfoPlist:        return "TAMPERED CONFIG"
        case .tamperedPatch:            return "TAMPERED PATCH"
        case .jailedDevice:             return "UNSUPPORTED DEVICE"
        case .hooked:                   return "HOOKED ENVIRONMENT"
        case .unknown:                  return "INTEGRITY FAILURE"
        }
    }

    private var messageText: String {
        switch result {
        case .ok:
            return "Everything looks good."

        case .tamperedExecutable:
            return "The app executable has been modified since it was first installed. This app cannot run with a tampered binary. Please reinstall EXTERNAL NIXX from the official source."

        case .tamperedInfoPlist:
            return "The app configuration (Info.plist) has been modified. This usually means the IPA was repackaged. Please reinstall from the official source."

        case .tamperedPatch(let filename):
            return "The patch file \"\(filename)\" has been modified or replaced. Only patches provided through the official channel are allowed. Please reinstall the patch or restore it from the original IPA."

        case .jailedDevice:
            return "A jailbreak or unauthorised modification was detected on this device. EXTERNAL NIXX runs only on non-jailbroken devices. Please restore your device to the stock iOS firmware."

        case .hooked:
            return "A hooking or instrumentation framework (Frida, Substrate, or similar) was detected. Close any tweak tools and relaunch the app."

        case .unknown:
            return "An integrity check failed. Please reinstall EXTERNAL NIXX from the official source."
        }
    }
}
