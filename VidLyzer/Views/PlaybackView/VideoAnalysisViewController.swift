//
//  VideoAnalysisViewController.swift
//  VidLyzer
//
//  Created by Shivansh Gaur on 14/12/24.
//

import UIKit
import AVFoundation
import AVKit

class VideoAnalysisViewController: UIViewController, VideoAnalysisDelegate {
    
    @IBOutlet weak var videoPlaybackLabel: UILabel!
    @IBOutlet weak var playerViewControllerContainer: UIView! // where we display uploaded/recorded video
    @IBOutlet weak var durationOfVideo: UILabel! // How to Display the duration of Video while presenting it on playerViewControllerContainer?
    @IBOutlet weak var videoAnalysisLabel: UILabel!
    @IBOutlet weak var analysisSummaryList: UITableView! // Should have different type of cell, 1. which show transcription of video in 3 line, on click of it I show bottom sheet with summary text, 2. a cell with two lable where I wan to display Entries for each compliance violation with type, description, and timestamp. 3. reuse cell 2 Use emojis or colored labels to represent sentiment (e.g., 😊 for positive, 😞 for negative).
    @IBOutlet weak var bottomButtonView: UIView!
    @IBOutlet weak var buttonStack: UIStackView!
    @IBOutlet weak var reuplaodVideoButton: UIButton! // Reupload pop back to home screen
    @IBOutlet weak var saveAnalysisButton: UIButton! // This will save analysis data in core data
    
    private var playerViewController: AVPlayerViewController?
    private var viewModel: VideoAnalysisViewModel!
    
    var transcriptionResponse: TranscriptionResponse?
    var moderationResults: [ModerationResult]?
    
    var videoURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Video Analysis"
        
        guard let videoURL = videoURL else {
            showAlert(title: "Error", message: "No video URL provided.")
            return
        }
        
        // Initialize ViewModel with your OpenAI API Key
        viewModel = VideoAnalysisViewModel(apiKey: Constants.openAIAPIKey)
        
        // Bind ViewModel callbacks
        viewModel.onUpdate = { [weak self] in
            self?.updateUI()
        }
        
        viewModel.onError = { [weak self] errorMessage in
            self?.showAlert(title: "Error", message: errorMessage)
        }
        viewModel.delegate = self

        // Table View Setup
        analysisSummaryList.delegate = self
        analysisSummaryList.dataSource = self
        analysisSummaryList.register(UINib(nibName: "TrancribedHistoryCell", bundle: nil), forCellReuseIdentifier: "TrancribedHistoryCell")
        analysisSummaryList.separatorStyle = .none
        analysisSummaryList.allowsSelection = true
        
        // Analyze video
        viewModel.analyzeVideo(url: videoURL)
        
        // Display video
        displayVideo(url: videoURL)
        
        viewDidLayoutSubviews()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let viewsToRound = [playerViewControllerContainer, analysisSummaryList, bottomButtonView, buttonStack]
        viewsToRound.forEach {
            $0?.layer.cornerRadius = 10
            $0?.layer.masksToBounds = true
        }
    }
    
    func didReceiveTranscriptionResponse(_ transcription: TranscriptionResponse) {
        self.transcriptionResponse = transcription
        viewModel.transcribedText = transcription.text
    }
    
    func didReceiveModerationResponse(_ moderationResult: ModerationResponse) {
        self.moderationResults = moderationResult.results
        viewModel.moderationResults = moderationResult.results
    }
    
    func updateUI() {
        // Update video duration
        if let player = playerViewController?.player,
           let currentItem = player.currentItem {
            let duration = CMTimeGetSeconds(currentItem.asset.duration)
            durationOfVideo.text = "Duration: \(formatTime(seconds: duration))"
        }
        
        // Update Transcription TextView with highlighted offensive words
//        if let transcribedText = viewModel.transcribedText {
//            transcriptionTextView.attributedText = highlightOffensiveWords(in: transcribedText)
//        }
        
//        let issuesText = viewModel.issuesDescription
//        let offensiveWords = viewModel.flaggedIssues.map { $0.description }.joined(separator: ", ")
//        let message = "Issues Detected: \(issuesText)\nOffensive Words: \(offensiveWords)"
//        showAlert(title: "Content Flags", message: message)
        
        analysisSummaryList.reloadData()
    }
    
    @IBAction func reuploadAction(_ sender: UIButton) {
        print("Re-Upload Video Tapped")
        navigationController?.popToRootViewController(animated: true)
    }
    
    @IBAction func saveVideoAnalysis(_ sender: UIButton) {
        print("Save Video Analysis Tapped")
        playVideo(fromTime: 0.2)
    }
}

extension VideoAnalysisViewController {
    
    func handleVideo(url: URL) {
        // Check if the URL can be accessed as a security-scoped resource
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Validate the file URL
        guard FileManager.default.fileExists(atPath: url.path) else {
            showAlert(title: "Error", message: "The video file could not be found.")
            return
        }
        
        // Load the video asset
        let asset = AVURLAsset(url: url)
        let audioTracks = asset.tracks(withMediaType: .audio)
        if audioTracks.isEmpty {
            showAlert(title: "Error", message: "The video has no audio.")
        } else {
            // Dispatch video display on the main thread
            DispatchQueue.main.async {
                self.displayVideo(url: url)
            }
        }
    }
    
    func displayVideo(url: URL) {
        let player = AVPlayer(url: url)
        playerViewController = AVPlayerViewController()
        playerViewController?.player = player
        
        guard let playerVC = playerViewController else { return }
        addChild(playerVC)
        playerVC.view.frame = playerViewControllerContainer.bounds
        playerViewControllerContainer.addSubview(playerVC.view)
        playerVC.didMove(toParent: self)
        player.play()
    }
    
