//
//  Card.swift
//  MaticDesignChallenge
//
//  Created by daemons on 5/18/26.
//

import Foundation
import SwiftUI

struct Card {
    var id: Int
    var bgColor: String
    var textColor: String
    var title: String
    var subTitle: String
    var agenda: String
    var participants: [String]
}

let cards: [Card] = [
    Card(
        id: 0,
        bgColor: "F4BB5C",
        textColor: "B44200",
        title: "Daily Focus",
        subTitle: "3 Tasks Left",
        agenda: "Discuss about the north star ver. of our current product",
        participants: ["John Lee", "Jane Doe", "Amanda Le", "Tony Muller"]
    ),
    Card(
        id: 1,
        bgColor: "0059BC",
        textColor: "FFFFFF",
        title: "Design Sync",
        subTitle: "Today 2:00 PM",
        agenda: "Discuss about the north star ver. of our current product",
        participants: ["John Lee", "Jane Doe", "Amanda Le", "Tony Muller"]
    ),
    Card(
        id: 2,
        bgColor: "E05D2D",
        textColor: "FFFFFF",
        title: "Inspiration",
        subTitle: "12 New Items",
        agenda: "Discuss about the north star ver. of our current product",
        participants: ["John Lee", "Jane Doe", "Amanda Le", "Tony Muller"]
    ),
]

