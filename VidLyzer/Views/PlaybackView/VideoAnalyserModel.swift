//
//  VideoAnalyserModel.swift
//  VidLyzer
//
//  Created by Shivansh Gaur on 13/12/24.
//

import Foundation

// MARK: - Transcription Response Model
struct TranscriptionResponse: Decodable {
    let task: String
    let text: String
    let language: String?
    let duration: Double?
    let words: [WordSegment]?
}

struct WordSegment: Decodable {
    let word: String
    let start: Double
    let end: Double
}

struct OffensiveContent {
    let type: String
    let timestamp: String
    let timestampSeconds: Double
    let description: String
    let emoji: String
}


// MARK: - Moderation Response Model
struct ModerationResponse: Decodable {
    let results: [ModerationResult]
}

struct ModerationResult: Decodable {
    let flagged: Bool
    let categories: ModerationCategories
    let category_scores: ModerationCategoryScores
    // Later can add: category_applied_input_types
}

struct ModerationCategories: Decodable {
    
    /// List of flag type supported
    /// Source: https://platform.openai.com/docs/guides/moderation/overview?lang=curl
    
    let sexual: Bool
    let hate: Bool
    let harassment: Bool
    let selfHarm: Bool
    let violence: Bool
    let harassment_threatening: Bool
    let hate_threatening: Bool
    let illicit: Bool
    let illicit_violent: Bool
    let violence_graphic: Bool
    let sexual_minors: Bool
    let selfHarm_intent: Bool
    let selfHarm_instructions: Bool
    
    enum CodingKeys: String, CodingKey {
        case sexual, violence, hate, harassment, illicit
        case selfHarm = "self-harm"
        case harassment_threatening = "harassment/threatening"
        case hate_threatening = "hate/threatening"
        case illicit_violent = "illicit/violent"
        case violence_graphic = "violence/graphic"
        case sexual_minors = "sexual/minors"
        case selfHarm_intent = "self-harm/intent"
        case selfHarm_instructions = "self-harm/instructions"
    }
}

struct ModerationCategoryScores: Decodable {
    
    let sexual: Double
    let hate: Double
    let harassment: Double
    let selfHarm: Double
    let violence: Double
    let harassment_threatening: Double
    let hate_threatening: Double
    let illicit: Double
    let illicit_violent: Double
    let violence_graphic: Double
    let sexual_minors: Double
    let selfHarm_intent: Double
    let selfHarm_instructions: Double
    
    enum CodingKeys: String, CodingKey {
        case sexual, violence, hate, harassment, illicit
        case selfHarm = "self-harm"
        case harassment_threatening = "harassment/threatening"
        case hate_threatening = "hate/threatening"
        case illicit_violent = "illicit/violent"
        case violence_graphic = "violence/graphic"
        case sexual_minors = "sexual/minors"
        case selfHarm_intent = "self-harm/intent"
        case selfHarm_instructions = "self-harm/instructions"
    }
}


// MARK: - Chat Completion Response Model
struct ChatCompletionResponse: Decodable {
    let choices: [ChatChoice]
}

struct ChatChoice: Decodable {
    let message: ChatMessage
}

struct ChatMessage: Decodable {
    let role: String
    let content: String
}
