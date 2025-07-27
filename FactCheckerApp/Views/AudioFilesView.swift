//
//  AudioFilesView.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import SwiftUI
import AVFoundation

struct AudioFilesView: View {
    @StateObject private var fileManager = AudioFileManager.shared
    @State private var audioFiles: [AudioFileInfo] = []
    @State private var selectedFiles: Set<URL> = []
    @State private var isSelectionMode = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var showingStorageInfo = false
    @State private var searchText = ""
    @State private var sortOption: SortOption = .dateModified
    @State private var isLoading = false
    
    private var filteredFiles: [AudioFileInfo] {
        let filtered = searchText.isEmpty ? audioFiles : audioFiles.filter { file in
            file.name.localizedCaseInsensitiveContains(searchText)
        }
        
        return filtered.sorted { file1, file2 in
            switch sortOption {
            case .name:
                return file1.name < file2.name
            case .dateCreated:
                return file1.creationDate > file2.creationDate
            case .dateModified:
                return file1.modificationDate > file2.modificationDate
            case .size:
                return file1.size > file2.size
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                searchAndFilterBar
                
                // Files List
                if filteredFiles.isEmpty {
                    emptyStateView
                } else {
                    filesList
                }
            }
            .navigationTitle("Audio Files")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if isSelectionMode {
                        selectionModeToolbar
                    } else {
                        normalModeToolbar
                    }
                }
            }
            .onAppear {
                loadAudioFiles()
            }
            .refreshable {
                loadAudioFiles()
            }
            .alert("Delete Files", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteSelectedFiles()
                }
            } message: {
                Text("Are you sure you want to delete \(selectedFiles.count) file(s)? This action cannot be undone.")
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: Array(selectedFiles))
            }
            .sheet(isPresented: $showingStorageInfo) {
                StorageInfoView()
            }
        }
    }
    
    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search audio files...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Sort Options
            HStack {
                Text("Sort by:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Sort", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Spacer()
                
                Button(action: { showingStorageInfo = true }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
            }
            .font(.caption)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Audio Files")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Audio recordings will appear here after you create them.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var filesList: some View {
        List {
            ForEach(filteredFiles, id: \.url) { file in
                AudioFileRowView(
                    file: file,
                    isSelected: selectedFiles.contains(file.url),
                    isSelectionMode: isSelectionMode,
                    onSelectionToggle: { toggleSelection(for: file.url) }
                )
                .onTapGesture {
                    if isSelectionMode {
                        toggleSelection(for: file.url)
                    } else {
                        // Play or open file
                        
