//
//  FakeNSURLSession.swift
//  Buzzword
//
//  Created by Chris Weber on 04.04.16.
//  Copyright © 2016 BFH. All rights reserved.
//

import Foundation

class FakeNSURLSession: NSURLSession {
    override func dataTaskWithRequest(request: NSURLRequest, completionHandler: (NSData?, NSURLResponse?, NSError?) -> Void) -> NSURLSessionDataTask {
        let dataTask = BuzzwordDataTask()
        dataTask.request = request
        dataTask.completionHandler = completionHandler
        
        return dataTask
    }
}

class BuzzwordDataTask: NSURLSessionDataTask {
    static var requestCount = 0
    var request: NSURLRequest!
    var completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)?
    
    override func resume() {
        
        BuzzwordDataTask.requestCount += 1
        
        if (BuzzwordDataTask.requestCount % 3 == 0) {
            // server error
            let response = NSHTTPURLResponse(URL: self.request!.URL!, statusCode: 500, HTTPVersion: nil, headerFields: nil)!
            let data = "Server Error".dataUsingEncoding(NSUTF8StringEncoding)
            self.completionHandler?(data, response, nil)
            return
        }
        
        if (BuzzwordDataTask.requestCount % 5 == 0) {
            // network error
            self.completionHandler?(nil, nil, NSError(domain: "NSURLErrorDomain", code: NSURLErrorNetworkConnectionLost, userInfo: nil))
            return
        }
        
        if self.request.URL?.absoluteString == "https://buzzword.com/buzzwords" {
            if self.request.HTTPMethod == "GET" {
                self.list()
            } else if (self.request.HTTPMethod == "POST") {
                do {
                    let uncastedBody = try NSJSONSerialization.JSONObjectWithData(self.request!.HTTPBody!, options:NSJSONReadingOptions(rawValue: 0))
                    if let castedBody = uncastedBody as? [String:String] {
                        self.create(castedBody)
                    }
                } catch {
                    let response = NSHTTPURLResponse(URL: self.request!.URL!, statusCode: 400, HTTPVersion: nil, headerFields: nil)!
                    let data = "Could not deserialize json".dataUsingEncoding(NSUTF8StringEncoding)
                    self.completionHandler?(data, response, nil)
                }
                
            }
        } else if self.request.URL!.absoluteString.hasPrefix("https://buzzword.com/buzzwords/") {
            if self.request.HTTPMethod == "PUT" {
                do {
                    let uncastedBody = try NSJSONSerialization.JSONObjectWithData(self.request!.HTTPBody!, options:NSJSONReadingOptions(rawValue: 0))
                    if let castedBody = uncastedBody as? [String:AnyObject] {
                        self.update(castedBody)
                    }
                } catch {
                    let response = NSHTTPURLResponse(URL: self.request!.URL!, statusCode: 400, HTTPVersion: nil, headerFields: nil)!
                    let data = "Could not deserialize json".dataUsingEncoding(NSUTF8StringEncoding)
                    self.completionHandler?(data, response, nil)
                }

            }
        } else {
            let response = NSHTTPURLResponse(URL: self.request!.URL!, statusCode: 404, HTTPVersion: nil, headerFields: nil)!
            let data = "Could not deserialize json".dataUsingEncoding(NSUTF8StringEncoding)
            self.completionHandler?(data, response, nil)
        }
    }
    
    func create(body:[String:String]) {
        let store = WebserviceStore()
        let buzzword = store.createBuzzword(body["name"]!)
        let response = NSHTTPURLResponse(URL: self.request!.URL!, statusCode: 201, HTTPVersion: nil, headerFields: nil)!
        let data = try! NSJSONSerialization.dataWithJSONObject(["id":buzzword.id, "name":buzzword.name, "count":buzzword.count], options:NSJSONWritingOptions(rawValue: 0))
        self.completionHandler!(data, response, nil)
    }
    
    func update(body:[String:AnyObject]) {
        let store = WebserviceStore()
        let buzzword = Buzzword(id:body["id"] as! Int , name: body["name"] as! String, count: body["count"] as! Int)
        store.saveBuzzword(buzzword)
        let response = NSHTTPURLResponse(URL: self.request!.URL!, statusCode: 204, HTTPVersion: nil, headerFields: nil)!
        self.completionHandler!(nil, response, nil)
    }
    
    func list() {
        let store = WebserviceStore()
        let buzzwords = store.allBuzzwords()
        var buzzwordResponse = [[String:AnyObject]]()
        for b in buzzwords {
            buzzwordResponse.append(["id":b.id, "name":b.name, "count":b.count])
        }
            
        let response = NSHTTPURLResponse(URL: self.request!.URL!, statusCode: 200, HTTPVersion: nil, headerFields: nil)!
        let data = try! NSJSONSerialization.dataWithJSONObject(buzzwordResponse, options:NSJSONWritingOptions(rawValue: 0))
        self.completionHandler!(data, response, nil)
    }
}
