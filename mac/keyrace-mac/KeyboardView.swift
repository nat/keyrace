//
//  KeyboardView.swift
//  keyrace-mac
//
//  Created by Jessie Frazelle on 2/21/21.
//

import Foundation
import SwiftUI

let ROWS: [[[String]]] = [
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
    [["q", ""],
    ["w", ""],
    ["e", ""],
    ["r", ""],
    ["t", ""],
    ["y", ""],
    ["u", ""],
    ["i", ""],
    ["o", ""],
    ["p", ""],
    ["{", "["],
    ["}", "]"],
    ["|", "\\"]],
    [["a", ""],
    ["s", ""],
    ["d", ""],
    ["f", ""],
    ["g", ""],
    ["h", ""],
    ["j", ""],
    ["k", ""],
    ["l", ""],
    [":", ";"],
    ["\"", "'"]],
    [["z", ""],
    ["x", ""],
    ["c", ""],
    ["v", ""],
    ["b", ""],
    ["n", ""],
    ["m", ""],
    ["<", ","],
    [">", "."],
    ["?", "/"]]]

struct KeyboardView: View {
    @ObservedObject var keyTap: KeyTap
    
    var body: some View {
        ForEach(
            ROWS,
            id: \.self
        ) { row in
            Section {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(
                        row,
                        id: \.self
                    ) { char in
                        KeyboardKey(keyTap: keyTap, char: char)
                    }
                }
                .frame(width: 350, height: 26, alignment: .center)
            }
        }
    }
}

struct KeyboardKey: View {
    var keyTap: KeyTap
    var char: [String]
    
    var body: some View {
        Text((char[0] + " " + char[1]).trimmingCharacters(in: .whitespacesAndNewlines))
            .background(Rectangle()
                            .fill(Color.purple.opacity(
                                char.getOpacity(keyTap)
                            ))
                            .frame(width: 22, height: 22)
                            .foregroundColor(.white))
            .font(.system(size: 8, weight: .medium, design: .monospaced))
            .frame(width: 22, height: 22)
            .help(String(format: "%d", keyTap.keyboardData[char]!))
    }
}

extension String {
    func toUnicodeScalarInt() -> Int {
        let scalar = Unicode.Scalar.init(self as String) ?? Unicode.Scalar.init(0 as UInt8)
        return Int(scalar.value)
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
    
    func getOpacity(_ keyTap: KeyTap) -> Double {
        let opacity = Double(keyTap.keyboardData[self]!) / Double(keyTap.maxKeyboardCount)
        return opacity
    }
}
