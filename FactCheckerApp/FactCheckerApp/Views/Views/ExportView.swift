//
//  ExportView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import SwiftUI

struct ExportView: View {
    let recordings: [AudioFileInfo]
    @Environment(\.dismiss) private var dismiss
    @StateObject private var exportManager = ExportManager.shared
    
    @State private var selectedFormat: AudioFileFormat = .m4a
    @State private var selectedQuality: ExportQuality = .high
    @State private var selectedExportType: MultipleExportType = .individual
    @State private var showingShareSheet = false
    @State private var exportedURL: URL?
    @State private var showingSuccessAlert = false
    
    private var isMultipleRecordings: Bool {
        recordings.count > 1
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    exportSummarySection
                    formatSelectionSection
                    qualitySelectionSection
                    
                    if isMultipleRecordings {
                        exportTypeSection
                    }
                    
                    exportButtonSection
                }
                .padding()
            }
            .navigationTitle("Export Recordings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedURL {
                    ShareSheet(items: [url]) { success in
                        if success {
                            showingSuccessAlert = true
                        }
                    }
                }
            }
            .alert("Export Successful", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your recordings have been exported successfully.")
            }
            .overlay {
                if exportManager.isExporting {
                    exportProgressOverlay
                }
            }
        }
    }
    
    private var exportSummarySection: some View {
        VStack(spacing: 16) {
            Text("Export Summary")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Recordings:")
                    Spacer()
                    Text("\(recordings.count)")
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
    
    private var formatSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Format")
                .font(.title3)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(AudioFileFormat.allCases, id: \.self) { format in
                    FormatSelectionCard(
                        format: format,
                        isSelected: selectedFormat == format
                    ) {
                        selectedFormat = format
                        HapticFeedbackManager.shared.buttonTapped()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var qualitySelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Quality")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(ExportQuality.allCases, id: \.self) { quality in
                    QualitySelectionRow(
                        quality: quality,
                        isSelected: selectedQuality == quality
                    ) {
                        selectedQuality = quality
                        HapticFeedbackManager.shared.buttonTapped()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var exportTypeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Type")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(MultipleExportType.allCases, id: \.self) { type in
                    ExportTypeRow(
                        type: type,
                        isSelected: selectedExportType == type
                    ) {
                        selectedExportType = type
                        HapticFeedbackManager.shared.buttonTapped()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var exportButtonSection: some View {
        VStack(spacing: 16) {
            Button(action: startExport) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export Recordings")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .disabled(exportManager.isExporting)
            
            Text("Estimated file size: \(estimatedExportSize())")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var exportProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView(value: exportManager.exportProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 200)
                
                Text("Exporting...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(Int(exportManager.exportProgress * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(Color(.systemGray5))
            .cornerRadius(20)
        }
    }
    
    private func startExport() {
        HapticFeedbackManager.shared.buttonTapped()
        
        if recordings.count == 1 {
            exportManager.exportRecording(
                recordings[0],
                format: selectedFormat,
                quality: selectedQuality
            ) { result in
                handleExportResult(result)
            }
        } else {
            exportManager.exportMultipleRecordings(
                recordings,
                format: selectedFormat,
                quality: selectedQuality,
                as: selectedExportType
            ) { result in
                handleExportResult(result)
            }
        }
    }
    
    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            exportedURL = url
            showingShareSheet = true
            HapticFeedbackManager.shared.effectApplied()
            
        case .failure(let error):
            print("Export failed: \(error)")
            HapticFeedbackManager.shared.errorOccurred()
        }
    }
    
    private func formatTotalDuration() -> String {
        let totalDuration = recordings.reduce(0) { $0 + $1.duration }
        return AudioFileInfo.formatDuration(totalDuration)
    }
    
    private func formatTotalSize() -> String {
        let totalSize = recordings.reduce(0) { $0 + $1.size }
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    private func estimatedExportSize() -> String {
        let totalSize = recordings.reduce(0) { $0 + $1.size }
        let multiplier = selectedQuality.sizeMultiplier(for: selectedFormat)
        let estimatedSize = Int64(Double(totalSize) * multiplier)
        return ByteCountFormatter.string(fromByteCount: estimatedSize, countStyle: .file)
    }
}

struct FormatSelectionCard: View {
    let format: AudioFileFormat
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: format.iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(format.rawValue.uppercased())
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(format.description)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct QualitySelectionRow: View {
    let quality: ExportQuality
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quality.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text(quality.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ExportTypeRow: View {
    let type: MultipleExportType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension AudioFileFormat {
    var iconName: String {
        switch self {
        case .m4a:
            return "waveform"
        case .wav:
            return "waveform.path"
        case .mp3:
            return "music.note"
        case .aiff:
            return "waveform.path.ecg"
        }
    }
    
    var description: String {
        switch self {
        case .m4a:
            return "High quality, small size"
        case .wav:
            return "Uncompressed, large size"
        case .mp3:
            return "Compressed, compatible"
        case .aiff:
            return "Uncompressed, Apple format"
        }
    }
}

extension ExportQuality {
    var description: String {
        switch self {
        case .low:
            return "Smaller file size, lower quality"
        case .medium:
            return "Balanced size and quality"
        case .high:
            return "High quality, larger size"
        case .highest:
            return "Maximum quality, largest size"
        }
    }
    
    func sizeMultiplier(for format: AudioFileFormat) -> Double {
        switch self {
        case .low:
            return 0.3
        case .medium:
            return 0.6
        case .high:
            return 0.9
        case .highest:
            return 1.0
        }
    }
}

extension MultipleExportType {
    var description: String {
        switch self {
        case .individual:
            return "Export each recording as a separate file"
        case .merged:
            return "Combine all recordings into one file"
        case .zip:
            return "Package all files into a ZIP archive"
        }
    }
}
