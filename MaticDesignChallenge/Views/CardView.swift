//
//  CardView.swift
//  MaticDesignChallenge
//
//  Created by daemons on 5/20/26.
//

import SwiftUI

// MARK: - CardView

struct CardView: View {
    @Binding var activeCardId: Int?

    @State private var currentSize = CGSize(width: 354, height: 102)
    @State private var isPressing: Bool = false
    @State private var scaleEffect = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var dragRotation: Double = 0

    let card: Card
    let properties: ContainerProperties

    // MARK: Local Constants
    private let cornerRadius: CGFloat = 12.0
    private let collapsedSize: CGSize = CGSize(width: 354, height: 102)
    private let expandedSize: CGSize = CGSize(width: 354, height: 532)
    private let cardPadding: CGFloat = 24
    private let cardSpacing: CGFloat = 24
    private let dragUpLimit: CGFloat = 120.0
    private let collapseThreshold: CGFloat = 120

    // MARK: Derived Properties

    /// Whether this card is the currently selected/expanded card.
    private var isExpanded: Bool { activeCardId == card.id }

    /// The position of this card in the global `cards` array.
    /// Captured in `renderState` to identify this card's role in the visual effect.
    private var currentIndex: Int {
        cards.firstIndex(where: { $0.id == card.id }) ?? 0
    }

    /// The position of the selected card in the global `cards` array.
    /// Captured in `renderState` so `.visualEffect` can determine which card to pin to the top.
    private var selectedCardIndex: Int {
        cards.firstIndex(where: { $0.id == activeCardId }) ?? 0
    }

    /// Whether any card in the stack is currently selected.
    /// The primary branch condition in `.visualEffect` & drives the entire layout switch
    /// between idle resting positions and the expanded/stacked states.
    private var anyCardSelected: Bool { activeCardId != nil }

    /// The position of this card within the non-selected cards.
    /// Used by `.visualEffect` to calculate each card's exact slot in the bottom stack
    /// when another card is expanded.
    private var stackPosition: (index: Int, count: Int) {
        let nonSelected = cards.indices.filter { $0 != selectedCardIndex }
        return (
            index: nonSelected.firstIndex(of: currentIndex) ?? 0,
            count: nonSelected.count
        )
    }

    /// Art-directed resting rotation for each card in the idle stack.
    /// Captured in `renderState` and applied by `.visualEffect` when no card is selected.
    /// Cycles through the array so the pattern holds regardless of card count.
    private var baselineRotation: Double {
        let rotations: [Double] = [-4, 0, -2]
        return rotations[currentIndex % rotations.count]
    }

