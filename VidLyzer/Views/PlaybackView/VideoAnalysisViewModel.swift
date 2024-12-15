//
//  VideoAnalysisViewModel.swift
//  VidLyzer
//
//  Created by Shivansh Gaur on 14/12/24.
//

import Foundation
import AVFoundation

protocol VideoAnalysisDelegate: AnyObject {
    func didReceiveTranscriptionResponse(_ transcription: TranscriptionResponse)
    func didReceiveModerationResponse(_ moderationResult: ModerationResponse)
}

class VideoAnalysisViewModel {
    
    // Bindable properties
    var flaggedIssues: [OffensiveContent] = []
    var issuesDetected: Bool = false
    var issuesDescription: String = ""
    var transcribedText: String = ""
    var moderationResults: [ModerationResult] = []
    
    weak var delegate: VideoAnalysisDelegate?
    
    // Callbacks
    var onUpdate: (() -> Void)?
    var onError: ((String) -> Void)?
    
    // OpenAI API Key
    private let openAIKey: String
    
    init(apiKey: String) {
        self.openAIKey = apiKey
    }
    
    // MARK: - Call analyzeVideo with url from View Controller
    func analyzeVideo(url: URL) {
        /// Extracting Audio from Vidoe to reduce load of sending packets to server
        extractAudio(from: url) { [weak self] audioURL in
            guard let self = self, let audioURL = audioURL else {
                self?.onError?("Failed to extract audio from video.")
                return
            }
            
            // Transcribe audio with OpenAI Static API's
            self.transcribeAudio(audioURL: audioURL)
        }
    }
    
    // MARK: - OpenAI API to transcribe extracted audio
    private func transcribeAudio(audioURL: URL) {
        let url = URL(string: Constants.ServerUrl.openAIUrl(type: .transcriptions))!
        print("Transcription URL: \(Constants.ServerUrl.openAIUrl(type: .transcriptions))")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        let filename = audioURL.lastPathComponent
        let mimeType = "audio/m4a"
        
        // Append audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        if let audioData = try? Data(contentsOf: audioURL) {
            body.append(audioData)
        }
        body.append("\r\n".data(using: .utf8)!)
        
        // Append model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        
        // Append response format parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("verbose_json\r\n".data(using: .utf8)!)
        
        // Append optional parameters if needed
        // e.g., language detection, timestamps
        
        // Append timestamp granularities parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"timestamp_granularities[]\"\r\n\r\n".data(using: .utf8)!)
        body.append("word\r\n".data(using: .utf8)!)
        
        // Close the body
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // TODO: Show activity indicator
//        DispatchQueue.main.async {
//            self.showLoadingIndicator()
//        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            
            // TODO: Hide activity indicator
//            DispatchQueue.main.async {
//                self.hideLoadingIndicator()
//            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self?.onError?("Transcription Error: \(error.localizedDescription)")
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self?.onError?("Transcription Error: No data received from Server")
                }
                return
            }
//            print(String(data: data, encoding: .utf8) ?? "No readable data")
            do {
                let transcription = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
                self?.delegate?.didReceiveTranscriptionResponse(transcription)
                // Proceed with content moderation
                self?.moderateContent(text: transcription.text, words: transcription.words ?? [])
            } catch {
                DispatchQueue.main.async {
                    self?.onError?("Transcription Error: Failed to parse response.")
                }
                print("Decoding error: \(error)")
            }
        }.resume()
    }
    
    // MARK: - Moderations api to analyse speech
    private func moderateContent(text: String, words: [WordSegment]) {
        let url = URL(string: Constants.ServerUrl.openAIUrl(type: .moderations))!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "model": "omni-moderation-latest",
            "input": text
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])
        
        //TODO: Show activity indicator
//        DispatchQueue.main.async {
//            self.showLoadingIndicator()
//        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            
            // TODO: Hide Activity Indicator
//            DispatchQueue.main.async {
//                self.hideLoadingIndicator()
//            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self?.onError?("Moderation Error: \(error.localizedDescription)")
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self?.onError?("Moderation Error: No data received from the server")
                }
                return
            }
            
