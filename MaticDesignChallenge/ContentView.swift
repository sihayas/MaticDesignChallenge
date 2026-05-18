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
            CardView()
        }
        .padding()
    }
}

struct CardView: View {
    @State var isExpanded = false
    
    let collapsedSize = CGSize(width: 354, height: 102)
    let expandedSize = CGSize(width: 354, height: 532)
    let padding = 24
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(hex: "#0059BC"))
            /// We overlay content on to the shape instead of embedding it within a Stack and setting the background property to define the shape to play better with MatchedGeometryEffect to get a more fluid transition/animation between sizes.
            .overlay {
                VStack {
                    Text("SF Pro")
                        .foregroundStyle(.white)
                }
            }
            
            
    }
}

#Preview {
    ContentView()
}
