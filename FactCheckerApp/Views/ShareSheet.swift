//
//  ShareSheet.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let excludedActivityTypes: [UIActivity.ActivityType]?
    let completion: ((Bool) -> Void)?
    
    init(
        items: [Any],
        excludedActivityTypes: [UIActivity.ActivityType]? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        self.items = items
        self.excludedActivityTypes = excludedActivityTypes
        self.completion = completion
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        activityViewController.excludedActivityTypes = excludedActivityTypes
        
        activityViewController.completionWithItemsHandler = { _, completed, _, _ in
            completion?(completed)
        }
        
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// Custom activity for specific sharing needs
class SaveToFilesActivity: UIActivity {
    override var activityType: UIActivity.ActivityType? {
        return UIActivity.ActivityType("com.voicerecorder.savetofiles")
    }
    
    override var activityTitle: String? {
        return "Save to Files"
    }
    
    override var activityImage: UIImage? {
        return UIImage(systemName: "folder")
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return activityItems.contains { $0 is URL }
    }
    
    override func perform() {
        // Implementation for saving to Files app
        activityDidFinish(true)
    }
}
