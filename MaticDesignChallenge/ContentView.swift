//
//  ContentView.swift
//  MaticDesignChallenge
//
//  Created by daemons on 5/15/26.
//

import SwiftUI

// MARK: - Data Model

let cards: [Card] = [
    Card(
        id: 0,
        bgColor: "F4BB5C",
        textColor: "B44200",
        title: "Design Sync",
        date: "Today 2:00 PM",
        agenda: "Discuss about the north star ver. of our current product",
        participants: ["John Lee", "Jane Doe", "Amanda Le", "Tony Muller"]
    ),
    Card(
        id: 1,
        bgColor: "0059BC",
        textColor: "FFFFFF",
        title: "Design Sync",
        date: "Today 2:00 PM",
        agenda: "Discuss about the north star ver. of our current product",
        participants: ["John Lee", "Jane Doe", "Amanda Le", "Tony Muller"]
    ),
    Card(
        id: 2,
        bgColor: "E05D2D",
        textColor: "FFFFFF",
        title: "Design Sync",
        date: "Today 2:00 PM",
        agenda: "Discuss about the north star ver. of our current product",
        participants: ["John Lee", "Jane Doe", "Amanda Le", "Tony Muller"]
    ),
]

// MARK: - Shared State

struct ContainerProperties {
    var scrollOffset: CGFloat = 0
    var containerSize: CGSize = .zero
    var safeArea: EdgeInsets = .init()
    var minY: CGFloat = 0
}

// MARK: - ContentView

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

// MARK: - CardView

struct CardView: View {
    @Binding var activeCardId: Int?

    @State var currentSize = CGSize(width: 354, height: 102)
    @State var scaleEffect = 1.0
    @State private var rotationAngle: Double = 0
    @State private var dragOffset: CGSize = .zero

    @Namespace private var namespace

    let card: Card
    let properties: ContainerProperties

    // MARK: Local Constants
    private let collapsedSize: CGSize = CGSize(width: 354, height: 102)
    private let expandedSize: CGSize = CGSize(width: 354, height: 532)
    private let cardPadding: CGFloat = 24
    private let cardSpacing: CGFloat = 24

    // MARK: Derived Properties

    private var isExpanded: Bool { activeCardId == card.id }

    private var currentIndex: Int {
        cards.firstIndex(where: { $0.id == card.id }) ?? 0
    }

    private var selectedCardIndex: Int {
        cards.firstIndex(where: { $0.id == activeCardId }) ?? 0
    }

    private var anyCardSelected: Bool { activeCardId != nil }

    private var stackPosition: (index: Int, count: Int) {
        let nonSelected = cards.indices.filter { $0 != selectedCardIndex }
        return (
            index: nonSelected.firstIndex(of: currentIndex) ?? 0,
            count: nonSelected.count
        )
    }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .top) {
            cardShape
        }
        .scaleEffect(scaleEffect)
        .rotationEffect(.degrees(rotationAngle))
        .gesture(collapseGesture)
        .simultaneousGesture(expandedDragGesture)

        /// Primary card stacking logic
        .visualEffect {
            [
                properties, anyCardSelected, stackPosition,
                currentIndex, selectedCardIndex, dragOffset
            ]
            content,
            proxy in

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
                        bounds.height - CGFloat(
                            stackPosition.count - 1 - stackPosition.index
                        ) * 27

                    yOffset += targetMidY - rect.midY
                }
            }

            /// Apply the single combined transform.
            return content.offset(x: xOffset, y: yOffset)
        }
    }
}

// MARK: - Sub-views

extension CardView {

    // MARK: Card Shape

    /// The card's primary shape is a colored rectangle that owns all content as an overlay.
    /// We overlay content ONTO the shape, instead of embedding it INSIDE a Stack and setting
    /// the background property to define the shape, to play better with MatchedGeometryEffect
    /// to get a more fluid transition/animation between sizes.
    private var cardShape: some View {
        Rectangle()
            .fill(Color(hex: card.bgColor))
            .frame(width: currentSize.width, height: currentSize.height)
            .overlay(alignment: .topLeading) {
                cardContent
            }
            /// Clip to get the desired shape to prevent overlay content overflowing
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onChange(of: isExpanded) { _, nV in
                withAnimation(.smooth()) {
                    currentSize = nV ? expandedSize : collapsedSize
                }
            }
    }

