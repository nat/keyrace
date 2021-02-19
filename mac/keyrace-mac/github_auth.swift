//
//  github_auth.swift
//  keyrace-mac
//
//  Created by Nat Friedman on 1/2/21.
//

import Foundation
import SwiftUI
import Cocoa

class GitHub {
    static let TOKEN_FILE = ".keyrace.ghtoken"
    var loggedIn : Bool = false
    var username : String?
    var token : String?
    
    init() {
        loadToken()
    }
    
    private func loadToken() {
        if self.token != nil {
            return
        }
        
        let filename = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(GitHub.TOKEN_FILE)
        self.token = try? String(contentsOf: filename, encoding: .utf8)
        getUserName() // FIXME: save/load username in a file to avoid this
        self.loggedIn = true
    }
    
    private func saveToken() {
        if token == nil {
            return
        }

        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(GitHub.TOKEN_FILE)
        
        do {
            try token!.write(to: path, atomically: true, encoding: String.Encoding.utf8)
            var attributes = [FileAttributeKey : Any]()
            attributes[.posixPermissions] = 0o600
            try FileManager.default.setAttributes(attributes, ofItemAtPath: path.path)

        } catch {
            NSLog("Could not save token to \(path.path)")
        }
    }
    
    func startDeviceAuth(clientId: String, scope: String, callback: @escaping () -> ()) -> (userCode: String, verificationUri: String){
        let url = URL(string: "https://github.com/login/device/code")!
        
        var request = URLRequest(url: url)
        let parameters: [String: Any] = ["client_id": clientId, "scope": scope]
        request.httpBody = parameters.percentEncoded()
        request.httpMethod = "POST"
        
        let (data,response,error) = URLSession.shared.performSynchronously(request: request)
        if let error = error {
            print("Error \(error.localizedDescription)")
        } else if let data = data, let response = response as? HTTPURLResponse, response.statusCode == 200 {
            let str = String(data: data, encoding: .utf8)
            let params = str?.getParams()
            let interval = Double(params?["interval"] ?? "15.0")!
            
            DispatchQueue.global(qos: .background).async {
                self.pollForAuth(interval: interval * 2, clientId: clientId, deviceCode: params!["device_code"]!, callback: callback)
            }

            return (params!["user_code"]!, params!["verification_uri"]!)
        }

        return ("", "")
    }
    
    func pollForAuth(interval: Double, clientId: String, deviceCode: String, callback: @escaping () -> ()) {
        var count = 0
        while (count < 20) {
            sleep(uint32(interval))
            let pollUrl = URL(string: "https://github.com/login/oauth/access_token")!
            var pollRequest = URLRequest(url: pollUrl)
            let pollParameters: [String:Any] = ["client_id": clientId, "device_code": deviceCode, "grant_type": "urn:ietf:params:oauth:grant-type:device_code"]
            pollRequest.httpBody = pollParameters.percentEncoded()
            pollRequest.httpMethod = "POST"
            
            let (data, response, error) = URLSession.shared.performSynchronously(request: pollRequest)
            if (error == nil), data != nil, let response = response as? HTTPURLResponse, response.statusCode == 200 {
                let str = String(data: data!, encoding: .utf8)
                let pollParams = str?.getParams()
                if (pollParams!["access_token"] != nil) {
                    self.token = pollParams!["access_token"]
                    self.loggedIn = true
                    self.saveToken()
                    self.getUserName()
                    DispatchQueue.main.async { callback() }
                    return
                }
            }
            count += 1
        }
    }
    
    func getUserName() {
        if token == nil {
            return
        }
        
        let url = URL(string: "https://api.github.com/user")!
        var req = URLRequest(url: url)
        req.addValue("token \(token!)", forHTTPHeaderField: "Authorization")
        req.httpMethod = "GET"
        let (data, response, error) = URLSession.shared.performSynchronously(request: req)
        if (error == nil), data != nil, let response = response as? HTTPURLResponse, response.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any] {
                if let login = json["login"] as? String {
                    username = login
                }
            }
        }
    }
}

extension URLSession {

    func performSynchronously(request: URLRequest) -> (data: Data?, response: URLResponse?, error: Error?) {
        let semaphore = DispatchSemaphore(value: 0)

        var data: Data?
        var response: URLResponse?
        var error: Error?

        let task = self.dataTask(with: request) {
            data = $0
            response = $1
            error = $2
            semaphore.signal()
        }

        task.resume()
        semaphore.wait()

        return (data, response, error)
    }
}

extension String {
    func getParams() -> [String: String] {
        var params = [String:String]()
        let items = self.split(separator: "&")
        for i in items {
            let kv = i.split(separator: "=")
            let key = kv[0].removingPercentEncoding
            let value = 1 < kv.count ? kv[1].removingPercentEncoding : ""
            if key != nil && value != nil {
                params[key!] = value!
            }
        }

        return params
    }
}

extension Dictionary {
    func percentEncoded() -> Data? {
        return map { key, value in
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            return escapedKey + "=" + escapedValue
        }
        .joined(separator: "&")
        .data(using: .utf8)
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="

        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        return allowed
    }()
}
