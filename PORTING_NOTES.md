# UnrealClaude — UE 5.7 → UE 4.25 port notes

Living document. Update as the port progresses. Branch: `ue4.25-port`.

## Status

**Phase 1 (mechanical port, no compile verification yet):** done.
**Phase 2 (first 4.25 build + iteration on real errors):** not started.

## What's done

### Project manifest & build
- [UnrealClaude.uplugin](UnrealClaude/UnrealClaude.uplugin): `EngineVersion` → `4.25.0`; dropped `EnhancedInput` plugin dep; `PlatformAllowList` → `WhitelistPlatforms` (pre-4.27 naming).
- [UnrealClaude.Build.cs](UnrealClaude/Source/UnrealClaude/UnrealClaude.Build.cs): dropped `EditorFramework` (5.0+ only), `AnimGraph`, `AnimGraphRuntime`, `EnhancedInput` modules.

### Files deleted (gated off for v1)
| Group | Files | Reason |
|---|---|---|
| EnhancedInput MCP tool | `MCPTool_EnhancedInput.cpp/.h` (~1000 lines) | Plugin does not exist in UE 4.25 (added experimental in 4.26, stable 5.0). |
| AnimBP editor helpers | `AnimAssetManager`, `AnimAssetNodeFactory`, `AnimGraphEditor`, `AnimGraphFinder`, `AnimNodePinUtils`, `AnimStateMachineEditor`, `AnimTransitionConditionFactory`, `AnimationBlueprintUtils` | Internal AnimBP editor APIs drift heavily across versions; reviving requires per-API 4.25 validation. |
| AnimBP MCP tool | `MCPTool_AnimBlueprintModify.cpp/.h`, `MCPAnimBlueprintTests.cpp` | Depends on the deleted helpers. |

All references to the deleted code were scrubbed from `MCPToolRegistry.cpp`, `UnrealClaudeConstants.h`, `ClaudeSubsystem.cpp`, and `MCPToolTests.cpp`. The files remain in git history on `master`.

### API migrations
| UE 5.x → UE 4.25 | Scope | Files |
|---|---|---|
| `FAppStyle::` → `FEditorStyle::` | 48 hits | `ClaudeEditorWidget.cpp`, `UnrealClaudeModule.cpp`, `UnrealClaudeCommands.h`, `SClaudeInputArea.cpp`, `SClaudeToolbar.cpp` |
| `#include "Styling/AppStyle.h"` → `#include "EditorStyleSet.h"` | 4 files | same |
| `FAppStyle::GetAppStyleSetName()` → `FEditorStyle::GetStyleSetName()` | inline | same |
| `FSavePackageArgs` + `UPackage::Save(..., SaveArgs)` → `UPackage::SavePackage(Package, Asset, RF_Public\|RF_Standalone, *Filename)` (returns `bool`) | 3 call sites | `MCPTool_Asset.cpp`, `MCPTool_Material.cpp`, `MCPTool_CharacterData.cpp` |
| `#include "UObject/SavePackage.h"` → transitively via `UObject/Package.h` | 4 files | same + `AnimationBlueprintUtils.cpp` (now deleted) |
| `FTSTicker::GetCoreTicker()` → `FTicker::GetCoreTicker()` | 2 call sites | `MCPTaskQueue.cpp`, `MCPToolRegistry.cpp` |
| `TArray64<uint8> CompressedData = ImageWrapper->GetCompressed(...)` → `const TArray<uint8>&` | 1 site | `MCPTool_CaptureViewport.cpp:107` |
| `UE::AssetRegistry::EDependencyCategory::Package` + `FDependencyQuery(EDependencyQuery::Hard)` → `EAssetRegistryDependencyType::Type` (`Packages` / `Hard`) | 2 call sites | `MCPTool_AssetDependencies.cpp`, `MCPTool_AssetReferencers.cpp` |
| `FAssetData::AssetClassPath.GetAssetName()` → `FAssetData::AssetClass` (FName) | 5 sites | `ProjectContext.cpp`, `MCPTool_Asset.cpp`, `MCPTool_AssetSearch.cpp`, `MCPTool_AssetDependencies.cpp`, `MCPTool_AssetReferencers.cpp` |
| `FAssetData::GetObjectPathString()` → `FAssetData::ObjectPath.ToString()` | 4 sites | `MCPTool_Asset.cpp`, `MCPTool_AssetSearch.cpp`, `MCPTool_CharacterData.cpp`, `MCPTool_BlueprintQueryList.cpp` |
| `FARFilter::ClassPaths.Add(FTopLevelAssetPath(...))` → `Filter.ClassNames.Add(FName(...))` | 2 sites | `MCPTool_AssetSearch.cpp`, `MCPTool_BlueprintQueryList.cpp` |
| `AssetRegistry.GetAssetByObjectPath(FSoftObjectPath(...))` → `GetAssetByObjectPath(FName(...))` | 2 sites | dependencies/referencers tools |
| `UClass::StaticClass()->GetClassPathName()` → `->GetFName()` (for `GetAssetsByClass`) | 1 site | `MCPTool_CharacterData.cpp` |

