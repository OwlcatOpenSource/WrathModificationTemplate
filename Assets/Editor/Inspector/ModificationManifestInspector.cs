using OwlcatModification.Editor.Build;
using UnityEditor;
using UnityEngine;

namespace OwlcatModification.Editor.Inspector
{
	[CustomEditor(typeof(Modification))]
	public class ModificationManifestInspector : UnityEditor.Editor
	{
		private Modification Target
			=> (Modification)target;
		
		public override void OnInspectorGUI()
		{
			base.OnInspectorGUI();

			GUILayout.BeginHorizontal();
			GUILayout.FlexibleSpace();
			bool build = GUILayout.Button("Build", GUILayout.MaxWidth(150));
			GUILayout.FlexibleSpace();
			GUILayout.EndHorizontal();
			
			if (build)
			{
				Builder.Build(Target);
			}
		}
	}
}