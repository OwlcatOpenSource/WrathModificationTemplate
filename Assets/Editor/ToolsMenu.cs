using System;
using System.IO;
using System.Linq;
using System.Net;
using System.Reflection;
using System.Text.RegularExpressions;
using Owlcat.Runtime.Visual.RenderPipeline;
using Owlcat.Runtime.Visual.RenderPipeline.Data;
using OwlcatModification.Editor.Build;
using OwlcatModification.Editor.Inspector;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace OwlcatModification.Editor
{
	public static class ToolsMenu
	{
		[MenuItem("Modification Tools/Setup render pipeline", priority = 1 - 1000)]
		private static void SetupRenderPipeline()
		{
			try
			{
				void SetPrivateValue(object target, string fieldName, object value)
				{
					var t = target.GetType();
					var field = t.GetField(fieldName,
						BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.GetField);
					if (field == null)
						throw new Exception($"Missing field: {t.Name}.{fieldName}");
					field.SetValue(target, value);
				}

				const string directoryPath = "Assets/RenderPipeline";

				// fix shaders' #includes
				string[] shaders = Directory.GetFiles(directoryPath, "*.hlsl", SearchOption.AllDirectories)
					.Concat(Directory.GetFiles(directoryPath, "*.shader", SearchOption.AllDirectories))
					.Concat(Directory.GetFiles(directoryPath, "*.compute", SearchOption.AllDirectories))
					.ToArray();
				foreach (string filepath in shaders)
				{
					string content = File.ReadAllText(filepath);
					content = content.Replace(
						"Packages/com.unity.render-pipelines.core/ShaderLibrary/",
						"Assets/RenderPipeline/UnityShaders/");
					File.WriteAllText(filepath, content);
				}

				const string shaderSourcesBundlePath = directoryPath + "/utility_shaders";
				if (!File.Exists(shaderSourcesBundlePath))
				{
					throw new Exception($"{shaderSourcesBundlePath} bundle is missing");
				}

				string renderPipelineAssetPath = Path.Combine(directoryPath, "RenderPipelineAsset.asset");
				var renderPipelineAsset =
					AssetDatabase.LoadAssetAtPath<OwlcatRenderPipelineAsset>(renderPipelineAssetPath);
				if (renderPipelineAsset == null)
				{
					renderPipelineAsset = ScriptableObject.CreateInstance<OwlcatRenderPipelineAsset>();
					AssetDatabase.CreateAsset(renderPipelineAsset, renderPipelineAssetPath);
				}

				string clusteredRendererDataPath = Path.Combine(directoryPath, "ClusteredRendererData.asset");
				var clusteredRendererData =
					AssetDatabase.LoadAssetAtPath<ClusteredRendererData>(clusteredRendererDataPath);
				if (clusteredRendererData == null)
				{
					clusteredRendererData = ScriptableObject.CreateInstance<ClusteredRendererData>();
					AssetDatabase.CreateAsset(clusteredRendererData, clusteredRendererDataPath);
				}

				SetPrivateValue(renderPipelineAsset, "m_RendererData", clusteredRendererData);

				clusteredRendererData.RenderPath = RenderPath.Deferred;
				clusteredRendererData.ShadersBundlePath = shaderSourcesBundlePath;

				EditorUtility.SetDirty(renderPipelineAsset);
				EditorUtility.SetDirty(clusteredRendererData);

				GraphicsSettings.renderPipelineAsset = renderPipelineAsset;

				AssetDatabase.SaveAssets();
				AssetDatabase.Refresh();
			}
			catch (Exception e)
			{
				EditorUtility.DisplayDialog("Error!", $"{e.Message}\n\n{e.StackTrace}", "Close");

				// avoid editor crash because of invalid render pipeline settings
				GraphicsSettings.renderPipelineAsset = null;
			}
		}
		
		[MenuItem("Modification Tools/Build", priority = 1)]
		private static void Build()
		{
			var modifications = AssetDatabase.FindAssets($"t:{nameof(Modification)}")
					.Select(AssetDatabase.GUIDToAssetPath)
					.Select(AssetDatabase.LoadAssetAtPath<Modification>)
					.ToArray();
			if (modifications.Length < 1)
			{
				EditorUtility.DisplayDialog("Error!", "No modifications found", "Close");
				return;
			}

			if (modifications.Length == 1)
			{
				Builder.Build(modifications[0]);
				return;
			}

			var window = EditorWindow.GetWindow<BuildModificationWindow>();
			window.Modifications = modifications;
			window.Show();
			window.Focus();
		}

		[MenuItem("Modification Tools/Blueprints' Types", priority = 2)]
		private static void ShowBlueprintTypesWindow()
		{
			BlueprintTypesWindow.ShowWindow();
		}

		[MenuItem("Assets/Modification Tools/Copy guid and file id", priority = 2)]
		private static void CopyAssetGuidAndFileID()
		{
			var obj = Selection.activeObject;
			if (AssetDatabase.TryGetGUIDAndLocalFileIdentifier(obj, out string guid, out long fileId))
			{
				GUIUtility.systemCopyBuffer = $"{{\"guid\": \"{guid}\", \"fileid\": {fileId}}}";
			}
			else
			{
				GUIUtility.systemCopyBuffer = $"Can't find guid and fileId for asset '{AssetDatabase.GetAssetPath(obj)}'";
			}
		}
		
		[MenuItem("Assets/Modification Tools/Copy blueprint's guid", priority = 3)]
		private static void CopyBlueprintGuid()
		{
			var obj = Selection.activeObject;
			string path = AssetDatabase.GetAssetPath(obj);
			var regex = new Regex("\"AssetId\": \"([^\"]+)\"");
			using (var s = new StreamReader(path))
			{
				while (!s.EndOfStream)
				{
					string line = s.ReadLine();
					if (string.IsNullOrEmpty(line))
					{
						continue;
					}

					var m = regex.Match(line);
					if (m.Success)
					{
						GUIUtility.systemCopyBuffer = m.Groups[1].ToString();
						return;
					}
				}
			}

			GUIUtility.systemCopyBuffer = "not blueprint id found";
		}
		
		[MenuItem("Assets/Modification Tools/Copy blueprint guid", true)]
		private static bool IsCopyBlueprintGuidAllowed()
		{
			var obj = Selection.activeObject;
			string path = AssetDatabase.GetAssetPath(obj);
			return path != null && path.EndsWith(".jbp");
		}
		
		[MenuItem("Assets/Modification Tools/Create Blueprint", priority = 1)]
		private static void CreateBlueprint()
		{
			CreateBlueprintWindow.ShowWindow();
		}
	}
}