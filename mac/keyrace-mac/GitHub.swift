//
//  github_auth.swift
//  keyrace-mac
//
//  Created by Nat Friedman on 1/2/21.
//
import Cocoa
import Combine
import Foundation
import SwiftUI

class GitHub: ObservableObject {
    @Published var loggedIn : Bool = false
    @Published var username: String = UserDefaults.standard.githubUsername {
        didSet {
            // Update UserDefaults whenever our local value for username is updated.
            UserDefaults.standard.githubUsername = username
        }
    }
    @Published var token: String = UserDefaults.standard.githubToken {
        didSet {
            // Update UserDefaults whenever our local value for token is updated.
            UserDefaults.standard.githubToken = token
        }
    }

    private var cancelableUsername: AnyCancellable?
    private var cancelableToken: AnyCancellable?
    init() {
        // Listen for changes to githubUsername, we need to do this
        // because the SettingsView changes githubUsername on logout to be empty.
        cancelableUsername = UserDefaults.standard.publisher(for: \.githubUsername)
            .sink(receiveValue: { [weak self] newValue in
                guard let self = self else { return }
                if newValue != self.username { // avoid cycling !!
                    self.username = newValue
                }
            })
        
        // Listen for changes to githubToken, we need to do this
        // because the SettingsView changes githubToken on logout to be empty.
        cancelableToken = UserDefaults.standard.publisher(for: \.githubToken)
            .sink(receiveValue: { [weak self] newValue in
                guard let self = self else { return }
                if newValue != self.token { // avoid cycling !!
                    self.token = newValue
                }
            })
        
        if self.username.isEmpty && !self.token.isEmpty {
            // We have a token but not a username, let's get the username.
            getUserName()
        }
    }
    
    func startDeviceAuth(clientId: String, scope: String) -> (userCode: String, verificationUri: String){
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
                self.pollForAuth(interval: interval * 2, clientId: clientId, deviceCode: params!["device_code"]!)
            }

            return (params!["user_code"]!, params!["verification_uri"]!)
        }

        return ("", "")
    }
    
    func pollForAuth(interval: Double, clientId: String, deviceCode: String) {
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
                    DispatchQueue.main.async {
                        self.token = pollParams!["access_token"] ?? ""
                        self.loggedIn = true
                        self.getUserName()
                    }
                    return
                }
            }
            count += 1
        }
    }
    
    func getUserName() {
        if token.isEmpty {
            // If we have an empty token, return early.
            return
        }
        
        let url = URL(string: "https://api.github.com/user")!
        var req = URLRequest(url: url)
        req.addValue("token \(token)", forHTTPHeaderField: "Authorization")
        req.httpMethod = "GET"
        let (data, response, error) = URLSession.shared.performSynchronously(request: req)
        if (error == nil), data != nil, let response = response as? HTTPURLResponse, response.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any] {
                if let login = json["login"] as? String {
                    DispatchQueue.main.async {
                        // Set the username.
                        self.username = login
                    }
                }
            }
        } else if let response = response as? HTTPURLResponse, response.statusCode == 401 {
            // Bad credentials, therefore user needs to re-authenticate, so we can set the
            // token back to an empty string.
            self.token = ""
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
