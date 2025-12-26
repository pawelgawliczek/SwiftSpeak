//
//  WaveformView.swift
//  SwiftSpeak
//
//  Real-time audio waveform visualization
//

import SwiftUI

struct WaveformView: View {
    let isActive: Bool
    let barCount: Int

    @State private var heights: [CGFloat] = []
    @State private var timer: Timer?

    init(isActive: Bool = true, barCount: Int = 12) {
        self.isActive = isActive
        self.barCount = barCount
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppTheme.accentGradient)
                    .frame(width: 4, height: heights.indices.contains(index) ? heights[index] : 10)
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.5),
                        value: heights.indices.contains(index) ? heights[index] : 10
                    )
            }
        }
        .onAppear {
            heights = Array(repeating: 10, count: barCount)
            if isActive {
                startAnimation()
            }
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }

    private func startAnimation() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation {
                heights = (0..<barCount).map { _ in
                    CGFloat.random(in: 10...50)
                }
            }
        }
    }

    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
        withAnimation {
            heights = Array(repeating: 10, count: barCount)
        }
    }
}

// MARK: - Circular Waveform
struct CircularWaveformView: View {
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                // More padding to prevent clipping
                let maxAmplitudeRatio = 0.2
                let padding = min(size.width, size.height) * maxAmplitudeRatio + 5
                let radius = min(size.width, size.height) / 2 - padding

                var path = Path()

                // Calculate animated values based on time
                let phase = isActive ? time * 2.5 : 0
                let amplitudePulse = isActive ? (sin(time * 3) * 0.5 + 0.5) : 0
                let amplitude = isActive ? 0.1 + amplitudePulse * 0.15 : 0

                for angle in stride(from: 0.0, to: 360.0, by: 2.0) {
                    let radians = angle * .pi / 180
                    let waveOffset = sin(radians * 7 + phase) * radius * amplitude
                    let r = radius + waveOffset

                    let x = center.x + r * cos(radians)
                    let y = center.y + r * sin(radians)

                    if angle == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                path.closeSubpath()

                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            AppTheme.accent,
                            AppTheme.accentSecondary,
                            AppTheme.accent
                        ]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: size.width, y: size.height)
                    ),
                    lineWidth: 4
                )
            }
        }
    }
}

// MARK: - Linear Wave
/// A flowing sine wave animation
struct LinearWaveView: View {
    let color: Color
    let lineWidth: CGFloat
    let amplitude: CGFloat
    let frequency: CGFloat

    init(color: Color = AppTheme.accent, lineWidth: CGFloat = 3, amplitude: CGFloat = 10, frequency: CGFloat = 4) {
        self.color = color
        self.lineWidth = lineWidth
        self.amplitude = amplitude
        self.frequency = frequency
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { timeline in
            Canvas { context, size in
                let time: Double = timeline.date.timeIntervalSinceReferenceDate
                var path = Path()
                let midY: CGFloat = size.height / 2
                let freq: CGFloat = frequency
                let amp: CGFloat = amplitude

                for x in stride(from: CGFloat(0), to: size.width, by: CGFloat(1)) {
                    let relativeX: CGFloat = x / size.width
                    let angle: CGFloat = (relativeX * freq * .pi * 2) + CGFloat(time * 3)
                    let sine: CGFloat = sin(angle)
                    let y: CGFloat = midY + sine * amp

                    if x == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                let gradient = Gradient(colors: [color.opacity(0.3), color, color.opacity(0.3)])
                let startPt = CGPoint(x: 0, y: midY)
                let endPt = CGPoint(x: size.width, y: midY)

                context.stroke(
                    path,
                    with: .linearGradient(gradient, startPoint: startPt, endPoint: endPt),
                    lineWidth: lineWidth
                )
            }
        }
    }
}

// MARK: - Mirrored Bar Waveform
/// Audio equalizer style bars mirrored from center
struct MirroredBarWaveformView: View {
    let barCount: Int
    let color: Color
    let isActive: Bool

