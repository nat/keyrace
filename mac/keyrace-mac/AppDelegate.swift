//
//  keyrace-mac
//
//  Created by Nat Friedman on 1/2/21.
//

import Cocoa
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
    var popover: NSPopover!
    var statusBarItem: NSStatusItem!
    var keyTap : KeyTap?
    var gitHub : GitHub?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the status item.
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        if let button = self.statusBarItem.button {
            button.title = "Setup Keyrace"
            button.action = #selector(togglePopover(_:))
        }
        
        // Initialize these things so we can pass them to the ContentView().
        gitHub = GitHub()
        keyTap = KeyTap(self)
        
        keyTap!.getAccessibilityPermissions()
        
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView(keyTap: keyTap!, gitHub: gitHub!)

        // Create the popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 350, height: 900)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        self.popover = popover
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = self.statusBarItem.button {
            if self.popover.isShown {
                self.popover.performClose(sender)
            } else {
                self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
    }
}
