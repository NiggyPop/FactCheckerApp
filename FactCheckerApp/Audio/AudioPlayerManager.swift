//
//  AudioPlayerManager.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/26/25.
//


import Foundation
import AVFoundation
import MediaPlayer
import Combine

class AudioPlayerManager: NSObject, ObservableObject {
    static let shared = AudioPlayerManager()
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentFile: AudioFileInfo?
    @Published var playbackRate: Float = 1.0
    @Published var volume: Float = 1.0
    @Published var isLooping = false
    @Published var playbackError: Error?
    
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    private var audioSession = AVAudioSession.sharedInstance()
    
    override init() {
        super.init()
        setupAudioSession()
        setupRemoteTransportControls()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.stopCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.skipForward(15)
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.skipBackward(15)
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: event.positionTime)
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.changePlaybackRateCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackRateCommandEvent {
                self?.setPlaybackRate(event.playbackRate)
                return .success
            }
            return .commandFailed
        }
    }
    
    // MARK: - Playback Control
    
    func loadFile(_ file: AudioFileInfo) {
        stop()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: file.url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            currentFile = file
            duration = audioPlayer?.duration ?? 0
            currentTime = 0
            playbackError = nil
            
            updateNowPlayingInfo()
            
        } catch {
            playbackError = error
            print("Failed to load audio file: \(error)")
        }
    }
    
    func play() {
        guard let player = audioPlayer else { return }
        
        do {
            try audioSession.setActive(true)
            player.play()
            isPlaying = true
            startPlaybackTimer()
            updateNowPlayingInfo()
        } catch {
            playbackError = error
            print("Failed to start playback: \(error)")
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopPlaybackTimer()
        updateNowPlayingInfo()
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        stopPlaybackTimer()
        updateNowPlayingInfo()
    }
    
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        
        let clampedTime = max(0, min(time, duration))
        player.currentTime = clampedTime
        currentTime = clampedTime
        updateNowPlayingInfo()
    }
    
    func skipForward(_ seconds: TimeInterval) {
        seek(to: currentTime + seconds)
    }
    
    func skipBackward(_ seconds: TimeInterval) {
        seek(to: currentTime - seconds)
    }
    
    func setPlaybackRate(_ rate: Float) {
        guard let player = audioPlayer else { return }
        
        let clampedRate = max(0.5, min(rate, 2.0))
        player.rate = clampedRate
        playbackRate = clampedRate
        
        if isPlaying {
            player.play()
        }
        
        updateNowPlayingInfo()
    }
    
    func setVolume(_ volume: Float) {
        guard let player = audioPlayer else { return }
        
        let clampedVolume = max(0.0, min(volume, 1.0))
        player.volume = clampedVolume
        self.volume = clampedVolume
    }
    
    func toggleLoop() {
        guard let player = audioPlayer else { return }
        
        isLooping.toggle()
        player.numberOfLoops = isLooping ? -1 : 0
    }
    
    // MARK: - Timer Management
    
    private func startPlaybackTimer() {
        stopPlaybackTimer()
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateCurrentTime()
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func updateCurrentTime() {
        guard let player = audioPlayer else { return }
        currentTime = player.currentTime
    }
    
    // MARK: - Now Playing Info
    
    private func updateNowPlayingInfo() {
        guard let file = currentFile else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: file.name,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackRate : 0.0
        ]
        
        // Add artwork if available
        if let artwork = generateAudioArtwork() {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func generateAudioArtwork() -> MPMediaItemArtwork? {
        let size = CGSize(width: 300, height: 300)
        
        return MPMediaItemArtwork(boundsSize: size) { _ in
            let renderer = UIGraphicsImageRenderer(size: size)
            
            return renderer.image { context in
                // Create gradient background
                let colors = [UIColor.blue.cgColor, UIColor.purple.cgColor]
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors as CFArray,
                                        locations: nil)!
                
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
                
                // Add waveform icon
                let iconSize: CGFloat = 100
                let iconRect = CGRect(
                    x: (size.width - iconSize) / 2,
                    y: (size.height - iconSize) / 2,
                    width: iconSize,
                    height: iconSize
                )
                
                UIColor.white.setFill()
                
                let waveformPath = UIBezierPath()
                let barWidth: CGFloat = 8
                let barSpacing: CGFloat = 4
                let numberOfBars = Int(iconSize / (barWidth + barSpacing))
                
                for i in 0..<numberOfBars {
                    let x = iconRect.minX + CGFloat(i) * (barWidth + barSpacing)
                    let height = CGFloat.random(in: 20...60)
                    let y = iconRect.midY - height / 2
                    
                    let barRect = CGRect(x: x, y: y, width: barWidth, height: height)
                    waveformPath.append(UIBezierPath(roundedRect: barRect, cornerRadius: barWidth / 2))
                }
                
                waveformPath.fill()
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag && !isLooping {
            isPlaying = false
            currentTime = 0
            stopPlaybackTimer()
            updateNowPlayingInfo()
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            playbackError = error
            print("Audio player decode error: \(error)")
        }
        
        isPlaying = false
        stopPlaybackTimer()
    }
}
