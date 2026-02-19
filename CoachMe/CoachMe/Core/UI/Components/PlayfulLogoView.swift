//
//  PlayfulLogoView.swift
//  CoachMe
//
//  Created by Antigravity on 2/10/26.
//

import SwiftUI

/// A custom, playful logo component for CoachMe.
/// Combines a chat bubble with a growing leaf motif.
struct PlayfulLogoView: View {
    var size: CGFloat = 100
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Main Bubble Shadow/Glow
            Circle()
                .fill(Color.adaptiveTerracotta(colorScheme).opacity(0.15))
                .frame(width: size * 1.2, height: size * 1.2)
                .blur(radius: size * 0.1)
            
            // The Bubble Shape
            BubbleShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.adaptiveTerracotta(colorScheme),
                            Color.adaptiveTerracotta(colorScheme).opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(radius: 5, y: 3)
            
            // The Leaf Motif (Playful Growth)
            LeafShape()
                .fill(.white.opacity(0.9))
                .frame(width: size * 0.45, height: size * 0.45)
                .offset(y: -size * 0.05)
                .blur(radius: 0.5)
                .blendMode(.overlay)
            
            // Inner Glass Highlight
            BubbleShape()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.6), .clear, .white.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Shapes

struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        // Main rounded rect
        path.addRoundedRect(
            in: CGRect(x: 0, y: 0, width: width, height: height * 0.85),
            cornerSize: CGSize(width: width * 0.3, height: width * 0.3)
        )
        
        // The "tail" of the bubble
        path.move(to: CGPoint(x: width * 0.2, y: height * 0.85))
        path.addLine(to: CGPoint(x: width * 0.1, y: height))
        path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.85))
        path.closeSubpath()
        
        return path
    }
}

struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        // Simple organic leaf shape
        path.move(to: CGPoint(x: width * 0.5, y: height))
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: 0),
            control1: CGPoint(x: width * 1.2, y: height * 0.8),
            control2: CGPoint(x: width * 0.8, y: height * 0.2)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height),
            control1: CGPoint(x: -width * 0.2, y: height * 0.2),
            control2: CGPoint(x: -width * 0.2, y: height * 0.8)
        )
        
        return path
    }
}

#Preview {
    ZStack {
        Color.cream.ignoresSafeArea()
        PlayfulLogoView(size: 150)
    }
}
