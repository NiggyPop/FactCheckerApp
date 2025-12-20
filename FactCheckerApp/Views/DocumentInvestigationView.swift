//
//  DocumentInvestigationView.swift
//  FactCheckerApp
//
//  Created by OpenAI Assistant on 7/13/24.
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentInvestigationView: View {
    @StateObject private var manager = InvestigationManager()
    @State private var showingImporter = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    summarySection
                    fileImportSection
                    if !manager.detectedFigures.isEmpty {
                        figuresSection
                    }
                    if !manager.aggregatedConnections.isEmpty {
                        connectionsSection
                    }
                    if !manager.timeline.isEmpty {
                        timelineSection
                    }
                    if !manager.documents.isEmpty {
                        documentsSection
                    }
                }
                .padding()
            }
            .navigationTitle("File Investigator")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        manager.clear()
                    } label: {
                        Label("Reset", systemImage: "trash")
                    }
                    .disabled(manager.documents.isEmpty)
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: manager.supportedTypes,
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    manager.importDocuments(from: urls)
                case .failure(let error):
                    manager.errorMessage = error.localizedDescription
                }
            }
            .overlay(alignment: .bottom) {
                if manager.isProcessing {
                    ProgressView("Analyzing documents...")
                        .padding()
                        .background(.thinMaterial)
                        .cornerRadius(12)
                        .padding(.bottom, 16)
                }
            }
        }
        .alert("Unable to import files", isPresented: Binding(get: {
            manager.errorMessage != nil
        }, set: { _ in
            manager.errorMessage = nil
        })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(manager.errorMessage ?? "")
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Upload files to map key people, connections, and timelines.")
                .font(.callout)
                .foregroundColor(.secondary)
            HStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("Multi-file investigator")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var summarySection: some View {
        let summary = manager.summary
        return HStack(spacing: 12) {
            SummaryCard(title: "Files", value: "\(summary.documentsCount)", icon: "doc.on.doc")
            SummaryCard(title: "Figures", value: "\(summary.figureCount)", icon: "person.3.fill")
            SummaryCard(title: "Connections", value: "\(summary.connectionCount)", icon: "link")
            SummaryCard(title: "Events", value: "\(summary.eventCount)", icon: "calendar")
        }
    }
    
    private var fileImportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upload files")
                    .font(.headline)
                Spacer()
                Button {
                    showingImporter = true
                } label: {
                    Label("Add Files", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
            }
            
            Text("Drop in emails, PDFs, research notes, contracts, or exports. The app will extract key people, highlight ties like real estate deals, and build a dated storyline.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
    
    private var figuresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Detected public figures", icon: "person.crop.circle.badge.checkmark")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(manager.detectedFigures) { figure in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(figure.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Chip(text: "\(Int(figure.confidence * 100))%")
                            }
                            Text(figure.role)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if !figure.relatedEntities.isEmpty {
                                Text(figure.relatedEntities.joined(separator: " • "))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    private var connectionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Pertinent connections", icon: "link.circle")
            LazyVStack(spacing: 12) {
                ForEach(manager.aggregatedConnections) { connection in
                    ConnectionCard(connection: connection)
                }
            }
        }
    }
    
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Timeline of events", icon: "clock.arrow.circlepath")
            TimelinePlot(events: manager.timeline)
        }
    }
    
    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Files analyzed", icon: "doc.richtext")
            LazyVStack(spacing: 12) {
                ForEach(manager.documents) { document in
                    DocumentCard(document: document)
                }
            }
        }
    }
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.headline)
            Spacer()
        }
    }
}

private struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

private struct Chip: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.15))
            .foregroundColor(.blue)
            .cornerRadius(8)
    }
}

private struct ConnectionCard: View {
    let connection: ConnectionInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(connection.title, systemImage: connection.type.iconName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Chip(text: "\(Int(connection.confidence * 100))%")
            }
            Text(connection.detail)
                .font(.caption)
                .foregroundColor(.secondary)
            if !connection.relatedFigures.isEmpty {
                Text(connection.relatedFigures.joined(separator: " • "))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

private struct TimelinePlot: View {
    let events: [TimelineEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                HStack(alignment: .top, spacing: 12) {
                    VStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 10, height: 10)
                        if index < events.count - 1 {
                            Rectangle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 2)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Chip(text: "\(Int(event.relevanceScore * 100))%")
                        }
                        Text(event.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(event.context)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if !event.linkedFigures.isEmpty {
                            Text("Figures: \(event.linkedFigures.joined(separator: \", \"))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

private struct DocumentCard: View {
    let document: InvestigatedDocument
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(document.fileName, systemImage: "doc.text.fill")
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Text(fileSize(document.fileSize))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !document.detectedFigures.isEmpty {
                Text(document.detectedFigures.map { $0.name }.joined(separator: " • "))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(document.textPreview)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            HStack {
                Label("\(document.connections.count) connections", systemImage: "link")
                    .font(.caption)
                Spacer()
                Label("\(document.events.count) events", systemImage: "clock")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func fileSize(_ size: Int64) -> String {
        guard size > 0 else { return "Unknown size" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

struct DocumentInvestigationView_Previews: PreviewProvider {
    static var previews: some View {
        DocumentInvestigationView()
    }
}
