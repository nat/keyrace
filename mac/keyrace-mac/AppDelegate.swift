//
//  keyrace-mac
//
//  Created by Nat Friedman on 1/2/21.
//

// TODO:
// - Restructure, cleanup, learn swift
// - Save username locally along with token
// - Talk to server and show leaderboard


import SwiftUI
import Foundation

@available(OSX 11.0, *)
@main
struct MenuBarPopoverApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings{
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var menubarItem: MenubarItem?
    var keyTap : KeyTap?
    var gh : GitHub?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        menubarItem = MenubarItem(title: "Setup Keyrace")

        gh = GitHub()
        menubarItem?.gh = gh

        keyTap = KeyTap(self)
        menubarItem?.keyTap = keyTap
        keyTap!.getAccessibilityPermissions()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}
