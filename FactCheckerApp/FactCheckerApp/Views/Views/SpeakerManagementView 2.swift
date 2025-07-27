//
//  SpeakerManagementView 2.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import SwiftUI
import AVFoundation

struct SpeakerManagementView: View {
    @StateObject private var speakerAnalyzer = SpeakerAnalyzer()
    @State private var knownSpeakers: [String] = []
    @State private var showingAddSpeaker = false
    @State private var showingDeleteAlert = false
    @State private var speakerToDelete: String?
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            List {
                if knownSpeakers.isEmpty {
                    emptyStateView
                } else {
                    ForEach(knownSpeakers, id: \.self) { speaker in
                        SpeakerRowView(
                            speakerName: speaker,
                            onDelete: { deleteSpeaker(speaker) },
                            onUpdate: { updateSpeaker(speaker) }
                        )
                    }
                    .onDelete(perform: deleteSpeakers)
                }
            }
            .navigationTitle("Known Speakers")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Speaker") {
                        showingAddSpeaker = true
                    }
                }
            }
            .sheet(isPresented: $showingAddSpeaker) {
                AddSpeakerView(speakerAnalyzer: speakerAnalyzer) {
                    loadKnownSpeakers()
                }
            }
            .alert("Delete Speaker", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let speaker = speakerToDelete {
                        confirmDeleteSpeaker(speaker)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this speaker profile? This action cannot be undone.")
            }
            .onAppear {
                loadKnownSpeakers()
            }
            .refreshable {
                loadKnownSpeakers()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.sequence")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Known Speakers")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add speaker profiles to enable automatic speaker identification during fact-checking sessions.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Add First Speaker") {
                showingAddSpeaker = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    private func loadKnownSpeakers() {
        knownSpeakers = speakerAnalyzer.getAllKnownSpeakers()
    }
    
    private func deleteSpeaker(_ speaker: String) {
        speakerToDelete = speaker
        showingDeleteAlert = true
    }
    
    private func confirmDeleteSpeaker(_ speaker: String) {
        do {
            try speakerAnalyzer.removeSpeaker(name: speaker)
            loadKnownSpeakers()
        } catch {
            print("Error deleting speaker: \(error)")
        }
    }
    
    private func deleteSpeakers(at offsets: IndexSet) {
        for index in offsets {
            let speaker = knownSpeakers[index]
            confirmDeleteSpeaker(speaker)
        }
    }
    
    private func updateSpeaker(_ speaker: String) {
        // Implementation for updating speaker profile
        // This would typically involve recording new samples
    }
}

struct SpeakerRowView: View {
    let speakerName: String
    let onDelete: () -> Void
    let onUpdate: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(speakerName)
                    .font(.headline)
                
                Text("Registered Speaker")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Menu {
                Button("Update Profile", action: onUpdate)
                Button("Delete", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddSpeakerView: View {
    let speakerAnalyzer: SpeakerAnalyzer
    let onComplete: () -> Void
    
    @State private var speakerName = ""
    @State private var recordedSamples: [AVAudioPCMBuffer] = []
    @State private var isRecording = false
    @State private var currentRecordingDuration: TimeInterval = 0
    @State private var audioProcessor = AdvancedAudioProcessor()
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isRegistering = false
    
    @Environment(\.dismiss) private var dismiss
    
    private let requiredSamples = 3
    private let sampleDuration: TimeInterval = 5.0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                headerView
                
                nameInputView
                
                recordingSectionView
                
                if !recordedSamples.isEmpty {
                    samplesListView
                }
                
                Spacer()
                
                actionButtonsView
            }
            .padding()
            .navigationTitle("Add Speaker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Register New Speaker")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Record \(requiredSamples) voice samples of \(Int(sampleDuration)) seconds each to create a speaker profile.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var nameInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Speaker Name")
                .font(.headline)
            
            TextField("Enter speaker name", text: $speakerName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
    
    private var recordingSectionView: some View {
        VStack(spacing: 20) {
            Text("Voice Samples (\(recordedSamples.count)/\(requiredSamples))")
                .font(.headline)
            
            if isRecording {
                VStack(spacing: 16) {
                    Text("Recording Sample \(recordedSamples.count + 1)")
                        .font(.subheadline)
                        .foregroundColor(.red)
                    
                    Text(String(format: "%.1f / %.0f seconds", currentRecordingDuration, sampleDuration))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    
                    ProgressView(value: currentRecordingDuration / sampleDuration)
                        .progressViewStyle(LinearProgressViewStyle(tint: .red))
                }
            }
            
            Button(action: toggleRecording) {
                HStack {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    Text(isRecording ? "Stop Recording" : "Start Recording")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(isRecording ? Color.red : Color.blue)
                .cornerRadius(12)
            }
            .disabled(recordedSamples.count >= requiredSamples)
        }
    }
    
    private var samplesListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recorded Samples")
                .font(.headline)
            
            ForEach(0..<recordedSamples.count, id: \.self) { index in
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.green)
                    
                    Text("Sample \(index + 1)")
                        .font(.body)
                    
                    Spacer()
                    
                    Button("Delete") {
                        recordedSamples.remove(at: index)
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            Button("Register Speaker") {
                registerSpeaker()
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(canRegister ? Color.green : Color.gray)
            .cornerRadius(12)
            .disabled(!canRegister || isRegistering)
            
            if isRegistering {
                ProgressView("Registering speaker...")
                    .font(.caption)
            }
        }
    }
    
    private var canRegister: Bool {
        !speakerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        recordedSamples.count >= requiredSamples
    }
    
    // MARK: - Actions
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        guard recordedSamples.count < requiredSamples else { return }
        
        Task {
            do {
                try await audioProcessor.startRecording()
                
                await MainActor.run {
                    isRecording = true
                    currentRecordingDuration = 0
                    startRecordingTimer()
                }
            } catch {
                await MainActor.run {
                    handleError(error)
                }
            }
        }
    }
    
    private func stopRecording() {
        audioProcessor.stopRecording()
        isRecording = false
        
        // Get the recorded buffer and add to samples
        if let recordedBuffer = audioProcessor.getLastRecordedBuffer() {
            recordedSamples.append(recordedBuffer)
        }
    }
    
    private func startRecordingTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            currentRecordingDuration += 0.1
            
            if currentRecordingDuration >= sampleDuration {
                timer.invalidate()
                stopRecording()
            }
        }
    }
    
    private func registerSpeaker() {
        guard canRegister else { return }
        
        isRegistering = true
        
        Task {
            do {
                try await speakerAnalyzer.registerSpeaker(
                    name: speakerName.trimmingCharacters(in: .whitespacesAndNewlines),
                    audioSamples: recordedSamples
                )
                
                await MainActor.run {
                    onComplete()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isRegistering = false
                    handleError(error)
                }
            }
        }
    }
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showingError = true
    }
}
