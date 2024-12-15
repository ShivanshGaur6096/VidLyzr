//
//  Constants.swift
//  VidLyzer
//
//  Created by Shivansh Gaur on 14/12/24.
//

import Foundation

enum OpenAIUrlType: String {
    case transcriptions = "/audio/transcriptions"
    case moderations = "/moderations"
    case completions = "/chat/completions"
}

struct Constants {
    // MARK: ENTER_YOUR_OPENAI_API_KEY here
    static let openAIAPIKey = ""
    
    struct ServerUrl {
        static func openAIUrl(type: OpenAIUrlType) -> String {
            var url = "https://api.openai.com/v1"
            url += type.rawValue
            return url
        }
    }
}
