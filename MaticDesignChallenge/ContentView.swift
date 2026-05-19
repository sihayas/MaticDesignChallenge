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

/// We store the
struct ContainerProperties {
    var scrollOffset: CGFloat = 0
    var containerSize: CGSize = .zero
    var safeArea: EdgeInsets = .init()
    var minY: CGFloat = 0
}

@Observable
class CardOrchestrator {
    /// All card's have access to this observable property, and react accordingly.
    /// If the id matches the card's own, the card will expand, and all other cards will contract.
    /// If there is an id but it is not the card's, the card will contract.
    var activeCardId: Int?
}

struct ContentView: View {
    @State private var properties: ContainerProperties = .init()
    
    let orchestrator = CardOrchestrator()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    ForEach(cards, id: \.id) { card in
                        CardView(
                            card: card,
                            orchestrator: orchestrator,
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
    @State var currentSize = CGSize(width: 354, height: 102)
    @State var scaleEffect = 1.0
    @State private var rotationAngle: Double = 0
    @State private var dragOffset: CGSize = .zero
    
    @Namespace private var namespace

    let collapsedSize = CGSize(width: 354, height: 102)
    let expandedSize = CGSize(width: 354, height: 532)

    let card: Card
    let orchestrator: CardOrchestrator
    let properties: ContainerProperties

    /// Derived from orchestrator
    var isExpanded: Bool { orchestrator.activeCardId == card.id }
    var currentIndex: Int {
        cards.firstIndex(where: { $0.id == card.id }) ?? 0
    }
    var selectedCardIndex: Int {
        cards.firstIndex(where: { $0.id == orchestrator.activeCardId }) ?? 0
    }
    
    var anyCardSelected: Bool { orchestrator.activeCardId != nil }
    
    var stackPosition: (index: Int, count: Int) {
        let nonSelected = cards.indices.filter { $0 != selectedCardIndex }
        return (
            index: nonSelected.firstIndex(of: currentIndex) ?? 0,
            count: nonSelected.count
        )
    }


    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                                Text("Design Sync")
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
                .onChange(of: isExpanded) { _, nV in
                    withAnimation(.smooth()) {
                        currentSize = nV ? expandedSize : collapsedSize
                    }
                }

        }
        .gesture(
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
                    /// Only trigger if finger lifted within the card bounds
                    let bounds = CGRect(origin: .zero, size: currentSize)
                    if bounds.contains(value.location) {
                        withAnimation(.smooth()) {
                            /// Set orchestrator id to this card's, collapsing all others automatically
                            orchestrator.activeCardId =
                                isExpanded ? nil : card.id
                        }
                    }
                }
        )
        .offset(dragOffset)
        .scaleEffect(scaleEffect)
        .rotationEffect(.degrees(rotationAngle))
        .simultaneousGesture(
            isExpanded ?
            DragGesture()
                .onChanged { value in
                    withAnimation(.interactiveSpring()) {
                        dragOffset = value.translation
                        rotationAngle = 4
                    }
                }
                .onEnded { _ in
                    withAnimation(.smooth()) {
                        dragOffset = .zero
                        rotationAngle = 0
                    }
                }
            : nil
        )
        .visualEffect { [properties, anyCardSelected, stackPosition, currentIndex, selectedCardIndex] content, proxy in
            let rect = proxy.frame(in: .scrollView)
            let bounds = properties.containerSize

            guard anyCardSelected else { return content.offset(y: 0) }

            /// Selected card goes to the center
            guard currentIndex != selectedCardIndex else {
                return content.offset(y: (bounds.height / 2) - rect.midY)
            }

            /// We want the cards to peek above each other at the bottom rather than
            /// all collapsing to the same point so we need each card to know its
            /// order in the stack. stackPosition.index tells us where this card sits
            /// and we use that to space them 27pt apart.
            let targetMidY = bounds.height - CGFloat(stackPosition.count - 1 - stackPosition.index) * 27
            return content.offset(y: targetMidY - rect.midY)
        }
    }
}

#Preview {
    ContentView()
}
