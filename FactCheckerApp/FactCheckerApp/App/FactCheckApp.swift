import SwiftUI
import Speech
import AVFoundation

@main
struct FactCheckerApp: App {
    @StateObject private var speechService = SpeechRecognitionService()
    @StateObject private var speakerService = SpeakerIdentificationService()
    @StateObject private var factCheckService = EnhancedFactCheckingService()
    @StateObject private var coordinator: FactCheckCoordinator
    
    init() {
        let speech = SpeechRecognitionService()
        let speaker = SpeakerIdentificationService()
        let factCheck = EnhancedFactCheckingService()
        
        _speechService = StateObject(wrappedValue: speech)
        _speakerService = StateObject(wrappedValue: speaker)
        _factCheckService = StateObject(wrappedValue: factCheck)
        _coordinator = StateObject(wrappedValue: FactCheckCoordinator(
            speechService: speech,
            speakerService: speaker,
            factCheckService: factCheck
        ))
        
        setupAppearance()
        requestPermissions()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(speechService)
                .environmentObject(speakerService)
                .environmentObject(factCheckService)
                .environmentObject(coordinator)
                .preferredColorScheme(.dark)
        }
    }
    
    private func setupAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.clear
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 20, weight: .semibold)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
    
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }
}
