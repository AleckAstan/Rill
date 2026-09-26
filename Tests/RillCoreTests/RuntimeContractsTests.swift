import XCTest

final class RuntimeContractsTests: XCTestCase {
    func testWorkspaceStateKeepsProviderNamespaceAndUnknownOccupancy() throws {
        let state = WorkspaceState(
            id: WorkspaceID(provider: ProviderID("yabai"), rawID: "1"),
            name: "one",
            display: DisplayID("display"),
            focused: true,
            visible: true,
            occupied: nil,
            applications: [
                WorkspaceApplication(
                    id: "app:finder",
                    name: "Finder",
                    bundleIdentifier: "com.apple.finder",
                    focused: true,
                    windowCount: 2
                )
            ]
        )
        let batch = ProviderStateBatch(source: ProviderID("yabai"), generation: 4, sequence: 9, value: [state])
        let decoded = try JSONDecoder().decode(ProviderStateBatch<[WorkspaceState]>.self, from: JSONEncoder().encode(batch))
        XCTAssertEqual(decoded, batch)
        XCTAssertNil(decoded.value.first?.occupied)
        XCTAssertEqual(decoded.value.first?.id.provider, ProviderID("yabai"))
        XCTAssertEqual(decoded.value.first?.applications?.first?.name, "Finder")
        XCTAssertEqual(decoded.value.first?.applications?.first?.windowCount, 2)
    }

    func testConfigurationRoundTripsStableIDsAndReferences() throws {
        let configuration = AppConfiguration(surfaces: [SurfaceSpec(id: SurfaceID("main"), start: [ModuleID("clock")])], modules: [ModuleSpec(id: ModuleID("clock"), kind: .clock)])
        let data = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(AppConfiguration.self, from: data)
        XCTAssertEqual(decoded, configuration)
        XCTAssertEqual(decoded.surfaces.first?.start.first?.rawValue, "clock")
    }

    func testThemePresetsResolveFlatAndSegmentedVisualTokens() {
        let flat = ThemeSpec(preset: .flat)
        XCTAssertEqual(flat.resolvedModuleBackground, "#00000000")
        XCTAssertEqual(flat.resolvedFocusedWorkspaceBackground, "#00000000")
        XCTAssertEqual(flat.resolvedBorderWidth, 0)
        XCTAssertEqual(flat.resolvedModulePadding, 0)

        let segmented = ThemeSpec(preset: .segmented)
        XCTAssertEqual(segmented.resolvedModuleBackground, "#2A2F39FF")
        XCTAssertEqual(segmented.resolvedFocusedWorkspaceBackground, "#3B4252FF")
        XCTAssertEqual(segmented.resolvedBorderWidth, 1)
        XCTAssertEqual(segmented.resolvedApplicationIconSize, 16)

        let glass = ThemeSpec(preset: .glass)
        XCTAssertEqual(glass.resolvedSurfaceBackground, "#00000000")
        XCTAssertEqual(glass.resolvedModuleBackground, "#FFFFFF14")
        XCTAssertEqual(glass.resolvedFocusedWorkspaceBackground, "#FFFFFFD9")
        XCTAssertEqual(glass.resolvedFocusedWorkspaceForeground, "#000000FF")
        XCTAssertEqual(glass.resolvedModuleCornerRadius, 7)
        XCTAssertEqual(glass.resolvedWorkspaceCornerRadius, 7)
        XCTAssertEqual(glass.resolvedModulePadding, 10)
        XCTAssertEqual(glass.resolvedModuleVerticalPadding, 6)
        XCTAssertEqual(glass.resolvedWorkspacePadding, 11)
        XCTAssertEqual(glass.resolvedWorkspaceVerticalPadding, 5)
        XCTAssertEqual(glass.resolvedWorkspaceContentSpacing, 4)
        XCTAssertEqual(glass.resolvedWorkspaceSpacing, 7)
        XCTAssertEqual(glass.resolvedApplicationIconSize, 18)
        XCTAssertEqual(glass.resolvedWorkspaceMinimumHeight, 18)
        XCTAssertEqual(glass.resolvedEmptyWorkspaceOpacity, 0.82)
        XCTAssertEqual(glass.resolvedSurfaceMaterial, .none)
        XCTAssertTrue(glass.resolvedAdaptiveText)
    }

    func testExplicitThemeTokensOverridePresetDefaults() {
        let theme = ThemeSpec(
            preset: .flat,
            moduleBackground: "#11223344",
            borderWidth: 2,
            modulePadding: 7,
            applicationIconSize: 20
        )
        XCTAssertEqual(theme.resolvedModuleBackground, "#11223344")
        XCTAssertEqual(theme.resolvedBorderWidth, 2)
        XCTAssertEqual(theme.resolvedModulePadding, 7)
        XCTAssertEqual(theme.resolvedApplicationIconSize, 20)
    }

    func testFocusedWorkspaceForegroundSelectsContrastingColor() {
        XCTAssertEqual(
            ThemeSpec(preset: .flat, background: "#FFFFFFFF", focusedWorkspaceBackground: "#17171CFF")
                .resolvedFocusedWorkspaceForeground,
            "#FFFFFFFF"
        )
        XCTAssertEqual(
            ThemeSpec(preset: .flat, background: "#17171CFF", focusedWorkspaceBackground: "#FFFFFF80")
                .resolvedFocusedWorkspaceForeground,
            "#000000FF"
        )
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
