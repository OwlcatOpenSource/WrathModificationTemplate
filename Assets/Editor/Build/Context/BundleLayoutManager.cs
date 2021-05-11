using System;
using System.IO;
using System.Text;
using JetBrains.Annotations;
using UnityEditor.Build.Pipeline.Interfaces;

namespace OwlcatModification.Editor.Build.Context
{
	public interface IBundleLayoutManager : IContextObject
	{
		/// <summary>
		/// 'prefix' is modification name without characters which forbidden for filenames.
		/// Used for decrease chance of name collision between different modifications.
		/// </summary>
		[CanBeNull]
		string GetBundleForAssetPath(string assetPath, string prefix);
	}

	public class DefaultBundleLayoutManager : IBundleLayoutManager
	{
		private static readonly StringBuilder StringBuilder = new StringBuilder();
		
		public string GetBundleForAssetPath(string assetPath, string prefix)
		{
			if (assetPath == null)
			{
				return null;
			}

			if (assetPath.EndsWith(".unity", StringComparison.OrdinalIgnoreCase))
			{
				return GetFullBundleName(prefix, Path.GetFileNameWithoutExtension(assetPath).ToLowerInvariant());
			}

			if (assetPath.EndsWith(".prefab", StringComparison.OrdinalIgnoreCase) || 
			    assetPath.EndsWith(".mat", StringComparison.OrdinalIgnoreCase) || 
			    assetPath.EndsWith(".asset", StringComparison.OrdinalIgnoreCase))
			{
				return GetFullBundleName(prefix, BuilderConsts.DefaultBundleName);
			}

			return null;
		}

		private static string GetFullBundleName(string prefix, string name)
		{
			StringBuilder.Clear();
			StringBuilder.Append(prefix);
			StringBuilder.Append("_");
			StringBuilder.Append(name);

			return StringBuilder.ToString();
		}
	}
}