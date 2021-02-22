//
//  UserDefaults.swift
//  keyrace-mac
//
//  Created by Jessie Frazelle on 2/21/21.
//

import Foundation

// Store data in user defaults.
// This allows us to more easily access it later.
extension UserDefaults {
    @objc dynamic var onlyShowFollows: Bool {
        get { bool(forKey: "onlyShowFollows") }
        set { setValue(newValue, forKey: "onlyShowFollows") }
    }
    
    @objc dynamic var githubToken: String {
        get { string(forKey: "githubToken") ?? "" }
        set { setValue(newValue, forKey: "githubToken") }
    }
    
    @objc dynamic var githubUsername: String {
        get { string(forKey: "githubUsername") ?? "" }
        set { setValue(newValue, forKey: "githubUsername") }
    }
    
    @objc dynamic var keyCount: Int {
        get { integer(forKey: "keyCount") }
        set { setValue(newValue, forKey: "keyCount") }
    }
    
    @objc dynamic var keyCountLastUpdated: String {
        get { string(forKey: "keyCountLastUpdated") ?? "" }
        set { setValue(newValue, forKey: "keyCountLastUpdated") }
    }
    
    @objc dynamic var minutes: [Int] {
        get { (object(forKey: "minutes") as? [Int]) ?? [Int](repeating:0, count:1440) }
        set { setValue(newValue, forKey: "minutes") }
    }
    
    @objc dynamic var keys: [Int] {
        get { (object(forKey: "keys") as? [Int]) ?? [Int](repeating:0, count:256) }
        set { setValue(newValue, forKey: "keys") }
    }
}
