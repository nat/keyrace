// Created by Nat Friedman on 1/2/21.

import Accessibility
import Cocoa
import Combine
import Foundation
import SwiftUI

func formatCount(count: Int) -> NSAttributedString {
    var str = ""

    if (count == 0) {
        str = "Waiting for first keystroke..."
    } else if (count == 1) {
        str = "👍 First key!"
    } else {
        var pfx = ""
        switch (count) {
        case 1..<500:       pfx = "👍 "
        case 500..<1000:    pfx = "🏃 "
        case 1000..<5000:   pfx = "💨 "
        case 5000..<10000:  pfx = "🙌 "
        case 10000..<20000: pfx = "🚀 "
        case 20000..<30000: pfx = "🥳 "
        case 30000...40000: pfx = "🔥 "
        case 40000...60000: pfx = "🤯 "
        default:
            pfx = ""
        }

        var sfx = ""
        if (count < 100) {
            sfx = " today"
        }
        str = "\(pfx)\(count) keys\(sfx)"
    }
    
    // We use a monospaced font here so as the number changes the popover does not get jumpy.
    let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    let attributes = [NSAttributedString.Key.font: font]
    return NSAttributedString(string: str, attributes: attributes)
}

func myCGEventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    let keyTap = Unmanaged<KeyTap>.fromOpaque(refcon!).takeUnretainedValue()

    if [.keyDown].contains(type) {
        DispatchQueue.global(qos: .background).async {
            var char = UniChar()
            var length = 0
            event.keyboardGetUnicodeString(maxStringLength: 1, actualStringLength: &length, unicodeString: &char)
            keyTap.increment(char)
        }
        DispatchQueue.main.async {
            keyTap.appDelegate.statusBarItem.button?.attributedTitle = formatCount(count: keyTap.keycount)
        }
    }

    if [.tapDisabledByTimeout].contains(type) {
        keyTap.appDelegate.statusBarItem.button?.title = "Lost event tap!"
    }

    return Unmanaged.passRetained(event)
}

// This is an ObservableObject so that the UI can subscribe to updates in players,
// and we’ll use @Published to send updates whenever the player list changes.
class KeyTap: ObservableObject {
    var appDelegate : AppDelegate
    var lastDay = -1
    var lastMin = -1
    var timerRunning = false
    var keyTrapSetup = false
    var KEYRACE_HOST = "https://keyrace.app"
    
    // Load values from UserDefaults.
    @Published var keycount: Int = UserDefaults.standard.keyCount {
        didSet {
            // Update UserDefaults whenever our local value for keycount is updated.
            UserDefaults.standard.keyCount = keycount
        }
    }
    var minutes: [Int] = UserDefaults.standard.minutes {
        didSet {
            DispatchQueue.main.async {
                // Update UserDefaults whenever our local value for minutes is updated.
                UserDefaults.standard.minutes = self.minutes
            }
        }
    }
    var keys: [Int] = UserDefaults.standard.keys {
        didSet {
            // Update UserDefaults whenever our local value for keys is updated.
            UserDefaults.standard.keys = keys
        }
    }
    
    @Published var minutesChart: [Int] = []
    @Published var hoursChart: [Int] = []
    @Published var keysChart: [Int] = []
    @Published var symbolsChart: [Int] = []
    @Published var keyboardData: [[String]: Int] = [:]
    @Published var maxKeyboardCount: Int = 0
    
    @Published var players: [Player] = []
    @Published var onlyShowFollows: Bool = UserDefaults.standard.onlyShowFollows

    private var cancelable: AnyCancellable?
    init(_ appd: AppDelegate) {
        self.appDelegate = appd
        
        // Listen for changes to onlyShowFollows, we need to do this
        // because the SettingsView changes onlyShowFollows.
        cancelable = UserDefaults.standard.publisher(for: \.onlyShowFollows)
            .sink(receiveValue: { [weak self] newValue in
                guard let self = self else { return }
                if newValue != self.onlyShowFollows { // avoid cycling !!
                    self.onlyShowFollows = newValue
                    self.uploadCount()
                }
            })
    }

