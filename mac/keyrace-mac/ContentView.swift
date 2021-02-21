//
//  ContentView.swift
//  keyrace-mac
//
//  Created by Jessie Frazelle on 2/21/21.
//

import Foundation
import SwiftUI

struct ContentView: View {
    @ObservedObject var keyTap: KeyTap
    @ObservedObject var gitHub: GitHub
    
    var body: some View {
        Group {
            TypingChart(typingCount: keyTap.minutesChart, color: [255, 0, 0], granularity: 3,
                        valueFormatter: MinAxisValueFormatter(), labelCount: 0)
                .frame(width: 350, height: 100, alignment: .center)
            TypingChart(typingCount: keyTap.hoursChart, color: [255, 0, 0], granularity: 3,
                        valueFormatter: HourAxisValueFormatter(), labelCount: 0 )
                .frame(width: 350, height: 100, alignment: .center)
            TypingChart(typingCount: keyTap.keysChart, color: [0, 255, 255], granularity: 1,
                        valueFormatter: KeyAxisValueFormatter(), labelCount: 25)
                .frame(width: 350, height: 100, alignment: .center)
            TypingChart(typingCount: keyTap.symbolsChart, color: [0, 255, 255], granularity: 1,
                        valueFormatter: SymbolAxisValueFormatter(), labelCount: 25)
                .frame(width: 350, height: 100, alignment: .center)
        }
        Section {
            LeaderboardView(keyTap: keyTap)
        }
        Section {
            SettingsView(keyTap: keyTap, gitHub: gitHub)
        }
    }
}
