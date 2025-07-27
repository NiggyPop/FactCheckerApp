import XCTest
import AVFoundation
@testable import FactCheckerApp

class ExportWorkflowTests: XCTestCase {
    func testExportRecordingCompletes() async throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4410) else {
            XCTFail("Failed to create buffer")
            return
        }
        buffer.frameLength = 4410

        let recordingURL = try await AudioFileManager.shared.saveAudioFile(buffer, filename: "ExportWorkflowTest")
        defer { try? AudioFileManager.shared.deleteAudioFile(at: recordingURL) }

        let info = AudioFileInfo(
            url: recordingURL,
            name: "ExportWorkflowTest",
            size: Int(buffer.frameLength),
            creationDate: Date(),
            modificationDate: Date(),
            format: .m4a
        )

        let expectation = XCTestExpectation(description: "Export finished")
        ExportManager.shared.exportRecording(info, format: .m4a, quality: .low) { result in
            switch result {
            case .success(let outputURL):
                XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
                try? FileManager.default.removeItem(at: outputURL)
            case .failure(let error):
                XCTFail("Export failed: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }
}
