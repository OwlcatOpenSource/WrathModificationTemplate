using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Kingmaker.BundlesLoading;
using Kingmaker.SharedTypes;
using Kingmaker.Utility;
using OwlcatModification.Editor.Build.Context;
using UnityEditor;
using UnityEditor.Build.Pipeline;
using UnityEditor.Build.Pipeline.Injector;
using UnityEditor.Build.Pipeline.Interfaces;
using UnityEngine;

namespace OwlcatModification.Editor.Build.Tasks
{
	public class PrepareBundles : IBuildTask
	{
#pragma warning disable 649
		[InjectContext(ContextUsage.In)]
		private IBuildParameters m_BuildParameters;
		
		[InjectContext(ContextUsage.In)]
		private IProgressTracker m_Tracker;
		
		[InjectContext(ContextUsage.In)]
		private IBundleLayoutManager m_LayoutManager;

		[InjectContext(ContextUsage.In)]
		private IBundleBuildContent m_BundleBuildContent;
		
		[InjectContext(ContextUsage.In)]
		private IModificationParameters m_ModificationParameters;
		
		[InjectContext(ContextUsage.In)]
		private IModificationRuntimeSettings m_ModificationSettings;
#pragma warning restore 649
		
		public int Version
			=> 1;

		public ReturnCode Run()
		{
			var buildContent = m_BundleBuildContent;
			var layout = new Dictionary<string, List<GUID>>();
			// bundle name -> [material guid]
			var materials = new Dictionary<string, List<string>>();
			string[] assetGuids = AssetDatabase.FindAssets("t:Object", new[] {m_ModificationParameters.ContentPath});
			foreach (string assetGuid in assetGuids)
			{
				string assetPath = AssetDatabase.GUIDToAssetPath(assetGuid);
				string bundleName = m_LayoutManager.GetBundleForAssetPath(assetPath, m_ModificationParameters.TargetFolderName);
				if (bundleName == null)
				{
					continue;
				}

				if (!m_Tracker.UpdateInfo(assetPath))
				{
					return ReturnCode.Canceled;
				}

				var guid = new GUID(assetGuid);
				// asset already added to bundle by ExtractBlueprintDirectReferences
				if (buildContent.Addresses.ContainsKey(guid))
				{
					continue;
				}

				if (assetPath.EndsWith(".unity", StringComparison.OrdinalIgnoreCase))
				{
					// this is a scene bundle
					buildContent.Scenes.Add(guid);
					buildContent.Addresses[guid] = Path.GetFileNameWithoutExtension(assetPath);
				}
				else
				{
					// this is an asset
					buildContent.Assets.Add(guid);
					buildContent.Addresses[guid] = assetGuid;
				}

				if (!layout.TryGetValue(bundleName, out var bundle))
				{
					layout[bundleName] = bundle = new List<GUID>();
				}
				
				bundle.Add(guid);

				if (assetPath.EndsWith(".mat"))
				{
					var container = materials.Get(bundleName);
					if (container == null)
					{
						materials[bundleName] = container = new List<string>();
					}
					
					container.Add(assetGuid);
				}
			}

			foreach ((string bundleName, var materialsList) in materials)
			{
				string directReferencesAssetPath = Path.Combine(
					m_ModificationParameters.GeneratedPath, BuilderConsts.MaterialsInBundle + ".asset");
				var containerAsset = ScriptableObject.CreateInstance<OwlcatModificationMaterialsInBundleAsset>();
				AssetDatabase.CreateAsset(containerAsset, directReferencesAssetPath);

				containerAsset.Materials = materialsList
					.Select(i => AssetDatabase.LoadAssetAtPath<Material>(AssetDatabase.GUIDToAssetPath(i)))
					.ToArray();
				
				EditorUtility.SetDirty(containerAsset);
				AssetDatabase.SaveAssets();

				string assetGuid = AssetDatabase.AssetPathToGUID(AssetDatabase.GetAssetPath(containerAsset));
				var guid = new GUID(assetGuid);
				buildContent.Assets.Add(guid);
				buildContent.Addresses[guid] = assetGuid;

				if (layout.TryGetValue(bundleName, out var bundle))
				{
					bundle.Add(guid);
				}
			}

			foreach (var bundle in layout)
			{
				buildContent.BundleLayout[Path.Combine(BuilderConsts.OutputBundles, bundle.Key)] = bundle.Value;
			}

			CopyLayout(layout, m_ModificationSettings.Settings.BundlesLayout);
			
			return ReturnCode.Success;
		}

		private static void CopyLayout(Dictionary<string, List<GUID>> sourceLayout, LocationList resultLayout)
		{
			foreach ((string bundle, var assetGuids) in sourceLayout)
			{
				foreach (var assetGuid in assetGuids)
				{
					string guid = assetGuid.ToString();
					string assetPath = AssetDatabase.GUIDToAssetPath(guid);
					guid = assetPath.EndsWith(".unity") ? Path.GetFileNameWithoutExtension(assetPath) : guid;
					resultLayout.GuidToBundle.Add(guid, bundle);
				}
			}
		}
	}
}