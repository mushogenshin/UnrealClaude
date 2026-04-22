// Copyright Natali Caggiano. All Rights Reserved.

using UnrealBuildTool;

public class UnrealClaude : ModuleRules
{
	public UnrealClaude(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = ModuleRules.PCHUsageMode.UseExplicitOrSharedPCHs;
		
		PublicIncludePaths.AddRange(
			new string[] {
			}
		);
				
		PrivateIncludePaths.AddRange(
			new string[] {
			}
		);
			
		PublicDependencyModuleNames.AddRange(
			new string[]
			{
				"Core",
				"CoreUObject",
				"Engine",
				"InputCore",
				"Slate",
				"SlateCore",
				"EditorStyle",
				"UnrealEd",
				"ToolMenus",
				"Projects",
				"WorkspaceMenuStructure"
				// Note: EditorFramework module was split out of UnrealEd in UE 5.0
				// and does not exist in 4.25. Removed for the 4.25 port.
			}
		);

		PrivateDependencyModuleNames.AddRange(
			new string[]
			{
				"Json",
				"JsonUtilities",
				"HTTP",
				"HTTPServer",
				"Sockets",
				"Networking",
				"ImageWrapper",
				// Blueprint manipulation
				"Kismet",
				"KismetCompiler",
				"BlueprintGraph",
				"GraphEditor",
				"AssetRegistry",
				"AssetTools",
				// Animation Blueprint manipulation modules removed from 4.25 port
				// (AnimGraph/AnimGraphRuntime editor helpers drift heavily across
				// engine versions — AnimBP MCP tools are excluded from v1).
				// Asset saving
				"EditorScriptingUtilities"
				// Note: EnhancedInput plugin does not exist in UE 4.25
				// (introduced as experimental in 4.26). Input MCP tool is
				// removed from the 4.25 port — reimplement against UInputSettings
				// if needed.
			}
		);

		// Clipboard support (FPlatformApplicationMisc) on all platforms
		PrivateDependencyModuleNames.Add("ApplicationCore");

		// Windows only
		if (Target.Platform == UnrealTargetPlatform.Win64)
		{
			// LiveCoding is only available in editor builds on Windows
			if (Target.bBuildEditor)
			{
				PrivateDependencyModuleNames.Add("LiveCoding");
			}
		}
	}
}
