using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text.RegularExpressions;
using JetBrains.Annotations;
using Kingmaker.Blueprints;
using Kingmaker.Blueprints.JsonSystem;
using OwlcatModification.Editor.Utility;
using UnityEditor;
using UnityEngine;
using Object = UnityEngine.Object;

namespace OwlcatModification.Editor.Inspector
{
	public class CreateBlueprintWindow : EditorWindow
	{
		private string m_SearchString = "";
		private Vector2 m_ScrollPosition;
		private string m_Path;
		
		public static void ShowWindow()
		{
			var window = GetWindow<CreateBlueprintWindow>();
			window.m_Path = TryGetSelectedPath();
			window.Show();
		}
		
		[CanBeNull]
		private static string TryGetSelectedPath()
		{
			foreach (Object obj in Selection.GetFiltered(typeof(Object), SelectionMode.Assets))
			{
				string path = AssetDatabase.GetAssetPath(obj);
				if (!string.IsNullOrEmpty(path) && File.Exists(path)) 
				{
					return Path.GetDirectoryName(path);
				}
			}
			
			try
			{
				var tryGetActiveFolderPathMethod = typeof(ProjectWindowUtil).GetMethod("TryGetActiveFolderPath",
					BindingFlags.Static | BindingFlags.NonPublic);

				var args = new object[] {null};
				bool found = (bool)tryGetActiveFolderPathMethod.Invoke(null, args);
				if (found)
				{
					return (string)args[0];
				}
			}
			catch (Exception e)
			{
				Debug.LogError(e);
			}

			return null;
		}

		private void OnLostFocus()
		{
			Close();
		}

		private void OnEnable()
		{
			titleContent = new GUIContent("Create Blueprint");
		}

		private void OnGUI()
		{
			if (string.IsNullOrEmpty(m_Path))
			{
				GUILayout.Label("Can't detect path for new asset!", EditorStyles.boldLabel);
				ShowSelectFolderButton();
				return;
			}
			
			EditorGUILayout.LabelField($"Target folder: {m_Path}");
			
			using (new EditorGUILayout.HorizontalScope())
			{
				EditorGUILayout.LabelField("Type: ", GUILayout.Width(50));
				
				GUI.SetNextControlName("SearchTextField");
				m_SearchString = EditorGUILayout.TextField(m_SearchString);
				GUI.FocusControl("SearchTextField");
			}
			
			EditorGUILayout.LabelField("enter at least 3 characters");

			if (m_SearchString.Length < 3)
			{
				return;
			}

			Type typeToInstantiate = null;
			using (var scroll = new EditorGUILayout.ScrollViewScope(
				m_ScrollPosition, GUIStyle.none, GUI.skin.verticalScrollbar))
			{
				m_ScrollPosition = scroll.scrollPosition;
				
				using (new EditorGUILayout.VerticalScope())
				{
					string[] words = m_SearchString.ToLowerInvariant().Split(' ');
					
					foreach (var t in BlueprintTypesCache.Types)
					{
						if (!words.All(t.NameLowerInvariant.Contains))
						{
							continue;
						}

						if (GUILayout.Button(t.Name))
						{
							typeToInstantiate = t.Type;
						}
					}
				}
			}

			if (typeToInstantiate != null)
			{
				string path = AssetDatabase.GenerateUniqueAssetPath(m_Path + $"/New {typeToInstantiate.Name}.jbp");
				var obj = (SimpleBlueprint)Activator.CreateInstance(typeToInstantiate);
				using (var jw = new StreamWriter(path))
				{
					var wrapper = new BlueprintJsonWrapper(obj);
					Json.Serializer.Serialize(jw, wrapper);
				}
				
				AssetDatabase.Refresh();
				
				string metaContent = File.ReadAllText(path + ".meta");
				var metaGuidRegex = new Regex("guid: ([^\n]*)\n");
				var m = metaGuidRegex.Match(metaContent);
				string guid = m.Groups[1].ToString();

				string blueprintContent = File.ReadAllText(path);
				blueprintContent = blueprintContent.Replace("\"AssetId\": null", $"\"AssetId\": \"{guid}\"");
				File.WriteAllText(path, blueprintContent);
				
				Close();
			}
			else if (Event.current.type == EventType.KeyDown && Event.current.keyCode == KeyCode.Escape)
			{
				Close();
			}
		}

		private void ShowSelectFolderButton()
		{
			if (GUILayout.Button("Select folder"))
			{
				m_Path = EditorUtility.OpenFolderPanel("Select destination folder", m_Path, "");
				if (m_Path != null && m_Path.StartsWith(Application.dataPath))
				{
					m_Path = "Assets" + m_Path.Substring(Application.dataPath.Length);
				}
				else
				{
					m_Path = null;
				}
			}
		}
	}
}