    init(barCount: Int = 16, color: Color = AppTheme.accent, isActive: Bool = true) {
        self.barCount = barCount
        self.color = color
        self.isActive = isActive
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30)) { timeline in
            Canvas { context, size in
                let time: Double = timeline.date.timeIntervalSinceReferenceDate
                let count: Int = barCount
                let barWidth: CGFloat = size.width / CGFloat(count * 2 - 1)
                let maxHeight: CGFloat = size.height / 2 - 2
                let centerY: CGFloat = size.height / 2

                for i in 0..<count {
                    let seed: Double = Double(i) * 1.5
                    let height: CGFloat
                    if isActive {
                        let wave1: Double = sin(time * 3 + seed) * 0.5 + 0.5
                        let wave2: Double = sin(time * 5 + seed * 0.7) * 0.3 + 0.5
                        height = maxHeight * CGFloat(wave1 * 0.6 + wave2 * 0.4)
                    } else {
                        height = 4
                    }

                    let x: CGFloat = CGFloat(i) * barWidth * 2
                    let topRect = CGRect(x: x, y: centerY - height, width: barWidth - 1, height: height)
                    let bottomRect = CGRect(x: x, y: centerY, width: barWidth - 1, height: height)

                    let opacity: Double = 0.5 + Double(height / maxHeight) * 0.5
                    let topPath = RoundedRectangle(cornerRadius: 2).path(in: topRect)
                    let bottomPath = RoundedRectangle(cornerRadius: 2).path(in: bottomRect)

                    context.fill(topPath, with: .color(color.opacity(opacity)))
                    context.fill(bottomPath, with: .color(color.opacity(opacity * 0.7)))
                }
            }
        }
    }
}

// MARK: - Organic Blob Waveform
/// A morphing organic blob shape
struct BlobWaveformView: View {
    let color: Color
    let isActive: Bool

    init(color: Color = AppTheme.accent, isActive: Bool = true) {
        self.color = color
        self.isActive = isActive
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { timeline in
            Canvas { context, size in
                let time: Double = timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let baseRadius: CGFloat = min(size.width, size.height) / 2 * 0.6
                var path = Path()

                let points: Int = 60
                let activeMultipliers: (Double, Double, Double) = isActive ? (0.15, 0.1, 0.08) : (0.02, 0.01, 0.01)

                for i in 0..<points {
                    let angle: Double = (Double(i) / Double(points)) * 2 * .pi
                    let noise1: Double = sin(angle * 3 + time * 2) * activeMultipliers.0
                    let noise2: Double = sin(angle * 5 - time * 1.5) * activeMultipliers.1
                    let noise3: Double = sin(angle * 2 + time * 3) * activeMultipliers.2

                    let radius: CGFloat = baseRadius * CGFloat(1 + noise1 + noise2 + noise3)
                    let x: CGFloat = center.x + cos(angle) * radius
                    let y: CGFloat = center.y + sin(angle) * radius

                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                path.closeSubpath()

                let fillGradient = Gradient(colors: [color.opacity(0.6), color.opacity(0.3)])
                let startPt = CGPoint(x: 0, y: 0)
                let endPt = CGPoint(x: size.width, y: size.height)

                context.fill(path, with: .linearGradient(fillGradient, startPoint: startPt, endPoint: endPt))
                context.stroke(path, with: .color(color), lineWidth: 2)
            }
        }
    }
}

// MARK: - Sound Bars Waveform
/// Classic sound level bars animation
struct SoundBarsWaveformView: View {
    let barCount: Int
    let spacing: CGFloat
    let isActive: Bool

    init(barCount: Int = 5, spacing: CGFloat = 4, isActive: Bool = true) {
        self.barCount = barCount
        self.spacing = spacing
        self.isActive = isActive
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30)) { timeline in
            SoundBarsContent(
                time: timeline.date.timeIntervalSinceReferenceDate,
                barCount: barCount,
                spacing: spacing,
                isActive: isActive
            )
        }
    }
}

private struct SoundBarsContent: View {
    let time: Double
    let barCount: Int
    let spacing: CGFloat
    let isActive: Bool

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<barCount, id: \.self) { index in
                SoundBarItem(time: time, index: index, isActive: isActive)
            }
        }
    }
}

private struct SoundBarItem: View {
    let time: Double
    let index: Int
    let isActive: Bool

    var body: some View {
        let seed: Double = Double(index) * 1.2
        let wave1: Double = sin(time * 4 + seed) * 0.3
        let wave2: Double = sin(time * 7 + seed * 0.5) * 0.2
        let height: CGFloat = isActive ? CGFloat(0.3 + wave1 + wave2) : 0.2

        RoundedRectangle(cornerRadius: 3)
            .fill(AppTheme.accentGradient)
            .frame(width: 6)
            .scaleEffect(y: height, anchor: .center)
    }
}

// MARK: - Spectrum Waveform
/// Audio spectrum analyzer style
struct SpectrumWaveformView: View {
    let barCount: Int
    let color: Color
    let isActive: Bool

