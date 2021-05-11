using System;
using System.Reflection;
using UnityEditor.Build.Pipeline.Interfaces;
using UnityEditor.Build.Pipeline.Utilities;

namespace OwlcatModification.Editor.Build
{
	static class UglySBPHacks
	{
		private static MethodInfo s_ThreadingManager_WaitForOutstandingTasks;
		private static MethodInfo s_BuildCacheUtility_ClearCacheHashes;
		private static MethodInfo s_BuildCache_SetBuildLogger;

		static UglySBPHacks()
		{
			var threadingManagerType = Type.GetType("ThreadingManager, Unity.ScriptableBuildPipeline.Editor");
			s_ThreadingManager_WaitForOutstandingTasks = threadingManagerType.GetMethod("WaitForOutstandingTasks",
				BindingFlags.NonPublic | BindingFlags.Static);

			var buildCacheUtilityType = Type.GetType("BuildCacheUtility, Unity.ScriptableBuildPipeline.Editor");
			s_BuildCacheUtility_ClearCacheHashes = buildCacheUtilityType.GetMethod("ClearCacheHashes",
				BindingFlags.NonPublic | BindingFlags.Static);

			var buildCacheType = typeof(BuildCache);
			s_BuildCache_SetBuildLogger = buildCacheType.GetMethod("SetBuildLogger",
				BindingFlags.NonPublic | BindingFlags.Instance);
		}

		public static void ThreadingManager_WaitForOutstandingTasks()
		{
			s_ThreadingManager_WaitForOutstandingTasks.Invoke(null, null);
		}
		
		public static void BuildCacheUtility_ClearCacheHashes()
		{
			s_BuildCacheUtility_ClearCacheHashes.Invoke(null, null);
		}
		
		public static void BuildCache_SetBuildLogger(BuildCache bc, IBuildLogger logger)
		{
			s_BuildCache_SetBuildLogger.Invoke(bc, new[] {(object)logger});
		}
	}
}