//
//  ContentView.swift
//  MaticDesignChallenge
//
//  Created by daemons on 5/15/26.
//

import SwiftUI

let cards: [Card] = [
    Card(id: 0, bgColor: "F4BB5C", textColor: "B44200"),
    Card(id: 1, bgColor: "0059BC", textColor: "FFFFFF"),
    Card(id: 2, bgColor: "E05D2D", textColor: "FFFFFF"),
]

struct ContainerProperties {
    var scrollOffset: CGFloat = 0
    var containerSize: CGSize = .zero
    var safeArea: EdgeInsets = .init()
    var minY: CGFloat = 0
}

struct ContentView: View {
    @State private var properties: ContainerProperties = .init()
    @State private var activeCardId: Int?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
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
            // `.onScrollGeometryChange` fires only for scroll-related changes (offset, insets,
            // content size). The closure computes a derived value; `action` runs when it
            // changes. Cheaper than reading a full ScrollViewProxy every frame.
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentOffset.y + $0.contentInsets.top
            } action: { _, newValue in
                properties.scrollOffset = newValue
            }
            // `.onGeometryChange` is the generic form — fires whenever the attached view's
            // geometry changes. Here we track the ScrollView's global minY so we can compute
            // where the sheet should sit relative to the content area.
            .onGeometryChange(for: CGFloat.self) {
                $0.frame(in: .global).minY
            } action: { newValue in
                properties.minY = newValue - properties.safeArea.top
            }
        }
        // Track the full container size (NavigationStack's frame).
        // `info.containerSize.height` feeds the `visualEffect` below — specifically the
        // `pushOffset = bounds.height - rect.minY` branch that shoves cards *below* the
        // tapped one off the bottom of the screen. If this modifier is missing,
        // `containerSize` stays `.zero`, `bounds.height` is 0, and the push-down math
        // collapses — see note in `cardView` for the visual consequence.
        .onGeometryChange(for: CGSize.self) {
            $0.size
        } action: { newValue in
            properties.containerSize = newValue
        }
        // Safe-area insets are needed to normalize `info.minY` (subtract the top inset so
        // sheet math works in content-space, not window-space).
        .onGeometryChange(for: EdgeInsets.self) {
            $0.safeAreaInsets
        } action: { newValue in
            properties.safeArea = newValue
        }
    }
}

struct CardView: View {
    @Binding var activeCardId: Int?
    
    @State var currentSize = CGSize(width: 354, height: 102)
    @State var scaleEffect = 1.0
    @State private var rotationAngle: Double = 0
    @State private var dragOffset: CGSize = .zero
    
    @Namespace private var namespace

    let collapsedSize = CGSize(width: 354, height: 102)
    let expandedSize = CGSize(width: 354, height: 532)

    let card: Card
    let properties: ContainerProperties

    /// Derived from orchestrator
    var isExpanded: Bool { activeCardId == card.id }
    var currentIndex: Int {
        cards.firstIndex(where: { $0.id == card.id }) ?? 0
    }
    var selectedCardIndex: Int {
        cards.firstIndex(where: { $0.id == activeCardId }) ?? 0
    }
    
    var anyCardSelected: Bool { activeCardId != nil }
    
