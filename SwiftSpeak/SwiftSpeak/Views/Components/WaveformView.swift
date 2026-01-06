//
//  WaveformView.swift
//  SwiftSpeak
//
//  Real-time audio waveform visualization
//

import SwiftUI
import SwiftSpeakCore

struct WaveformView: View {
    let isActive: Bool
    let barCount: Int
    let audioLevels: [Float]?

    @State private var fallbackHeights: [CGFloat] = []
    @State private var timer: Timer?

    init(isActive: Bool = true, barCount: Int = 12, audioLevels: [Float]? = nil) {
        self.isActive = isActive
        self.barCount = barCount
        self.audioLevels = audioLevels
    }

    private var heights: [CGFloat] {
        if let levels = audioLevels, !levels.isEmpty, isActive {
            // Use real audio levels - normalize from 0-1 to 10-50
            return levels.prefix(barCount).map { CGFloat(10 + $0 * 40) }
        }
        return fallbackHeights
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
            fallbackHeights = Array(repeating: 10, count: barCount)
            if isActive && audioLevels == nil {
                startFallbackAnimation()
            }
        }
        .onDisappear {
            stopFallbackAnimation()
        }
        .onChange(of: isActive) { _, newValue in
            if newValue && audioLevels == nil {
                startFallbackAnimation()
            } else if !newValue {
                stopFallbackAnimation()
            }
        }
    }

    private func startFallbackAnimation() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation {
                fallbackHeights = (0..<barCount).map { _ in
                    CGFloat.random(in: 10...50)
                }
            }
        }
    }

    private func stopFallbackAnimation() {
        timer?.invalidate()
        timer = nil
        withAnimation {
            fallbackHeights = Array(repeating: 10, count: barCount)
        }
    }
}

// MARK: - Circular Waveform
struct CircularWaveformView: View {
    let isActive: Bool
    let audioLevels: [Float]?

    init(isActive: Bool = true, audioLevels: [Float]? = nil) {
        self.isActive = isActive
        self.audioLevels = audioLevels
    }

    private var averageLevel: CGFloat {
        guard let levels = audioLevels, !levels.isEmpty else { return 0 }
        let sum = levels.reduce(0, +)
        return CGFloat(sum / Float(levels.count))
    }

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

                // Calculate animated values based on time or audio levels
                let phase = isActive ? time * 2.5 : 0
                let amplitude: CGFloat
                if isActive {
                    if audioLevels != nil {
                        // Use real audio level for amplitude
                        amplitude = 0.1 + averageLevel * 0.25
                    } else {
                        let amplitudePulse = (sin(time * 3) * 0.5 + 0.5)
                        amplitude = 0.1 + amplitudePulse * 0.15
                    }
                } else {
                    amplitude = 0
                }

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
    let baseAmplitude: CGFloat
    let frequency: CGFloat
    let audioLevels: [Float]?

    init(color: Color = AppTheme.accent, lineWidth: CGFloat = 3, amplitude: CGFloat = 10, frequency: CGFloat = 4, audioLevels: [Float]? = nil) {
        self.color = color
        self.lineWidth = lineWidth
        self.baseAmplitude = amplitude
        self.frequency = frequency
        self.audioLevels = audioLevels
    }