    func increment(_ keyCode: UInt16) {
        let date = Date()
        let calendar = Calendar.current

        // Reset to 0 at midnight
        let day = calendar.component(.day, from:date)
        if (lastDay != day) {
            lastDay = day
            DispatchQueue.main.async {
                self.keycount = 0
            }
            self.keys = [Int](repeating:0, count:256)

            //  Clears our minutes, leaving the last 20 minutes, and than deletes the rest after 20 minutes
            minutes.replaceSubrange(0..<1420, with: repeatElement(0, count: 1420))
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1200), execute: {
                self.minutes.replaceSubrange(1420..<1440, with: repeatElement(0, count: 20))
            })
        }

        DispatchQueue.main.async {
            self.keycount += 1
        }

        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        DispatchQueue.main.async {
            self.minutes[hour*60 + minute] += 1
            if self.keys.indices.contains(Int(keyCode)) {
                self.keys[Int(keyCode)] += 1
            } else {
                self.keys[Int(keyCode)] = 0
            }
        }

        // Upload every minute
        if (lastMin != minute) {
            lastMin = minute
            uploadCount()
            updateCharts()
        }

        saveCount()
    }

    func updateCharts() {
        // Update all the charts.
        updateMinutesChart()
        updateHoursChart()
        updateKeyboardData()
        updateKeysChart()
        updateSymbolsChart()
    }
    
    func updateMinutesChart() {
        // Return the last 20 minutes minutely
        let date = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let min = calendar.component(.minute, from: date)
        let currMin = hour*60 + min

        var mins : [Int] = []
        for i in (0...20).reversed() {
            currMin - i > 0 ? mins.append(minutes[currMin - i]): mins.append(minutes[1440 + i - (20 - currMin)])
        }
        DispatchQueue.main.async {
            self.minutesChart = mins
        }
    }

    func updateHoursChart() {
        var hours = [Int](repeating: 0, count: 24)

        for i in 0..<minutes.count {
            hours[i/60] += minutes[i]
        }

        DispatchQueue.main.async {
            self.hoursChart = hours
        }
    }

    func updateKeysChart() {
        // Return key press counts for the lowercase alphabet
        DispatchQueue.main.async {
            self.keysChart = Array(self.keys[97...97+25])
        }
    }

    func updateSymbolsChart() {
        // Return key press counts for the the numbers
        DispatchQueue.main.async {
            self.symbolsChart = Array(self.keys[33...57])
        }
    }
    
    func updateKeyboardData() {
        // Iterate over all the keys and count for the keyboard layout.
        DispatchQueue.main.async {
            for row in ROWS {
                for char in row {
                    // Update the value in our keyboardData dictionary.
                    self.keyboardData.updateValue(char.getCount(self.keys), forKey: char)
                }
            }
            
            self.maxKeyboardCount = self.keyboardData.values.max() ?? 0
        }
    }

    func uploadKeycount() {
        if UserDefaults.standard.githubToken.isEmpty {
            // Token is empty, return early.
            return
        }

        var url = URLComponents(string: "\(KEYRACE_HOST)/count")!
        url.queryItems = [
            URLQueryItem(name: "count", value: "\(keycount)")
        ]
        // Add the query to the URL if we are only supposed to show people they follow.
        if onlyShowFollows {
            url.queryItems?.append(URLQueryItem(name: "only_follows", value: "1"))
        }

        var request = URLRequest(url: url.url!)
        request.addValue("Bearer \(UserDefaults.standard.githubToken)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,                            // is there data
                let response = response as? HTTPURLResponse,  // is there HTTP response
                (200 ..< 300) ~= response.statusCode,         // is statusCode 2XX
                error == nil else {                           // was there no error, otherwise ...
                    print("Error uploading count \(error!)")
                    return
            }

            // Parse the JSON data for the leaderboard.
            let decoder = JSONDecoder()
            if let leaderboard = try? decoder.decode([Player].self, from: data) {
                DispatchQueue.main.sync {
                    // Set the players in Leaderboard, so we can auto update the UI.
                    self.players = leaderboard
                }
            }
        }
        task.resume()
    }

    func setupKeyTap() {
        if (keyTrapSetup) {
            return
        }

        loadCount()

        let eventMask = (1 << CGEventType.keyDown.rawValue)
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                              place: .headInsertEventTap,
                                              options: .defaultTap,
                                              eventsOfInterest: CGEventMask(eventMask),
                                              callback: myCGEventCallback,
                                              userInfo: refcon) else {
            NSLog("failed to create event tap; quitting")
            exit(1)
        }
        keyTrapSetup = true

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        appDelegate.statusBarItem.button?.attributedTitle = formatCount(count: keycount)

        uploadCount()
        updateCharts()
    }

    func uploadCount () {
        uploadKeycount()
    }

    func saveCount() {
        // Save the keycount to UserDefaults.
        let now = Date()
        UserDefaults.standard.keyCountLastUpdated = now
    }

    func loadCount() {
        // Get today's date info.
        let date = Date()
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from:date)

        // Set the count back to zero if the UserDefault for keyCountLastUpdated is not from today.
        // Get the date the keycount was last updated.
        let keyCountLastUpdated = UserDefaults.standard.keyCountLastUpdated
        lastDay = calendar.component(.day, from: keyCountLastUpdated)
        let lastMonth = calendar.component(.month, from: keyCountLastUpdated)
        
        if (lastDay != day || lastMonth != month) {
            // Reset the keycount back to 0.
            // In the case of success, it would have already loaded from UserDefaults.
            keycount = 0
            // Set the minutes back to 0.
            minutes = [Int](repeating:0, count:1440)
            // Set the keys back to 0.
            keys = [Int](repeating:0, count:256)
        }
    }

    func getAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
        var isAppTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary?)
        if (isAppTrusted) {
            self.setupKeyTap()
            return
        }

        // Wait for the user to give us permission
        if (timerRunning) { return }
        self.timerRunning = true
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: false]
            isAppTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary?)
            if (isAppTrusted) {
                self.setupKeyTap()
                timer.invalidate()
                self.timerRunning = false
            }
        }
    }
}
