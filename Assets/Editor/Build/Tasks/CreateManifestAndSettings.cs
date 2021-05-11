using System.IO;
using System.Linq;
using Kingmaker.Modding;
using OwlcatModification.Editor.Build.Context;
using UnityEditor;
using UnityEditor.Build.Pipeline;
using UnityEditor.Build.Pipeline.Injector;
using UnityEditor.Build.Pipeline.Interfaces;
using UnityEngine;

namespace OwlcatModification.Editor.Build.Tasks
{
	public class CreateManifestAndSettings : IBuildTask
	{
#pragma warning disable 649
		[InjectContext(ContextUsage.In)]
		private IBuildParameters m_BuildParameters;
		
		[InjectContext(ContextUsage.In)]
		private IModificationParameters m_ModificationParameters;
		
		[InjectContext(ContextUsage.In)]
		private IModificationRuntimeSettings m_ModificationSettings;
#pragma warning restore 649
		
		public int Version
			=> 1;

		public ReturnCode Run()
		{
			string buildFolderPath = m_BuildParameters.GetOutputFilePathForIdentifier("");

			var blueprintPatches =
				AssetDatabase.FindAssets($"t:{nameof(BlueprintPatches)}", new[] {m_ModificationParameters.SourcePath})
					.Select(AssetDatabase.GUIDToAssetPath)
					.Select(AssetDatabase.LoadAssetAtPath<BlueprintPatches>)
					.FirstOrDefault();
			if (blueprintPatches != null)
			{
				m_ModificationSettings.Settings.BlueprintPatches = blueprintPatches.Entries.ToList();
			}

			string manifestJsonFilePath = Path.Combine(buildFolderPath, Kingmaker.Modding.OwlcatModification.ManifestFileName);
			string manifestJsonContent = JsonUtility.ToJson(m_ModificationParameters.Manifest, true);
			File.WriteAllText(manifestJsonFilePath, manifestJsonContent);
			
			string settingsJsonFilePath = Path.Combine(buildFolderPath, Kingmaker.Modding.OwlcatModification.SettingsFileName);
			string settingsJsonContent = JsonUtility.ToJson(m_ModificationSettings.Settings, true);
			File.WriteAllText(settingsJsonFilePath, settingsJsonContent);
			
			return ReturnCode.Success;
		}
	}
}