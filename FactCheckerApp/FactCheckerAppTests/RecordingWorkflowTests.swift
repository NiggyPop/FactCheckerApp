import XCTest
import AVFoundation
@testable import FactCheckerApp

class RecordingWorkflowTests: XCTestCase {
    func testSavingRecordingCreatesFile() async throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4410) else {
            XCTFail("Failed to create buffer")
            return
        }
        buffer.frameLength = 4410

        let url = try await AudioFileManager.shared.saveAudioFile(buffer, filename: "TestRecording")
        defer { try? AudioFileManager.shared.deleteAudioFile(at: url) }

        let files = AudioFileManager.shared.getAllAudioFiles()
        XCTAssertTrue(files.contains(where: { $0.url == url }))
    }
}
