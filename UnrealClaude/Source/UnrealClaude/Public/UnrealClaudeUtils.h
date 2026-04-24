// Copyright Natali Caggiano. All Rights Reserved.

#pragma once

#include "CoreMinimal.h"
#include "Misc/OutputDevice.h"

/**
 * Shared utility classes and functions for UnrealClaude plugin
 * Centralizes common patterns to reduce code duplication
 */

/**
 * Custom output device to capture console command output
 * Used by MCP tools and script execution to capture command results
 * Note: Named differently to avoid collision with engine's FStringOutputDevice
 */
class FUnrealClaudeOutputDevice : public FOutputDevice
{
public:
	FString Output;

	virtual void Serialize(const TCHAR* V, ELogVerbosity::Type Verbosity, const FName& Category) override
	{
		Output += V;
		Output += TEXT("\n");
	}

	/** Clear captured output */
	void Clear()
	{
		Output.Empty();
	}

	/** Get trimmed output (removes trailing whitespace) */
	FString GetTrimmedOutput() const
	{
		return Output.TrimEnd();
	}
};

/**
 * JSON parsing utilities for MCP tools
 * Provides safe extraction of transform data from JSON objects
 */
namespace UnrealClaudeJsonUtils
{
	/**
	 * Safely extract a FVector from a JSON object
	 * @param JsonObj - The JSON object containing x, y, z fields
	 * @param DefaultValue - Value to use if extraction fails
	 * @return Extracted vector or default
	 */
	inline FVector ExtractVector(const TSharedPtr<FJsonObject>& JsonObj, const FVector& DefaultValue = FVector::ZeroVector)
	{
		if (!JsonObj.IsValid())
		{
			return DefaultValue;
		}

		// UE 4.25 FVector fields are float; FJsonObject::TryGetNumberField has
		// overloads for double/int32/uint32/int64 but not float. Read into a
		// double temporary and narrow. (In 5.x this code worked because FVector
		// became double-backed and matched the default overload.)
		FVector Result = DefaultValue;
		double Tmp;
		if (JsonObj->TryGetNumberField(TEXT("x"), Tmp)) { Result.X = static_cast<float>(Tmp); }
		if (JsonObj->TryGetNumberField(TEXT("y"), Tmp)) { Result.Y = static_cast<float>(Tmp); }
		if (JsonObj->TryGetNumberField(TEXT("z"), Tmp)) { Result.Z = static_cast<float>(Tmp); }
		return Result;
	}

	/**
	 * Safely extract a FRotator from a JSON object
	 * @param JsonObj - The JSON object containing pitch, yaw, roll fields
	 * @param DefaultValue - Value to use if extraction fails
	 * @return Extracted rotator or default
	 */
	inline FRotator ExtractRotator(const TSharedPtr<FJsonObject>& JsonObj, const FRotator& DefaultValue = FRotator::ZeroRotator)
	{
		if (!JsonObj.IsValid())
		{
			return DefaultValue;
		}

		// Same 4.25 float-vs-double issue as ExtractVector above.
		FRotator Result = DefaultValue;
		double Tmp;
		if (JsonObj->TryGetNumberField(TEXT("pitch"), Tmp)) { Result.Pitch = static_cast<float>(Tmp); }
		if (JsonObj->TryGetNumberField(TEXT("yaw"), Tmp))   { Result.Yaw   = static_cast<float>(Tmp); }
		if (JsonObj->TryGetNumberField(TEXT("roll"), Tmp))  { Result.Roll  = static_cast<float>(Tmp); }
		return Result;
	}

	/**
	 * Safely extract a scale FVector from a JSON object
	 * @param JsonObj - The JSON object containing x, y, z fields
	 * @param DefaultValue - Value to use if extraction fails (typically 1,1,1)
	 * @return Extracted scale or default
	 */
	inline FVector ExtractScale(const TSharedPtr<FJsonObject>& JsonObj, const FVector& DefaultValue = FVector::OneVector)
	{
		return ExtractVector(JsonObj, DefaultValue);
	}

	/**
	 * Create a JSON object from a FVector
	 */
	inline TSharedPtr<FJsonObject> VectorToJson(const FVector& Vector)
	{
		TSharedPtr<FJsonObject> JsonObj = MakeShared<FJsonObject>();
		JsonObj->SetNumberField(TEXT("x"), Vector.X);
		JsonObj->SetNumberField(TEXT("y"), Vector.Y);
		JsonObj->SetNumberField(TEXT("z"), Vector.Z);
		return JsonObj;
	}

	/**
	 * Create a JSON object from a FRotator
	 */
	inline TSharedPtr<FJsonObject> RotatorToJson(const FRotator& Rotator)
	{
		TSharedPtr<FJsonObject> JsonObj = MakeShared<FJsonObject>();
		JsonObj->SetNumberField(TEXT("pitch"), Rotator.Pitch);
		JsonObj->SetNumberField(TEXT("yaw"), Rotator.Yaw);
		JsonObj->SetNumberField(TEXT("roll"), Rotator.Roll);
		return JsonObj;
	}
}
