using Kingmaker.View;
using UnityEditor;

namespace OwlcatModification.Editor.Inspector
{
	public static class CustomInspector
	{
		public static void Draw(SerializedObject obj)
		{
			int originalDepth = EditorGUI.indentLevel;
			obj.UpdateIfRequiredOrScript();
			EditorGUI.BeginChangeCheck();
			try
			{
				
				var i = obj.GetIterator();
				bool enterChildren = true;
				bool skip = true;
				while (i.Next(enterChildren))
				{
					if (skip)
					{
						enterChildren = false;
						skip = i.displayName != "Editor Class Identifier";
						continue;
					}

					EditorGUI.indentLevel = originalDepth + i.depth;
					if (i.propertyType == SerializedPropertyType.Generic)
					{
						string name = i.isArray
							? $"{i.displayName}[{i.arraySize}] ({i.type})"
							: $"{i.displayName} ({i.type})";
						i.isExpanded = EditorGUILayout.Foldout(i.isExpanded, name);
					}
					else
					{
						EditorGUILayout.PropertyField(i, false);
					}

					enterChildren = i.propertyType == SerializedPropertyType.Generic && i.isExpanded;
				}

			}
			finally
			{
				EditorGUI.indentLevel = originalDepth;
				if (EditorGUI.EndChangeCheck())
				{
					obj.ApplyModifiedProperties();
				}
			}
		}
	}

	[CustomEditor(typeof(EntityViewBase), true, isFallback = true)]
	public class UnitSpawnerEditor
		: UnityEditor.Editor
	{
		public override void OnInspectorGUI()
		{
			CustomInspector.Draw(serializedObject);
		}
	}
}