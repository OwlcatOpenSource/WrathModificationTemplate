using System.IO;
using System.Linq;
using OwlcatModification.Editor.Build.Context;
using UnityEditor;
using UnityEditor.Build.Pipeline;
using UnityEditor.Build.Pipeline.Injector;
using UnityEditor.Build.Pipeline.Interfaces;
using UnityEditor.Build.Player;

namespace OwlcatModification.Editor.Build.Tasks
{
	public class BuildAssemblies : IBuildTask
	{
		public int Version
			=> 1;

#pragma warning disable 649
		[InjectContext(ContextUsage.In)]
		private IBuildParameters m_BuildParameters;
		
		[InjectContext(ContextUsage.In)]
		private IModificationParameters m_ModificationParameters;
#pragma warning restore 649

		public ReturnCode Run()
		{
			var settings = m_BuildParameters.GetScriptCompilationSettings(); 
			string outputFolder = m_BuildParameters.GetOutputFilePathForIdentifier(BuilderConsts.OutputAssemblies);
			var results = PlayerBuildInterface.CompilePlayerScripts(settings, outputFolder);
			if (results.assemblies == null || !results.assemblies.Any())
			{
				return ReturnCode.Error;
			}

			string[] asmdefGuids = AssetDatabase.FindAssets("t:Asmdef", new[] {m_ModificationParameters.ScriptsPath});
			string[] asmdefNames = asmdefGuids.Select(AssetDatabase.GUIDToAssetPath).Select(Path.GetFileNameWithoutExtension).ToArray();
			foreach (string filePath in Directory.GetFiles(outputFolder))
			{
				if (asmdefNames.All(i => !filePath.Contains(i)))
				{
					File.Delete(filePath);
				}
			}

			return ReturnCode.Success;
		}
	}
}