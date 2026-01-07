//
//  MacSplashView.swift
//  SwiftSpeakMac
//
//  Splash screen shown during app initialization
//  Displays pulsing logo while audio engine warms up
//

import SwiftUI

struct MacSplashView: View {
    @State private var logoScale: CGFloat = 1.0
    @State private var logoOpacity: Double = 0.7
    @State private var glowRadius: CGFloat = 10

    var body: some View {
        ZStack {
            // Dark background with subtle gradient
            LinearGradient(
                colors: [
                    Color.black.opacity(0.95),
                    Color(white: 0.1).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 20) {
                // Pulsing logo with glow
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.blue.opacity(0.3),
                                    Color.purple.opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 30,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .blur(radius: glowRadius)
                        .scaleEffect(logoScale)

                    // Logo
                    Image("SwiftSpeakLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                }

                // App name
                Text("SwiftSpeak")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Loading indicator
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                        .tint(.white.opacity(0.7))

                    Text("Initializing...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 8)
            }
        }
        .frame(width: 240, height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 10)
        .onAppear {
            startPulseAnimation()
        }
    }

    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 1.2)
            .repeatForever(autoreverses: true)
        ) {
            logoScale = 1.08
            logoOpacity = 1.0
            glowRadius = 20
        }
    }
}

// MARK: - Splash Window Controller

@MainActor
final class MacSplashController {
    private var splashWindow: NSWindow?

    func show() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 280),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isReleasedWhenClosed = false

        let hostingView = NSHostingView(rootView: MacSplashView())
        window.contentView = hostingView

        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 120
            let y = screenFrame.midY - 140
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window.makeKeyAndOrderFront(nil)
        splashWindow = window
    }

    func dismiss() {
        guard let window = splashWindow else { return }

        // Fade out animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            self?.splashWindow = nil
        })
    }
}

// MARK: - Preview

#Preview {
    MacSplashView()
        .background(Color.gray)
}