    func playVideo(fromTime time: Double) {
        guard let player = playerViewController?.player,
              let duration = player.currentItem?.duration else {
            showAlert(title: "Error", message: "No video loaded.")
            return
        }
        
        let totalDuration = CMTimeGetSeconds(duration)
        
        guard time >= 0, time <= totalDuration else {
            showAlert(title: "Invalid Timestamp", message: "Enter a time between 0 and \(totalDuration) seconds.")
            return
        }
        let targetTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            player.play()
        }
    }
}

extension VideoAnalysisViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3  // Transcription Preview, Compliance Violations, Sentiment
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1 // Transcription Preview
        case 1:
            return viewModel.flaggedIssues.filter { $0.type != "Sentiment" }.count // Compliance Violations and Pauses
        case 2:
            return viewModel.flaggedIssues.filter { $0.type == "Sentiment" }.count // Sentiment
        default:
            return 0
        }
    }
    
    // Section Headers
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Transcription Preview"
        case 1:
            return "Flagged Issues"
        case 2:
            return "Sentiment Analysis"
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch indexPath.section {
        case 0:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "TruncatedCell")
            cell.textLabel?.numberOfLines = 3
            cell.textLabel?.lineBreakMode = .byTruncatingTail
            cell.textLabel?.text = "Transcription: \n" + (transcriptionResponse?.text ?? "Empty Transcription")
            return cell
            
        case 1:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "TrancribedHistoryCell", for: indexPath) as? TrancribedHistoryCell else {
                return UITableViewCell()
            }
            let violations = viewModel.flaggedIssues.filter { $0.type != "Sentiment" }
            let violation = violations[indexPath.row]
            cell.emojiLabel.text = violation.type
//            cell.descriptionLabel.text = violation.description
            cell.transcriptionLabel.text = violation.timestamp
            
            // Configure typeContainerView based on type
            switch violation.type {
            case "Offensive Word":
                cell.contentView.backgroundColor = UIColor.systemRed
                cell.emojiLabel.text = "🛑"
            case "Pause":
                cell.contentView.backgroundColor = UIColor.systemOrange
                cell.emojiLabel.text = "⏸️"
            default:
                cell.contentView.backgroundColor = UIColor.systemGray
                cell.emojiLabel.text = "❓"
            }
            
            return cell
            
        case 2:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "TrancribedHistoryCell", for: indexPath) as? TrancribedHistoryCell else {
                return UITableViewCell()
            }
            let sentiments = viewModel.flaggedIssues.filter { $0.type == "Sentiment" }
            let sentiment = sentiments[indexPath.row]
            cell.transcriptionLabel.text = sentiment.description
            cell.emojiLabel.text = sentiment.emoji
            
            // Configure sentiment label based on sentiment type
            switch sentiment.description.lowercased() {
            case "positive":
                cell.transcriptionLabel.textColor = UIColor.systemGreen
                cell.emojiLabel.text = "😊"
            case "negative":
                cell.transcriptionLabel.textColor = UIColor.systemRed
                cell.emojiLabel.text = "😞"
            case "neutral":
                cell.transcriptionLabel.textColor = UIColor.systemGray
                cell.emojiLabel.text = "😐"
            default:
                cell.transcriptionLabel.textColor = UIColor.systemGray
                cell.emojiLabel.text = "❓"
            }
            
            return cell
            
        default:
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            // Transcription Preview - Show full transcription in bottom sheet
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            guard let bottomSheetVC = storyboard.instantiateViewController(withIdentifier: "BottomSheetVC") as? BottomSheetVC else {
                showAlert(title: "Error", message: "Could not navigate to the BottomSheetVC")
                return
            }
            
//            guard let transcriptionResponse, let moderationResults else { return }
//            let analyzer = ContentAnalysis(transcriptionResponse: transcriptionResponse, moderationResults: moderationResults)
//            let analysisSummary = analyzer.analyzeContent()
//            bottomSheetVC.customText = analysisSummary
            
            bottomSheetVC.customText = viewModel.transcribedText
            bottomSheetVC.modalPresentationStyle = .pageSheet
            if let sheet = bottomSheetVC.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
            }
            present(bottomSheetVC, animated: true)
            
        case 1:
            // Compliance Violation or Pause - Navigate to timestamp
            let violations = viewModel.flaggedIssues.filter { $0.type != "Sentiment" }
            let violation = violations[indexPath.row]
            if let timeInSeconds = viewModel.getTimestampSeconds(from: violation.timestamp) {
                playVideo(fromTime: timeInSeconds)
            }
            
        case 2:
            // Sentiment Cell - No action needed
            break
            
        default:
            break
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func parseTimestamp(_ timestamp: String) -> Double? {
        let components = timestamp.split(separator: ":").compactMap { Double($0) }
        guard components.count == 2 else { return nil }
        return components[0] * 60 + components[1]
    }
}

extension VideoAnalysisViewController {
    func showAlert(title: String, message: String) {
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alertVC, animated: true, completion: nil)
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
    
    func highlightOffensiveWords(in text: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let offensiveWords = viewModel.flaggedIssues.filter { $0.type == "Offensive Word" }.map { $0.description.lowercased() }
        
        for word in offensiveWords {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: attributedString.string.utf16.count)
                for match in regex.matches(in: attributedString.string, options: [], range: range) {
                    attributedString.addAttribute(.backgroundColor, value: UIColor.red.withAlphaComponent(0.3), range: match.range)
                }
            }
        }
        
        return attributedString
    }
}
