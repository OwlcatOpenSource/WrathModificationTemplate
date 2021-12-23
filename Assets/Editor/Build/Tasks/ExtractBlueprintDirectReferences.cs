using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Kingmaker.Localization;
using Kingmaker.SharedTypes;
using Newtonsoft.Json.Linq;
using OwlcatModification.Editor.Build.Context;
using UnityEditor;
using UnityEditor.Build.Pipeline;
using UnityEditor.Build.Pipeline.Injector;
using UnityEditor.Build.Pipeline.Interfaces;
using UnityEngine;
using Object = UnityEngine.Object;

namespace OwlcatModification.Editor.Build.Tasks
{
	public class ExtractBlueprintDirectReferences : IBuildTask
	{
		public int Version
			=> 1;
		
#pragma warning disable 649
		[InjectContext(ContextUsage.In)]
		private IModificationParameters m_ModificationParameters;

		[InjectContext(ContextUsage.In)]
		private IBundleBuildContent m_BundleBuildContent;

		[InjectContext(ContextUsage.In)]
		private IBundleLayoutManager m_LayoutManager;
#pragma warning restore 649
		
		public ReturnCode Run()
		{
			string directReferencesAssetPath = Path.Combine(
				m_ModificationParameters.GeneratedPath, BuilderConsts.BlueprintDirectReferences + ".asset");
			
			var result = ScriptableObject.CreateInstance<BlueprintReferencedAssets>();
			AssetDatabase.CreateAsset(result, directReferencesAssetPath);

			string bundleName = Path.Combine(
				BuilderConsts.OutputBundles,
				m_ModificationParameters.TargetFolderName + "_" +
				Kingmaker.Modding.OwlcatModification.BlueprintDirectReferencesBundleName);

			string[] blueprints = Directory.GetFiles(m_ModificationParameters.BlueprintsPath);
			foreach (string blueprintPath in blueprints)
			{
				if (!blueprintPath.EndsWith(".jbp") && !blueprintPath.EndsWith(".patch"))
				{
					continue;
				}

				JObject root;
				using (var fs = File.Open(blueprintPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
				using (var sr = new StreamReader(fs))
				{
					root = JObject.Parse(sr.ReadToEnd());
				}

				var allObjs = root.DescendantsAndSelf().OfType<JObject>();

				foreach (var obj in allObjs)
				{
					// Helper function common to all patterns
					// If the asset exists and it has NOT already been added to the BlueprintReferencedAssets object, add it
					void TryAddAsset(UnityEngine.Object asset) 
					{
						if (asset)
						{
							AssetDatabase.TryGetGUIDAndLocalFileIdentifier(asset, out string assetId, out long fileId);
							if (result.Get(assetId, fileId) == null)
							{
								result.Add(asset, assetId, fileId);
								EditorUtility.SetDirty(result);
								AddToBundle(asset, bundleName);
							}
						}
					}

					//Note as soon as we find a matching pattern we will unconditionally continue regardless if the asset was found
					//An object can't match multiple types of patterns simultaneously (yet?)

					// Check if this is a guid+fileid style asset:
					// These are typically GameObjects that are referenced directly, e.g. icons:
					//          "m_Icon": {
					//              "guid": "cc03741c7895f0346bc0836f35a99741",
					//              "fileid": "21300000"
					//          }
					var obj_guid = obj["guid"]?.Value<string>();
					var obj_fileid = obj["fileid"]?.Value<long>();
					if (obj_guid != null && obj_fileid != null)
					{
						var asset = LoadAsset(obj_guid, obj_fileid);
						TryAddAsset(asset);
						continue;
					}

					// check if this is a sharedstring asset, e.g:
					// "m_DisplayName": {
					//     "m_Key": "",
					//     "m_OwnerString": "",
					//     "m_OwnerPropertyPath": "",
					//     "m_JsonPath": "",
					//     "Shared": {
					//         "assetguid": "8d2b31b8256099e4da9c2db1484393a1",
					//         "stringkey": "8bf04757-2441-4326-85d0-e003a06562ee"
					//     }
					// },
					var obj_assetguid = obj["assetguid"]?.Value<string>();
					var obj_stringkey = obj["stringkey"];
					if (obj_assetguid != null && obj_stringkey != null)
					{
						var asset = AssetDatabase.LoadAssetAtPath<SharedStringAsset>(AssetDatabase.GUIDToAssetPath(obj_assetguid));
						TryAddAsset(asset);
						continue;
					}

					// Check if this is a WeakResourceLink, such as a Sprite or EquipmentEntity, e.g.
					// {
					//     "AssetId": "4eea3ef5f2e01474ba5b03fe28324ad3"
					// },
					// Note this is NOT the same as obj_assetguid
					var obj_AssetId = obj["AssetId"]?.Value<string>();
					if (obj_AssetId != null)
					{
						// We do not call TryAddAsset since assets in the direct references bundle are "different"
						// Instead we register with the LayoutManager so that PrepareBundles will handle the asset later.
						if (AssetDatabase.LoadAssetAtPath<UnityEngine.Object>(AssetDatabase.GUIDToAssetPath(obj_AssetId)) != null)
						{
							m_LayoutManager.AddWeakAssetLink(obj_AssetId);
						}
						continue;
					}
				}
			}

			AssetDatabase.SaveAssets();
			
			AddToBundle(result, bundleName);

			return ReturnCode.Success;
		}

		private Object LoadAsset(string assetId, long? fileId)
		{
			var path = AssetDatabase.GUIDToAssetPath(assetId);
			if (path.EndsWith(".unity", StringComparison.OrdinalIgnoreCase))
			{
				return null; // we do not need to save scene references
			}

			// this is a super dumb way to load an asset by fileId, but Unity does not have anything better )-8
			var allAssets = AssetDatabase.LoadAllAssetsAtPath(path);
			foreach (var asset in allAssets)
			{
				if (AssetDatabase.TryGetGUIDAndLocalFileIdentifier(asset, out _, out long fileId2) && fileId2 == fileId)
					return asset;
			}
			return null;
		}

		private void AddToBundle(Object asset, string bundleName)
		{
			string guidString = AssetDatabase.AssetPathToGUID(AssetDatabase.GetAssetPath(asset));
			var guid = new GUID(guidString);
			m_BundleBuildContent.Assets.Add(guid);
			m_BundleBuildContent.Addresses[guid] = guidString;

			if (!m_BundleBuildContent.BundleLayout.TryGetValue(bundleName, out var layout))
			{
				m_BundleBuildContent.BundleLayout[bundleName] = layout = new List<GUID>();
			}
			
			layout.Add(guid);
		}
	}
}