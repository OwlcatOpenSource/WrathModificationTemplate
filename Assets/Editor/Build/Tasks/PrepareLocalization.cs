using System;
using System.IO;
using System.Linq;
using Kingmaker.Localization.Shared;
using OwlcatModification.Editor.Build.Context;
using UnityEditor.Build.Pipeline;
using UnityEditor.Build.Pipeline.Injector;
using UnityEditor.Build.Pipeline.Interfaces;

namespace OwlcatModification.Editor.Build.Tasks
{
	public class PrepareLocalization : IBuildTask
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
			string[] localeFiles = Enum.GetNames(typeof(Locale)).Select(i => i + ".json").ToArray();

			string originDirectory = m_ModificationParameters.LocalizationPath;
			string destinationDirectory = m_BuildParameters.GetOutputFilePathForIdentifier(BuilderConsts.OutputLocalization);
			BuilderUtils.CopyFilesWithFoldersStructure(
				originDirectory, destinationDirectory, i =>
				{
					string filename = Path.GetFileName(i);
					return localeFiles.Contains(filename);
				});
			
			return ReturnCode.Success;
		}
	}
}