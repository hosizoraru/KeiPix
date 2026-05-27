import Foundation
import Testing
@testable import KeiPix

/// Exercises the value-typed `ReaderWindowArtworkRegistry` directly
/// rather than going through `KeiPixStore`. The store's initializer
/// reaches AppKit/bundle code that swift-test doesn't have a host
/// for, so we prove the bounded-cache contract on the registry
/// itself — that's where the eviction and lookup logic lives.
@Suite("Reader window artwork registry")
struct ReaderWindowRegistryTests {

    @Test("Registering an artwork returns its id and stores it for later resolution")
    func registerRoundTrip() {
        var registry = ReaderWindowArtworkRegistry()
        let artwork = VisualQASampleData.galleryLayoutArtworks[0]

        let returnedID = registry.register(artwork)

        #expect(returnedID == artwork.id)
        #expect(registry.artwork(id: artwork.id)?.id == artwork.id)
    }

    @Test("Registry stays bounded — overflow evicts the oldest IDs first")
    func registryEvictsOnOverflow() {
        var registry = ReaderWindowArtworkRegistry()
        let cap = ReaderWindowArtworkRegistry.cap

        // Pull a real sample artwork to clone — the registry stores
        // by identity but we only need distinct ids for this test.
        let template = VisualQASampleData.galleryLayoutArtworks[0]

        // Register cap + 5 artworks with synthetic ids 1...(cap + 5).
        // The registry should evict the 5 lowest ids (1...5) on
        // overflow, keeping ids 6...(cap + 5) resident.
        for index in 1...(cap + 5) {
            let cloned = clonedArtwork(from: template, withID: index)
            registry.register(cloned)
        }

        #expect(registry.count == cap)
        for evictedID in 1...5 {
            #expect(
                registry.artwork(id: evictedID) == nil,
                "id \(evictedID) should have been evicted"
            )
        }
        for resident in 6...(cap + 5) {
            #expect(
                registry.artwork(id: resident) != nil,
                "id \(resident) should still be resident"
            )
        }
    }

    @Test("Registry returns nil for ids it has never seen")
    func unknownIDReturnsNil() {
        let registry = ReaderWindowArtworkRegistry()
        #expect(registry.artwork(id: 999_999_999) == nil)
    }

    @Test("Re-registering the same id refreshes the entry without growing the registry")
    func reRegisterIsIdempotentInSize() {
        var registry = ReaderWindowArtworkRegistry()
        let template = VisualQASampleData.galleryLayoutArtworks[0]
        let cloned = clonedArtwork(from: template, withID: 42)

        registry.register(cloned)
        registry.register(cloned)
        registry.register(cloned)

        #expect(registry.count == 1)
        #expect(registry.artwork(id: 42)?.id == 42)
    }

    /// Re-encodes the sample artwork JSON with a fresh id so we can
    /// build distinct entries without exposing the private decoder
    /// in VisualQASampleData. Keeping this here also keeps the test
    /// honest about what the registry treats as identity (the id).
    private func clonedArtwork(from artwork: PixivArtwork, withID id: Int) -> PixivArtwork {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(artwork),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return artwork
        }
        json["id"] = id
        guard let mutated = try? JSONSerialization.data(withJSONObject: json),
              let decoded = try? JSONDecoder().decode(PixivArtwork.self, from: mutated)
        else {
            return artwork
        }
        return decoded
    }
}
