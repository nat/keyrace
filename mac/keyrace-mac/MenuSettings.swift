//
//  MenuSettings.swift
//  keyrace-mac
//
//  Created by Jessie Frazelle on 2/16/21.
//

import Foundation
import SwiftUI

class MenuSettings : NSObject {
    static var onlyShowFollowsKey = "onlyShowFollows"
    
    static func setOnlyShowFollows(_ state: NSControl.StateValue?) {
        let defaults = UserDefaults.standard
        defaults.set(state?.rawValue, forKey: onlyShowFollowsKey)
    }
    
    static func getOnlyShowFollows() -> NSControl.StateValue {
        let defaults = UserDefaults.standard
        let state : Int? = defaults.integer(forKey: onlyShowFollowsKey)
        var typedState: NSControl.StateValue?
        if(state == nil) {
            typedState = NSControl.StateValue.off;
        } else {
            typedState = NSControl.StateValue.init(state!)
        }
        
        return typedState!;
    }
}
