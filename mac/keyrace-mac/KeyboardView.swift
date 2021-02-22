//
//  KeyboardView.swift
//  keyrace-mac
//
//  Created by Jessie Frazelle on 2/21/21.
//

import Foundation
import SwiftUI

struct KeyboardView: View {
    let rows: [[[String]]] = [
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
    
    var body: some View {
        ForEach(
            rows,
            id: \.self
        ) { row in
            Section {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(
                        row,
                        id: \.self
                    ) { char in
                        Text((char[0] + " " + char[1]).trimmingCharacters(in: .whitespacesAndNewlines))
                            .background(Rectangle()
                                            .fill(Color.black)
                                            .frame(width: 22, height: 22)
                                            .foregroundColor(.white))
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .frame(width: 22, height: 22)
                    }
                }
                .frame(width: 350, height: 26, alignment: .center)
            }
        }
    }
}
