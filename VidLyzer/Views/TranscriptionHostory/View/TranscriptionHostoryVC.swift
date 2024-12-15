//
//  TranscriptionHostoryVC.swift
//  VidLyzer
//
//  Created by Shivansh Gaur on 14/12/24.
//

import UIKit

struct Transcription {
    let emoji: String
    let transcriptionText: String
    let moderationCategory: String
    let timestampedWords: [String: String]
}

class TranscriptionHostoryVC: UIViewController {

    @IBOutlet weak var transcriptionHistoryList: UITableView!
    
    var transcriptions: [Transcription] = [
        Transcription(
            emoji: "🤬",
            transcriptionText: "Hate speech example line 1.\nHate speech example line 2.\nHate speech example line 3.",
            moderationCategory: "hate",
            timestampedWords: ["HateWord1": "00:23", "HateWord2": "01:45"]
        ),
        Transcription(
            emoji: "🔞",
            transcriptionText: "Sexual content example line 1.\nSexual content example line 2.\nSexual content example line 3.",
            moderationCategory: "sexual",
            timestampedWords: ["ExplicitWord": "02:10"]
        )
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        transcriptionHistoryList.dataSource = self
        transcriptionHistoryList.delegate = self
        
        // Register nib or custom cell
        transcriptionHistoryList.register(UINib(nibName: "TrancribedHistoryCell", bundle: nil), forCellReuseIdentifier: "TrancribedHistoryCell")
        
        // Add a cell to transcriptionHistoryList which show an emoji and 3 line of transcribe text.
        // it should be like ["emoji" the transcribed text in three lines..]
        // Emoji will be based on ModerationCategories: sexual, violence, hate, harassment, selfHarm which I will assign like in case of hate 🤬
        // On click of this page I will open bottom sheet which will have 3 segments
        // segment one: Transcription of Video
        // Segment two: sexual, violence, hate, harassment, selfHarm word used in video with time stamp eg. violence - "Fuck" at 02:32
    }
}

extension TranscriptionHostoryVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return transcriptions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "TrancribedHistoryCell", for: indexPath) as? TrancribedHistoryCell else {
            return UITableViewCell()
        }
        
        let transcription = transcriptions[indexPath.row]
        cell.emojiLabel.text = transcription.emoji
        cell.transcriptionLabel.text = transcription.transcriptionText
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedTranscription = transcriptions[indexPath.row]
        presentBottomSheet(for: selectedTranscription)
    }
}

// Bottom Sheet Presentation
extension TranscriptionHostoryVC {
    func presentBottomSheet(for transcription: Transcription) {
        let bottomSheetVC = BottomSheetViewController()
        bottomSheetVC.transcription = transcription
        present(bottomSheetVC, animated: true, completion: nil)
    }
}
