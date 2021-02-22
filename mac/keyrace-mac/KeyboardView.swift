//
//  KeyboardView.swift
//  keyrace-mac
//
//  Created by Jessie Frazelle on 2/21/21.
//

import Foundation
import SwiftUI

let ROWS: [[[String]]] = [
    [["", ""]],
    [["~", "`"],
    ["!", "1"],
    ["@", "2"],
    ["#", "3"],
    ["$", "4"],
    ["%", "5"],
    ["^", "6"],
    ["&", "7"],
    ["*", "8"],
    ["(", "9"],
    [")", "0"],
    ["_", "-"],
    ["+", "="]],
    [["Q", "q"],
    ["W", "w"],
    ["E", "e"],
    ["R", "r"],
    ["T", "t"],
    ["Y", "y"],
    ["U", "u"],
    ["I", "i"],
    ["O", "o"],
    ["P", "p"],
    ["{", "["],
    ["}", "]"],
    ["|", "\\"]],
    [["A", "a"],
    ["S", "s"],
    ["D", "d"],
    ["F", "f"],
    ["G", "g"],
    ["H", "h"],
    ["J", "j"],
    ["K", "k"],
    ["L", "l"],
    [":", ";"],
    ["\"", "'"]],
    [["Z", "z"],
    ["X", "x"],
    ["C", "c"],
    ["V", "v"],
    ["B", "b"],
    ["N", "n"],
    ["M", "m"],
    ["<", ","],
    [">", "."],
    ["?", "/"]],
    [["", ""]]]

struct KeyboardView: View {
    @ObservedObject var keyTap: KeyTap
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            ForEach(
                ROWS.indexed(),
                id: \.1.self
            ) { index, row in
                Section {
                    HStack(alignment: .center, spacing: 0) {
                        ForEach(
                            row,
                            id: \.self
                        ) { char in
                            KeyView(keyTap: keyTap, char: char, index: index)
                                .padding(.top, 1.4)
                                .padding(.leading, -3.1)
                                .padding(.trailing, -3.1)
                                .padding(.bottom, 1.4)
                        }
                    }
                    .frame(width: 344.4, height: 20.7, alignment: index.getRowAlignment())
                    .padding(.top, 1.4)
                    .padding(.bottom, 1.4)
                    .padding(.leading, 0)
                    .padding(.trailing, 0)
                }
            }
        }
        .background(
            Image("magic-keyboard")
                .resizable()
                .frame(width: 350, height: 144)
        )
        .padding(.leading, 8)
        .padding(.trailing, 8)
    }
}

struct KeyView: View {
    var keyTap: KeyTap
    var char: [String]
    var index: Int
    @State private var hover = false
    
    var body: some View {
        if index == 0 || index == 5 {
            // These are empty purposely so that the heatmapped keys are aligned perfectly.
            Rectangle()
                .frame(width: 20.7, height: 20.7)
                .hidden()
        } else {
            ZStack {
                Circle()
                    .fill(char.getFill(keyTap))
                    .frame(width: 30, height: 30)
                    .overlay(
                        // We stick this inside another overlay so you can't be overed over 2 keys at once.
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 20.7, height: 20.7)
                            .overlay(
                                RoundedRectangle(cornerSize: CGSize(width: 3, height: 3), style: .continuous)
                                    .fill(Color.black.opacity(0.7))
                                    .overlay(
                                        Text(String(format: "%d (%.2f%%)",
                                                    keyTap.keyboardData[char]!,
                                                    char.getPercentage(keyTap)))
                                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                                            .foregroundColor(Color.white)
                                            .padding(2)
                                            .lineLimit(1)
                                            )
                                    // FIXME: Somehow make the width of the tooltip the width of the text.
                                    .frame(width: 90, height: 16, alignment: .center)
                                    .shadow(radius: 2)
                                    .offset(x: 0, y: -20)
                                    .opacity(hover ? 1 : 0)
                                    .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
                                    .zIndex(1)
                            )
                            // FIXME: if you hover too fast things get stuck
                            .onHover { hover in
                                self.hover = hover
                            }
                    )
            }
            .zIndex(0)
            .frame(width: 30, height: 30)
        }
    }
}

extension String {
    func toUnicodeScalarInt() -> Int {
        let scalar = Unicode.Scalar.init(self as String) ?? Unicode.Scalar.init(0 as UInt8)
        return Int(scalar.value)
    }
}

extension Int {
    func getRowAlignment() -> Alignment {
        if self == 1 {
            return .leading
        } else if self == 2 {
            return .trailing
        }
        return .center
    }
}

extension Array where Element == String  {
    func getCount(_ keys: [Int]) -> Int {
        var count = 0
        
        for char in self {
            if char.isEmpty {
                continue
            }
            
            // Get the count for this key and return it.
            count += keys[char.toUnicodeScalarInt()]
        }
        
        return count
    }
    
    func getPercentage(_ keyTap: KeyTap) -> Double {
        return (Double(keyTap.keyboardData[self]!) / Double(keyTap.maxKeyboardCount)) * 100
    }
    
    func getFill(_ keyTap: KeyTap) -> RadialGradient {
        let percentage = self.getPercentage(keyTap)
        
        // Calculate the color and the percentage.
        var color = Color.green
        var opacity = percentage / 33
        if percentage > 33 && percentage < 66 {
            color = Color.yellow
            opacity = percentage / 66
        } else if percentage >= 66 {
            color = Color.red
            opacity = percentage / 100
        }
        
        return RadialGradient(
            gradient: Gradient(colors: [color.opacity(opacity), color.opacity(opacity / 1.6), color.opacity(0.1)]),
            center: .center,
            startRadius: 0,
            endRadius: 15)
    }
}
