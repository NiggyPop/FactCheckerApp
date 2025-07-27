//
//  TranscriptionView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import SwiftUI
import Speech

struct TranscriptionView: View {
    let audioURL: URL
    @Environment(\.dismiss) private var dismiss
    @StateObject private var transcriptionManager = TranscriptionManager()
    
    @State private var transcriptionText = ""
    @State private var isTranscribing = false
    @State private var transcriptionProgress: Double = 0
    @State private var selectedLanguage = "en-US"
    @State private var showingLanguageSelector = false
    @State private var showingShareSheet = false
    
    private let availableLanguages = [
        ("en-US", "English (US)"),
        ("en-GB", "English (UK)"),
        ("es-ES", "Spanish"),
        ("fr-FR", "French"),
        ("de-DE", "German"),
        ("it-IT", "Italian"),
        ("pt-BR", "Portuguese"),
        ("ja-JP", "Japanese"),
        ("ko-KR", "Korean"),
        ("zh-CN", "Chinese (Simplified)")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with controls
                headerSection
                
                // Transcription content
                transcriptionContentSection
                
                // Action buttons
                actionButtonsSection
            }
            .navigationTitle("Transcription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Copy Text") {
                            copyTranscription()
                        }
                        .disabled(transcriptionText.isEmpty)
                        
                        Button("Share") {
                            showingShareSheet = true
                        }
                        .disabled(transcriptionText.isEmpty)
                        
                        Button("Save as Text File") {
                            saveAsTextFile()
                        }
                        .disabled(transcriptionText.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingLanguageSelector) {
                LanguageSelectorView(
                    selectedLanguage: $selectedLanguage,
                    availableLanguages: availableLanguages
                )
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [transcriptionText])
            }
            .onAppear {
                requestTranscriptionPermission()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Language selector
            Button(action: { showingLanguageSelector = true }) {
                HStack {
                    Text("Language:")
                        .foregroundColor(.secondary)
                    
                    Text(languageDisplayName)
                        .fontWeight(.medium)
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .disabled(isTranscribing)
            
            // Progress indicator
            if isTranscribing {
                VStack(spacing: 8) {
                    ProgressView(value: transcriptionProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    Text("Transcribing audio...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
    }
    
    private var transcriptionContentSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if transcriptionText.isEmpty && !isTranscribing {
                    emptyStateView
                } else {
                    transcriptionTextView
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.bubble")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Transcription Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap 'Start Transcription' to convert your audio to text")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var transcriptionTextView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Transcription")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(transcriptionText.count) characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(transcriptionText)
                .font(.body)
                .lineSpacing(4)
                .textSelection(.enabled)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if !isTranscribing {
                Button(action: startTranscription) {
                    HStack {
                        Image(systemName: "text.bubble.fill")
                        Text("Start Transcription")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .disabled(!transcriptionManager.isAvailable)
            } else {
                Button(action: cancelTranscription) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Cancel")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
                }
            }
            
            if !transcriptionManager.isAvailable {
                Text("Speech recognition is not available on this device")
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var languageDisplayName: String {
        availableLanguages.first { $0.0 == selectedLanguage }?.1 ?? "Unknown"
    }
    
    private func requestTranscriptionPermission() {
        transcriptionManager.requestPermission { granted in
            if !granted {
                // Handle permission denied
            }
        }
    }
    
    private func startTranscription() {
        isTranscribing = true
        transcriptionProgress = 0
        transcriptionText = ""
        
        transcriptionManager.transcribeAudio(
            url: audioURL,
            language: selectedLanguage
        ) { result in
            DispatchQueue.main.async {
                self.isTranscribing = false
                
                switch result {
                case .success(let text):
                    self.transcriptionText = text
                    HapticFeedbackManager.shared.effectApplied()
                    
                case .failure(let error):
                    print("Transcription failed: \(error)")
                    HapticFeedbackManager.shared.errorOccurred()
                }
            }
        } progressHandler: { progress in
            DispatchQueue.main.async {
                self.transcriptionProgress = progress
            }
        }
    }
    
    private func cancelTranscription() {
        transcriptionManager.cancelTranscription()
        isTranscribing = false
        transcriptionProgress = 0
    }
    
    private func copyTranscription() {
        UIPasteboard.general.string = transcriptionText
        HapticFeedbackManager.shared.effectApplied()
    }
    
    private func saveAsTextFile() {
        let fileName = "Transcription_\(DateFormatter.exportFormatter.string(from: Date())).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try transcriptionText.write(to: tempURL, atomically: true, encoding: .utf8)
            showingShareSheet = true
        } catch {
            print("Failed to save transcription: \(error)")
            HapticFeedbackManager.shared.errorOccurred()
        }
    }
}

struct LanguageSelectorView: View {
    @Binding var selectedLanguage: String
    let availableLanguages: [(String, String)]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(availableLanguages, id: \.0) { language in
                    Button(action: {
                        selectedLanguage = language.0
                        dismiss()
                    }) {
                        HStack {
                            Text(language.1)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedLanguage == language.0 {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
