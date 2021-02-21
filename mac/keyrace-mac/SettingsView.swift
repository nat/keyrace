//
//  SettingsView.swift
//  keyrace-mac
//
//  Created by Jessie Frazelle on 2/16/21.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    @ObservedObject var keyTap: KeyTap
    @ObservedObject var gitHub: GitHub
    @AppStorage("onlyShowFollows") private var onlyShowFollows = UserDefaults.standard.onlyShowFollows

    var body: some View {
        Menu("Settings") {
            Toggle("Only show users I follow", isOn: $onlyShowFollows)
            
            if gitHub.username != nil {
                Text("Logged in as @" + gitHub.username!)
            } else {
                Button("Login with GitHub") {
                    login()
                }
            }
            
            Button("Quit") {
                quit()
            }
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .padding(.leading, 10)
        .padding(.trailing, 10)
        .padding(.bottom, 10)
    }
    
    func login() {
        if !(gitHub.token ?? "").isEmpty {
            gitHub.getUserName()
            return
        }

        let alert = NSAlert()
        alert.messageText = "Login with GitHub"

        DispatchQueue.global(qos: .background).async {
            let (userCode, verificationUri) = self.gitHub.startDeviceAuth(clientId: "a945f87ad537bfddb109", scope: "")
            
            if (userCode == "") {
                alert.informativeText = "Could not contact GitHub. Try again later."
                alert.addButton(withTitle: "Ok")
                alert.runModal()
                return
            }
            
            DispatchQueue.main.async {
                alert.informativeText = "Your GitHub device code is \(userCode)"
                alert.addButton(withTitle: "Copy device code and open browser")
                alert.addButton(withTitle: "Cancel")

                let modalResult = alert.runModal()
                switch modalResult {
                case .alertFirstButtonReturn:
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(userCode, forType: .string)
                    let url = URL(string: verificationUri)!
                    NSWorkspace.shared.open(url)
                default:
                    return
                }
            }
        }
    }
    
    func quit() {
        print("quitting")
        exit(0)
    }
}

// define key for observing
extension UserDefaults {
    @objc dynamic var onlyShowFollows: Bool {
        get { bool(forKey: "onlyShowFollows") }
        set { setValue(newValue, forKey: "onlyShowFollows") }
    }
}
