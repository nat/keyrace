//
//  LeaderboardView.swift
//  keyrace-mac
//
//  Created by Jessie Frazelle on 2/20/21.
//

import Foundation
import SwiftUI

struct Player: Codable {
    var username: String
    var gravatar: String
    var score: Int
}

extension Player {
    // Turn the URL for the player's avatar into an NSImage.
    func avatar() -> NSImage {
        let url = URLComponents(string: self.gravatar)?.url
        if let data = try? Data.init(contentsOf: url!, options: []) {
            let avatar = NSImage(data: data)!
            avatar.size = NSSizeFromString("100,100")
            return avatar
        }
        return NSImage()
    }
    
    // Get the score string for the player
    func scoreString(index: Int) -> String {
        var format = "%d"
        if index == 0 {
            format += " 🎉"
        }
        return String(format: format, self.score)
    }
    
    // Get the link to the player's GitHub profile.
    func profileLink() -> String {
        return "https://github.com/" + self.username
    }
}

struct LeaderboardView: View {
    @ObservedObject var keyTap: KeyTap
    @ObservedObject var gitHub: GitHub
    @Environment(\.openURL) var openURL
    
    var body: some View {
        // This allows the leaderboard view to watch for when we login and update.
        if !gitHub.username.isEmpty {
            List(keyTap.players.indexed(), id: \.1.username) { index, player in
                // Create the profile image in a button so it is a link.
                Button(action: {
                    openProfile(player)
                }) {
                    Image(nsImage: player.avatar())
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25, alignment: .center)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(EdgeInsets(top: 2.5, leading: 2.5, bottom: 2.5, trailing: 0))
        
                // Print the username as a link.
                Link("@" + player.username,
                     destination: URL(string: "https://github.com/" + player.username)!)
                    .foregroundColor(/*@START_MENU_TOKEN@*/.blue/*@END_MENU_TOKEN@*/)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .frame(width: 100, alignment: .leading)
            
                // Print the score.
                Text(player.scoreString(index: index))
                    .font(.system(size: 12, design: .monospaced))
            }
            .listStyle(SidebarListStyle())
            .frame(width: 350, height: (40 * CGFloat(keyTap.players.count)) + 20, alignment: .topLeading)
        }
    }
    
    func openProfile(_ player: Player) {
        guard let url = URL(string: player.profileLink()) else {
            return
        }
        openURL(url)
    }
}

// Make it so we can index our list of players for the leaderboard view.
struct IndexedCollection<Base: RandomAccessCollection>: RandomAccessCollection {
    typealias Index = Base.Index
    typealias Element = (index: Index, element: Base.Element)

    let base: Base
    var startIndex: Index { base.startIndex }

   // corrected typo: base.endIndex, instead of base.startIndex
    var endIndex: Index { base.endIndex }

    func index(after i: Index) -> Index {
        base.index(after: i)
    }

    func index(before i: Index) -> Index {
        base.index(before: i)
    }

    func index(_ i: Index, offsetBy distance: Int) -> Index {
        base.index(i, offsetBy: distance)
    }

    subscript(position: Index) -> Element {
        (index: position, element: base[position])
    }
}

extension RandomAccessCollection {
    func indexed() -> IndexedCollection<Self> {
        IndexedCollection(base: self)
    }
}