//            print(String(data: data, encoding: .utf8) ?? "No readable data")
            
            do {
                let moderation = try JSONDecoder().decode(ModerationResponse.self, from: data)
                self?.delegate?.didReceiveModerationResponse(moderation)
                
                // Process moderation results
                self?.processModerationResults(moderation.results, words: words)
                
            } catch {
                DispatchQueue.main.async {
                    self?.onError?("Moderation Error: Failed to parse response.")
                }
                print("Decoding error: \(error)")
            }
        }.resume()
    }
    
    private func processModerationResults(_ results: [ModerationResult], words: [WordSegment]) {
        guard let result = results.first else { return }
        
        if result.flagged {
            var flaggedIssues: [OffensiveContent] = []
            // Identify offensive words
            let offensiveWords = extractOffensiveWords(from: transcribedText, categories: result.categories)
            
            for word in offensiveWords {
                if let wordSegment = words.first(where: { $0.word.lowercased() == word.lowercased() }) {
                    let formattedTime = formatTime(seconds: wordSegment.start)
                    let offensiveContent = OffensiveContent(
                        type: "Offensive Word",
                        timestamp: formattedTime,
                        timestampSeconds: wordSegment.start,
                        description: word,
                        emoji: "🛑"
                    )
                    flaggedIssues.append(offensiveContent)
                }
            }
            
            // Detect pauses
            let pauses = detectPauses(from: words)
            flaggedIssues += pauses.map { pause in
                OffensiveContent(
                    type: "Pause",
                    timestamp: pause.timestamp,
                    timestampSeconds: pause.seconds,
                    description: "Unusual pause of \(pause.duration) seconds",
                    emoji: "⏸️"
                )
            }
            
            // Assess sentiment
            assessSentiment(from: transcribedText) { [weak self] sentiment in
                guard let self = self else { return }
                let sentimentEmoji: String
                switch sentiment.lowercased() {
                case "positive":
                    sentimentEmoji = "😊"
                case "negative":
                    sentimentEmoji = "😞"
                default:
                    sentimentEmoji = "😐"
                }
                
                let sentimentContent = OffensiveContent(
                    type: "Sentiment",
                    timestamp: "-",
                    timestampSeconds: 0,
                    description: sentiment,
                    emoji: sentimentEmoji
                )
                flaggedIssues.append(sentimentContent)
                
                // Update ViewModel
                self.flaggedIssues = flaggedIssues
                self.issuesDescription = "Issues Detected"
                DispatchQueue.main.async {
                    self.onUpdate?()
                }
            }
        } else {
            DispatchQueue.main.async {
                self.onError?("No offensive content detected.")
            }
        }
    }
    
    func formatTime(seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "00:00" }
        let hrs = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hrs > 0 {
            return String(format: "%02d:%02d:%02d", hrs, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }
    
    private func extractOffensiveWords(from text: String, categories: ModerationCategories) -> [String] {
        
        var offensiveWords: [String] = []
        
        // Define your offensive words dictionary
        let offensiveDictionary: [String: [String]] = [
            "hate": ["hateword1", "hateword2"],
            "harassment": ["fuck", "harassword2"],
            "selfHarm": ["suicide", "harmword2"]
            // Add other categories and words as needed
        ]
        
        for (category, words) in offensiveDictionary {
            switch category {
            case "hate":
                if categories.hate {
                    offensiveWords += words
                }
            case "harassment":
                if categories.harassment {
                    offensiveWords += words
                }
            case "selfHarm":
                if categories.selfHarm {
                    offensiveWords += words
                }
                // Handle other categories similarly
            default:
                break
            }
        }
        
        // Simple extraction: split text and filter
        let wordsInText = text.lowercased().split(separator: " ").map { String($0) }
        let detectedOffensiveWords = offensiveWords.filter { wordsInText.contains($0.lowercased()) }
        
        return detectedOffensiveWords
    }
    
    // Detect Pauses
    private func detectPauses(from words: [WordSegment]) -> [Pause] {
        let pauseThreshold: Double = 2.0 // 2 seconds
        var pauses: [Pause] = []
        
        guard words.count > 1 else { return pauses }
        
        for i in 1..<words.count {
            let previousWord = words[i - 1]
            let currentWord = words[i]
            let gap = currentWord.start - previousWord.end
            
            if gap >= pauseThreshold {
                let formattedTime = formatTime(seconds: previousWord.end)
                pauses.append(Pause(timestamp: formattedTime, duration: gap, seconds: previousWord.end))
            }
        }
        
        return pauses
    }
    
    // Pause Struct
    struct Pause {
        let timestamp: String
        let duration: Double
        let seconds: Double
    }
    
    private func assessSentiment(from text: String, completion: @escaping (String) -> Void) {
        let prompt = "Analyze the sentiment of the following text and categorize it as Positive, Negative, or Neutral.\n\nText:\n\"\(text)\""
        
        guard let url = URL(string: Constants.ServerUrl.openAIUrl(type: .completions)) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "model": "gpt-3.5-turbo", // Updated model
            "messages": [
                ["role": "system", "content": "You are a helpful assistant for sentiment analysis."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 10,
            "temperature": 0
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.onError?("Sentiment Analysis Error: \(error.localizedDescription)")
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.onError?("Sentiment Analysis Error: No data received.")
                }
                return
            }
            
            print(String(data: data, encoding: .utf8) ?? "No readable data")
            
            do {
                let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
                if let sentimentResult = chatResponse.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) {
                    completion(sentimentResult)
                } else {
                    completion("Neutral")
                }
            } catch {
                DispatchQueue.main.async {
                    self.onError?("Sentiment Analysis Error: Failed to parse response.")
                }
                print("Decoding error: \(error)")
            }
        }.resume()
    }
    
    // Retrieve Timestamp in Seconds from "MM:SS" Format
    func getTimestampSeconds(from timestamp: String) -> Double? {
        let components = timestamp.split(separator: ":").compactMap { Double($0) }
        guard components.count == 2 else { return nil }
        return components[0] * 60 + components[1]
    }
    
}


extension VideoAnalysisViewModel {
    
    /// Extracting Audio from Vidoe to reduce load of sending packets to server
    private func extractAudio(from videoURL: URL, completion: @escaping (URL?) -> Void) {
        let asset = AVAsset(url: videoURL)
        let composition = AVMutableComposition()
        
        guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
            completion(nil)
            return
        }
        
        let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        do {
            try compositionAudioTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: audioTrack, at: .zero)
        } catch {
            print("Error extracting audio: \(error)")
            completion(nil)
            return
        }
        
        // Export the audio to a temporary file
        let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("extractedAudio.m4a")
        // Remove existing file if any
        if FileManager.default.fileExists(atPath: exportURL.path) {
            try? FileManager.default.removeItem(at: exportURL)
        }
        
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            completion(nil)
            return
        }
        
        exporter.outputURL = exportURL
        exporter.outputFileType = .m4a
        exporter.exportAsynchronously {
            switch exporter.status {
            case .completed:
                completion(exportURL)
            default:
                print("Audio extraction failed: \(String(describing: exporter.error))")
                completion(nil)
            }
        }
    }
}
