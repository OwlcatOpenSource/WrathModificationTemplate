using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Kingmaker.Modding;
using OwlcatModification.Editor.Build.Context;
using OwlcatModification.Editor.Build.Tasks;
using UnityEditor;
using UnityEditor.Build.Pipeline;
using UnityEditor.Build.Pipeline.Interfaces;
using UnityEditor.Build.Pipeline.Tasks;
using UnityEditor.Build.Pipeline.Utilities;
using UnityEditor.Build.Player;
using UnityEngine;

namespace OwlcatModification.Editor.Build
{
	public static class Builder
	{
		public static ReturnCode Build(Modification modification)
		{
			string sourcePath = Path.GetDirectoryName(AssetDatabase.GetAssetPath(modification));
			return Build(
				modification.Manifest, 
				modification.Settings, 
				sourcePath, 
				BuilderConsts.DefaultBuildFolder, 
				null);
		}

		public static ReturnCode Build(
			OwlcatModificationManifest manifest,
			Modification.SettingsData settings,
			string sourceFolder,
			string targetFolder,
			params IContextObject[] contextObjects)
		{
			try
			{
				return BuildInternal(manifest, settings, sourceFolder, targetFolder, contextObjects);
			}
			catch (Exception e)
			{
				EditorUtility.DisplayDialog("Error!", $"{e.Message}\n\n{e.StackTrace}", "Close");
				return ReturnCode.Exception;
			}
		}

		private static ReturnCode BuildInternal(
			OwlcatModificationManifest manifest,
			Modification.SettingsData settings,
			string sourceFolder,
			string targetFolder,
			params IContextObject[] contextObjects)
		{
			if (!Path.IsPathRooted(targetFolder))
			{
				targetFolder = Path.Combine(Path.Combine(Application.dataPath, ".."), targetFolder);
			}

			string intermediateBuildFolder = Path.Combine(targetFolder, BuilderConsts.Intermediate);
			if (Directory.Exists(targetFolder))
			{
				Directory.Delete(targetFolder, true);
			}

			Directory.CreateDirectory(intermediateBuildFolder);

			string logFilepath = Path.Combine(targetFolder, "build.log");
			var defaultBuildTarget = EditorUserBuildSettings.activeBuildTarget;
			var defaultBuildTargetGroup = BuildTargetGroup.Standalone;
			var defaultBuildOptions = EditorUserBuildSettings.development
				? ScriptCompilationOptions.DevelopmentBuild
				: ScriptCompilationOptions.None;
			
			UglySBPHacks.ThreadingManager_WaitForOutstandingTasks();
			AssetDatabase.SaveAssets();

			var buildContext = new BuildContext(contextObjects);
			var buildParameters = buildContext.EnsureContextObject<IBundleBuildParameters>(
				() => new BundleBuildParameters(defaultBuildTarget, defaultBuildTargetGroup, intermediateBuildFolder)
				{
					BundleCompression = BuildCompression.LZ4,
					ScriptOptions = defaultBuildOptions,
					UseCache = false,
				});
			
			contextObjects = (contextObjects ?? new IContextObject[0]).Concat(new IContextObject[]
			{
				buildParameters,
				buildContext.EnsureContextObject<IBundleLayoutManager>(() => new DefaultBundleLayoutManager()),
				buildContext.EnsureContextObject<IModificationRuntimeSettings>(() => new DefaultModificationRuntimeSettings()),
				buildContext.EnsureContextObject(() => new BuildInterfacesWrapper()),
				buildContext.EnsureContextObject<IBuildLogger>(() => new BuildLoggerFile(logFilepath)),
				buildContext.EnsureContextObject<IProgressTracker>(() => new ProgressLoggingTracker()),
				buildContext.EnsureContextObject<IDependencyData>(() => new BuildDependencyData()),
				buildContext.EnsureContextObject<IBundleWriteData>(() => new BundleWriteData()),
				buildContext.EnsureContextObject<IBundleBuildResults>(() => new BundleBuildResults()),
				buildContext.EnsureContextObject<IDeterministicIdentifiers>(() => new Unity5PackedIdentifiers()),
				buildContext.EnsureContextObject<IBundleBuildContent>(() 
					=> new BundleBuildContent(Enumerable.Empty<AssetBundleBuild>())),
				buildContext.EnsureContextObject<IBuildCache>(
					() => new BuildCache(buildParameters.CacheServerHost, buildParameters.CacheServerPort)),
				buildContext.EnsureContextObject<IModificationParameters>(
					() => new DefaultModificationParameters(manifest, settings, sourceFolder)),
			}).ToArray();

			var tasksList = GetTasks().ToArray();
			try
			{
				return RunTasks(tasksList, buildContext);
			}
			finally
			{
				Dispose(contextObjects, tasksList);
			}
		}

		private static ReturnCode RunTasks(IList<IBuildTask> tasksList, IBuildContext context)
		{
			var validationResult = BuildTasksRunner.Validate(tasksList, context);
			if (validationResult < ReturnCode.Success)
			{
				return validationResult;
			}

			return BuildTasksRunner.Run(tasksList, context);
		}

		private static void Dispose(IEnumerable<IContextObject> contextObjects, IEnumerable<IBuildTask> tasks)
		{
			foreach (var disposable in contextObjects.OfType<IDisposable>())
			{
				try
				{
					disposable.Dispose();
				}
				catch (Exception e)
				{
					BuildLogger.LogException(e);
				}
			}

			// ReSharper disable once SuspiciousTypeConversion.Global
			foreach (var disposable in tasks.OfType<IDisposable>())
			{
				try
				{
					disposable.Dispose();
				}
				catch (Exception e)
				{
					BuildLogger.LogException(e);
				}
			}
		}

		private static T EnsureContextObject<T>(this BuildContext context, Func<T> createDefaultObject) where T : IContextObject
		{
			if (!context.ContainsContextObject<T>())
			{
				var obj = createDefaultObject.Invoke();
				context.SetContextObject(obj);
				return obj;
			}

			return context.GetContextObject<T>();
		}

		private static IEnumerable<IBuildTask> GetTasks()
		{
			yield return new SwitchToBuildPlatform();

			yield return new PrepareBuild();
			
			yield return new BuildAssemblies();

			yield return new PrepareBlueprints();
			
			yield return new ExtractBlueprintDirectReferences();
			yield return new PrepareBundles();

			yield return new PrepareLocalization();

			yield return new CheckAssetsValidity();

			yield return new CalculateSceneDependencyData();
			yield return new CalculateCustomDependencyData();
			yield return new CalculateAssetDependencyData();

			yield return new GenerateBundlePacking();
			yield return new UpdateBundleObjectLayout();
			yield return new GenerateBundleCommands();
			yield return new GenerateSubAssetPathMaps();
			yield return new GenerateBundleMaps();

			yield return new WriteSerializedFiles();
			yield return new ArchiveAndCompressBundles();

			yield return new CreateManifestAndSettings();

			yield return new PrepareArtifacts();
			yield return new PackArtifacts();
		}
	}
}