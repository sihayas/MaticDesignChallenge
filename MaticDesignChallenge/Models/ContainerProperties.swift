//
//  ContainerProperties.swift
//  MaticDesignChallenge
//
//  Created by daemons on 5/20/26.
//
import SwiftUI

// MARK: - Shared State

struct ContainerProperties {
    var scrollOffset: CGFloat = 0
    var containerSize: CGSize = .zero
    var safeArea: EdgeInsets = .init()
    var minY: CGFloat = 0
}