    // MARK: Card Content

    /// Overlay content container that owns each individual section.
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: cardSpacing) {
            titlebarSection()

            if isExpanded {
                detailSection()
            }
        }
        .padding(cardPadding)
        .frame(
            width: expandedSize.width,
            height: expandedSize.height,
            alignment: .topLeading
        )
    }

    // MARK: Titlebar Section

    @ViewBuilder
    private func titlebarSection() -> some View {
        ZStack(alignment: isExpanded ? .topTrailing : .bottomLeading) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    titleView()
                    
                    Spacer()
                    
                    /// Reserve space for layout
                    expandedDateView()
                        .opacity(0)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                
                /// Reserve space for layout
                collapsedDateView()
                    .opacity(0)
            }
            
            Text("Today \(isExpanded ? "\n2:00 PM" : "2:00 PM")")
                .font(.system(size: 17, weight: .medium))
                .fixedSize()
                .foregroundStyle(Color(hex: card.textColor))
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity)
//        .border(.red)
    }

    // MARK: Detail Section

    @ViewBuilder
    private func detailSection() -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Rectangle()
                .fill(.black.opacity(0.35))
                .frame(height: 1)

            detailRow(title: "Agenda", text: card.agenda)

            detailRow(
                title: "Participants",
                text: card.participants.joined(separator: ", ")
            )
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }

    // MARK: Leaf Views

    @ViewBuilder
    private func titleView() -> some View {
        Text("Design \(isExpanded ? "\nSync" : "Sync")")
            .font(.system(size: isExpanded ? 36 : 24, weight: .medium))
            .foregroundStyle(Color(hex: card.textColor))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: isExpanded ? 160 : .infinity, alignment: .leading)
            .animation(.smooth(), value: isExpanded)
    }

    @ViewBuilder
    private func expandedDateView() -> some View {
        if isExpanded {
            Text(card.date.replacingOccurrences(of: " at ", with: "\n"))
                .font(.system(size: 17, weight: .medium))
                .fixedSize()
                .foregroundStyle(Color(hex: card.textColor))
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private func collapsedDateView() -> some View {
        if !isExpanded {
            Text(card.date)
                .font(.system(size: 17, weight: .medium))
                .fixedSize()
                .foregroundStyle(Color(hex: card.textColor))
        }
    }

    @ViewBuilder
    private func detailRow(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .cardLabelStyle(color: Color(hex: card.textColor))

            Text(text)
                .cardBodyStyle(color: Color(hex: card.textColor))
        }
    }

    // MARK: Gestures

    private var collapseGesture: some Gesture {
        !isExpanded
            ? DragGesture(minimumDistance: 0)
                .onChanged { _ in collapseGestureChanged() }
                .onEnded { value in collapseGestureEnded(value) }
            : nil
    }

    private var expandedDragGesture: some Gesture {
        isExpanded
            ? DragGesture()
                .onChanged { value in expandedDragChanged(value) }
                .onEnded { value in expandedDragEnded(value) }
            : nil
    }

    // MARK: Gesture Handlers

    private func collapseGestureChanged() {
        withAnimation(.smooth()) { scaleEffect = 0.92 }
    }

    private func collapseGestureEnded(_ value: DragGesture.Value) {
        withAnimation(.smooth()) { scaleEffect = 1 }
        let bounds = CGRect(origin: .zero, size: currentSize)
        if bounds.contains(value.location) {
            withAnimation(.smooth()) { activeCardId = card.id }
        }
    }

    private func expandedDragChanged(_ value: DragGesture.Value) {
        withAnimation(.interactiveSpring()) {
            dragOffset = value.translation
            rotationAngle = 4
        }
    }

    private func expandedDragEnded(_ value: DragGesture.Value) {
        let shouldCollapse =
            abs(value.predictedEndTranslation.height) > 120
            || abs(value.predictedEndTranslation.width) > 120

        withAnimation(.smooth()) {
            dragOffset = .zero
            rotationAngle = 0
            if shouldCollapse { activeCardId = nil }
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
