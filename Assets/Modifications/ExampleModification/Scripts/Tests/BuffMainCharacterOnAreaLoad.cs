using Kingmaker;
using Kingmaker.Blueprints;
using Kingmaker.PubSubSystem;
using Kingmaker.UnitLogic;
using Kingmaker.UnitLogic.Buffs.Blueprints;
using Kingmaker.UnitLogic.Mechanics;

namespace OwlcatModification.Modification.Tests
{
	public class BuffMainCharacterOnAreaLoad : IAreaActivationHandler
	{
		private const string BuffGuid = "42ea8fe3618449a5b09561d8207c50ab";
		
		public void OnAreaActivated()
		{
			var buff = ResourcesLibrary.TryGetBlueprint<BlueprintBuff>(BuffGuid);
			var mainCharacter = Game.Instance.Player.MainCharacter.Value;
			mainCharacter.AddBuff(buff, (MechanicsContext)null);
		}
	}
}