//
//  Config.swift
//  smartass
//
//  Created by Viet Le on 1/28/25.
//


import Foundation

enum Config {
    static var openAIApiKey: String {
        // First try to get from environment variable
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            return envKey
        }
        
        // Then try to get from Config.plist
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let apiKey = dict["OpenAIApiKey"] as? String {
            return apiKey
        }
        
        // For development only - you should never commit this fallback key
        #if DEBUG
        return "YOUR_DEVELOPMENT_KEY_HERE"
        #else
        fatalError("OpenAI API Key not found. Please set OPENAI_API_KEY environment variable or add it to Config.plist")
        #endif
    }
} 