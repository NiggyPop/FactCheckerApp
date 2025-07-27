//
//  StorageInfoView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import SwiftUI
import Charts

struct StorageInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var fileManager = AudioFileManager.shared
    @State private var storageInfo: StorageInfo?
    @State private var isLoading = true
    @State private var showingCleanupAlert = false
    @State private var selectedCleanupOptions: Set<CleanupOption> = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        ProgressView("Analyzing storage...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let info = storageInfo {
                        storageOverviewSection(info)
                        storageBreakdownSection(info)
                        fileTypesSection(info)
                        cleanupSection(info)
                    }
                }
                .padding()
            }
            .navigationTitle("Storage Usage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Clean Up Storage", isPresented: $showingCleanupAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clean Up", role: .destructive) {
                    performCleanup()
                }
            } message: {
                Text("This will permanently delete the selected items. This action cannot be undone.")
            }
        }
        .onAppear {
            loadStorageInfo()
        }
    }
    
    private func storageOverviewSection(_ info: StorageInfo) -> some View {
        VStack(spacing: 16) {
            Text("Total Storage Used")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                Text(info.formattedTotalSize)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text("\(info.totalFiles) files")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Storage usage chart
            if #available(iOS 16.0, *) {
                Chart(info.categoryBreakdown, id: \.category) { item in
                    SectorMark(
                        angle: .value("Size", item.size),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(item.color)
                    .opacity(0.8)
                }
                .frame(height: 200)
                .chartLegend(position: .bottom, alignment: .center)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private func storageBreakdownSection(_ info: StorageInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Storage Breakdown")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(info.categoryBreakdown, id: \.category) { item in
                    StorageBreakdownRow(
                        category: item.category,
                        size: item.formattedSize,
                        percentage: item.percentage,
                        color: item.color
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private func fileTypesSection(_ info: StorageInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("File Types")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(info.fileTypeBreakdown, id: \.format) { item in
                    HStack {
                        Text(item.format.rawValue.uppercased())
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                        
                        Text("\(item.count) files")
                            .font(.body)
                        
                        Spacer()
                        
                        Text(item.formattedSize)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private func cleanupSection(_ info: StorageInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Storage Cleanup")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(CleanupOption.allCases, id: \.self) { option in
                    CleanupOptionRow(
                        option: option,
                        isSelected: selectedCleanupOptions.contains(option),
                        potentialSavings: info.potentialSavings(for: option)
                    ) { isSelected in
                        if isSelected {
                            selectedCleanupOptions.insert(option)
                        } else {
                            selectedCleanupOptions.remove(option)
                        }
                    }
                }
            }
            
            if !selectedCleanupOptions.isEmpty {
                Button("Clean Up Selected Items") {
                    showingCleanupAlert = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private func loadStorageInfo() {
        isLoading = true
        
        Task {
            let info = await fileManager.getDetailedStorageInfo()
            
            await MainActor.run {
                self.storageInfo = info
                self.isLoading = false
            }
        }
    }
    
    private func performCleanup() {
        Task {
            await fileManager.performCleanup(options: selectedCleanupOptions)
            selectedCleanupOptions.removeAll()
            loadStorageInfo()
        }
    }
}

struct StorageBreakdownRow: View {
    let category: String
    let size: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                
                Text(category)
                    .font(.body)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(size)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text("\(Int(percentage))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            ProgressView(value: percentage / 100)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .scaleEffect(y: 0.5)
        }
    }
}

struct CleanupOptionRow: View {
    let option: CleanupOption
    let isSelected: Bool
    let potentialSavings: String
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(option.title)
                    .font(.body)
                
                Text(option.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(potentialSavings)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
}

enum CleanupOption: CaseIterable {
    case temporaryFiles
    case oldRecordings
    case duplicateFiles
    case largeFiles
    case corruptedFiles
    
    var title: String {
        switch self {
        case .temporaryFiles:
            return "Temporary Files"
        case .oldRecordings:
            return "Old Recordings (>30 days)"
        case .duplicateFiles:
            return "Duplicate Files"
        case .largeFiles:
            return "Large Files (>100MB)"
        case .corruptedFiles:
            return "Corrupted Files"
        }
    }
    
    var description: String {
        switch self {
        case .temporaryFiles:
            return "Cache and temporary processing files"
        case .oldRecordings:
            return "Recordings older than 30 days"
        case .duplicateFiles:
            return "Files with identical content"
        case .largeFiles:
            return "Unusually large audio files"
        case .corruptedFiles:
            return "Files that cannot be played"
        }
    }
}
