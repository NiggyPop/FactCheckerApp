//
//  OnboardingView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import SwiftUI

struct OnboardingView: View {
    @ObservedObject var settingsManager: SettingsManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var currentPage = 0
    @State private var showingPermissions = false
    
    private let pages = OnboardingPage.allPages
    
    var body: some View {
        VStack(spacing: 0) {
            // Page Indicator
            HStack {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut, value: currentPage)
                }
            }
            .padding(.top, 20)
            
            // Content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Navigation Buttons
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                if currentPage < pages.count - 1 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
                } else {
                    Button("Get Started") {
                        showingPermissions = true
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(25)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
        .sheet(isPresented: $showingPermissions) {
            PermissionsView(settingsManager: settingsManager) {
                settingsManager.completeOnboarding()
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon
            Image(systemName: page.iconName)
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            // Title
            Text(page.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            Text(page.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

struct PermissionsView: View {
    @ObservedObject var settingsManager: SettingsManager
    let onComplete: () -> Void
    
    @State private var microphonePermission: PermissionStatus = .notDetermined
    @State private var speechRecognitionPermission: PermissionStatus = .notDetermined
    @State private var notificationPermission: PermissionStatus = .notDetermined
    
    enum PermissionStatus {
        case notDetermined
        case granted
        case denied
        case requesting
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Permissions Required")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("FactCheck Pro needs these permissions to work properly")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Permissions List
            VStack(spacing: 20) {
                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    description: "Required to listen to and transcribe speech",
                    status: microphonePermission,
                    action: requestMicrophonePermission
                )
                
                PermissionRow(
                    icon: "waveform",
                    title: "Speech Recognition",
                    description: "Converts speech to text for fact-checking",
                    status: speechRecognitionPermission,
                    action: requestSpeechRecognitionPermission
                )
                
                PermissionRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    description: "Get alerts about fact-check results",
                    status: notificationPermission,
                    action: requestNotificationPermission
                )
            }
            
            Spacer()
            
            // Continue Button
            Button("Continue") {
                onComplete()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(allPermissionsGranted ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(!allPermissionsGranted)
        }
        .padding()
        .onAppear {
            checkCurrentPermissions()
        }
    }
    
    private var allPermissionsGranted: Bool {
        microphonePermission == .granted && speechRecognitionPermission == .granted
    }
    
    private func checkCurrentPermissions() {
        // Check microphone permission
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            microphonePermission = .granted
        case .denied:
            microphonePermission = .denied
        case .undetermined:
            microphonePermission = .notDetermined
        @unknown default:
            microphonePermission = .notDetermined
        }
        
        // Check speech recognition permission
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            speechRecognitionPermission = .granted
        case .denied, .restricted:
            speechRecognitionPermission = .denied
        case .notDetermined:
            speechRecognitionPermission = .notDetermined
        @unknown default:
            speechRecognitionPermission = .notDetermined
        }
        
        // Check notification permission
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    notificationPermission = .granted
                case .denied:
                    notificationPermission = .denied
                case .notDetermined:
                    notificationPermission = .notDetermined
                @unknown default:
                    notificationPermission = .notDetermined
                }
            }
        }
    }
    
    private func requestMicrophonePermission() {
        microphonePermission = .requesting
        
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                microphonePermission = granted ? .granted : .denied
            }
        }
    }
    
    private func requestSpeechRecognitionPermission() {
        speechRecognitionPermission = .requesting
        
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    speechRecognitionPermission = .granted
                case .denied, .restricted:
                    speechRecognitionPermission = .denied
                case .notDetermined:
                    speechRecognitionPermission = .notDetermined
                @unknown default:
                    speechRecognitionPermission = .denied
                }
            }
        }
    }
    
    private func requestNotificationPermission() {
        notificationPermission = .requesting
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                notificationPermission = granted ? .granted : .denied
            }
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionsView.PermissionStatus
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            // Status/Action
            Group {
                switch status {
                case .notDetermined:
                    Button("Allow") {
                        action()
                    }
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                    
                case .requesting:
                    ProgressView()
                        .scaleEffect(0.8)
                    
                case .granted:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                case .denied:
                    Button("Settings") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                    .foregroundColor(.orange)
                    .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct OnboardingPage {
    let iconName: String
    let title: String
    let description: String
    
    static let allPages = [
        OnboardingPage(
            iconName: "checkmark.shield.fill",
            title: "Real-time Fact Checking",
            description: "Automatically verify statements as they're spoken using advanced AI and multiple reliable sources."
        ),
        OnboardingPage(
            iconName: "person.2.wave.2.fill",
            title: "Speaker Identification",
            description: "Identify different speakers and track their fact-checking history over time."
        ),
        OnboardingPage(
            iconName: "chart.line.uptrend.xyaxis",
            title: "Detailed Analytics",
            description: "View comprehensive statistics about accuracy rates, claim types, and verification trends."
        ),
        OnboardingPage(
            iconName: "lock.shield.fill",
            title: "Privacy First",
            description: "Your data stays on your device. Audio processing is done locally whenever possible."
        )
    ]
}