    var stackPosition: (index: Int, count: Int) {
        let nonSelected = cards.indices.filter { $0 != selectedCardIndex }
        return (
            index: nonSelected.firstIndex(of: currentIndex) ?? 0,
            count: nonSelected.count
        )
    }


    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color(hex: card.bgColor))
                .frame(width: currentSize.width, height: currentSize.height)
                /// We overlay content ONTO the shape, instead of embedding it INSIDE a Stack and setting the background property to define the shape, to play better with MatchedGeometryEffect to get a more fluid transition/animation between sizes.
                .overlay(alignment: .topLeading) {
                    /// Outer container that owns each individual section
                    VStack(alignment: .leading, spacing: 24) {

                        // MARK: Titlebar Section
                        VStack(alignment: .leading, spacing: 4) {
                            /// Inner container for the title section
                            HStack(alignment: .top) {
                                Text("Design \(isExpanded ? "\nSync" : "Sync")")
                                    .font(
                                        .system(
                                            size: isExpanded ? 36 : 24,
                                            weight: .medium
                                        )
                                    )
                                    .foregroundStyle(Color(hex: card.textColor))
                                    .animation(
                                        .smooth(),
                                        value: isExpanded
                                    )

                                Spacer()

                                /// MatchedGeometry here
                                if isExpanded {
                                    Text("Today \n2:00 PM")
                                        .font(
                                            .system(size: 17, weight: .medium)
                                        )
                                        .fixedSize()
                                        .foregroundStyle(
                                            Color(hex: card.textColor)
                                        )
                                        .multilineTextAlignment(.trailing)
                                        .matchedGeometryEffect(
                                            id: "date",
                                            in: namespace
                                        )
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            /// We remove the date view when expanding so MatchedGeometry knows to animate and transition it towards the top right
                            if !isExpanded {
                                Text("Today at 2:00 PM")
                                    .font(.system(size: 17, weight: .medium))
                                    .fixedSize()
                                    .foregroundStyle(Color(hex: card.textColor))
                                    .matchedGeometryEffect(
                                        id: "date",
                                        in: namespace
                                    )
                            }
                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .topLeading
                        )

                        // MARK: DetailView Section
                        if isExpanded {
                            Rectangle()
                                .fill(.black.opacity(0.35))
                                .frame(height: 1)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Agenda")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(
                                        Color(hex: card.textColor).opacity(0.6)
                                    )

                                Text(
                                    "Discuss about the north star ver. of our current product"
                                )
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(Color(hex: card.textColor))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Participants")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(
                                        Color(hex: card.textColor).opacity(0.6)
                                    )

                                Text(
                                    "John Lee, Jane Doe, Amanda Le, Tony Muller"
                                )
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(Color(hex: card.textColor))
                            }
                        }
                    }
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .topLeading
                    )
                    .padding(24)
                }
                /// Clip to get the desired shape to prevent overlay content overflowing
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onChange(of: isExpanded) { _, nV in
                    withAnimation(.smooth()) {
                        currentSize = nV ? expandedSize : collapsedSize
                    }
                }

        }
        .scaleEffect(scaleEffect)
        .rotationEffect(.degrees(rotationAngle))
        .gesture(
            !isExpanded ?
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.smooth()) {
                        scaleEffect = 0.92
                    }
                }
                .onEnded { value in
                    withAnimation(.smooth()) {
                        scaleEffect = 1
                    }
                    let bounds = CGRect(origin: .zero, size: currentSize)
                    if bounds.contains(value.location) {
                        withAnimation(.smooth()) {
                            activeCardId = card.id
                        }
                    }
                }
            : nil
        )
        .simultaneousGesture(
            isExpanded ?
            DragGesture()
                .onChanged { value in
                    withAnimation(.interactiveSpring()) {
                        dragOffset = value.translation
                        rotationAngle = 4
                    }
                }
                .onEnded { value in
                    /// predictedEndTranslation factors in velocity so a fast flick
                    /// registers even if the actual translation wasn't huge
                    let shouldCollapse = abs(value.predictedEndTranslation.height) > 120
                        || abs(value.predictedEndTranslation.width) > 120
                    withAnimation(.smooth()) {
                        dragOffset = .zero
                        rotationAngle = 0
                        if shouldCollapse {
                            activeCardId = nil
                        }
                    }
                }
            : nil
        )
        .visualEffect {
            /// Combine drag translation and stack positioning into a single offset.
            /// This prevents `matchedGeometryEffect` from seeing two independent
            /// transforms (`dragOffset` + stack offset) changing at the same time.
            [properties, anyCardSelected, stackPosition,
             currentIndex, selectedCardIndex, dragOffset]
            content, proxy in

            /// Card's current frame in the ScrollView coordinate space.
            let rect = proxy.frame(in: .scrollView)

            /// Container size used for centering and bottom stacking.
            let bounds = properties.containerSize

            /// Start with the user's drag translation.
            var yOffset = dragOffset.height
            var xOffset = dragOffset.width

            if anyCardSelected {
                if currentIndex == selectedCardIndex {
                    /// Move the selected card to the vertical center.
                    yOffset += (bounds.height / 2) - rect.midY
                } else {
                    /// Stack non-selected cards at the bottom with a 27pt overlap.
                    let targetMidY =
                        bounds.height -
                        CGFloat(stackPosition.count - 1 - stackPosition.index) * 27

                    yOffset += targetMidY - rect.midY
                }
            }

            /// Apply the single combined transform.
            return content.offset(x: xOffset, y: yOffset)
        }
    }
}

#Preview {
    ContentView()
}
