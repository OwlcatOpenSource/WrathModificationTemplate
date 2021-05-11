using System;
using System.IO;
using System.Linq;
using UnityEditor;

namespace OwlcatModification.Editor.Setup
{
	public static class ProjectSetup
	{
		[MenuItem("Modification Tools/Setup assemblies", false, -1000)]
		public static void Setup()
		{
			try
			{
				EditorUtility.DisplayProgressBar("Setup assemblies", "", 0);
				SetupAssemblies();
			}
			catch (Exception e)
			{
				EditorUtility.DisplayDialog("Error!", $"{e.Message}\n\n{e.StackTrace}", "Close");
			}
			finally
			{
				EditorUtility.ClearProgressBar();
			}
		}

		private static void SetupAssemblies()
		{
			string[] skipAssemblies = {
				"mscorlib.dll",
				"Unity.ScriptableBuildPipeline.dll",
				"Owlcat.SharedTypes.dll"
			};

			string assembliesDirectory = EditorUtility.OpenFolderPanel(
				"<Wrath-of-the-Righteous>/Wrath_Data/Managed", "", "");
			if (!Directory.Exists(assembliesDirectory))
			{
				throw new Exception("Assemblies' folder is missing!");
			}

			const string targetDirectory = "Assets/PathfinderAssemblies";
			Directory.CreateDirectory(targetDirectory);
			
			foreach (string assemblyPath in Directory.GetFiles(assembliesDirectory, "*.dll"))
			{
				if (skipAssemblies.Any(assemblyPath.EndsWith))
				{
					continue;
				}

				string filename = Path.GetFileName(assemblyPath);
				File.Copy(assemblyPath, Path.Combine(targetDirectory, filename), true);
			}
			
			AssetDatabase.Refresh();
		}
	}
}