using System.Linq;
using OwlcatModification.Editor.Utility;
using UnityEditor;
using UnityEngine;

namespace OwlcatModification.Editor.Inspector
{
	public class BlueprintTypesWindow : EditorWindow
	{
		private string m_SearchString = "";
		private Vector2 m_ScrollPosition;
		
		public static void ShowWindow()
		{
			GetWindow<BlueprintTypesWindow>().Show();
		}

		private void OnEnable()
		{
			titleContent = new GUIContent("Blueprints' Types");
		}

		private void OnGUI()
		{
			using (new EditorGUILayout.HorizontalScope())
			{
				EditorGUILayout.LabelField("Type: ", GUILayout.Width(50));
				m_SearchString = EditorGUILayout.TextField(m_SearchString);
			}
			
			EditorGUILayout.LabelField("enter at least 3 characters, click on result for copy to system buffer");

			if (m_SearchString.Length < 3)
			{
				return;
			}

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

						string typeString = $"{t.Guid}, {t.Name}";
						if (GUILayout.Button(typeString))
						{
							GUIUtility.systemCopyBuffer = typeString;
						}
					}
				}
			}
		}
	}
}