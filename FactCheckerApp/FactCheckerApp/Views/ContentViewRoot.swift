//
//  ContentView 2.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import SwiftUI

struct ContentView: View {
    @EnvironmentObject var coordinator: FactCheckCoordinator
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if settingsManager.isFirstLaunch {
                OnboardingView(settingsManager: settingsManager)
            } else {
                mainTabView
            }
        }
        .onAppear {
            coordinator.initialize()
        }
    }
    
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            // Main Fact Check View
            MainFactCheckView()
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
            
            // Statistics View
            StatisticsView(coordinator: coordinator)
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Statistics")
                }
                .tag(2)
            
            // Speaker Management View
            SpeakerManagementView(speakerService: coordinator.speakerService)
                .tabItem {
                    Image(systemName: "person.2")
                    Text("Speakers")
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
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(FactCheckCoordinator())
            .environmentObject(SettingsManager())
    }
}
