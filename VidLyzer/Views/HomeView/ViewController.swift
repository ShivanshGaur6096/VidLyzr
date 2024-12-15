//
//  ViewController.swift
//  VidLyzer
//
//  Created by Shivansh Gaur on 13/12/24.
//

import UIKit
import PhotosUI
import Photos

class ViewController: UIViewController {
    
    @IBOutlet weak var welcomeLabel: UILabel!
    @IBOutlet weak var processVideoButton: UIButton!
    @IBOutlet weak var usageTipsView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Initial Setup
        usageTipsView.layer.cornerRadius = 10
        usageTipsView.layer.masksToBounds = true
    }
    

    @IBAction func processVideoButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "Select Video Option", message: "Choose to record a new video or upload an existing one.", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Record Video", style: .default, handler: { _ in
            self.requestCameraPermission { granted in
                if granted {
                    self.presentVideoRecorder()
                } else {
                    self.showAlert(title: "Permission Denied", message: "Please allow access to the Camera in Settings.")
                }
            }
        }))
        
        alert.addAction(UIAlertAction(title: "Upload Video", style: .default, handler: { _ in
            self.requestPhotoLibraryPermission { granted in
                if granted {
                    self.presentVideoUploader()
                } else {
                    self.showAlert(title: "Permission Denied", message: "Please allow access to the Photo Library in Settings.")
                }
            }
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        // For iPad support
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = sender
            popoverController.sourceRect = sender.bounds
        }
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func navigateToVideoAnalysisScreen(with videoURL: URL) {
        // Instantiate VideoAnalysisViewController
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let analysisVC = storyboard.instantiateViewController(withIdentifier: "VideoAnalysisViewController") as? VideoAnalysisViewController else {
            showAlert(title: "Error", message: "Could not navigate to the analysis screen.")
            return
        }
        
        // Pass the video URL
        analysisVC.videoURL = videoURL
        
        // Navigate
        navigationController?.pushViewController(analysisVC, animated: true)
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func presentVideoRecorder() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showAlert(title: "Camera Unavailable", message: "This device has no camera.")
            return
        }
        
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        picker.mediaTypes = ["public.movie"]
        picker.videoMaximumDuration = 60.0 // 1 minute max
        picker.videoQuality = .typeHigh
        picker.allowsEditing = false
        self.present(picker, animated: true, completion: nil)
    }
    
    // UIImagePickerControllerDelegate Methods
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let mediaURL = info[.mediaURL] as? URL else { return }
        
        // Check file size
        do {
            let resources = try mediaURL.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = resources.fileSize {
                let fileSizeMB = Double(fileSize) / (1024.0 * 1024.0)
                if fileSizeMB > 25.0 {
                    showAlert(title: "File Too Large", message: "Please select a video smaller than 25 MB.")
                    return
                }
            }
        } catch {
            print("Error retrieving file size: \(error)")
            showAlert(title: "Error", message: "Could not process the video.")
            return
        }
        
        navigateToVideoAnalysisScreen(with: mediaURL)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

extension ViewController: PHPickerViewControllerDelegate {
    
    func presentVideoUploader() {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        self.present(picker, animated: true, completion: nil)
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        guard let provider = results.first?.itemProvider,
              provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else { return }
        
        provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                }
                return
            }
            
            guard let url = url else {
                DispatchQueue.main.async {
                    self?.showAlert(title: "Error", message: "Invalid video URL.")
                }
                return
            }
            
            // Ensure the file is accessible
            guard FileManager.default.fileExists(atPath: url.path) else {
                DispatchQueue.main.async {
                    self?.showAlert(title: "Error", message: "The selected video file could not be found.")
                }
                return
            }
            
            // Copy the file to a temporary location
            let tempDir = FileManager.default.temporaryDirectory
            let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)
            do {
                
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                try FileManager.default.copyItem(at: url, to: tempURL)
                
                // Check file size
                let resources = try tempURL.resourceValues(forKeys: [.fileSizeKey])
                if let fileSize = resources.fileSize {
                    let fileSizeMB = Double(fileSize) / (1024.0 * 1024.0)
                    if fileSizeMB > 25.0 {
                        DispatchQueue.main.async {
                            self?.showAlert(title: "File Too Large", message: "Please select a video smaller than 25 MB.")
                        }
                        return
                    }
                }
                
                // Proceed with processing the video
                DispatchQueue.main.async {
                    self?.navigateToVideoAnalysisScreen(with: tempURL)
                }
                
            } catch {
                DispatchQueue.main.async {
                    self?.showAlert(title: "Error", message: "Could not process the selected video.")
                }
            }
        }
    }
}

extension ViewController {
    func showAlert(title: String, message: String) {
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alertVC, animated: true, completion: nil)
    }
}

extension ViewController {
    
    func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    completion(newStatus == .authorized || newStatus == .limited)
                }
            }
        case .authorized, .limited:
            completion(true)
        default:
            completion(false)
        }
    }
    
    
    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .authorized:
            completion(true)
        default:
            completion(false)
        }
    }
}

// TODO: Later Shift it in Base View Controller
extension ViewController {
    
    func showLoadingIndicator() {
        // Implement a loading indicator (e.g., UIActivityIndicatorView)
    }
    
    func hideLoadingIndicator() {
        // Hide the loading indicator
    }
}

