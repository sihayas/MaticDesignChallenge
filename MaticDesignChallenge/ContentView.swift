//
//  ContentView.swift
//  MaticDesignChallenge
//
//  Created by daemons on 5/15/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            CardView(
                bgColor: Color(hex: "F4BB5C"),
                textColor: Color(hex: "B44200")
            )
            CardView(
                bgColor: Color(hex: "0059BC"),
                textColor: Color(hex: "FFF")
            )
            CardView(
                bgColor: Color(hex: "E05D2D"),
                textColor: Color(hex: "FFF")
            )
        }
        .padding()
    }
}


struct CardState {
    var offset: CGPoint = .zero
    var isExpanded: Bool = false
}

struct CardView: View {
    @State var isExpanded = false
    @State var currentSize = CGSize(width: 354, height: 102)
    @State var scaleEffect = 1.0
    @Namespace private var namespace

    let collapsedSize = CGSize(width: 354, height: 102)
    let expandedSize = CGSize(width: 354, height: 532)
    
    let bgColor: Color
    let textColor: Color

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(bgColor)
                .frame(width: currentSize.width, height: currentSize.height)
                /// We overlay content on TO the shape, instead of embedding it INSIDE a Stack and setting the background property to define the shape, to play better with MatchedGeometryEffect to get a more fluid transition/animation between sizes.
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
                                    .foregroundStyle(textColor)
                                    .animation(
                                        .smooth(),
                                        value: isExpanded
                                    )
                                
                                Spacer()
                                
                                /// MatchedGeometry here
                                if isExpanded {
                                    Text("Today \n2:00 PM")
                                        .font(.system(size: 17, weight: .medium))
                                        .fixedSize()
                                        .foregroundStyle(textColor)
                                        .multilineTextAlignment(.trailing)
                                        .matchedGeometryEffect(id: "date", in: namespace)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            /// We remove the date view when expanding so MatchedGeometry knows to animate and transition it towards the top right
                            if !isExpanded {
                                Text("Today at 2:00 PM")
                                    .font(.system(size: 17, weight: .medium))
                                    .fixedSize()
                                    .foregroundStyle(textColor)
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
                                    .foregroundStyle(textColor.opacity(0.6))
                                
                                
                                Text("Discuss about the north star ver. of our current product")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(textColor)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Participants")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(textColor.opacity(0.6))
                                
                                
                                Text("John Lee, Jane Doe, Amanda Le, Tony Muller")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(textColor)
                            }
                        }
                    }
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .topLeading
                    )
                    .border(.red)
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
                            isExpanded.toggle()
                        }
                    }
                }
        )
        .scaleEffect(scaleEffect)
    }
}

#Preview {
    ContentView()
}
