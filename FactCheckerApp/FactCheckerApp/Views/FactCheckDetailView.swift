//
//  FactCheckDetailView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import SwiftUI
import SafariServices

struct FactCheckDetailView: View {
    let result: FactCheckResult
    @State private var showingSafari = false
    @State private var selectedURL: URL?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Card
                headerCard
                
                // Statement Analysis
                analysisCard
                
                // Sources Section
                if !result.sources.isEmpty {
                    sourcesSection
                }
                
                // Key Entities
                if !result.keyEntities.isEmpty {
                    entitiesSection
                }
                
                // Metadata
                metadataSection
            }
            .padding()
        }
        .navigationTitle("Fact Check Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSafari) {
            if let url = selectedURL {
                SafariView(url: url)
            }
        }
    }
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Truth Label and Confidence
            HStack {
                truthLabelView
                Spacer()
                confidenceView
            }
            
            // Statement
            Text(result.statement)
                .font(.title3)
                .fontWeight(.medium)
                .fixedSize(horizontal: false, vertical: true)
            
            // Speaker and Timestamp
            HStack {
                if !result.speakerId.isEmpty && result.speakerId != "Unknown" {
                    Label(result.speakerId, systemImage: "person.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(result.timestamp, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var truthLabelView: some View {
        HStack(spacing: 6) {
            Image(systemName: result.truthLabel.iconName)
                .font(.title2)
            Text(result.truthLabel.displayName)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .foregroundColor(result.truthLabel.color)
    }
    
    private var confidenceView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Confidence")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(result.confidence * 100, specifier: "%.1f")%")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(confidenceColor)
        }
    }
    
    private var confidenceColor: Color {
        if result.confidence > 0.8 { return .green }
        else if result.confidence > 0.6 { return .orange }
        else { return .red }
    }
    
    private var analysisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analysis")
                .font(.headline)
            
            Text(result.explanation)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            
            // Truth Score Bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Truth Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(result.truthScore * 100, specifier: "%.1f")%")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                ProgressView(value: result.truthScore)
                    .progressViewStyle(LinearProgressViewStyle(tint: result.truthLabel.color))
            }
            
            // Claim Type and Sentiment
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Claim Type")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(result.claimType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Sentiment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(sentimentText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(sentimentColor)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var sentimentText: String {
        if result.sentiment > 0.3 { return "Positive" }
        else if result.sentiment < -0.3 { return "Negative" }
        else { return "Neutral" }
    }
    
    private var sentimentColor: Color {
        if result.sentiment > 0.3 { return .green }
        else if result.sentiment < -0.3 { return .red }
        else { return .gray }
    }
    
    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sources (\(result.sources.count))")
                .font(.headline)
            
            LazyVStack(spacing: 8) {
                ForEach(result.sources, id: \.id) { source in
                    SourceRowView(source: source) {
                        if let url = URL(string: source.url) {
                            selectedURL = url
                            showingSafari = true
                        }
                    }
                }
            }
        }
    }
    
    private var entitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Entities")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 80))
            ], spacing: 8) {
                ForEach(result.keyEntities, id: \.self) { entity in
                    Text(entity)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata")
                .font(.headline)
            
            VStack(spacing: 8) {
                MetadataRow(label: "Fact Check ID", value: result.id.uuidString)
                MetadataRow(label: "Timestamp", value: DateFormatter.detailed.string(from: result.timestamp))
                MetadataRow(label: "Processing Time", value: "< 1 second") // This would be calculated
                MetadataRow(label: "Sources Checked", value: "\(result.sources.count)")
                MetadataRow(label: "Average Source Credibility", value: String(format: "%.1f", averageSourceCredibility))
            }
        }
    }
    
    private var averageSourceCredibility: Double {
        guard !result.sources.isEmpty else { return 0.0 }
        return result.sources.reduce(0.0) { $0 + $1.credibilityScore } / Double(result.sources.count)
    }
}

struct SourceRowView: View {
    let source: RealTimeSource
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Source type icon
                    Image(systemName: source.sourceType.iconName)
                        .foregroundColor(source.sourceType.color)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Text(source.domain)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Credibility score
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Credibility")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(source.credibilityScore * 100, specifier: "%.0f")%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(credibilityColor)
                    }
                }
                
                if let excerpt = source.excerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                
                HStack {
                    if let author = source.author {
                        Text("By \(author)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let publishDate = source.publishDate {
                        Text(publishDate, style: .date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var credibilityColor: Color {
        if source.credibilityScore > 0.8 { return .green }
        else if source.credibilityScore > 0.6 { return .orange }
        else { return .red }
    }
}

struct MetadataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Extensions

extension RealTimeSource.SourceType {
    var iconName: String {
        switch self {
        case .news: return "newspaper"
        case .academic: return "graduationcap"
        case .government: return "building.columns"
        case .factCheck: return "checkmark.shield"
        case .social: return "bubble.left.and.bubble.right"
        case .encyclopedia: return "book.closed"
        }
    }
    
    var color: Color {
        switch self {
        case .news: return .blue
        case .academic: return .purple
        case .government: return .green
        case .factCheck: return .orange
        case .social: return .pink
        case .encyclopedia: return .brown
        }
    }
}

extension ClaimType {
    var displayName: String {
        switch self {
        case .factual: return "Factual"
        case .statistical: return "Statistical"
        case .historical: return "Historical"
        case .scientific: return "Scientific"
        case .political: return "Political"
        case .economic: return "Economic"
        case .health: return "Health"
        case .opinion: return "Opinion"
        case .prediction: return "Prediction"
        case .other: return "Other"
        }
    }
}

extension DateFormatter {
    static let detailed: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter
    }()
}
