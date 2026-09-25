import XCTest

final class RuntimeContractsTests: XCTestCase {
    func testWorkspaceStateKeepsProviderNamespaceAndUnknownOccupancy() throws {
        let state = WorkspaceState(
            id: WorkspaceID(provider: ProviderID("yabai"), rawID: "1"),
            name: "one",
            display: DisplayID("display"),
            focused: true,
            visible: true,
            occupied: nil
        )
        let batch = ProviderStateBatch(source: ProviderID("yabai"), generation: 4, sequence: 9, value: [state])
        let decoded = try JSONDecoder().decode(ProviderStateBatch<[WorkspaceState]>.self, from: JSONEncoder().encode(batch))
        XCTAssertEqual(decoded, batch)
        XCTAssertNil(decoded.value.first?.occupied)
        XCTAssertEqual(decoded.value.first?.id.provider, ProviderID("yabai"))
    }

    func testConfigurationRoundTripsStableIDsAndReferences() throws {
        let configuration = AppConfiguration(surfaces: [SurfaceSpec(id: SurfaceID("main"), start: [ModuleID("clock")])], modules: [ModuleSpec(id: ModuleID("clock"), kind: .clock)])
        let data = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(AppConfiguration.self, from: data)
        XCTAssertEqual(decoded, configuration)
        XCTAssertEqual(decoded.surfaces.first?.start.first?.rawValue, "clock")
    }

    func testSurfaceEdgesAreComplete() { XCTAssertEqual(Set(SurfaceEdge.allCases), [.top, .bottom, .left, .right]) }

    func testDisplaySelectorsDetectPotentialSurfaceCollisions() {
        XCTAssertTrue(DisplaySelector.all.mayResolveSameDisplay(as: .primary))
        XCTAssertTrue(DisplaySelector.primary.mayResolveSameDisplay(as: .id(DisplayID("main"))))
        XCTAssertTrue(DisplaySelector.id(DisplayID("main")).mayResolveSameDisplay(as: .id(DisplayID("main"))))
        XCTAssertFalse(DisplaySelector.id(DisplayID("main")).mayResolveSameDisplay(as: .id(DisplayID("aux"))))
    }

    func testConfigurationRejectsOverlappingResolvedDisplaySelectors() {
        let configuration = AppConfiguration(
            surfaces: [
                SurfaceSpec(id: SurfaceID("all-top"), display: .all, edge: .top),
                SurfaceSpec(id: SurfaceID("primary-top"), display: .primary, edge: .top)
            ]
        )
        XCTAssertTrue(configuration.validate().contains {
            $0.path == "surfaces[1]" && $0.message.contains("Overlapping surfaces")
        })
    }
}
