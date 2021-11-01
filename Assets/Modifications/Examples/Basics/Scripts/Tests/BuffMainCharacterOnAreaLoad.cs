using Kingmaker;
using Kingmaker.Blueprints;
using Kingmaker.PubSubSystem;
using Kingmaker.UnitLogic;
using Kingmaker.UnitLogic.Buffs.Blueprints;
using Kingmaker.UnitLogic.Mechanics;

namespace OwlcatModification.Modifications.Examples.Basics.Tests
{
	public class BuffMainCharacterOnAreaLoad : IAreaActivationHandler
	{
		private const string TestBuffGuid = "42ea8fe3618449a5b09561d8207c50ab";
		private const string InvisibilityBuffGuid = "525f980cb29bc2240b93e953974cb325";
		
		public void OnAreaActivated()
		{
			AddBuff(TestBuffGuid);
			AddBuff(InvisibilityBuffGuid);
		}

		private static void AddBuff(string guid)
		{
			var buff = ResourcesLibrary.TryGetBlueprint<BlueprintBuff>(guid);
			var mainCharacter = Game.Instance.Player.MainCharacter.Value;
			mainCharacter.AddBuff(buff, (MechanicsContext)null);
		}
	}
}