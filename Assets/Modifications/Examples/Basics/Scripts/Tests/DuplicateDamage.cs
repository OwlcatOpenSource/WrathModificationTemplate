using System.Linq;
using Kingmaker.PubSubSystem;
using Kingmaker.RuleSystem;
using Kingmaker.RuleSystem.Rules.Damage;

namespace OwlcatModification.Modifications.Examples.Basics.Tests
{
	public class DuplicateDamage :
		IBeforeRulebookEventTriggerHandler<RuleDealDamage>,
		IBeforeRulebookEventTriggerHandler<RulePrepareDamage>
	{
		public RulebookEvent.CustomDataKey DuplicateDamageKey =
			new RulebookEvent.CustomDataKey(nameof(DuplicateDamageKey));
		
		public void OnBeforeRulebookEventTrigger(RuleDealDamage evt)
		{
			evt.SetCustomData(DuplicateDamageKey, true);
		}

		public void OnBeforeRulebookEventTrigger(RulePrepareDamage evt)
		{
			if (evt.ParentRule.TryGetCustomData(DuplicateDamageKey, out bool duplicate) && duplicate)
			{
				foreach (var damage in evt.DamageBundle.ToArray())
				{
					evt.Add(damage.Copy());
				}
			}
		}
	}
}