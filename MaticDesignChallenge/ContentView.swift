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
        date: "Today at 2:00 PM",
        agenda: "Discuss about the north star ver. of our current product",
        participants: ["John Lee", "Jane Doe", "Amanda Le", "Tony Muller"]
    ),
    Card(
        id: 1,
        bgColor: "0059BC",
        textColor: "FFFFFF",
        title: "Design Sync",
        date: "Today at 2:00 PM",
        agenda: "Discuss about the north star ver. of our current product",
        participants: ["John Lee", "Jane Doe", "Amanda Le", "Tony Muller"]
    ),
    Card(
        id: 2,
        bgColor: "E05D2D",
        textColor: "FFFFFF",
        title: "Design Sync",
        date: "Today at 2:00 PM",
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

// MARK: - Text Styles

/// Applies the card label style, small semibold text at reduced opacity, used for
/// field labels like "Agenda" and "Participants".
struct CardLabelStyle: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color.opacity(0.6))
    }
}

/// Applies the card body style, regular text at full opacity, used for field values.
struct CardBodyStyle: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(color)
    }
}

extension View {
    /// Styles text as a card field label (12pt semibold, muted).
    func cardLabelStyle(color: Color) -> some View {
        modifier(CardLabelStyle(color: color))
    }

    /// Styles text as a card field value (16pt regular, full opacity).
    func cardBodyStyle(color: Color) -> some View {
        modifier(CardBodyStyle(color: color))
    }
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

    /// Outer container that owns each individual section.
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            titlebarSection
            if isExpanded {
                detailSection
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

    private var titlebarSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            /// Top/Title
            ///
            HStack(alignment: .top) {
                /// BUG: Using the title property directly does not work well with text animations for some reason. Use hardcoded string for now to accomdate a working animation.
                Text("Design \(isExpanded ? "\nSync" : "Sync")")
                    .font(.system(size: isExpanded ? 36 : 24, weight: .medium))
                    .foregroundStyle(Color(hex: card.textColor))
                    .multilineTextAlignment(.leading)
                    .frame(
                        maxWidth: isExpanded ? 160 : .infinity,
                        alignment: .leading
                    )
                    .animation(.smooth(), value: isExpanded)

                Spacer()

                /// MatchedGeometry here & date moves to top-right when expanded
                if isExpanded {
                    Text(card.date.replacingOccurrences(of: " at ", with: "\n"))
                        .font(.system(size: 17, weight: .medium))
                        .fixedSize()
                        .foregroundStyle(Color(hex: card.textColor))
                        .multilineTextAlignment(.trailing)
                        .matchedGeometryEffect(id: "date", in: namespace)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            /// Bottom / Date
            ///
            /// We remove the date view when expanding so MatchedGeometry knows to animate
            /// and transition it towards the top right.
            if !isExpanded {
                Text(card.date)
                    .font(.system(size: 17, weight: .medium))
                    .fixedSize()
                    .foregroundStyle(Color(hex: card.textColor))
                    .matchedGeometryEffect(id: "date", in: namespace)
            }
        }
        /// The frame *needs* to have a minHeight or else MatchedGeometryEffect cannot reserve space for the target transition on expansion.
        .frame(minHeight: 72, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: Detail Section

    private var detailSection: some View {
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
    
    
    // MARK: ViewBuilder's
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

    /// Tap-and-hold scale-down gesture for collapsed cards.
    /// Pressing scales to 0.92; lifting inside the card bounds triggers expansion.
    /// `Optional` conditionally conforms to `Gesture`, so the ternary returning `nil`
    /// is the correct way to disable a gesture — not type-erasure or a separate type.
    private var collapseGesture: some Gesture {
        !isExpanded
            ? DragGesture(minimumDistance: 0)
                .onChanged { _ in collapseGestureChanged() }
                .onEnded { value in collapseGestureEnded(value) }
            : nil
    }

    /// Drag-to-dismiss gesture for the expanded card.
    /// `predictedEndTranslation` factors in velocity so a fast flick
    /// registers even if the actual translation wasn't huge.
    private var expandedDragGesture: some Gesture {
        isExpanded
            ? DragGesture()
                .onChanged { value in expandedDragChanged(value) }
                .onEnded { value in expandedDragEnded(value) }
            : nil
    }

    // MARK: Gesture Handlers

    /// Scales the card down while the user is pressing, giving tactile press feedback.
    private func collapseGestureChanged() {
        withAnimation(.smooth()) { scaleEffect = 0.92 }
    }

    /// Restores scale and expands the card if the finger lifted within its bounds.
    /// Lifting outside the bounds (i.e. a drag-off) cancels the interaction without expanding.
    /// - Parameter value: The final drag value, used to check the lift location.
    private func collapseGestureEnded(_ value: DragGesture.Value) {
        withAnimation(.smooth()) { scaleEffect = 1 }
        let bounds = CGRect(origin: .zero, size: currentSize)
        if bounds.contains(value.location) {
            withAnimation(.smooth()) { activeCardId = card.id }
        }
    }

    /// Tracks the drag translation and applies a fixed rotation to suggest the card
    /// is being physically picked up and moved.
    /// - Parameter value: The in-flight drag value containing the current translation.
    private func expandedDragChanged(_ value: DragGesture.Value) {
        withAnimation(.interactiveSpring()) {
            dragOffset = value.translation
            rotationAngle = 4
        }
    }

    /// Collapses the card if the gesture ended with enough velocity or distance,
    /// otherwise snaps it back to center. Uses `predictedEndTranslation` rather than
    /// raw translation so a fast flick registers even if the finger didn't travel far.
    /// - Parameter value: The final drag value containing predicted end translation.
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

// MARK: - Preview

#Preview {
    ContentView()
}
