//
//  ContentAnalysis.swift
//  VidLyzer
//
//  Created by Shivansh Gaur on 15/12/24.
//

import Foundation

class ContentAnalysis {
    
    let transcriptionResponse: TranscriptionResponse
    let moderationResults: [ModerationResult]
    
    init(transcriptionResponse: TranscriptionResponse,
         moderationResults: [ModerationResult]) {
        self.transcriptionResponse = transcriptionResponse
        self.moderationResults = moderationResults
    }
    
    func analyzeContent() -> String {
        let pauses = identifyUnusualPauses()
        let complianceFlags = detectComplianceViolations()
        let harmfulContent = detectHarmfulContent()
        let sentiment = assessSentiment()
        let summary = generateSummary(pauses: pauses, complianceFlags: complianceFlags, harmfulContent: harmfulContent, sentiment: sentiment)
        return summary
    }
    
    private func identifyUnusualPauses() -> [(time: Double, duration: Double)] {
        guard let words = transcriptionResponse.words else { return [] }
        var pauses: [(time: Double, duration: Double)] = []
        
        for i in 1..<words.count {
            let currentWordEnd = words[i - 1].end
            let nextWordStart = words[i].start
            let pauseDuration = nextWordStart - currentWordEnd
            
            if pauseDuration > 1.0 { // Threshold for unusual pause
                pauses.append((time: currentWordEnd, duration: pauseDuration))
            }
        }
        
        return pauses
    }
    
    private func detectComplianceViolations() -> [(word: String, time: Double)] {
        let disallowedWords = ["anchor", "implant", "stud"] // Example list
        guard let words = transcriptionResponse.words else { return [] }
        
        var violations: [(word: String, time: Double)] = []
        for segment in words {
            if disallowedWords.contains(segment.word.lowercased()) {
                violations.append((word: segment.word, time: segment.start))
            }
        }
        
        return violations
    }
    
    private func detectHarmfulContent() -> [(category: String, time: Double)] {
        var flaggedContent: [(category: String, time: Double)] = []
        
        for moderation in moderationResults {
            if moderation.flagged {
                if moderation.categories.hate {
                    flaggedContent.append((category: "Hate Speech", time: 0.0)) // Replace with actual timestamp if available
                }
                if moderation.categories.violence {
                    flaggedContent.append((category: "Violence", time: 0.0))
                }
                if moderation.categories.sexual {
                    flaggedContent.append((category: "Sexual Content", time: 0.0))
                }
                if moderation.categories.selfHarm {
                    flaggedContent.append((category: "Self-Harm", time: 0.0))
                }
            }
        }
        
        return flaggedContent
    }
    
    private func assessSentiment() -> String {
        let negativeCategories = moderationResults.filter { $0.flagged }
        let totalDuration = transcriptionResponse.duration ?? 1.0
        let density = Double(negativeCategories.count) / totalDuration
        
        if density > 0.1 {
            return "Negative"
        } else if density > 0.05 {
            return "Neutral"
        } else {
            return "Positive"
        }
    }
    
    private func generateSummary(pauses: [(time: Double, duration: Double)],
                                 complianceFlags: [(word: String, time: Double)],
                                 harmfulContent: [(category: String, time: Double)],
                                 sentiment: String) -> String {
        
        var summary = "Content Analysis Summary:\n\n"
        
        summary += "1. Detected Unusual Pauses:\n"
        if pauses.isEmpty {
            summary += "- None\n"
        } else {
            for pause in pauses {
                summary += "- Pause of \(pause.duration) seconds at \(formatTimestamp(pause.time))\n"
            }
        }
        
        summary += "\n2. Compliance Violations:\n"
        if complianceFlags.isEmpty {
            summary += "- None\n"
        } else {
            for violation in complianceFlags {
                summary += "- Violation: '\(violation.word)' at \(formatTimestamp(violation.time))\n"
            }
        }
        
        summary += "\n3. Harmful Content:\n"
        if harmfulContent.isEmpty {
            summary += "- None\n"
        } else {
            for content in harmfulContent {
                summary += "- \(content.category) at \(formatTimestamp(content.time))\n"
            }
        }
        
        summary += "\n4. Overall Sentiment:\n"
        summary += "- \(sentiment)\n"
        
        return summary
    }
    
    private func formatTimestamp(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
}
