using System;
using System.IO;

namespace OwlcatModification.Editor.Build
{
	public static class BuilderUtils
	{
		public static void CopyFilesWithFoldersStructure(string origin, string destination, Predicate<string> predicate = null)
		{
			if (!Directory.Exists(origin))
			{
				return;
			}

			predicate = predicate ?? (_ => true);
			Directory.CreateDirectory(destination);

			string[] files = Directory.GetFiles(origin, "*", SearchOption.TopDirectoryOnly);
			foreach (string filePath in files)
			{
				if (!predicate.Invoke(filePath))
				{
					continue;
				}

				string fileName = Path.GetFileName(filePath);
				File.Copy(filePath, Path.Combine(destination, fileName));
			}

			string[] directories = Directory.GetDirectories(origin, "*", SearchOption.TopDirectoryOnly);
			foreach (string directoryPath in directories)
			{
				string directoryName = Path.GetFileName(directoryPath);
				CopyFilesWithFoldersStructure(directoryPath, Path.Combine(destination, directoryName), predicate);
			}
		}
	}
}