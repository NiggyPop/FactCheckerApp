//
//  HistoryView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import SwiftUI

struct HistoryView: View {
    @ObservedObject var coordinator: FactCheckCoordinator
    @State private var searchText = ""
    @State private var selectedFilter: FilterOption = .all
    @State private var sortOption: SortOption = .newest
    @State private var showingExportSheet = false
    
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case true_ = "True"
        case false_ = "False"
        case mixed = "Mixed"
        case unknown = "Unknown"
        
        var truthLabel: FactCheckResult.TruthLabel? {
            switch self {
            case .all: return nil
            case .true_: return .true
            case .false_: return .false
            case .mixed: return .mixed
            case .unknown: return .unknown
            }
        }
    }
    
    enum SortOption: String, CaseIterable {
        case newest = "Newest"
        case oldest = "Oldest"
        case confidence = "Confidence"
        case truthScore = "Truth Score"
    }
    
    var filteredResults: [FactCheckResult] {
        var results = coordinator.factCheckHistory
        
        // Apply search filter
        if !searchText.isEmpty {
            results = results.filter { result in
                result.statement.localizedCaseInsensitiveContains(searchText) ||
                result.speakerId.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply truth label filter
        if let truthLabel = selectedFilter.truthLabel {
            results = results.filter { $0.truthLabel == truthLabel }
        }
        
        // Apply sorting
        switch sortOption {
        case .newest:
            results.sort { $0.timestamp > $1.timestamp }
        case .oldest:
            results.sort { $0.timestamp < $1.timestamp }
        case .confidence:
            results.sort { $0.confidence > $1.confidence }
        case .truthScore:
            results.sort { $0.truthScore > $1.truthScore }
        }
        
        return results
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                searchAndFilterView
                
                // Results List
                if filteredResults.isEmpty {
                    emptyStateView
                } else {
                    resultsList
                }
            }
            .navigationTitle("Fact Check History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Export History") {
                            showingExportSheet = true
                        }
                        
                        Button("Clear All", role: .destructive) {
                            coordinator.clearHistory()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportView(coordinator: coordinator)
        }
    }
    
    private var searchAndFilterView: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search statements or speakers...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .font(.caption)
                }
            }
            
            // Filter and Sort Options
            HStack {
                // Filter Picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(FilterOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 20)
                
                // Sort Picker
                Picker("Sort", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Results Found")
                .font(.title2)
                .fontWeight(.medium)
            
            Text(searchText.isEmpty ? 
                 "Start fact-checking to see results here" : 
                 "Try adjusting your search or filters")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var resultsList: some View {
        List {
            ForEach(filteredResults, id: \.id) { result in
                NavigationLink(destination: FactCheckDetailView(result: result)) {
                    HistoryRowView(result: result)
                }
            }
            .onDelete(perform: deleteResults)
        }
        .listStyle(PlainListStyle())
    }
    
    private func deleteResults(at offsets: IndexSet) {
        // Note: This would require implementing deletion in the coordinator
        // For now, we'll just show the functionality
    }
}

struct HistoryRowView: View {
    let result: FactCheckResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with truth label and timestamp
            HStack {
                truthLabelBadge
                Spacer()
                Text(result.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Statement
            Text(result.statement)
                .font(.subheadline)
                .lineLimit(3)
            
            // Footer with speaker and confidence
            HStack {
                if !result.speakerId.isEmpty && result.speakerId != "Unknown" {
                    Label(result.speakerId, systemImage: "person.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "gauge.medium")
                        .font(.caption)
                    Text("\(result.confidence * 100, specifier: "%.0f")%")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            // Sources count
            if !result.sources.isEmpty {
                HStack {
                    Image(systemName: "link")
                        .font(.caption)
                    Text("\(result.sources.count) sources")
                        .font(.caption)
                    
                    Spacer()
                    
                    // Top source domain
                    if let topSource = result.sources.first {
                        Text(topSource.domain)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var truthLabelBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: result.truthLabel.iconName)
            Text(result.truthLabel.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(result.truthLabel.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(result.truthLabel.color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ExportView: View {
    @ObservedObject var coordinator: FactCheckCoordinator
    @Environment(\.presentationMode) var presentationMode
    @State private var exportFormat: ExportFormat = .json
    @State private var isExporting = false
    
    enum ExportFormat: String, CaseIterable {
        case json = "JSON"
        case csv = "CSV"
        case pdf = "PDF"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Export your fact-check history")
                    .font(.title2)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export Format")
                        .font(.headline)
                    
                    Picker("Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export will include:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Label("All fact-check results", systemImage: "checkmark")
                        Label("Source information", systemImage: "checkmark")
                        Label("Speaker data", systemImage: "checkmark")
                        Label("Timestamps and metadata", systemImage: "checkmark")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: exportData) {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text("Export Data")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isExporting)
            }
            .padding()
            .navigationTitle("Export History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func exportData() {
        isExporting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = coordinator.exportHistory() else {
                DispatchQueue.main.async {
                    isExporting = false
                }
                return
            }
            
            DispatchQueue.main.async {
                // Present share sheet
                let activityVC = UIActivityViewController(
                    activityItems: [data],
                    applicationActivities: nil
                )
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.present(activityVC, animated: true)
                }
                
                isExporting = false
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
