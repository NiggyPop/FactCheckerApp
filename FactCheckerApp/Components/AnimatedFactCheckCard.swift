//
//  AnimatedFactCheckCard.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import SwiftUI

struct AnimatedFactCheckCard: View {
    let result: FactCheckResult
    @State private var isExpanded = false
    @State private var showSources = false
    @State private var animationPhase: AnimationPhase = .initial
    
    enum AnimationPhase {
        case initial
        case processing
        case result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card content
            VStack(alignment: .leading, spacing: 12) {
                // Header with veracity indicator
                HStack {
                    veracityIndicator
                    
                    Spacer()
                    
                    confidenceIndicator
                }
                
                // Statement
                Text(result.statement)
                    .font(.body)
                    .lineLimit(isExpanded ? nil : 3)
                    .animation(.easeInOut, value: isExpanded)
                
                // Expand/Collapse button
                if result.statement.count > 100 {
                    Button(action: {
                        withAnimation(.spring()) {
                            isExpanded.toggle()
                        }
                    }) {
                        Text(isExpanded ? "Show Less" : "Show More")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                // Quick stats
                HStack {
                    Label("\(result.sources.count)", systemImage: "doc.text")
                    
                    Spacer()
                    
                    Label(formatProcessingTime(result.processingTime), systemImage: "clock")
                    
                    Spacer()
                    
                    Label(result.claimType.rawValue.capitalized, systemImage: "tag")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                // Action buttons
                HStack {
                    Button("Sources") {
                        withAnimation(.spring()) {
                            showSources.toggle()
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Share") {
                        shareResult()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Feedback") {
                        provideFeedback()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            
            // Sources section (expandable)
            if showSources {
                Divider()
                
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(result.sources, id: \.url) { source in
                        SourceRowView(source: source)
                    }
                }
                .padding()
                .transition(.slide.combined(with: .opacity))
            }
        }
        .background(cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .scaleEffect(animationPhase == .initial ? 0.9 : 1.0)
        .opacity(animationPhase == .initial ? 0 : 1)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animationPhase = .result
            }
        }
    }
    
    private var veracityIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: result.veracity.iconName)
                .foregroundColor(result.veracity.color)
                .font(.title2)
            
            Text(result.veracity.displayName)
                .font(.headline)
                .foregroundColor(result.veracity.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(result.veracity.color.opacity(0.1))
        .cornerRadius(20)
    }
    
    private var confidenceIndicator: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(Int(result.confidence * 100))%")
                .font(.headline)
                .foregroundColor(confidenceColor)
            
            Text("Confidence")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(result.veracity.color.opacity(0.3), lineWidth: 1)
            )
    }
    
    private var confidenceColor: Color {
        switch result.confidence {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
    
    private func formatProcessingTime(_ time: TimeInterval) -> String {
        if time < 1.0 {
            return "\(Int(time * 1000))ms"
        } else {
            return String(format: "%.1fs", time)
        }
    }
    
    private func shareResult() {
        // Implement sharing functionality
        let shareText = "FactCheck Pro: \"\(result.statement)\" - \(result.veracity.displayName) (\(Int(result.confidence * 100))% confidence)"
        
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func provideFeedback() {
        // Implement feedback functionality
        // This could open a feedback form or rating system
    }
}

struct SourceRowView: View {
    let source: FactCheckSource
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Credibility indicator
            Circle()
                .fill(credibilityColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(source.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text(source.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                HStack {
                    Text(URL(string: source.url)?.host ?? source.url)
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("Credibility: \(Int(source.credibilityScore * 100))%")
                        .font(.caption2)
                        .foregroundColor(credibilityColor)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            openURL(source.url)
        }
    }
    
    private var credibilityColor: Color {
        switch source.credibilityScore {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

extension FactVeracity {
    var iconName: String {
        switch self {
        case .true:
            return "checkmark.circle.fill"
        case .false:
            return "xmark.circle.fill"
        case .mixed:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
    
    var displayName: String {
        switch self {
        case .true:
            return L("statement_true")
        case .false:
            return L("statement_false")
        case .mixed:
            return L("statement_mixed")
        case .unknown:
            return L("statement_unknown")
        }
    }
    
    var color: Color {
        switch self {
        case .true:
            return .factCheckGreen
        case .false:
            return .factCheckRed
        case .mixed:
            return .factCheckOrange
        case .unknown:
            return .factCheckGray
        }
    }
}
