import Foundation
import Testing
@testable import SocialsCore

@Suite("WidgetSnapshot")
struct WidgetSnapshotTests {

    private func makeFiles() -> SharedCacheFiles {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return SharedCacheFiles(containerURL: dir)
    }

    @Test("writeWidgetSnapshot then readWidgetSnapshot round-trips the value")
    func roundTrip() throws {
        let files = makeFiles()
        let snapshot = WidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            posts: [
                WidgetSnapshotPost(
                    id: "post-1", title: "Launch announcement", channelName: "X",
                    scheduledAt: Date(timeIntervalSince1970: 1_700_100_000)),
                WidgetSnapshotPost(
                    id: "post-2", title: "Behind the scenes", channelName: "Instagram",
                    scheduledAt: Date(timeIntervalSince1970: 1_700_200_000)),
            ])

        try files.writeWidgetSnapshot(snapshot)

        #expect(files.readWidgetSnapshot() == snapshot)
    }

    @Test("readWidgetSnapshot returns nil when nothing has been written")
    func missingSnapshot() {
        let files = makeFiles()
        #expect(files.readWidgetSnapshot() == nil)
    }

    @Test("wipe removes a previously written snapshot")
    func wipeRemovesSnapshot() throws {
        let files = makeFiles()
        let snapshot = WidgetSnapshot(generatedAt: .now, posts: [])
        try files.writeWidgetSnapshot(snapshot)
        #expect(files.readWidgetSnapshot() != nil)

        try files.wipe()

        #expect(files.readWidgetSnapshot() == nil)
    }
}
