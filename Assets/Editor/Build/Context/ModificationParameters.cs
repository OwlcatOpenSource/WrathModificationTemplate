using System;
using System.IO;
using System.Text.RegularExpressions;
using Kingmaker.Modding;
using UnityEditor.Build.Pipeline.Interfaces;
using UnityEngine.SocialPlatforms;

namespace OwlcatModification.Editor.Build.Context
{
	public interface IModificationParameters : IContextObject
	{
		OwlcatModificationManifest Manifest { get; }
		Modification.SettingsData Settings { get; }
		
		string SourcePath { get; }
		string GeneratedPath { get; }
		string ScriptsPath { get; }
		string ContentPath { get; }
		string BlueprintsPath { get; }
		string LocalizationPath { get; }

		string TargetFolderName { get; }
	}
	
	public class DefaultModificationParameters : IModificationParameters
	{
		public OwlcatModificationManifest Manifest { get; }
		public Modification.SettingsData Settings { get; }

		public string SourcePath { get; }

		public string GeneratedPath { get; }

		public string ScriptsPath { get; }
		
		public string ContentPath { get; }
		
		public string BlueprintsPath { get; }

		public string LocalizationPath { get; }

		public string TargetFolderName { get; }

		public DefaultModificationParameters(
			OwlcatModificationManifest manifest, Modification.SettingsData settings, string sourcePath)
		{
			Manifest = manifest;
			Settings = settings;
			SourcePath = sourcePath;
			if (string.IsNullOrEmpty(SourcePath))
			{
				throw new Exception("Can't detect RootPath for modification");
			}
			
			GeneratedPath = Path.Combine(SourcePath, BuilderConsts.Generated);
			ScriptsPath = Path.Combine(SourcePath, BuilderConsts.Scripts);
			ContentPath = Path.Combine(SourcePath, BuilderConsts.Content);
			BlueprintsPath = Path.Combine(SourcePath, BuilderConsts.Blueprints);
			LocalizationPath = Path.Combine(SourcePath, BuilderConsts.Localization);
			
			string regexSearch = new string(Path.GetInvalidFileNameChars());
			var invalidCharsRegex = new Regex($"[{Regex.Escape(regexSearch) + "\\s"}]");
			TargetFolderName = invalidCharsRegex.Replace(Manifest.UniqueName, "");
		}
	}
}