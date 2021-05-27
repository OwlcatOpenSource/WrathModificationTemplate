using Kingmaker;
using Kingmaker.PubSubSystem;
using Kingmaker.RuleSystem.Rules;

namespace OwlcatModification.Modifications.Examples.Basics.Tests
{
    public class BarkOnAttackWithWeapon : IGlobalRulebookHandler<RuleAttackWithWeapon>
    {
        public void OnEventAboutToTrigger(RuleAttackWithWeapon evt)
        {
        }

        public void OnEventDidTrigger(RuleAttackWithWeapon evt)
        {
            Game.Instance.UI.Bark(evt.Initiator, evt.AttackRoll.IsHit ? "HIT!" : "MISS!");
        }
    }
}
