import XCTest
@testable import FactCheckerApp

class SyncWorkflowTests: XCTestCase {
    func testSyncRecordingsUpdatesState() async {
        let manager = CloudSyncManager.shared
        await manager.syncRecordings()
        XCTAssertFalse(manager.isSyncing)
        XCTAssertNotNil(manager.lastSyncDate)
    }
}