    init(barCount: Int = 32, color: Color = AppTheme.accent, isActive: Bool = true) {
        self.barCount = barCount
        self.color = color
        self.isActive = isActive
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30)) { timeline in
            Canvas { context, size in
                let time: Double = timeline.date.timeIntervalSinceReferenceDate
                let count: Int = barCount
                let barWidth: CGFloat = size.width / CGFloat(count)

                for i in 0..<count {
                    let normalizedIndex: CGFloat = CGFloat(i) / CGFloat(count)
                    let seed: Double = Double(i) * 0.8
                    let distribution: CGFloat = 1 - abs(normalizedIndex - 0.5) * 1.5

                    let height: CGFloat
                    if isActive {
                        let wave1: Double = sin(time * 5 + seed) * 0.4 + 0.5
                        let wave2: Double = sin(time * 8 + seed * 1.3) * 0.3 + 0.5
                        let wave3: Double = sin(time * 3 + seed * 0.5) * 0.2 + 0.5
                        let combined: Double = wave1 * wave2 * wave3
                        height = size.height * CGFloat(combined) * distribution
                    } else {
                        height = 4
                    }

                    let x: CGFloat = CGFloat(i) * barWidth
                    let rect = CGRect(x: x + 1, y: size.height - height, width: barWidth - 2, height: height)

                    let hue: Double = 0.55 + Double(height / size.height) * 0.15
                    let barColor = Color(hue: hue, saturation: 0.8, brightness: 0.9)
                    let barPath = RoundedRectangle(cornerRadius: 1).path(in: rect)

                    context.fill(barPath, with: .color(barColor))
                }
            }
        }
    }
}

// MARK: - SwiftSpeak Text Waveform
/// Animated "SwiftSpeak" text with sound wave effect
struct SwiftSpeakWaveformView: View {
    let isActive: Bool
    let fontSize: CGFloat
    let showWaveBackground: Bool

    init(isActive: Bool = true, fontSize: CGFloat = 32, showWaveBackground: Bool = true) {
        self.isActive = isActive
        self.fontSize = fontSize
        self.showWaveBackground = showWaveBackground
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                // Background wave lines
                if showWaveBackground {
                    WaveBackgroundCanvas(time: time, isActive: isActive)
                        .opacity(0.3)
                }

                // Animated text with wave distortion
                SwiftSpeakTextCanvas(time: time, isActive: isActive, fontSize: fontSize)
            }
        }
    }
}

/// Canvas for background wave lines
private struct WaveBackgroundCanvas: View {
    let time: Double
    let isActive: Bool

    var body: some View {
        Canvas { context, size in
            let lineCount = 5
            let midY = size.height / 2

            for lineIndex in 0..<lineCount {
                let offset = CGFloat(lineIndex - lineCount / 2) * 12
                var path = Path()

                let phase = isActive ? time * 2 + Double(lineIndex) * 0.5 : 0
                let amplitude: CGFloat = isActive ? 8 + CGFloat(lineIndex) * 2 : 2

                for x in stride(from: CGFloat(0), to: size.width, by: 2) {
                    let relativeX = x / size.width
                    let angle = relativeX * .pi * 6 + CGFloat(phase)
                    let y = midY + offset + sin(angle) * amplitude

                    if x == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                let opacity = 0.3 + Double(abs(lineIndex - lineCount / 2)) * 0.1
                context.stroke(
                    path,
                    with: .color(AppTheme.accent.opacity(opacity)),
                    lineWidth: 1.5
                )
            }
        }
    }
}

/// Canvas for the animated SwiftSpeak text
private struct SwiftSpeakTextCanvas: View {
    let time: Double
    let isActive: Bool
    let fontSize: CGFloat

