using System;
using System.Reflection;
using HarmonyLib;
using Kingmaker.Modding;
using Kingmaker.PubSubSystem;
using Owlcat.Runtime.Core.Logging;
using OwlcatModification.Modifications.Examples.Basics.Tests;
using UnityEngine;

namespace OwlcatModification.Modifications.Examples.Basics
{
	// ReSharper disable once UnusedType.Global
	public static class ModificationRoot
	{
		private static Kingmaker.Modding.OwlcatModification Modification { get; set; }
		
		private static readonly LogChannel Channel = LogChannelFactory.GetOrCreate("TestModification"); 

		// ReSharper disable once UnusedMember.Global
		[OwlcatModificationEnterPoint]
		public static void Initialize(Kingmaker.Modding.OwlcatModification modification)
		{
			Modification = modification;

			var harmony = new Harmony(modification.Manifest.UniqueName);
			harmony.PatchAll(Assembly.GetExecutingAssembly());

			TestData();
			AddLoadResourceCallback();

			modification.OnGUI += OnGUI;
			
			EventBus.Subscribe(new BarkOnAttackWithWeapon());
			EventBus.Subscribe(new AddCubeToProjectileView());
			EventBus.Subscribe(new DuplicateDamage());
			EventBus.Subscribe(new BuffMainCharacterOnAreaLoad());

			ControllersTest.SetupControllers();
		}

		private static void TestData()
		{
			var data = Modification.LoadData<ModificationData>();
			Channel.Log($"TestModification: prev load time {data.LastLoadTime}");
			data.LastLoadTime = DateTime.Now.ToString();
			Channel.Log($"TestModification: current load time {data.LastLoadTime}");
			Modification.SaveData(data);
		}

		private static void AddLoadResourceCallback()
		{
			Modification.LoadResourceCallbacks +=
				(resource, guid) =>
				{
					string name = (resource as UnityEngine.Object)?.name ?? resource.ToString();
					Channel.Log($"Resource loaded: {name}, {resource.GetType().Name}, {guid}");
				};
		}

		private static void OnGUI()
		{
			GUILayout.Label("Hello world!");
			GUILayout.Button("Some Button");
		}
	}
}