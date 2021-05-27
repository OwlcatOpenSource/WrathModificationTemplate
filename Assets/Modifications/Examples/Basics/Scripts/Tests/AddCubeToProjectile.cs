using Kingmaker.Blueprints;
using Kingmaker.Controllers.Projectiles;
using Kingmaker.PubSubSystem;
using UnityEngine;

namespace OwlcatModification.Modifications.Examples.Basics.Tests
{
	public class AddCubeToProjectileView : IProjectileLaunchedHandler
	{
		private const string TestCubeGuid = "27fcf6625bec1e3449217d6531f3315b";
		
		public void HandleProjectileLaunched(Projectile projectile)
		{
			var cubePrefab = ResourcesLibrary.TryGetResource<GameObject>(TestCubeGuid);
			var cube = GameObject.Instantiate(cubePrefab, projectile.View.transform);
			cube.transform.localPosition = Vector3.zero;
		}
	}
}