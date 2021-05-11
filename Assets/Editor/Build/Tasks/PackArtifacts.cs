using System.IO;
using Ionic.Zip;
using OwlcatModification.Editor.Build.Context;
using UnityEditor.Build.Pipeline;
using UnityEditor.Build.Pipeline.Injector;
using UnityEditor.Build.Pipeline.Interfaces;

namespace OwlcatModification.Editor.Build.Tasks
{
	public class PackArtifacts : IBuildTask
	{
#pragma warning disable 649
		[InjectContext(ContextUsage.In)]
		private IBuildParameters m_BuildParameters;

		[InjectContext(ContextUsage.In)]
		private IModificationParameters m_ModificationParameters;
#pragma warning restore 649

		public int Version
			=> 1;
		
		public ReturnCode Run()
		{
			string buildFolderPath = m_BuildParameters.GetOutputFilePathForIdentifier("../");
			string modificationFolderPath = Path.Combine(buildFolderPath, m_ModificationParameters.TargetFolderName);
			string targetFilePath = Path.Combine(buildFolderPath, m_ModificationParameters.TargetFolderName + ".zip");
			
			using (var zip = new ZipFile())
			{
				zip.AddDirectory(modificationFolderPath, "./");
				zip.Save(targetFilePath);
			}
			
			return ReturnCode.Success;
		}
	}
}