    private var averageLevel: CGFloat {
        guard let levels = audioLevels, !levels.isEmpty else { return 0.5 }
        let sum = levels.reduce(0, +)
        return CGFloat(sum / Float(levels.count))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { timeline in
            Canvas { context, size in
                let time: Double = timeline.date.timeIntervalSinceReferenceDate
                var path = Path()
                let midY: CGFloat = size.height / 2
                let freq: CGFloat = frequency
                // Use audio level to modulate amplitude
                let amp: CGFloat = audioLevels != nil ? baseAmplitude * (0.3 + averageLevel * 1.5) : baseAmplitude

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
    let speed: Double
    let audioLevels: [Float]?

    init(barCount: Int = 16, color: Color = AppTheme.accent, isActive: Bool = true, speed: Double = 1.0, audioLevels: [Float]? = nil) {
        self.barCount = barCount
        self.color = color
        self.isActive = isActive
        self.speed = speed
        self.audioLevels = audioLevels
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30)) { timeline in
            Canvas { context, size in
                let time: Double = timeline.date.timeIntervalSinceReferenceDate * speed
                let count: Int = barCount
                let barWidth: CGFloat = size.width / CGFloat(count * 2 - 1)
                let maxHeight: CGFloat = size.height / 2 - 2
                let centerY: CGFloat = size.height / 2

                for i in 0..<count {
                    let seed: Double = Double(i) * 1.5
                    let height: CGFloat
                    if isActive {
                        if let levels = audioLevels, !levels.isEmpty {
                            // Use real audio levels - map bar index to audio level index
                            let levelIndex = min(i, levels.count - 1)
                            let level = CGFloat(levels[levelIndex])
                            height = maxHeight * (0.1 + level * 0.9)
                        } else {
                            let wave1: Double = sin(time * 3 + seed) * 0.5 + 0.5
                            let wave2: Double = sin(time * 5 + seed * 0.7) * 0.3 + 0.5
                            height = maxHeight * CGFloat(wave1 * 0.6 + wave2 * 0.4)
                        }
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
    let audioLevels: [Float]?

    init(color: Color = AppTheme.accent, isActive: Bool = true, audioLevels: [Float]? = nil) {
        self.color = color
        self.isActive = isActive
        self.audioLevels = audioLevels
    }

    private var averageLevel: CGFloat {
        guard let levels = audioLevels, !levels.isEmpty else { return 0.5 }
        let sum = levels.reduce(0, +)
        return CGFloat(sum / Float(levels.count))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { timeline in
            Canvas { context, size in
                let time: Double = timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let baseRadius: CGFloat = min(size.width, size.height) / 2 * 0.6
                var path = Path()

                let points: Int = 60
                // Scale multipliers based on audio level when available
                let levelScale = audioLevels != nil ? Double(0.5 + averageLevel) : 1.0
                let activeMultipliers: (Double, Double, Double) = isActive ? (0.15 * levelScale, 0.1 * levelScale, 0.08 * levelScale) : (0.02, 0.01, 0.01)

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
    let color: Color
    let isActive: Bool
    let audioLevels: [Float]?

    init(barCount: Int = 5, spacing: CGFloat = 4, color: Color = AppTheme.accent, isActive: Bool = true, audioLevels: [Float]? = nil) {
        self.barCount = barCount
        self.spacing = spacing
        self.color = color
        self.isActive = isActive
        self.audioLevels = audioLevels
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30)) { timeline in
            SoundBarsContent(
                time: timeline.date.timeIntervalSinceReferenceDate,
                barCount: barCount,
                spacing: spacing,
                color: color,
                isActive: isActive,
                audioLevels: audioLevels
            )
        }
    }
}

private struct SoundBarsContent: View {
    let time: Double
    let barCount: Int
    let spacing: CGFloat
    let color: Color
    let isActive: Bool
    let audioLevels: [Float]?

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<barCount, id: \.self) { index in
                SoundBarItem(time: time, index: index, color: color, isActive: isActive, audioLevels: audioLevels)
            }
        }
    }
}

private struct SoundBarItem: View {
    let time: Double
    let index: Int
    let color: Color
    let isActive: Bool
    let audioLevels: [Float]?

    private var height: CGFloat {
        guard isActive else { return 0.2 }

        if let levels = audioLevels, !levels.isEmpty {
            // Use real audio level
            let levelIndex = min(index, levels.count - 1)
            return CGFloat(0.2 + levels[levelIndex] * 0.8)
        } else {
            let seed: Double = Double(index) * 1.2
            let wave1: Double = sin(time * 4 + seed) * 0.3
            let wave2: Double = sin(time * 7 + seed * 0.5) * 0.2
            return CGFloat(0.3 + wave1 + wave2)
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color.gradient)
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
    let audioLevels: [Float]?

    init(barCount: Int = 32, color: Color = AppTheme.accent, isActive: Bool = true, audioLevels: [Float]? = nil) {
        self.barCount = barCount
        self.color = color
        self.isActive = isActive
        self.audioLevels = audioLevels
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
                        if let levels = audioLevels, !levels.isEmpty {
                            // Map bar index to audio level - interpolate for smooth spectrum
                            let levelIndex = Int(Float(i) / Float(count) * Float(levels.count - 1))
                            let level = CGFloat(levels[min(levelIndex, levels.count - 1)])
                            height = size.height * (0.1 + level * 0.9) * distribution
                        } else {
                            let wave1: Double = sin(time * 5 + seed) * 0.4 + 0.5
                            let wave2: Double = sin(time * 8 + seed * 1.3) * 0.3 + 0.5
                            let wave3: Double = sin(time * 3 + seed * 0.5) * 0.2 + 0.5
                            let combined: Double = wave1 * wave2 * wave3
                            height = size.height * CGFloat(combined) * distribution
                        }
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

// MARK: - SwiftSpeak Waveform Reveal
/// Sound wave that reveals/morphs into SwiftSpeak text
struct SwiftSpeakWaveRevealView: View {
    let isActive: Bool

    @State private var revealProgress: CGFloat = 0

    init(isActive: Bool = true) {
        self.isActive = isActive
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let midY = size.height / 2
                let phase = time * 3

                // Draw multiple wave lines that converge into text shape
                for waveIndex in 0..<5 {
                    let waveOffset = CGFloat(waveIndex - 2) * 8
                    let baseAmplitude: CGFloat = isActive ? 15 - CGFloat(waveIndex) * 2 : 5

                    var path = Path()

                    for x in stride(from: CGFloat(0), to: size.width, by: 1) {
                        let relativeX = x / size.width

                        // Calculate how much to blend between wave and text position
                        // Waves converge toward center
                        let convergeFactor = sin(relativeX * .pi) // Peaks at center
                        let textY = midY // Text baseline

                        // Wave calculation
                        let waveAngle = relativeX * .pi * 8 + CGFloat(phase) + CGFloat(waveIndex) * 0.5
                        let waveY = midY + waveOffset + sin(waveAngle) * baseAmplitude * (1 - convergeFactor * 0.5)

                        // Blend between wave and converged position
                        let y = waveY * (1 - convergeFactor * 0.3) + textY * convergeFactor * 0.3

                        if x == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }

                    let opacity = 0.3 + Double(2 - abs(waveIndex - 2)) * 0.2
                    context.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [
                                AppTheme.accent.opacity(0),
                                AppTheme.accent.opacity(opacity),
                                AppTheme.accentSecondary.opacity(opacity),
                                AppTheme.accent.opacity(opacity),
                                AppTheme.accent.opacity(0)
                            ]),
                            startPoint: CGPoint(x: 0, y: midY),
                            endPoint: CGPoint(x: size.width, y: midY)
                        ),
                        lineWidth: waveIndex == 2 ? 3 : 1.5
                    )
                }

                // Draw text on top
                let text = "SwiftSpeak"

                let resolvedText = context.resolve(
                    Text(text)
                        .font(.system(size: size.height * 0.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.accentSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )

                let textPoint = CGPoint(x: size.width / 2, y: midY)
                context.draw(resolvedText, at: textPoint, anchor: .center)
            }
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

#Preview("SwiftSpeak Wave Text") {
    ZStack {
        AppTheme.darkBase.ignoresSafeArea()
        SwiftSpeakWaveTextView(isActive: true)
            .frame(width: 300)
    }
}

#Preview("SwiftSpeak Wave Reveal") {
    ZStack {
        AppTheme.darkBase.ignoresSafeArea()
        SwiftSpeakWaveRevealView(isActive: true)
            .frame(width: 350, height: 80)
    }
}
