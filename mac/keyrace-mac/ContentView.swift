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
        Section {
            LeaderboardView(keyTap: keyTap)
        }
        Section {
            SettingsView(keyTap: keyTap, gitHub: gitHub)
        }
    }
}
