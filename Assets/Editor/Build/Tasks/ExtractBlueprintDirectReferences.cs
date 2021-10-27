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
                    var gp = obj["guid"]?.Value<string>();
                    var fp = obj["fileid"]?.Value<long>();

                    if (gp != null && fp != null)
                    {
                        var asset = LoadAsset(gp, fp);
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
                    else
                    {
                        // check if this is a sharedstring asset
                        var ag = obj["assetguid"]?.Value<string>();
                        var sk = obj["stringkey"];
                        if (ag != null && sk != null)
                        {
                            var asset = AssetDatabase.LoadAssetAtPath<SharedStringAsset>(AssetDatabase.GUIDToAssetPath(ag));
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