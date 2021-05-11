using System.IO;
using OwlcatModification.Editor.Build.Context;
using UnityEditor;
using UnityEditor.Build.Pipeline;
using UnityEditor.Build.Pipeline.Injector;
using UnityEditor.Build.Pipeline.Interfaces;

namespace OwlcatModification.Editor.Build.Tasks
{
	public class PrepareBuild : IBuildTask
	{
#pragma warning disable 649
		[InjectContext(ContextUsage.In)]
		private IModificationParameters m_ModificationParameters;
#pragma warning restore 649
		
		public int Version
			=> 1;
		
		public ReturnCode Run()
		{
			if (Directory.Exists(m_ModificationParameters.GeneratedPath))
			{
				Directory.Delete(m_ModificationParameters.GeneratedPath, true);
			}

			Directory.CreateDirectory(m_ModificationParameters.GeneratedPath);
			
			AssetDatabase.Refresh();
			
			return ReturnCode.Success;
		}
	}
}