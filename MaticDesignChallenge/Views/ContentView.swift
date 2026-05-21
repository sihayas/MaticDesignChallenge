//
//  ContentView.swift
//  MaticDesignChallenge
//
//  Created by daemons on 5/15/26.
//

import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    @State private var properties: ContainerProperties = .init()
    @State private var activeCardId: Int?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: -5) {
                    ForEach(cards, id: \.id) { card in
                        CardView(
                            activeCardId: $activeCardId,
                            card: card,
                            properties: properties
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.center)
            .scrollDisabled(true)
            /// Tracks scroll position in content space (offset + insets). Cheaper than a proxy-based read.
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentOffset.y + $0.contentInsets.top
            } action: { _, newValue in
                properties.scrollOffset = newValue
            }

            /// Global Y position of ScrollView. Used for screen-relative sheet/card positioning.
            .onGeometryChange(for: CGFloat.self) {
                $0.frame(in: .global).minY
            } action: { newValue in
                properties.minY = newValue - properties.safeArea.top
            }

        }
    
        /// Container size (NavigationStack bounds). Required for push-down animation math.
        .onGeometryChange(for: CGSize.self) {
            $0.size
        } action: { newValue in
            properties.containerSize = newValue
        }

        /// Safe area insets. Normalizes geometry into content-space instead of window-space.
        .onGeometryChange(for: EdgeInsets.self) {
            $0.safeAreaInsets
        } action: { newValue in
            properties.safeArea = newValue
        }
    }
}


// MARK: - Text Styles

struct CardLabelStyle: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color.opacity(0.6))
    }
}

struct CardBodyStyle: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(color)
    }
}

extension View {
    func cardLabelStyle(color: Color) -> some View {
        modifier(CardLabelStyle(color: color))
    }

    func cardBodyStyle(color: Color) -> some View {
        modifier(CardBodyStyle(color: color))
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
