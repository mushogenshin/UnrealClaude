# UnrealClaude — UE 5.7 → UE 4.25 port notes

Branch: `ue4.25-port`. Verified on macOS 26.3 (Tahoe), Apple Silicon M4, Xcode 17.

## Status

| Layer | Status |
|---|---|
| **Plugin compile** against UE 4.25-plus | ✅ `BUILD SUCCESSFUL` |
| **Plugin runtime** (editor loads dylib, menu entry, chat UI) | ✅ verified in Flying4_25 project |
| **MCP server** on `localhost:3000` | ✅ 26 tools registered, serves JSON |
| **mcp-bridge → editor round-trip** | ✅ Claude Code CLI successfully invokes tools |
| **Engine** (UE 4.25-plus from Epic's `4.25-plus` branch) | ✅ builds + runs on macOS 26 / Xcode 17 after engine-side patches |

The port took **one initial mechanical port commit + 7 iterative fix-round commits** on the plugin side, plus **~13 engine patches** on a parallel `macos26-xcode17-port` branch of the engine itself (documented separately; those are not in this repo).

## Engine-side prerequisites

The port work assumed — and then had to produce — a working UE 4.25-plus editor on modern macOS. That bring-up was substantial because nobody at Epic has tested 4.25-plus on macOS 26 / Xcode 17. Summary of what was needed on the engine side (in `/Users/Shared/EpicGames/UE_4.25-plus/`):

- 10× `-Wno-*` flags in `MacToolChain.cs` for Xcode 17's stricter clang (`-Wdeprecated-builtins`, `-Wunused-but-set-variable`, `-Wenum-constexpr-conversion`, `-Wvla-cxx-extension`, etc.).
- `-F <SDK>/System/Library/PrivateFrameworks` added to link args so .tbd stubs resolve (macOS 15+ dropped on-disk private-framework binaries).
- `Core.Build.cs` / `ApplicationCore.Build.cs`: raw `/System/Library/...MultitouchSupport` path → `PublicWeakFrameworks.Add("MultitouchSupport")`.
- `ScriptInterface.h`: `FScriptInterface::Serialize` moved `private` → `public` (newer clang enforces access strictly).
- Real bugs in 4.25-plus: `FieldIterator` → `PropertyIterator` in `KismetCompiler`, `Rhs.bHasEntry` → `Rhs.Idx.bHasEntry` in Chaos, `mLefttChild` typo in FBX 2018.1.1.
- `libwebsockets.h`: `#ifndef _CUPS_HTTP_H_` guard against macOS 26 SDK's `cups/http.h` redefining `HTTP_STATUS_*`.
- `MetalDerivedData.cpp`: in-flight MSL post-processing to fix SPIRV-Cross's `spvStorageBufferCoords` macro (ambiguous `metal::min(uint, ulong)` on Xcode 17), **disabled shared Metal PCH** (macOS 26's Metal driver embeds a randomized `$TMPDIR` clang-module-cache path in every PCH, which then breaks every dependent shader compile).
- `MacMenu.cpp`: wrapped `FSlateMacMenu::PostInitStartup` in `MainThreadCall(^{...}, NSDefaultRunLoopMode, true)` — macOS 15+ fatal-enforces main-thread for `[NSApplication setMainMenu:]`.
- `ConsoleVariables.ini`: `r.ShaderDevelopmentMode=0` (the retry-dialog path renders transparently on macOS 26 and blocks the editor), `r.DumpShaderDebugInfo=2` kept for future diagnosis.

None of those live in this plugin repo. If you move this plugin to another machine you'll need an equivalently-patched UE 4.25-plus engine.

## Plugin port — what landed

Commit history on `ue4.25-port` from oldest:

