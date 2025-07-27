//
//  MainFactCheckView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import SwiftUI
import Combine

struct MainFactCheckView: View {
    @ObservedObject var coordinator: FactCheckCoordinator
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State private var isListening = false
    @State private var showingPermissionAlert = false
    @State private var permissionError: Error?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                headerView
                
                // Current Status
                statusView
                
                // Active Fact Checks
                activeFactChecksView
                
                // Recent Results
                recentResultsView
                
                Spacer()
                
                // Control Button
                controlButton
            }
            .padding()
            .navigationTitle("Live Fact Check")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        coordinator.clearHistory()
                    }
                    .disabled(coordinator.factCheckHistory.isEmpty)
                }
            }
        }
        .alert("Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Microphone access is required for speech recognition. Please enable it in Settings.")
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(isListening ? .red : .gray)
                .symbolEffect(.pulse, isActive: isListening)
            
            Text(isListening ? "Listening..." : "Ready to Listen")
                .font(.title2)
                .fontWeight(.medium)
        }
    }
    
    private var statusView: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Processing", systemImage: "gearshape.2")
                Spacer()
                if coordinator.isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            HStack {
                Label("Total Checks", systemImage: "number.circle")
                Spacer()
                Text("\(coordinator.totalFactChecks)")
                    .fontWeight(.semibold)
            }
            
            HStack {
                Label("Accuracy Rate", systemImage: "percent")
                Spacer()
                Text("\(coordinator.accuracyRate * 100, specifier: "%.1f")%")
                    .fontWeight(.semibold)
                    .foregroundColor(coordinator.accuracyRate > 0.7 ? .green : .orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var activeFactChecksView: some View {
        Group {
            if !coordinator.activeFactChecks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Checks")
                        .font(.headline)
                    
                    ForEach(Array(coordinator.activeFactChecks.values), id: \.id) { result in
                        ActiveFactCheckCard(result: result)
                    }
                }
            }
        }
    }
    
    private var recentResultsView: some View {
        Group {
            if !coordinator.factCheckHistory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Recent Results")
                            .font(.headline)
                        Spacer()
                        NavigationLink("View All") {
                            HistoryView(coordinator: coordinator)
                        }
                        .font(.caption)
                    }
                    
                    LazyVStack(spacing: 8) {
                        ForEach(Array(coordinator.factCheckHistory.prefix(3)), id: \.id) { result in
                            FactCheckResultCard(result: result)
                        }
                    }
                }
            }
        }
    }
    
    private var controlButton: some View {
        Button(action: toggleListening) {
            HStack {
                Image(systemName: isListening ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                Text(isListening ? "Stop Listening" : "Start Listening")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isListening ? Color.red : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(coordinator.isProcessing)
    }
    
    private func toggleListening() {
        if isListening {
            coordinator.stopFactChecking()
            isListening = false
        } else {
            Task {
                do {
                    coordinator.startFactChecking()
                    isListening = true
                } catch {
                    permissionError = error
                    showingPermissionAlert = true
                }
            }
        }
    }
}

struct ActiveFactCheckCard: View {
    let result: FactCheckResult
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.statement)
                    .font(.caption)
                    .lineLimit(2)
                
                HStack {
                    Text("Analyzing...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            
            Spacer()
        }
        .padding(8)
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }
}

struct FactCheckResultCard: View {
    let result: FactCheckResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                truthLabelView
                Spacer()
                confidenceView
            }
            
            Text(result.statement)
                .font(.subheadline)
                .lineLimit(3)
            
            if !result.sources.isEmpty {
                HStack {
                    Image(systemName: "link")
                        .font(.caption)
                    Text("\(result.sources.count) sources")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(result.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var truthLabelView: some View {
        HStack(spacing: 4) {
            Image(systemName: result.truthLabel.iconName)
                .foregroundColor(result.truthLabel.color)
            Text(result.truthLabel.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(result.truthLabel.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(result.truthLabel.color.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var confidenceView: some View {
        Text("\(result.confidence * 100, specifier: "%.0f")%")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.secondary)
    }
}

// MARK: - Extensions

extension FactCheckResult.TruthLabel {
    var iconName: String {
        switch self {
        case .true: return "checkmark.circle.fill"
        case .likelyTrue: return "checkmark.circle"
        case .mixed: return "questionmark.circle"
        case .likelyFalse: return "xmark.circle"
        case .false: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        case .unverifiable: return "exclamationmark.triangle"
        }
    }
    
    var color: Color {
        switch self {
        case .true: return .green
        case .likelyTrue: return .green.opacity(0.7)
        case .mixed: return .orange
        case .likelyFalse: return .red.opacity(0.7)
        case .false: return .red
        case .unknown: return .gray
        case .unverifiable: return .yellow
        }
    }
    
    var displayName: String {
        switch self {
        case .true: return "True"
        case .likelyTrue: return "Likely True"
        case .mixed: return "Mixed"
        case .likelyFalse: return "Likely False"
        case .false: return "False"
        case .unknown: return "Unknown"
        case .unverifiable: return "Unverifiable"
        }
    }
}