### System prompt & user strings
- [ClaudeSubsystem.cpp](UnrealClaude/Source/UnrealClaude/Private/ClaudeSubsystem.cpp): complete rewrite of `CachedUE57SystemPrompt` for UE 4.25 — explicit "do not suggest post-4.25 features" list covering Enhanced Input, World Partition, TObjectPtr, FAppStyle, FSavePackageArgs, FTopLevelAssetPath, FTSTicker, Nanite/Lumen/Chaos/MetaSounds.
- User-facing UE5.7 strings (welcome message, menu tooltips, input hint, toolbar checkbox) → UE 4.25 in `ClaudeEditorWidget.cpp`, `UnrealClaudeModule.cpp`, `UnrealClaudeCommands.cpp`, `SClaudeInputArea.cpp`, `SClaudeToolbar.cpp`.
- Internal field/method names like `bUE57ContextEnabled`, `GetUE57SystemPrompt()` intentionally **kept as-is** — renaming would break binary compatibility with saved-session files.

## What's kept intentionally

- **Blueprint graph modification tools** (`MCPTool_BlueprintModify`, `MCPTool_BlueprintQuery`, `BlueprintEditor`, `BlueprintGraphEditor`, `BlueprintLoader`, `BlueprintUtils`). They lean on `FBlueprintEditorUtils` and `K2Node_*` classes that are stable in 4.25. Risk is lower than AnimBP. Expect minor tweaks on first build.
- **HTTP server** (`UnrealClaudeMCPServer`): HTTPServer module was added in UE 4.24; `IHttpRouter::BindRoute` signature should be compatible. Verify on first build.
- **LiveCoding** integration in `ScriptExecutionManager.cpp` — LiveCoding has existed since 4.22.
- **Clipboard / image paste** (`ClipboardImageUtils`, `FPlatformApplicationMisc`) — stable API.
- **mcp-bridge submodule** (Node.js layer) — engine-version-agnostic, kept as-is. **But** its `contexts/*.md` docs are all UE 5.7-specific — see TODO below.

## TODO / known-risk areas

### Must do before the port is useful
1. **First real compile in UE 4.25** (macOS via `build.sh`). Expect errors from:
   - `UToolMenus` menu attachment-point names (`LevelEditor.MainMenu.Tools`, `LevelEditor.LevelEditorToolBar.PlayToolBar`) — these exist in 4.25 but weren't verified per-string.
   - Slate icon names like `"Icons.Help"` — 5.x-specific; won't break compile, just missing icons. Swap for 4.25 equivalents (e.g. `"LevelEditor.OpenLevel"`, `"MessageLog.TabIcon"`).
   - `IHttpRouter::BindRoute` signature — verify handler type matches.
   - Possible `TArray::Sort` predicate or lambda-capture issues (C++17 vs C++20 — 4.25 uses C++17).
   - 5.x-only convenience methods on `UBlueprint` / `UEdGraph` that I didn't spot.
