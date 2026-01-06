//
//  Animations.swift
//  SwiftSpeak
//
//  Reusable animation components for the app
//  (Waveforms are in WaveformView.swift)
//

import SwiftUI
import SwiftSpeakCore

// MARK: - Pulse Animation
/// A pulsing circle that expands and fades out repeatedly
struct PulseView: View {
    let color: Color
    let size: CGFloat
    let duration: Double

    @State private var isAnimating = false

    init(color: Color = AppTheme.accent, size: CGFloat = 100, duration: Double = 1.5) {
        self.color = color
        self.size = size
        self.duration = duration
    }

    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 2)
                    .frame(width: size, height: size)
                    .scaleEffect(isAnimating ? 1.5 : 1)
                    .opacity(isAnimating ? 0 : 0.8)
                    .animation(
                        .easeOut(duration: duration)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * duration / 3),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Breathing Glow
/// A soft breathing glow effect for icons or buttons
struct BreathingGlowView: View {
    let color: Color
    let intensity: CGFloat

    @State private var isGlowing = false

    init(color: Color = AppTheme.accent, intensity: CGFloat = 0.6) {
        self.color = color
        self.intensity = intensity
    }

    var body: some View {
        Circle()
            .fill(color.opacity(isGlowing ? intensity : intensity * 0.3))
            .blur(radius: 20)
            .scaleEffect(isGlowing ? 1.2 : 0.9)
            .animation(
                .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                value: isGlowing
            )
            .onAppear {
                isGlowing = true
            }
    }
}

// MARK: - Loading Dots
/// Animated loading dots (3 dots bouncing)
struct LoadingDotsView: View {
    let color: Color
    let dotSize: CGFloat

    @State private var isAnimating = false

    init(color: Color = .primary, dotSize: CGFloat = 8) {
        self.color = color
        self.dotSize = dotSize
    }

