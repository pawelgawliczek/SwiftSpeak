//
//  SwipePathView.swift
//  SwiftSpeakKeyboard
//
//  Phase 13.8: Visual feedback for swipe typing path
//

import SwiftUI

// MARK: - Swipe Path View
struct SwipePathView: View {
    let path: [CGPoint]

    var body: some View {
        Canvas { context, size in
            guard path.count > 1 else { return }

            var pathShape = Path()
            pathShape.move(to: path[0])
            for point in path.dropFirst() {
                pathShape.addLine(to: point)
            }

            // Draw the path with a gradient stroke
            context.stroke(
                pathShape,
                with: .linearGradient(
                    Gradient(colors: [.blue.opacity(0.3), .blue.opacity(0.7)]),
                    startPoint: path.first!,
                    endPoint: path.last!
                ),
                lineWidth: 8
            )

            // Draw dots at each point for visual feedback
            for point in path {
                let circle = Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6))
                context.fill(circle, with: .color(.blue.opacity(0.5)))
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    SwipePathView(path: [
        CGPoint(x: 50, y: 50),
        CGPoint(x: 100, y: 60),
        CGPoint(x: 150, y: 55),
        CGPoint(x: 200, y: 50),
    ])
    .frame(width: 300, height: 200)
    .background(Color.black.opacity(0.8))
}
