# Code Examples

SwiftUI implementation patterns for the design system.

## Glass Panel / Translucent Card

```swift
struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 5)
    }
}
```

## Waveform Animation

```swift
struct WaveformView: View {
    @State private var heights: [CGFloat] = Array(repeating: 10, count: 12)
    let isAnimating: Bool
    let accentColor: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<12, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4, height: heights[index])
            }
        }
        .onAppear {
            if isAnimating { startAnimation() }
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue { startAnimation() }
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard isAnimating else { return }
            withAnimation(.spring(dampingFraction: 0.5)) {
                heights = heights.map { _ in CGFloat.random(in: 8...40) }
            }
        }
    }
}
```

## Recording Card

```swift
struct RecordingCard: View {
    enum State {
        case idle
        case listening
        case processing
        case formatting
    }

    let state: State
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Close button
            HStack {
                Spacer()
                Button(action: onStop) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Waveform or spinner
            Group {
                switch state {
                case .idle:
                    Image(systemName: "mic.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.accent)
                case .listening:
                    WaveformView(isAnimating: true, accentColor: .accent)
                        .frame(height: 40)
                case .processing, .formatting:
                    ProgressView()
                        .scaleEffect(1.2)
                }
            }
            .frame(height: 50)

            // Status text
            Text(statusText)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)

            // Tap hint
            if state == .listening {
                Text("Tap to finish")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 5)
    }

    private var statusText: String {
        switch state {
        case .idle: "Tap to speak"
        case .listening: "Listening..."
        case .processing: "Transcribing..."
        case .formatting: "Formatting..."
        }
    }
}
```

## Keyboard Button

```swift
struct KeyboardButton: View {
    let icon: String
    let label: String?
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body.weight(.medium))
                if let label {
                    Text(label)
                        .font(.callout.weight(.semibold))
                }
            }
            .foregroundStyle(isActive ? .accent : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
```

## Dropdown Menu

```swift
struct DropdownMenu<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content

    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.content = content()
    }

    var body: some View {
        if isPresented {
            content
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 5)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .animation(.spring(dampingFraction: 0.8), value: isPresented)
        }
    }
}

struct DropdownRow: View {
    let icon: String?
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.body)
                        .frame(width: 24)
                }
                Text(title)
                    .font(.body)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 44)  // Minimum touch target
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
```

## Spring Animations

```swift
// Card appear animation
.transition(.move(edge: .bottom).combined(with: .opacity))
.animation(.spring(dampingFraction: 0.8), value: isVisible)

// Scale with bounce
.scaleEffect(isPressed ? 0.95 : 1.0)
.animation(.spring(dampingFraction: 0.6), value: isPressed)

// Smooth state change
.animation(.spring(duration: 0.3, bounce: 0.2), value: state)
```

## Haptic Feedback

```swift
struct HapticManager {
    static func lightTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func mediumTap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// Usage in button
Button("Record") {
    HapticManager.mediumTap()
    startRecording()
}
```

## Color Extensions

```swift
extension Color {
    static let darkBase = Color(hex: "#1C1C1E")
    static let darkElevated = Color(hex: "#2C2C2E")
    static let lightBase = Color(hex: "#F2F2F7")

    // Accent - customize as needed
    static let accent = Color.blue  // Or custom hex

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

## View Modifiers

```swift
// Glass background modifier
struct GlassBackground: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 5)
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = 12) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius))
    }
}

// Usage
Text("Hello")
    .padding()
    .glassBackground()
```

## Animated Icon Transition

```swift
struct AnimatedIcon: View {
    let isRecording: Bool

    var body: some View {
        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
            .font(.title)
            .foregroundStyle(.accent)
            .contentTransition(.symbolEffect(.replace))
            .animation(.spring(duration: 0.3), value: isRecording)
    }
}
```
