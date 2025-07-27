//
//  SpeakerManagementView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import SwiftUI

struct SpeakerManagementView: View {
    @ObservedObject var speakerService: SpeakerIdentificationService
    @State private var showingAddSpeaker = false
    @State private var showingDeleteAlert = false
    @State private var speakerToDelete: Speaker?
    @State private var searchText = ""
    
    var filteredSpeakers: [Speaker] {
        if searchText.isEmpty {
            return speakerService.knownSpeakers
        } else {
            return speakerService.knownSpeakers.filter { speaker in
                speaker.name.localizedCaseInsensitiveContains(searchText) ||
                speaker.id.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                searchBar
                
                // Speakers List
                if filteredSpeakers.isEmpty {
                    emptyStateView
                } else {
                    speakersList
                }
            }
            .navigationTitle("Speaker Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Speaker") {
                        showingAddSpeaker = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSpeaker) {
            AddSpeakerView(speakerService: speakerService)
        }
        .alert("Delete Speaker", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let speaker = speakerToDelete {
                    speakerService.removeSpeaker(speaker.id)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let speaker = speakerToDelete {
                Text("Are you sure you want to delete \(speaker.name)? This action cannot be undone.")
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search speakers...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !searchText.isEmpty {
                Button("Clear") {
                    searchText = ""
                }
                .font(.caption)
            }
        }
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Speakers Found")
                .font(.title2)
                .fontWeight(.medium)
            
            Text(searchText.isEmpty ? 
                 "Add speakers to track their fact-check history" : 
                 "No speakers match your search")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if searchText.isEmpty {
                Button("Add First Speaker") {
                    showingAddSpeaker = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var speakersList: some View {
        List {
            ForEach(filteredSpeakers, id: \.id) { speaker in
                NavigationLink(destination: SpeakerDetailView(speaker: speaker, speakerService: speakerService)) {
                    SpeakerRowView(speaker: speaker)
                }
            }
            .onDelete(perform: deleteSpeakers)
        }
        .listStyle(PlainListStyle())
    }
    
    private func deleteSpeakers(at offsets: IndexSet) {
        for index in offsets {
            let speaker = filteredSpeakers[index]
            speakerToDelete = speaker
            showingDeleteAlert = true
        }
    }
}

struct SpeakerRowView: View {
    let speaker: Speaker
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Speaker Avatar
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(speaker.name.prefix(1).uppercased())
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(speaker.name)
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text("ID: \(speaker.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(speaker.isActive ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }
            
            // Statistics
            HStack(spacing: 16) {
                StatView(label: "Statements", value: "\(speaker.totalStatements)")
                StatView(label: "Accuracy", value: "\(speaker.accuracyRate * 100, specifier: "%.1f")%")
                StatView(label: "Last Seen", value: speaker.lastSeen, style: .relative)
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

struct StatView: View {
    let label: String
    let value: String
    var style: Text.DateStyle?
    
    init(label: String, value: String) {
        self.label = label
        self.value = value
        self.style = nil
    }
    
    init(label: String, value: Date, style: Text.DateStyle) {
        self.label = label
        self.value = ""
        self.style = style
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .foregroundColor(.secondary)
            if let style = style {
                Text(Date(), style: style) // This would use the actual date
                    .fontWeight(.medium)
            } else {
                Text(value)
                    .fontWeight(.medium)
            }
        }
    }
}

struct AddSpeakerView: View {
    @ObservedObject var speakerService: SpeakerIdentificationService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var speakerName = ""
    @State private var speakerId = ""
    @State private var isRecording = false
    @State private var recordingProgress: Double = 0.0
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Add New Speaker")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                // Form
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Speaker Name")
                            .font(.headline)
                        TextField("Enter speaker name", text: $speakerName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Speaker ID (Optional)")
                            .font(.headline)
                        TextField("Auto-generated if empty", text: $speakerId)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                // Voice Recording Section
                VStack(spacing: 16) {
                    Text("Voice Sample")
                        .font(.headline)
                    
                    Text("Record a 10-second voice sample to improve speaker identification accuracy")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // Recording Button
                    Button(action: toggleRecording) {
                        VStack(spacing: 8) {
                            Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(isRecording ? .red : .blue)
                                .symbolEffect(.pulse, isActive: isRecording)
                            
                            Text(isRecording ? "Recording..." : "Tap to Record")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                    .disabled(speakerName.isEmpty)
                    
                    if isRecording {
                        ProgressView(value: recordingProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                    }
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button("Add Speaker") {
                        addSpeaker()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(speakerName.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(speakerName.isEmpty)
                    
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
            .padding()
            .navigationTitle("Add Speaker")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        recordingProgress = 0.0
        
        // Simulate recording progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            recordingProgress += 0.01
            if recordingProgress >= 1.0 {
                timer.invalidate()
                stopRecording()
            }
        }
    }
    
    private func stopRecording() {
        isRecording = false
        recordingProgress = 0.0
    }
    
    private func addSpeaker() {
        let finalSpeakerId = speakerId.isEmpty ? UUID().uuidString : speakerId
        
        let speaker = Speaker(
            id: finalSpeakerId,
            name: speakerName,
            registrationDate: Date(),
            lastSeen: Date(),
            totalStatements: 0,
            trueStatements: 0,
            falseStatements: 0,
            mixedStatements: 0,
            unknownStatements: 0,
            isActive: true
        )
        
        do {
            try speakerService.addSpeaker(speaker)
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

struct SpeakerDetailView: View {
    let speaker: Speaker
    @ObservedObject var speakerService: SpeakerIdentificationService
    @State private var showingEditSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Card
                speakerHeaderCard
                
                // Statistics Cards
                statisticsSection
                
                // Recent Activity
                recentActivitySection
                
                // Voice Profile Management
                voiceProfileSection
            }
            .padding()
        }
        .navigationTitle(speaker.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditSpeakerView(speaker: speaker, speakerService: speakerService)
        }
    }
    
    private var speakerHeaderCard: some View {
        VStack(spacing: 16) {
            // Avatar and basic info
            HStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(speaker.name.prefix(2).uppercased())
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(speaker.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("ID: \(speaker.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Circle()
                            .fill(speaker.isActive ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(speaker.isActive ? "Active" : "Inactive")
                            .font(.caption)
                            .foregroundColor(speaker.isActive ? .green : .gray)
                    }
                }
                
                Spacer()
            }
            
            // Registration info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Registered")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(speaker.registrationDate, style: .date)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Last Seen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(speaker.lastSeen, style: .relative)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(title: "Total Statements", value: "\(speaker.totalStatements)", color: .blue)
                StatCard(title: "Accuracy Rate", value: "\(speaker.accuracyRate * 100, specifier: "%.1f")%", color: .green)
                StatCard(title: "True Statements", value: "\(speaker.trueStatements)", color: .green)
                StatCard(title: "False Statements", value: "\(speaker.falseStatements)", color: .red)
            }
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
            
            // This would show recent fact-check results for this speaker
            Text("No recent activity")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
    
    private var voiceProfileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice Profile")
                .font(.headline)
            
            VStack(spacing: 8) {
                Button("Update Voice Sample") {
                    // Implement voice sample update
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button("Test Recognition") {
                    // Implement recognition test
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}

struct EditSpeakerView: View {
    let speaker: Speaker
    @ObservedObject var speakerService: SpeakerIdentificationService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var speakerName: String
    @State private var isActive: Bool
    
    init(speaker: Speaker, speakerService: SpeakerIdentificationService) {
        self.speaker = speaker
        self.speakerService = speakerService
        self._speakerName = State(initialValue: speaker.name)
        self._isActive = State(initialValue: speaker.isActive)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Speaker Information") {
                    TextField("Name", text: $speakerName)
                    
                    HStack {
                        Text("Speaker ID")
                        Spacer()
                        Text(speaker.id)
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Active", isOn: $isActive)
                }
                
                Section("Statistics") {
                    HStack {
                        Text("Total Statements")
                        Spacer()
                        Text("\(speaker.totalStatements)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Accuracy Rate")
                        Spacer()
                        Text("\(speaker.accuracyRate * 100, specifier: "%.1f")%")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Registration Date")
                        Spacer()
                        Text(speaker.registrationDate, style: .date)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Speaker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSpeaker()
                    }
                    .disabled(speakerName.isEmpty)
                }
            }
        }
    }
    
    private func saveSpeaker() {
        let updatedSpeaker = Speaker(
            id: speaker.id,
            name: speakerName,
            registrationDate: speaker.registrationDate,
            lastSeen: speaker.lastSeen,
            totalStatements: speaker.totalStatements,
            trueStatements: speaker.trueStatements,
            falseStatements: speaker.falseStatements,
            mixedStatements: speaker.mixedStatements,
            unknownStatements: speaker.unknownStatements,
            isActive: isActive
        )
        
        speakerService.updateSpeaker(updatedSpeaker)
        presentationMode.wrappedValue.dismiss()
    }
}
