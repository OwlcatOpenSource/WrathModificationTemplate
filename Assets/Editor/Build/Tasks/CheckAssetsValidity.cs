using UnityEditor.Build.Pipeline;
using UnityEditor.Build.Pipeline.Interfaces;

namespace OwlcatModification.Editor.Build.Tasks
{
	public class CheckAssetsValidity : IBuildTask
	{
		public int Version
			=> 1;
		
		public ReturnCode Run()
		{
			return ReturnCode.Success;
		}
	}
}