    var body: some View {
        HStack(spacing: dotSize * 0.75) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
                    .offset(y: isAnimating ? -dotSize : 0)
                    .animation(
                        .spring(dampingFraction: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Shimmer Effect
/// A shimmering highlight effect (great for loading states)
struct ShimmerView: View {
    let baseColor: Color
    let highlightColor: Color

    @State private var isAnimating = false

    init(baseColor: Color = Color.gray.opacity(0.3), highlightColor: Color = Color.white.opacity(0.5)) {
        self.baseColor = baseColor
        self.highlightColor = highlightColor
    }

    var body: some View {
        GeometryReader { geometry in
            baseColor
                .overlay(
                    LinearGradient(
                        colors: [.clear, highlightColor, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.5)
                    .offset(x: isAnimating ? geometry.size.width : -geometry.size.width)
                )
                .mask(Rectangle())
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Ripple Effect
/// Expanding ripple circles from center
struct RippleView: View {
    let color: Color
    let count: Int

    @State private var isAnimating = false

    init(color: Color = AppTheme.accent, count: Int = 3) {
        self.color = color
        self.count = count
    }

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .stroke(color, lineWidth: 2)
                    .scaleEffect(isAnimating ? 2.5 : 0.5)
                    .opacity(isAnimating ? 0 : 0.8)
                    .animation(
                        .easeOut(duration: 2.0)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.6),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Spinning Loader
/// A spinning arc loader
struct SpinningLoaderView: View {
    let color: Color
    let lineWidth: CGFloat

    @State private var isAnimating = false

    init(color: Color = AppTheme.accent, lineWidth: CGFloat = 3) {
        self.color = color
        self.lineWidth = lineWidth
    }

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                AngularGradient(
                    colors: [color.opacity(0), color],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(
                .linear(duration: 1.0).repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Success Checkmark
/// Animated checkmark that draws in
struct AnimatedCheckmark: View {
    let color: Color
    let lineWidth: CGFloat

    @State private var isDrawn = false

    init(color: Color = .green, lineWidth: CGFloat = 4) {
        self.color = color
        self.lineWidth = lineWidth
    }

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let size = min(geometry.size.width, geometry.size.height)
                let startX = size * 0.2
                let startY = size * 0.5
                let midX = size * 0.4
                let midY = size * 0.7
                let endX = size * 0.8
                let endY = size * 0.3

                path.move(to: CGPoint(x: startX, y: startY))
                path.addLine(to: CGPoint(x: midX, y: midY))
                path.addLine(to: CGPoint(x: endX, y: endY))
            }
            .trim(from: 0, to: isDrawn ? 1 : 0)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .animation(.spring(dampingFraction: 0.7).delay(0.1), value: isDrawn)
        }
        .onAppear {
            isDrawn = true
        }
    }
}

// MARK: - Bounce In Modifier
/// View modifier for bounce-in animation
struct BounceInModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1 : 0.5)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.spring(dampingFraction: 0.6).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Slide In Modifier
/// View modifier for slide-in animation
struct SlideInModifier: ViewModifier {
    let edge: Edge
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .offset(x: offsetX, y: offsetY)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.spring(dampingFraction: 0.8).delay(delay)) {
                    isVisible = true
                }
            }
    }

    private var offsetX: CGFloat {
        guard !isVisible else { return 0 }
        switch edge {
        case .leading: return -50
        case .trailing: return 50
        default: return 0
        }
    }

    private var offsetY: CGFloat {
        guard !isVisible else { return 0 }
        switch edge {
        case .top: return -50
        case .bottom: return 50
        default: return 0
        }
    }
}

// MARK: - Fade In Modifier
/// View modifier for fade-in animation
struct FadeInModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Scale On Press Modifier
/// Button press scale effect
struct ScaleOnPressModifier: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1)
            .animation(.spring(dampingFraction: 0.7), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

// MARK: - View Extensions
extension View {
    /// Applies bounce-in animation when view appears
    func bounceIn(delay: Double = 0) -> some View {
        modifier(BounceInModifier(delay: delay))
    }

    /// Applies slide-in animation from specified edge
    func slideIn(from edge: Edge, delay: Double = 0) -> some View {
        modifier(SlideInModifier(edge: edge, delay: delay))
    }

    /// Applies fade-in animation when view appears
    func fadeIn(delay: Double = 0) -> some View {
        modifier(FadeInModifier(delay: delay))
    }

    /// Applies scale effect when pressed
    func scaleOnPress() -> some View {
        modifier(ScaleOnPressModifier())
    }
}

// MARK: - Previews
#Preview("Pulse") {
    ZStack {
        Color.black.ignoresSafeArea()
        PulseView()
            .frame(width: 100, height: 100)
    }
}

#Preview("Breathing Glow") {
    ZStack {
        Color.black.ignoresSafeArea()
        ZStack {
            BreathingGlowView()
                .frame(width: 100, height: 100)
            Image(systemName: "mic.fill")
                .font(.system(size: 30))
                .foregroundStyle(.white)
        }
    }
}

#Preview("Loading Dots") {
    ZStack {
        Color.black.ignoresSafeArea()
        LoadingDotsView()
    }
}

#Preview("Shimmer") {
    ZStack {
        Color.black.ignoresSafeArea()
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.3))
            .frame(width: 200, height: 50)
            .overlay(ShimmerView())
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Ripple") {
    ZStack {
        Color.black.ignoresSafeArea()
        ZStack {
            RippleView()
                .frame(width: 100, height: 100)
            Circle()
                .fill(AppTheme.accent)
                .frame(width: 50, height: 50)
        }
    }
}

#Preview("Spinning Loader") {
    ZStack {
        Color.black.ignoresSafeArea()
        SpinningLoaderView()
            .frame(width: 40, height: 40)
    }
}

#Preview("Checkmark") {
    ZStack {
        Color.black.ignoresSafeArea()
        AnimatedCheckmark()
            .frame(width: 60, height: 60)
    }
}

#Preview("Modifiers") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 20) {
            Text("Bounce In")
                .padding()
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .bounceIn(delay: 0.2)

            Text("Slide In")
                .padding()
                .background(AppTheme.accentSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .slideIn(from: .leading, delay: 0.4)

            Text("Fade In")
                .padding()
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .fadeIn(delay: 0.6)

            Text("Press Me")
                .padding()
                .background(Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .scaleOnPress()
        }
        .foregroundStyle(.white)
    }
}
