//
//  ContentView 2.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import SwiftUI

struct ContentView: View {
    @StateObject private var speechService = SpeechRecognitionService()
    @StateObject private var speakerService = SpeakerIdentificationService()
    @StateObject private var factCheckService = EnhancedFactCheckingService()
    @StateObject private var coordinator: FactCheckCoordinator
    @StateObject private var settingsManager = SettingsManager()
    
    @State private var selectedTab = 0
    @State private var showingSettings = false
    @State private var showingOnboarding = false
    
    init() {
        let speech = SpeechRecognitionService()
        let speaker = SpeakerIdentificationService()
        let factCheck = EnhancedFactCheckingService()
        let coord = FactCheckCoordinator(
            speechService: speech,
            speakerService: speaker,
            factCheckService: factCheck
        )
        
        self._coordinator = StateObject(wrappedValue: coord)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Main Fact Checking View
            MainFactCheckView(coordinator: coordinator)
                .tabItem {
                    Image(systemName: "checkmark.shield")
                    Text("Fact Check")
                }
                .tag(0)
            
            // History View
            HistoryView(coordinator: coordinator)
                .tabItem {
                    Image(systemName: "clock")
                    Text("History")
                }
                .tag(1)
            
            // Speaker Management
            SpeakerManagementView(speakerService: speakerService)
                .tabItem {
                    Image(systemName: "person.2")
                    Text("Speakers")
                }
                .tag(2)
            
            // Statistics View
            StatisticsView(coordinator: coordinator)
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Stats")
                }
                .tag(3)
            
            // Settings View
            SettingsView(settingsManager: settingsManager)
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(4)
        }
        .accentColor(.blue)
        .onAppear {
            if settingsManager.isFirstLaunch {
                showingOnboarding = true
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView(settingsManager: settingsManager)
        }
        .environmentObject(coordinator)
        .environmentObject(settingsManager)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
