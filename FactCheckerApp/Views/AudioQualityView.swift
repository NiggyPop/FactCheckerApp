//
//  AudioQualityView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import SwiftUI

struct AudioQualityView: View {
    let audioQuality: AudioQuality
    @State private var showingDetails = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Quality Score Display
            qualityScoreView
            
            // Issues Summary
            if !audioQuality.issues.isEmpty {
                issuesSummaryView
            }
            
            // Recommendations
            if !audioQuality.recommendations.isEmpty {
                recommendationsView
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var qualityScoreView: some View {
        VStack(spacing: 12) {
            Text("Audio Quality")
                .font(.headline)
                .foregroundColor(.primary)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: CGFloat(audioQuality.score))
                    .stroke(
                        Color(audioQuality.color),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: audioQuality.score)
                
                VStack {
                    Text("\(Int(audioQuality.score * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(audioQuality.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var issuesSummaryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text("Issues Detected")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            ForEach(audioQuality.issues.prefix(3), id: \.description) { issue in
                HStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                    
                    Text(issue.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            
            if audioQuality.issues.count > 3 {
                Button("Show All Issues") {
                    showingDetails = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var recommendationsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.blue)
                
                Text("Recommendations")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            ForEach(audioQuality.recommendations.prefix(2), id: \.self) { recommendation in
                HStack(alignment: .top) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    
                    Text(recommendation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
            }
            
            if audioQuality.recommendations.count > 2 {
                Button("Show All Recommendations") {
                    showingDetails = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct AudioQualityDetailView: View {
    let audioQuality: AudioQuality
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Overall Score
                    AudioQualityView(audioQuality: audioQuality)
                    
                    // Detailed Issues
                    if !audioQuality.issues.isEmpty {
                        detailedIssuesView
                    }
                    
                    // Detailed Recommendations
                    if !audioQuality.recommendations.isEmpty {
                        detailedRecommendationsView
                    }
                    
                    // Quality Metrics
                    qualityMetricsView
                }
                .padding()
            }
            .navigationTitle("Audio Quality Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var detailedIssuesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detected Issues")
                .font(.title2)
                .fontWeight(.semibold)
            
            ForEach(audioQuality.issues, id: \.description) { issue in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(issue.description)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Text(getIssueExplanation(issue))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    private var detailedRecommendationsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommendations")
                .font(.title2)
                .fontWeight(.semibold)
            
            ForEach(Array(audioQuality.recommendations.enumerated()), id: \.offset) { index, recommendation in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 24, height: 24)
                        
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Text(recommendation)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    private var qualityMetricsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quality Metrics")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                QualityMetricRow(
                    title: "Overall Score",
                    value: "\(Int(audioQuality.score * 100))%",
                    color: Color(audioQuality.color)
                )
                
                QualityMetricRow(
                    title: "Issues Found",
                    value: "\(audioQuality.issues.count)",
                    color: audioQuality.issues.isEmpty ? .green : .orange
                )
                
                QualityMetricRow(
                    title: "Quality Level",
                    value: audioQuality.description,
                    color: Color(audioQuality.color)
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private func getIssueExplanation(_ issue: AudioQualityIssue) -> String {
        switch issue {
        case .noSignal:
            return "No audio input detected. Check microphone connection and permissions."
        case .lowSignalLevel:
            return "Audio signal is too quiet, which may affect transcription accuracy."
        case .highSignalLevel:
            return "Audio signal is too loud, which may cause distortion."
        case .highNoiseLevel:
            return "Significant background noise detected that may interfere with speech recognition."
        case .moderateNoise:
            return "Some background noise present. Consider using noise reduction."
        case .clipping:
            return "Audio signal is being cut off at peaks, causing distortion."
        case .occasionalClipping:
            return "Intermittent clipping detected. Slightly reduce input gain."
        case .poorFrequencyResponse:
            return "Frequency balance is not optimal for speech clarity."
        case .limitedDynamicRange:
            return "Audio appears over-compressed, reducing natural dynamics."
        case .excessiveDynamicRange:
            return "Large volume variations may affect consistent processing."
        }
    }
}

struct QualityMetricRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}