    var body: some View {
        Canvas { context, size in
            let text = "SwiftSpeak"
            let midX = size.width / 2
            let midY = size.height / 2

            // Create attributed string for measurement
            let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let attributedString = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributedString.size()

            // Draw each character with wave offset
            var currentX = midX - textSize.width / 2

            for (index, char) in text.enumerated() {
                let charString = String(char)
                let charAttr = NSAttributedString(string: charString, attributes: attributes)
                let charWidth = charAttr.size().width

                // Calculate wave offset for this character
                let phase = isActive ? time * 3 : 0
                let charPhase = Double(index) * 0.4 + phase
                let waveOffset: CGFloat = isActive ? sin(charPhase) * 4 : 0
                let scaleOffset: CGFloat = isActive ? 1.0 + sin(charPhase * 0.5) * 0.05 : 1.0

                // Calculate color hue shift for rainbow effect when active
                let hueShift = isActive ? Double(index) / Double(text.count) * 0.15 : 0
                let charColor = Color(
                    hue: 0.6 + hueShift + (isActive ? sin(time + Double(index) * 0.3) * 0.05 : 0),
                    saturation: 0.8,
                    brightness: 0.95
                )

                // Draw character
                let charPoint = CGPoint(
                    x: currentX + charWidth / 2,
                    y: midY + waveOffset
                )

                context.drawLayer { ctx in
                    ctx.translateBy(x: charPoint.x, y: charPoint.y)
                    ctx.scaleBy(x: scaleOffset, y: scaleOffset)
                    ctx.translateBy(x: -charPoint.x, y: -charPoint.y)

                    // Draw the character
                    let resolvedText = ctx.resolve(Text(charString)
                        .font(.system(size: fontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(charColor))

                    ctx.draw(resolvedText, at: charPoint, anchor: .center)
                }

                currentX += charWidth
            }
        }
    }
}

// MARK: - SwiftSpeak Logo Waveform
/// Complete logo with waveform circle and text
struct SwiftSpeakLogoWaveformView: View {
    let isActive: Bool

    init(isActive: Bool = true) {
        self.isActive = isActive
    }

    var body: some View {
        VStack(spacing: 16) {
            // Circular waveform with mic icon
            ZStack {
                CircularWaveformView(isActive: isActive)
                    .frame(width: 80, height: 80)

                Image(systemName: "mic.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.accentGradient)
            }

            // Animated text
            SwiftSpeakWaveformView(isActive: isActive, fontSize: 28, showWaveBackground: false)
                .frame(height: 40)
        }
    }
}

// MARK: - SwiftSpeak Wave Text (Simple Version)
/// Simple version with flowing underline wave
struct SwiftSpeakWaveTextView: View {
    let isActive: Bool
    let fontSize: CGFloat

    init(isActive: Bool = true, fontSize: CGFloat = 36) {
        self.isActive = isActive
        self.fontSize = fontSize
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            VStack(spacing: 4) {
                // Text with gradient
                Text("SwiftSpeak")
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accentSecondary, AppTheme.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                // Animated wave underline
                WaveUnderlineCanvas(time: time, isActive: isActive)
                    .frame(height: 8)
            }
        }
    }
}

/// Canvas for the wave underline
private struct WaveUnderlineCanvas: View {
    let time: Double
    let isActive: Bool

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let midY = size.height / 2

            let phase = isActive ? time * 4 : 0
            let amplitude: CGFloat = isActive ? 3 : 1

            for x in stride(from: CGFloat(0), to: size.width, by: 1) {
                let relativeX = x / size.width
                // Fade amplitude at edges
                let edgeFade = sin(relativeX * .pi)
                let angle = relativeX * .pi * 8 + CGFloat(phase)
                let y = midY + sin(angle) * amplitude * edgeFade

                if x == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            let gradient = Gradient(colors: [
                AppTheme.accent.opacity(0.3),
                AppTheme.accent,
                AppTheme.accentSecondary,
                AppTheme.accent,
                AppTheme.accent.opacity(0.3)
            ])

            context.stroke(
                path,
                with: .linearGradient(gradient, startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)),
                lineWidth: 3
            )
        }
    }
}

// MARK: - Previews
#Preview("Bar Waveform") {
    ZStack {
        AppTheme.darkBase.ignoresSafeArea()
        WaveformView(isActive: true)
            .frame(height: 60)
    }
}

#Preview("Circular Waveform") {
    ZStack {
        AppTheme.darkBase.ignoresSafeArea()
        CircularWaveformView(isActive: true)
            .frame(width: 150, height: 150)
    }
}

#Preview("Linear Wave") {
    ZStack {
        Color.black.ignoresSafeArea()
        LinearWaveView()
            .frame(width: 200, height: 60)
    }
}

#Preview("Mirrored Bars") {
    ZStack {
        Color.black.ignoresSafeArea()
        MirroredBarWaveformView()
            .frame(width: 200, height: 80)
    }
}

#Preview("Blob Waveform") {
    ZStack {
        Color.black.ignoresSafeArea()
        BlobWaveformView()
            .frame(width: 120, height: 120)
    }
}

#Preview("Sound Bars") {
    ZStack {
        Color.black.ignoresSafeArea()
        SoundBarsWaveformView()
            .frame(height: 50)
    }
}

#Preview("Spectrum") {
    ZStack {
        Color.black.ignoresSafeArea()
        SpectrumWaveformView()
            .frame(width: 250, height: 80)
    }
}

#Preview("SwiftSpeak Waveform") {
    ZStack {
        AppTheme.darkBase.ignoresSafeArea()
        SwiftSpeakWaveformView(isActive: true)
            .frame(width: 300, height: 80)
    }
}

#Preview("SwiftSpeak Logo") {
    ZStack {
        AppTheme.darkBase.ignoresSafeArea()
        SwiftSpeakLogoWaveformView(isActive: true)
    }
}

#Preview("SwiftSpeak Wave Text") {
    ZStack {
        AppTheme.darkBase.ignoresSafeArea()
        SwiftSpeakWaveTextView(isActive: true)
            .frame(width: 300)
    }
}