| Commit | Round | Theme |
|---|---|---|
| `0231256` | Initial | Mechanical source port: .uplugin manifest, Build.cs, delete AnimBP + EnhancedInput tools, FAppStyle → FEditorStyle, FSavePackageArgs rewrite, AssetRegistry shape changes, FTSTicker → FTicker, TArray64 → TArray, UE5.7 strings rewrite |
| `5b28066` | Round 1 | Blueprint editor APIs: PC_Real/PC_Double → PC_Float, GetPackage → GetOutermost, 2-arg CreatePackage, PKG_Cooked → PKG_FilterEditorOnly, UBlueprintFactory rewrite to FKismetEditorUtilities, StringBuilder/Actor.h includes |
| `5950e07` | Round 2 | Header compat: HttpServerResponse, SkeletalMesh, AnimInstance, CondensedJsonPrintPolicy includes; STextBlock forward decl; C++14 `static` replacements for `inline constexpr`; 2-arg `FPlatformProcess::CreatePipe`; portable `build.sh` |
| `67b2b9e` | Round 3 | AssetRegistry include-path flattening (9 files): `AssetRegistry/X.h` → `X.h` |
| `247ea11` | Round 4 | FVector/FRotator float-vs-double narrowing in JSON reads; SkelMesh->Materials / MeshComp->SkeletalMesh direct UPROPERTY access |
| `c346eb3` | Round 5 | More 2-arg CreatePackage sites; TArray64 for ImageWrapper::GetCompressed (4.25-plus backported 5.x's 64-bit variant); dropped `FJsonValue::Duplicate` in favor of sharing TSharedPtr |
| `d654088` | Round 6 | `UUnrealEdEngine::TemplateMapInfos` public UPROPERTY (not `GetTemplateMapInfos()`); `FTemplateMapInfo::Map` is FString directly; `UScriptStruct::ImportText` replaces `FStructProperty::ImportText_Direct`; more float narrowing |
| `2afc251` | Round 7 | `FHttpRequestHandler` is `TFunction<bool(...)>` in 4.25, no `CreateRaw` — use capturing lambdas; `FGlobalTabmanager::InvokeTab` (not `TryInvokeTab`); cleanup of earlier comment that orphaned a `.ToString()` |

**Plugin line-count delta after port:** +~500 / −~12,000 (mostly AnimBP deletions).

## Files deleted (intentionally out of scope)

| Group | Files | Reason |
|---|---|---|
| EnhancedInput MCP tool | `MCPTool_EnhancedInput.cpp/.h` (~1000 lines) | Plugin does not exist in UE 4.25 (added experimental in 4.26, stable 5.0). |
| AnimBP editor helpers | `AnimAssetManager`, `AnimAssetNodeFactory`, `AnimGraphEditor`, `AnimGraphFinder`, `AnimNodePinUtils`, `AnimStateMachineEditor`, `AnimTransitionConditionFactory`, `AnimationBlueprintUtils` (~3000 lines) | Internal AnimBP editor APIs drift heavily across versions; reviving requires per-API 4.25 validation. |
| AnimBP MCP tool | `MCPTool_AnimBlueprintModify.cpp/.h`, `MCPAnimBlueprintTests.cpp` | Depends on the deleted helpers. |

All references to the deleted code are scrubbed. Files remain in git history on `master`.

## API migration reference — ground truth after 7 rounds

The one-line rules that mattered, each with concrete examples of where we hit them in practice:

| UE 5.x → UE 4.25 | First hit | # of sites | Notes |
|---|---|---|---|
| `FAppStyle::` → `FEditorStyle::` (+ `Styling/AppStyle.h` → `EditorStyleSet.h`) | initial | 48 | Mechanical rename |
| `FSavePackageArgs` + `UPackage::Save` → `UPackage::SavePackage(Pkg, Asset, Flags, Filename)` returns `bool` | initial | 4 | Positional API; no-comma-args |
| `FTSTicker::GetCoreTicker()` → `FTicker::GetCoreTicker()` | initial | 2 | 4.25's `FTicker::AddTicker` is **not** thread-safe; see known-risk |
| `UE::AssetRegistry::EDependencyCategory` + `FDependencyQuery` → `EAssetRegistryDependencyType::Type` | initial | 2 | `Packages` (soft+hard) vs `Hard` |
| `FAssetData::AssetClassPath.GetAssetName()` → `FAssetData::AssetClass` (FName) | initial | 5 | 4.25 is pre-FTopLevelAssetPath |
| `FAssetData::GetObjectPathString()` → `FAssetData::ObjectPath.ToString()` | initial | 4 | |
| `FARFilter::ClassPaths.Add(FTopLevelAssetPath)` → `Filter.ClassNames.Add(FName)` | initial | 2 | Short class name suffices |
| `AssetRegistry.GetAssetByObjectPath(FSoftObjectPath)` → `GetAssetByObjectPath(FName)` | initial | 2 | |
| `UClass::StaticClass()->GetClassPathName()` → `->GetFName()` | initial | 1 | For `GetAssetsByClass` |
| **Uplugin manifest** `PlatformAllowList` → `WhitelistPlatforms` | initial | 1 | 4.27 renamed the field |
| Drop Build.cs modules: `EditorFramework`, `EnhancedInput`, `AnimGraph`, `AnimGraphRuntime` | initial | — | Missing in 4.25 |
| `UEdGraphSchema_K2::PC_Real` / `PC_Double` → `PC_Float` | round 1 | 7 | 4.25 has no double-precision BP pins |
| `UBlueprint::GetPackage()` → `GetOutermost()` | round 1 | 1 | `UObject::GetPackage` is 5.0+ |
| `CreatePackage(*Path)` → `CreatePackage(nullptr, *Path)` | round 1 | 4 | 5.0 removed the Outer arg |
| `PKG_Cooked` → `PKG_FilterEditorOnly` | round 1 | 1 | Flag doesn't exist in 4.25 |
| `UBlueprintFactory::BlueprintType` → `FKismetEditorUtilities::CreateBlueprint(ParentClass, Outer, Name, Type, BP, BPGenClass)` | round 1 | 1 | 4.25 factory has no BlueprintType field |
| `#include "Misc/StringBuilder.h"` | round 1 | 1 | Only forward-decl'd via StringFwd.h in 4.25 |
| `#include "HttpServerResponse.h"` (header files using `EHttpServerResponseCodes`) | round 1 | 1 | Not pulled in transitively |
| `#include "GameFramework/Actor.h"` (when using `AActor::StaticClass()`) | round 2 | 1 | |
| `#include "Engine/SkeletalMesh.h"`, `"Animation/AnimInstance.h"` (when using those types) | round 2 | 1 | |
| `#include "Policies/CondensedJsonPrintPolicy.h"` (when using `TCondensedJsonPrintPolicy`) | round 2 | 1 | Not via JsonWriter.h in 4.25 |
| `FPlatformProcess::CreatePipe(R, W, bool)` → `CreatePipe(R, W)` | round 2 | 2 | 4.25 has 2-arg signature |
| `inline constexpr` / `inline const` at namespace scope → `static constexpr` / `static const` | round 2 | 3 | 4.25 module default is C++14 |
| Forward-declare `class STextBlock;` when used in `TSharedPtr<STextBlock>` member | round 2 | 1 | |
| `#include "AssetRegistry/AssetRegistryModule.h"` → `"AssetRegistryModule.h"` (and same for `IAssetRegistry.h`) | round 3 | 9 | 4.25 module headers are flat |
| `TryGetNumberField(TEXT("x"), FVector::X)` → read into `double Tmp`, narrow to float | rounds 4+5+6 | ~25 | 4.25 `FVector`/`FRotator`/`FLinearColor` are float-backed; no float overload on the JSON helper |
| `USkeletalMesh::GetMaterials()` → `->Materials` | round 4 | 2 | Public UPROPERTY in 4.25 |
| `USkeletalMeshComponent::GetSkeletalMeshAsset()` → `->SkeletalMesh` | round 4 | 1 | Public UPROPERTY in 4.25 |
| `IImageWrapper::GetCompressed()` returns `TArray64<uint8>` (in 4.25-plus) | round 5 | 1 | 4.25-plus backported this from 5.x; vanilla 4.25 would be `TArray<uint8>` |
| `FJsonValue::Duplicate(v)` → share `TSharedPtr<FJsonValue>` directly | round 5 | 1 | Static helper doesn't exist in 4.25 |
| `UUnrealEdEngine::GetTemplateMapInfos()` → `->TemplateMapInfos` | round 6 | 2 | Public UPROPERTY in 4.25 |
| `FTemplateMapInfo::Map.ToString()` → `.Map` (already `FString`) | round 6 | 5 | Later versions changed `Map` to `FSoftObjectPath` |
| `FStructProperty::ImportText_Direct(...)` → `StructProp->Struct->ImportText(...)` | round 6 | 2 | 4.25 suggests `UScriptStruct::ImportText` |
| `FHttpRequestHandler::CreateRaw(this, &Fn)` → `[this](auto&&... a) { return Fn(a...); }` | round 7 | 3 | 4.25's FHttpRequestHandler is `typedef TFunction<bool(...)>` — no CreateRaw |
| `FGlobalTabmanager::TryInvokeTab` → `InvokeTab` | round 7 | 1 | Returns `TSharedRef<SDockTab>` (always-valid) |

## Quick reference: 4.25 vs 5.x API shape

| Area | UE 4.25 | UE 5.x |
|---|---|---|
| Editor style | `FEditorStyle` / `EditorStyleSet.h` | `FAppStyle` / `Styling/AppStyle.h` (5.1+) |
| Style-set name accessor | `FEditorStyle::GetStyleSetName()` | `FAppStyle::GetAppStyleSetName()` |
| Package saving | `UPackage::SavePackage(Pkg, Asset, Flags, Filename[, ...])` → `bool` | `UPackage::Save(Pkg, Asset, Filename, FSavePackageArgs)` → `FSavePackageResultStruct` (5.0+) |
| SavePackage header | `UObject/Package.h` (transitive) | `UObject/SavePackage.h` (5.0+) |
| Ticker | `FTicker::GetCoreTicker()` — not thread-safe | `FTSTicker::GetCoreTicker()` (5.0+, thread-safe) |
| Asset class on `FAssetData` | `FName AssetClass` | `FTopLevelAssetPath AssetClassPath` (5.1+) |
| Asset object path on `FAssetData` | `FName ObjectPath` / `.ToString()` | `GetObjectPathString()` (5.1+) |
| `FARFilter` class filter | `TArray<FName> ClassNames` | `TArray<FTopLevelAssetPath> ClassPaths` (5.1+) |
| `AssetRegistry.GetAssetByObjectPath` arg | `FName` | `FSoftObjectPath` (5.0+) |
| `UClass` path name | `GetFName()` (short) or `GetPathName()` | `GetClassPathName()` → `FTopLevelAssetPath` (5.1+) |
| Dependency query | `EAssetRegistryDependencyType::Type` (`Hard`, `Soft`, `Packages`, `All`) | `UE::AssetRegistry::EDependencyCategory` + `FDependencyQuery` (5.0+) |
| `USkeletalMesh::Materials` access | public UPROPERTY (direct field) | `GetMaterials()` / `SetMaterials()` (4.27+) |
| `USkeletalMeshComponent::SkeletalMesh` access | public UPROPERTY (direct field) | `GetSkeletalMeshAsset()` / `SetSkeletalMeshAsset()` (5.1+) |
| `UUnrealEdEngine::TemplateMapInfos` access | public UPROPERTY | `GetTemplateMapInfos()` (post-4.25) |
| `FTemplateMapInfo::Map` type | `FString` | `FSoftObjectPath` (post-4.25) |
| `UBlueprintFactory::BlueprintType` | **not present**; use `FKismetEditorUtilities::CreateBlueprint(...)` | public field |
| `FBlueprintEditorUtils::PC_Float` vs `PC_Real` / `PC_Double` | `PC_Float` only | `PC_Real` (5.0+) with `PC_Float`/`PC_Double` subcategory |
| `FPlatformProcess::CreatePipe` | `CreatePipe(R, W)` — 2 args | `CreatePipe(R, W, bool bWritePipeLocal)` — 3 args (5.0+) |
| Image compression return (plain 4.25) | `const TArray<uint8>&` | `TArray64<uint8>` (4.26+) |
| **Image compression return (4.25-plus)** | `TArray64<uint8>` (backported) | `TArray64<uint8>` |
| `FHttpRequestHandler` shape | `typedef TFunction<bool(...)>` | delegate with `CreateRaw/CreateLambda/CreateUObject` (5.0+) |
| `FGlobalTabmanager::InvokeTab` vs `TryInvokeTab` | only `InvokeTab` (`TSharedRef<SDockTab>`) | `TryInvokeTab` added later |
| `FStructProperty::ImportText_Direct` | not present; go through `StructProp->Struct->ImportText(...)` | present (5.1+) |
| `FJsonValue::Duplicate` static helper | not present; share `TSharedPtr` or manually clone | present (5.0+) |
| Property reflection | `FProperty` (introduced in 4.25) | same (FProperty is the transition point) |
| Build.cs: `EditorFramework` module | **does not exist** | 5.0+ |
| Build.cs: `AnimGraph` / `AnimGraphRuntime` (editor helpers) | present but deep API drift across versions | present with different APIs |
| Plugin: EnhancedInput | **does not exist** | 4.26 experimental, 5.0 stable |
| Uplugin platform field | `WhitelistPlatforms` | `PlatformAllowList` (4.27+) |
| C++ standard (module default) | **C++14** (opt into C++17 via `CppStandard = CppStandardVersion.Cpp17` in Build.cs) | C++17 (5.0–5.2), C++20 (5.3+) |
| inline namespace-scope variables | require C++17 opt-in | default |

### ⚠️ C++17 opt-in trap on UE 4.25

If you set `CppStandard = CppStandardVersion.Cpp17` on a module, **UHT-generated `*.gen.cpp` files fail to compile on modern clang** with `-Wc++11-narrowing` errors in init lists — `STRUCT_OFFSET` returns `size_t` and narrowing-to-`int32` is stricter under C++17. The pragmatic fix is to **stay on C++14** at the module level and rewrite any `inline` namespace-scope variables you had as `static` equivalents (see `UnrealClaudeConstants.h`).

## What's still there (not in this repo)

### `Resources/mcp-bridge/contexts/*.md` — 5.7 docs

The 11 markdown context files (`actor.md`, `animation.md`, `assets.md`, `blueprint.md`, `character.md`, `enhanced_input.md`, `material.md`, `parallel_workflows.md`, `replication.md`, `slate.md`, `ue-core-api.md`) are all UE 5.7-specific. Until rewritten for 4.25, the `unreal_get_ue_context` tool will feed Claude 5.x-flavored API documentation and Claude will happily hallucinate `TObjectPtr<>`, `FTopLevelAssetPath`, etc.

Minimum viable cleanup:
- Rename `enhanced_input.md` → `legacy_input.md`, rewrite for `UInputSettings` / `InputComponent::BindAction`.
- Rewrite `slate.md`, `ue-core-api.md`, `actor.md`, `assets.md`, `blueprint.md` — the five most-frequently-queried categories — for 4.25.
- The rest (`animation.md`, `material.md`, `parallel_workflows.md`, `replication.md`) can stay 5.7-inspired short-term if you accept minor hallucinations.

### `README.md` / `INSTALL_MAC.md` — still advertises UE 5.7

Badges, install paths (`UE_5.7`), example prompts, all mention 5.7. Cosmetic but should be updated before anyone else uses this branch.

### Internal field/method naming

`bUE57ContextEnabled`, `GetUE57SystemPrompt()` etc. are intentionally **kept** as internal names — renaming would break binary compat with existing saved session files (`Saved/UnrealClaude/`). User-facing strings (welcome message, tooltips, checkbox labels) are UE 4.25.

## Deferred / nice-to-have

1. **Port `MCPTool_EnhancedInput` to legacy input** — reimplement against `UInputSettings`, `FInputActionKeyMapping`, `FInputAxisKeyMapping`, `DefaultInput.ini` read/write. Gives 4.25 users an `input` MCP tool. Est. 1–2 days.
2. **Revive AnimBP state-machine tools** — per-function audit of `FAnimStateMachineEditor`, `FAnimGraphEditor` against 4.25's `AnimGraph` / `AnimGraphRuntime`. Est. 3–5 days for ~3000 lines of editor-adjacent code.
3. **`FTicker` thread-safety** — 4.25's `FTicker::AddTicker` is not thread-safe, but `MCPTaskQueue` currently dispatches from its own worker thread. Audit whether the queue's synchronization is sufficient, or wrap the dispatch in `AsyncTask(ENamedThreads::GameThread, ...)` instead.
4. **Port 3000 collision** — plugin silently fails to start HTTP server if port 3000 is held by another process. Add retry on next port (3001, 3002…) in `FUnrealClaudeMCPServer::Start`, or change the default to something obscure (e.g. `34050`) in `UnrealClaudeConstants.h`.
5. **Chat panel text selection** — `SChatMessage` uses `STextBlock` instead of a read-only `SMultiLineEditableText` → text isn't selectable/copyable. Pre-existing plugin bug, not port-related; fixable later.
6. **Rename `bUE57ContextEnabled` / `GetUE57SystemPrompt()`** on a major version bump when session format is free to change.
7. **Update plugin icons / marketplace strings** if ever published.

## Reproducing this port

If you're porting a similar UE plugin backwards, the playbook:

1. Run `BuildPlugin` via UAT. Let it fail loudly.
2. Categorize errors by **shape**, not by file — most errors are instances of ~5 patterns: API rename, missing transitive include, 5.x `Get*` accessor vs 4.x public UPROPERTY, float-vs-double narrowing, single-vs-multi-arg call-site drift.
3. Fix one pattern across **all files** before moving on. `grep` + `sed` saves hours.
4. Expect 5–10 compile rounds even for a small plugin. Each round halves or tenths the error count.
5. Don't try to solve version fragility you don't need — delete features (AnimBP here, EnhancedInput here) rather than port them bit-for-bit.
6. For each "5.x convenience accessor missing in 4.x" (e.g., `GetMaterials`, `GetSkeletalMeshAsset`, `GetTemplateMapInfos`) **check if it's a public UPROPERTY** — it almost always is. Direct field access is the 4.x idiom.
7. The float-vs-double trap (`TryGetNumberField` with `FVector::X`) is the single highest-count issue class — UE 5.x made `FVector` double-backed and the plugin was written against that. Abstract it into a helper lambda once and reuse.

## Runtime verification checklist

As of the last commit on this branch, all of these are ✅ in the Flying4_25 test project:

- [x] Editor loads with plugin dylib (no "Module missing" prompt, no "incompatible engine version" rejection)
- [x] Menu: **Tools → Claude Assistant** appears and opens a dock tab
- [x] Chat UI renders: input area, send button, response streaming
- [x] Claude Code CLI runs (invoked via `claude -p` subprocess)
- [x] MCP server starts on `localhost:3000`: `curl /mcp/status` returns JSON with `toolCount: 26` and `engineVersion: "4.25.0-0+++UE4+Release-4.25Plus"`
- [x] `mcp-bridge` (Node) connects to HTTP server and registers the 26 tools with Claude
- [x] Claude successfully invokes at least one MCP tool end-to-end (`unreal_asset_search` confirmed)

Known runtime caveats:
- Port 3000 must not be held by another process (the plugin will silently fail to start the HTTP server otherwise).
- Chat-panel text is not selectable (pre-existing plugin limitation; see deferred item #5).