2. **Rewrite `Resources/mcp-bridge/contexts/*.md`** for UE 4.25 APIs. Currently 11 markdown files document 5.7 APIs (actor, animation, assets, blueprint, character, enhanced_input, material, parallel_workflows, replication, slate, ue-core-api). The `enhanced_input.md` file should probably be replaced with a `legacy_input.md` covering `UInputSettings` / `InputComponent::BindAction`. This is where Claude will "hallucinate 5.x APIs" if left unchanged.

### Deferred (nice to have)
3. **Port `MCPTool_EnhancedInput` to legacy input**: reimplement against `UInputSettings`, `FInputActionKeyMapping`, `FInputAxisKeyMapping`, and `DefaultInput.ini` read/write. Would give 4.25 users an `input` MCP tool. Estimated 1-2 days.
4. **Revive AnimBP state-machine tools**: requires per-function audit of `FAnimStateMachineEditor`, `FAnimGraphEditor` helpers against 4.25's `AnimGraph`/`AnimGraphRuntime`. Likely 3-5 days given the ~3000 lines of editor-adjacent code.
5. **Thread-safety note on `FTicker`**: 4.25's `FTicker::AddTicker` is not thread-safe, but `MCPTaskQueue` currently dispatches from its own worker thread. Audit whether the queue's synchronization is sufficient, or wrap the dispatch in an `AsyncTask(ENamedThreads::GameThread, ...)` instead.

### Lower priority
6. Refresh `README.md` and `INSTALL_MAC.md` / `INSTALL_LINUX.md` for the 4.25 fork (install paths, supported engine version badge, etc.).
7. Rename `bUE57ContextEnabled` / `GetUE57SystemPrompt()` on a major version bump when session format is free to change.
8. Update plugin icons / marketplace strings if ever published.

## Quick reference: 4.25 vs 5.x API table

Used during the port, kept here in case more migrations are needed:

| Area | UE 4.25 | UE 5.x |
|---|---|---|
| Editor style | `FEditorStyle` / `EditorStyleSet.h` | `FAppStyle` / `Styling/AppStyle.h` (5.1+) |
| Style-set name | `FEditorStyle::GetStyleSetName()` | `FAppStyle::GetAppStyleSetName()` |
| Package saving | `UPackage::SavePackage(Pkg, Asset, Flags, Filename[, ...])` returns `bool` | `UPackage::Save(Pkg, Asset, Filename, FSavePackageArgs)` returns `FSavePackageResultStruct` |
| SavePackage header | `UObject/Package.h` (transitive) | `UObject/SavePackage.h` (5.0+) |
| Ticker | `FTicker::GetCoreTicker()` (not thread-safe) | `FTSTicker::GetCoreTicker()` (5.0+, thread-safe) |
| Asset class on `FAssetData` | `FName AssetClass` | `FTopLevelAssetPath AssetClassPath` (5.1+) |
| Asset object path | `FName ObjectPath` / `.ToString()` | `GetObjectPathString()` (5.1+) |
| `FARFilter` class filter | `TArray<FName> ClassNames` | `TArray<FTopLevelAssetPath> ClassPaths` (5.1+) |
| `GetAssetByObjectPath` arg | `FName` | `FSoftObjectPath` (5.0+) |
| `UClass` path name | `GetFName()` (short) or `GetPathName()` | `GetClassPathName()` → `FTopLevelAssetPath` |
| Dependency query | `EAssetRegistryDependencyType::Type` (`Hard`, `Soft`, `Packages`, `All`) | `UE::AssetRegistry::EDependencyCategory` + `FDependencyQuery` (5.0+) |
| Image compression return | `const TArray<uint8>&` | `TArray64<uint8>` (4.26+) |
| Property reflection | `FProperty` (introduced in 4.25) | same |
| Module: EditorFramework | does not exist | 5.0+ |
| Plugin: EnhancedInput | does not exist | 4.26 experimental, 5.0 stable |
| Uplugin platform field | `WhitelistPlatforms` | `PlatformAllowList` (4.27+) |
| C++ standard | C++17 | C++20 (5.3+) |
