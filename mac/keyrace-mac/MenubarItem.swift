//
//  MenubarItem.swift
//  keyrace-mac
//
//  Created by Nat Friedman on 1/3/21.
//

import Foundation
import Cocoa
import SwiftUI
import Charts

class ChartValueFormatter: NSObject, IValueFormatter {

    func stringForValue(_ value: Double, entry: ChartDataEntry, dataSetIndex: Int, viewPortHandler: ViewPortHandler?) -> String {
        if value == 0.0 {
            return ""
        }

        return String(Int(value))
    }
}

class TypingChart: BarChartView {
    
    func NewData(_ typingCount: [Int]) {
        
        let yse1 = typingCount.enumerated().map { x, y in return BarChartDataEntry(x: Double(x), y: Double(y)) }

        let data = BarChartData()
        let ds1 = BarChartDataSet(entries: yse1, label: "Hello")
        ds1.colors = [NSUIColor.init(srgbRed: 255.0/255.0, green: 255.0/255.0, blue: 0.0/255.0, alpha: 1.0)]
        data.addDataSet(ds1)
        data.barWidth = Double(0.5)
        data.setDrawValues(true)
        let valueFormatter = ChartValueFormatter()
        data.setValueFormatter(valueFormatter)
        
        self.data = data
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let xArray = Array(1..<24)
        let ys1 = xArray.map { x in return abs(sin(Double(x) / 2.0 / 3.141 * 1.5)) }
        
        let yse1 = ys1.enumerated().map { x, y in return BarChartDataEntry(x: Double(x), y: y) }

        let data = BarChartData()
        let ds1 = BarChartDataSet(entries: yse1, label: "Hello")
        ds1.colors = [NSUIColor.red]
        data.addDataSet(ds1)
        data.barWidth = Double(0.5)
        
        self.data = data
        
        self.legend.enabled = false
        self.leftAxis.drawGridLinesEnabled = false
        self.leftAxis.drawAxisLineEnabled = false
        self.leftAxis.drawLabelsEnabled = false
        self.rightAxis.drawGridLinesEnabled = false
        self.rightAxis.drawAxisLineEnabled = false
        self.rightAxis.drawLabelsEnabled = false
        self.xAxis.drawGridLinesEnabled = false
        self.xAxis.drawAxisLineEnabled = false
        self.xAxis.drawLabelsEnabled = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

class MenubarItem : NSObject {
    private var settingsMenuItem : NSMenuItem
    private var settingsSubMenu : NSMenu
    private var onlyShowFollows : NSMenuItem
    
    private var loginMenuItem : NSMenuItem
    private var quitMenuItem : NSMenuItem
    private var barChartItem : NSMenuItem
    private var leaderboardItem : NSMenuItem
    
    var gh : GitHub? {
        didSet {
            if gh!.loggedIn {
                loggedIn()
            }
        }
    }
    
    var keyTap : KeyTap?

    var statusBarItem : NSStatusItem = {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        return item
    }()

    let statusBarMenu = NSMenu(title: "foo")

    init(title: String) {
        settingsMenuItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        settingsSubMenu = NSMenu.init(title: "Settings")
        settingsMenuItem.submenu = settingsSubMenu
        onlyShowFollows = NSMenuItem(title: "Only show users I follow", action: #selector(onlyShowUsersIFollow), keyEquivalent: "")
        
        loginMenuItem = NSMenuItem(title: "Login with GitHub", action: #selector(login), keyEquivalent: "")
        quitMenuItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "")
        barChartItem = NSMenuItem()
        leaderboardItem = NSMenuItem()

        super.init()

        statusBarItem.button?.title = title

        let barChart = TypingChart(frame: CGRect(x: 0, y: 0, width: 350, height: 100))
        barChartItem.view = barChart

        let leaderboard = NSTextView(frame: CGRect(x: 0, y: 0, width: 350, height: 200))
        leaderboard.string = ""
        leaderboard.font = NSFont(name:"Helvetica Bold", size:12)
        leaderboardItem.view = leaderboard
        
        quitMenuItem.target = self
        loginMenuItem.target = self
        
        settingsMenuItem.target = self
        onlyShowFollows.target = self
        settingsSubMenu.addItem(onlyShowFollows)

        
        statusBarMenu.addItem(barChartItem)
        statusBarMenu.addItem(leaderboardItem)
        statusBarMenu.addItem(settingsMenuItem)
        statusBarMenu.addItem(loginMenuItem)
        statusBarMenu.addItem(quitMenuItem)
        statusBarItem.menu = statusBarMenu
        
        statusBarMenu.delegate = self
    }
    
    func loggedIn() {
        if gh?.username != nil {
            loginMenuItem.title = "Logged in as @" + gh!.username!
            loginMenuItem.isEnabled = false
            loginMenuItem.target = nil
        }
    }
    
    @objc func login() {
        if gh == nil {
            return
        }
        
        if gh!.token != nil {
            gh!.getUserName()
            loggedIn()
            return
        }

        let alert = NSAlert()
        alert.messageText = "Login with GitHub"

        DispatchQueue.global(qos: .background).async {
            let (userCode, verificationUri) = self.gh!.startDeviceAuth(clientId: "a945f87ad537bfddb109", scope: "", callback: self.loggedIn)
            
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
    
    @objc func onlyShowUsersIFollow() {
        // Toggle the state.
        if (self.onlyShowFollows.state == NSControl.StateValue.off) {
            // Set it to be on
            self.onlyShowFollows.state = NSControl.StateValue.on
        } else {
            self.onlyShowFollows.state = NSControl.StateValue.off
        }
    
        // Save the setting.
        MenuSettings.setOnlyShowFollows(self.onlyShowFollows.state)
        // Update the leaderboard.
        self.keyTap?.uploadCount()
    }

    @objc func quit() {
        print("quitting")
        exit(0)
    }
}

extension MenubarItem : NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Update the bar chart
        (self.barChartItem.view as? TypingChart)?.NewData((keyTap?.getChart())!)
        (self.leaderboardItem.view as? NSTextView)?.string = (keyTap?.getLeaderboardText())!
        
        self.onlyShowFollows.state = MenuSettings.getOnlyShowFollows()
        
        self.leaderboardItem.isHidden = true // FIXME why doesn't this work?
    }
}
