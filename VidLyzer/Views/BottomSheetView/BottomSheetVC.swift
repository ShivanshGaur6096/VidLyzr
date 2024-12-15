//
//  BottomSheetVC.swift
//  VidLyzer
//
//  Created by Shivansh Gaur on 15/12/24.
//

import UIKit

class BottomSheetVC: UIViewController {

    @IBOutlet weak var pageTitle: UILabel!
    @IBOutlet weak var textView: UITextView!
    
    // Add a property to hold text content
    var customText: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Assign the custom text to the textView
        textView.text = customText
        textView.isEditable = false
        textView.font = UIFont.systemFont(ofSize: 16)
    }
}
