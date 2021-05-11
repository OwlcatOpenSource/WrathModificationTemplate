using Kingmaker.Modding;
using UnityEditor.Build.Pipeline.Interfaces;

namespace OwlcatModification.Editor.Build.Context
{
	public interface IModificationRuntimeSettings : IContextObject
	{
		OwlcatModificationSettings Settings { get; }
	}

	public class DefaultModificationRuntimeSettings : IModificationRuntimeSettings
	{
		public OwlcatModificationSettings Settings { get; } = new OwlcatModificationSettings();
	}
}