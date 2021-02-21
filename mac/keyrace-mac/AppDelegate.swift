//
//  keyrace-mac
//
//  Created by Nat Friedman on 1/2/21.
//

import Foundation
import SwiftUI

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
        // Initialize these things first so MenubarItem does not panic.
        gh = GitHub()
        keyTap = KeyTap(self)
        menubarItem = MenubarItem(title: "Setup Keyrace", kt: keyTap!)
        menubarItem!.gh = gh
        
        keyTap!.getAccessibilityPermissions()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