    /// Determines the correct rotation based on the current state.
    private var currentRotation: Double {
        if anyCardSelected {
            return currentIndex == selectedCardIndex ? dragRotation : 0
        } else {
            return baselineRotation
        }
    }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .top) {
            cardShape
                /// Rotation effect has to apply to the card itself, as applying it to the outer ZStack in conjunction with offset translation's creates an unintended "pendulum" effect when both occur at the same time.
                .rotationEffect(.degrees(currentRotation))
        }
        .scaleEffect(scaleEffect)
        /// Primary card stacking logic
        ///
        /// If we used standard offsets or altered the view hierarchy, SwiftUI would force a heavy
        /// layout recalculation on every frame, which can stutter. `.visualEffect` hooks directly
        /// into the render tree. It allows us to read the card's position inside the `ScrollView`
        /// and calculate the exact mathematical delta needed to move it to the center (if selected)
        /// or stack it at the bottom (if inactive) whilst keeping the gesture translation
        /// butter-smooth and separate from the layout engine. For readability, we could put this into a Sendable struct to maintain the safe copies.
        /// Keep ONLY the heavy geometry math inside visualEffect
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

            /// Start with the user's interactive drag translation.
            var yOffset = dragOffset.height
            let xOffset = dragOffset.width

            if anyCardSelected {
                if currentIndex == selectedCardIndex {
                    /// Selected: Pin to 48pt from the top of the container.
                    yOffset += 48 - rect.minY
                } else {
                    /// Calculate the "anchor point" for this specific card in the bottom stack.
                    /// We treat the bottom of the container as the floor (bounds.height).
                    /// Each card is pushed up 27pt from the previous one, creating a
                    /// cascading "deck of cards" effect.
                    let stackOffsetFromBottom =
                        CGFloat(stackPosition.count - 1 - stackPosition.index)
                        * 27
                    let targetMidY = bounds.height - stackOffsetFromBottom

                    /// Calculate the travel distance.
                    /// A View's .offset() is relative to its original position.
                    /// We find the difference between where the card *should* be (targetMidY)
                    /// and where it currently sits in the scroll view (rect.midY).
                    /// By adding this difference to yOffset, we force the card to "snap"
                    /// into its specific stack slot.
                    yOffset += targetMidY - rect.midY
                }
            }

            /// Apply the single combined transform to the render tree.
            return content.offset(x: xOffset, y: yOffset)
        }

        .gesture(collapseGesture)
        .simultaneousGesture(expandedDragGesture)
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
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(hex: card.bgColor))
            .strokeBorder(.black.opacity(0.35), lineWidth: 1)
            .frame(width: currentSize.width, height: currentSize.height)
            .overlay(alignment: .topLeading) {
                cardContent
            }
            .colorMultiply(isPressing ? Color(white: 0.85) : .white)
            /// We could use an overlay here to match the Figma spec, but there are sizing and clipping isues when expanding and contracting a shape so a color multiply on the Rectangle itself is more appealing, either approach works.
            //            .overlay {
            //                if isPressing {
            //                    Rectangle()
            //                        .fill(.black.opacity(0.16))
            //                }
            //            }
            /// Clip to get the desired shape to prevent overlay content overflowing.
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onChange(of: isExpanded) { _, nV in
                withAnimation(.smooth()) {
                    currentSize = nV ? expandedSize : collapsedSize
                }
            }
    }

    // MARK: Card Content

    /// Overlaid content container that owns each individual section. Takes up the expanded size of the card to align with a masking approach to preserve performance and avoid layout calculations.
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            titlebarSection()
            
            /// We could conditionally render this but this is fine for now.
            detailSection()
        }
        /// Utilizing a "mask" approach for performance, so we set the content frame size to our expanded size.
        .frame(
            width: expandedSize.width,
            height: expandedSize.height,
            alignment: .topLeading
        )
    }

    // MARK: Titlebar Section

    @ViewBuilder
    private func titlebarSection() -> some View {
        /// Utilize a ZStack and animate the alignment change to get a fluid transition for the `subtitleView` from the bottom left corner to the top right corner. MatchedGeometryEffect could also get the effect we are looking for but it is not ideal to maintain.
        ZStack(alignment: isExpanded ? .topTrailing : .bottomLeading) {
            HStack(alignment: .top) {
                titleView()
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: isExpanded ? nil : 102,
                alignment: .topLeading
            )

            subtitleView()
        }
        .padding(cardPadding)
        .frame(maxHeight: isExpanded ? nil : 102)
        .frame(maxWidth: .infinity)
    }

    // MARK: Detail Section

    @ViewBuilder
    private func detailSection() -> some View {
        VStack(alignment: .leading, spacing: cardSpacing) {
            Rectangle()
                .fill(.black.opacity(0.35))
                .frame(height: 1)

            detailRow(title: "Agenda", text: card.agenda)

            detailRow(
                title: "Participants",
                text: card.participants.joined(separator: ", ")
            )
        }
        .padding([.horizontal, .bottom], cardPadding)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }

    // MARK: - Component Implementations

    @ViewBuilder
    private func titleView() -> some View {
        animatedSplitText(
            text: card.title,
            expandedAlignment: .leading,
            collapsedSpacing: 6,
            expandedFont: .system(size: 36, weight: .medium),
            collapsedFont: .system(size: 24, weight: .medium)
        )
    }

    @ViewBuilder
    private func subtitleView() -> some View {
        animatedSplitText(
            text: card.subTitle,
            expandedAlignment: .trailing,
            collapsedSpacing: 4,
            expandedFont: .system(size: 17, weight: .medium),
            collapsedFont: .system(size: 17, weight: .medium),
        )
    }

    /// Physically animates a string splitting from one line into two.
    ///
    /// Standard SwiftUI text updates (like dynamically inserting a `\n`) trigger a crossfade
    /// replacement animation. By splitting the text into two distinct `Text` views and shifting
    /// the container from an `HStack` to a `VStack` using `AnyLayout`, SwiftUI physically tracks
    /// the bounding boxes of the words, resulting in a fluid, spatial layout transition.
    ///
    /// - Parameters:
    ///   - text: The string to split. The first word becomes the first `Text`, the remainder the second.
    ///   - expandedAlignment: Horizontal alignment of the `VStack` when expanded (e.g. `.leading` for title, `.trailing` for subtitle).
    ///   - collapsedSpacing: The spacing between the two words when collapsed inline in the `HStack`.
    ///   - expandedFont: Font applied when the card is expanded.
    ///   - collapsedFont: Font applied when the card is collapsed.
    @ViewBuilder
    private func animatedSplitText(
        text: String,
        expandedAlignment: HorizontalAlignment,
        collapsedSpacing: CGFloat,
        expandedFont: Font,
        collapsedFont: Font,
    ) -> some View {
        /// Split on the first space so "Team Sync" becomes ["Team", "Sync"].
        /// Single-word strings produce an empty secondPart and render as one Text.
        let parts = text.components(separatedBy: " ")
        let firstPart = parts.first ?? ""
        let secondPart = parts.dropFirst().joined(separator: " ")

        /// Swap the container type based on expansion state.
        /// `AnyLayout` type-erases the layout so SwiftUI sees one view whose
        /// container changes, rather than two separate views being swapped in/out.
        /// This is what produces the physical word-travel animation instead of a crossfade.
        let layout =
            isExpanded
            ? AnyLayout(VStackLayout(alignment: expandedAlignment, spacing: 0))
            : AnyLayout(HStackLayout(spacing: collapsedSpacing))

        layout {
            /// Anchors the animation for the first word.
            Text(firstPart)

            /// Omitted entirely for single-word strings to avoid a trailing empty Text
            /// which would add unexpected spacing in the HStack.
            if !secondPart.isEmpty {
                Text(secondPart)
            }
        }
        .font(isExpanded ? expandedFont : collapsedFont)
        .foregroundStyle(Color(hex: card.textColor))
        /// Drive the layout swap animation from `isExpanded` so it stays in sync
        /// with the card size change triggered by `onChange(of: isExpanded)`.
        .animation(.snappy(), value: isExpanded)
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
                .onChanged { _ in collapsedGestureChanged() }
                .onEnded { value in collapsedGestureEnded(value) }
            : nil
    }

    private var expandedDragGesture: some Gesture {
        isExpanded
            /// Tell the gesture to calculate its translation relative to the device screen, not the moving card. This  decouples the touch math from the view's rotation and bounding box changes.
            ? DragGesture(coordinateSpace: .global)
                .onChanged { value in expandedGestureChanged(value) }
                .onEnded { value in expandedGestureEnded(value) }
            : nil
    }

    // MARK: Gesture Handlers

    /// Fires every frame while the user presses a collapsed card.
    /// Scales down and activates the press overlay to give tactile feedback.
    private func collapsedGestureChanged() {
        withAnimation(.smooth) {
            scaleEffect = 0.92
            isPressing = true
        }
    }

    /// Fires when the user lifts their finger from a collapsed card.
    /// Restores scale and press state, then expands the card if the finger
    /// is still within the card bounds (i.e. it was a tap, not a drag off).
    private func collapsedGestureEnded(_ value: DragGesture.Value) {
        withAnimation(.smooth) {
            scaleEffect = 1
            isPressing = false
        }
        let bounds = CGRect(origin: .zero, size: currentSize)
        if bounds.contains(value.location) {
            withAnimation(.smooth) { activeCardId = card.id }
        }
    }

    /// Fires every frame while the user drags an expanded card.
    private func expandedGestureChanged(_ value: DragGesture.Value) {
        var rawTranslation = value.translation

        /// Clamps upward drag using Apple's rubber band formula so the card
        /// resists being pulled further up the screen the harder you pull.
        if rawTranslation.height < 0 {
            let upwardDrag = abs(rawTranslation.height)
            let rubberbandedY = upwardDrag / (1 + (upwardDrag / dragUpLimit))
            rawTranslation.height = -rubberbandedY
        }

        /// interactiveSpring tracks the finger in real time while preserving
        /// enough velocity to carry through the collapse threshold naturally.
        withAnimation(.interactiveSpring) {
            dragOffset = rawTranslation
            dragRotation = 4
        }
    }

    /// Fires when the user releases an expanded card.
    /// Snaps back to rest, or collapses the card if the threshold was passed enough.
    private func expandedGestureEnded(_ value: DragGesture.Value) {
        /// predictedEndTranslation extrapolates the finger velocity to decide
        /// intent. A slow drag that crosses 120pt won't collapse, but a fast flick will.
        let shouldCollapse =
            value.predictedEndTranslation.height > collapseThreshold

        withAnimation(.spring) {
            dragOffset = .zero
            dragRotation = 0

            if shouldCollapse {
                activeCardId = nil
            }
        }
    }
}
