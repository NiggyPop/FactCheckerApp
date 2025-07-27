//
//  BatchOperationsView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import SwiftUI

struct BatchOperationsView: View {
    @Binding var selectedRecordings: Set<UUID>
    let allRecordings: [AudioFileInfo]
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingDeleteConfirmation = false
    @State private var showingExportView = false
    @State private var showingMoveToFolderView = false
    @State private var showingTagEditor = false
    @State private var isProcessing = false
    
    private var selectedRecordingsList: [AudioFileInfo] {
        allRecordings.filter { selectedRecordings.contains($0.id) }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    selectionSummarySection
                    operationsSection
                }
                .padding()
            }
            .navigationTitle("Batch Operations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear Selection") {
                        selectedRecordings.removeAll()
                    }
                    .disabled(selectedRecordings.isEmpty)
                }
            }
            .sheet(isPresented: $showingExportView) {
                ExportView(recordings: selectedRecordingsList)
            }
            .sheet(isPresented: $showingMoveToFolderView) {
                FolderSelectorView(recordings: selectedRecordingsList)
            }
            .sheet(isPresented: $showingTagEditor) {
                BatchTagEditorView(recordings: selectedRecordingsList)
            }
            .alert("Delete Recordings", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteSelectedRecordings()
                }
            } message: {
                Text("Are you sure you want to delete \(selectedRecordings.count) recording(s)? This action cannot be undone.")
            }
            .overlay {
                if isProcessing {
                    processingOverlay
                }
            }
        }
    }
    
    private var selectionSummarySection: some View {
        VStack(spacing: 16) {
            Text("Selection Summary")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Selected Recordings:")
                    Spacer()
                    Text("\(selectedRecordings.count)")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Total Duration:")
                    Spacer()
                    Text(formatTotalDuration())
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Total Size:")
                    Spacer()
                    Text(formatTotalSize())
                        .fontWeight(.medium)
                }
            }
            .font(.body)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var operationsSection: some View {
        VStack(spacing: 16) {
            Text("Available Operations")
                .font(.title3)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                BatchOperationCard(
                    title: "Export",
                    icon: "square.and.arrow.up",
                    color: .blue,
                    action: { showingExportView = true }
                )
                
                BatchOperationCard(
                    title: "Move to Folder",
                    icon: "folder",
                    color: .orange,
                    action: { showingMoveToFolderView = true }
                )
                
                BatchOperationCard(
                    title: "Add Tags",
                    icon: "tag",
                    color: .green,
                    action: { showingTagEditor = true }
                )
                
                BatchOperationCard(
                    title: "Delete",
                    icon: "trash",
                    color: .red,
                    action: { showingDeleteConfirmation = true }
                )
                
                BatchOperationCard(
                    title: "Duplicate",
                    icon: "doc.on.doc",
                    color: .purple,
                    action: duplicateSelectedRecordings
                )
                
                BatchOperationCard(
                    title: "Apply Effect",
                    icon: "waveform.path.ecg",
                    color: .indigo,
                    action: showEffectsMenu
                )
            }
        }
    }
    
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Processing...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(Color(.systemGray5))
            .cornerRadius(20)
        }
    }
    
    private func formatTotalDuration() -> String {
        let totalDuration = selectedRecordingsList.reduce(0) { $0 + $1.duration }
        return AudioFileInfo.formatDuration(totalDuration)
    }
    
    private func formatTotalSize() -> String {
        let totalSize = selectedRecordingsList.reduce(0) { $0 + $1.size }
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    private func deleteSelectedRecordings() {
        isProcessing = true
        
        Task {
            for recording in selectedRecordingsList {
                try? AudioFileManager.shared.deleteAudioFile(recording)
            }
            
            await MainActor.run {
                selectedRecordings.removeAll()
                isProcessing = false
                dismiss()
                HapticFeedbackManager.shared.effectApplied()
            }
        }
    }
    
    private func duplicateSelectedRecordings() {
        isProcessing = true
        
        Task {
            for recording in selectedRecordingsList {
                try? AudioFileManager.shared.duplicateAudioFile(recording)
            }
            
            await MainActor.run {
                isProcessing = false
                HapticFeedbackManager.shared.effectApplied()
            }
        }
    }
    
    private func showEffectsMenu() {
        // Implementation for showing effects menu
        // This would present a sheet with available audio effects
    }
}

struct BatchOperationCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(color)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FolderSelectorView: View {
    let recordings: [AudioFileInfo]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFolder: String = ""
    @State private var newFolderName: String = ""
    @State private var showingNewFolderAlert = false
    
    private let existingFolders = ["Work", "Personal", "Meetings", "Notes", "Archive"]
    
    var body: some View {
        NavigationView {
            List {
                Section("Existing Folders") {
                    ForEach(existingFolders, id: \.self) { folder in
                        Button(action: {
                            selectedFolder = folder
                            moveToFolder()
                        }) {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.blue)
                                Text(folder)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        showingNewFolderAlert = true
                    }) {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                                .foregroundColor(.green)
                            Text("Create New Folder")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Select Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("New Folder", isPresented: $showingNewFolderAlert) {
                TextField("Folder Name", text: $newFolderName)
                Button("Cancel", role: .cancel) { }
                Button("Create") {
                    selectedFolder = newFolderName
                    moveToFolder()
                }
            } message: {
                Text("Enter a name for the new folder")
            }
        }
    }
    
    private func moveToFolder() {
        // Implementation for moving recordings to folder
        // This would update the folder property of each recording
        dismiss()
        HapticFeedbackManager.shared.effectApplied()
    }
}

struct BatchTagEditorView: View {
    let recordings: [AudioFileInfo]
    @Environment(\.dismiss) private var dismiss
    @State private var availableTags = ["Important", "Meeting", "Personal", "Work", "Archive"]
    @State private var selectedTags: Set<String> = []
    @State private var newTagName = ""
    @State private var showingNewTagField = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add tags to \(recordings.count) recording(s)")
                    .font(.headline)
                    .padding()
                
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(availableTags, id: \.self) { tag in
                            TagSelectionButton(
                                tag: tag,
                                isSelected: selectedTags.contains(tag)
                            ) {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            }
                        }
                        
                        Button(action: {
                            showingNewTagField = true
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("New Tag")
                            }
                            .font(.body)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
                
                if showingNewTagField {
                    HStack {
                        TextField("Tag name", text: $newTagName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Add") {
                            if !newTagName.isEmpty {
                                availableTags.append(newTagName)
                                selectedTags.insert(newTagName)
                                newTagName = ""
                                showingNewTagField = false
                            }
                        }
                        .disabled(newTagName.isEmpty)
                    }
                    .padding(.horizontal)
                }
                
                Button(action: applyTags) {
                    Text("Apply Tags")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedTags.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(12)
                }
                .disabled(selectedTags.isEmpty)
                .padding()
            }
            .navigationTitle("Add Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func applyTags() {
        // Implementation for applying tags to recordings
        // This would update the tags property of each recording
        dismiss()
        HapticFeedbackManager.shared.effectApplied()
    }
}

struct TagSelectionButton: View {
    let tag: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .white : .blue)
                Text(tag)
                    .foregroundColor(isSelected ? .white : .primary)
                Spacer()
            }
            .padding()
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
