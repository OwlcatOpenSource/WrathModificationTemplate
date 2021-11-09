using Kingmaker;
using Kingmaker.EntitySystem;
using Kingmaker.PubSubSystem;
using Kingmaker.Utility;

namespace OwlcatModification.Modifications.Examples.Basics.Tests
{
	public class PerSaveDataTest : IAreaActivationHandler
	{
		public void OnAreaActivated()
		{
			const string propertyName = "IntValue";
			var data = Game.Instance.Player
				.Ensure<EntityPartKeyValueStorage>()
				.GetStorage(ModificationRoot.Modification.Manifest.UniqueName);
			if (data.Get(propertyName) == null)
			{
				data["IntValue"] = 42.ToString();
			}
			else
			{
				data[propertyName] = (int.Parse(data[propertyName]) + 1).ToString();
			}
			
			ModificationRoot.Logger.Log(data[propertyName]);
		}
	}
}