using OwlcatModification.Editor.Build;
using UnityEditor;
using UnityEngine;

namespace OwlcatModification.Editor.Inspector
{
	public class BuildModificationWindow : EditorWindow
	{
		private Vector2 m_ScrollPosition;

		public Modification[] Modifications { get; set; } = {};

		private void OnLostFocus()
		{
			Close();
		}

		private void OnEnable()
		{
			titleContent = new GUIContent("Build modification");
		}

		private void OnGUI()
		{
			Modification modification = null;
			using (var scroll = new EditorGUILayout.ScrollViewScope(
				m_ScrollPosition, GUIStyle.none, GUI.skin.verticalScrollbar))
			{
				m_ScrollPosition = scroll.scrollPosition;
				
				using (new EditorGUILayout.VerticalScope())
				{
					foreach (var m in Modifications)
					{
						string modificationName = m.Manifest.UniqueName;
						if (!string.IsNullOrEmpty(m.Manifest.Version))
						{
							modificationName += ", " + m.Manifest.Version;
						}

						if (GUILayout.Button(modificationName))
						{
							modification = m;
						}
					}
				}
			}

			if (modification != null)
			{
				Close();
				Builder.Build(modification);
			}
		}
	}
}