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
		public static Kingmaker.Modding.OwlcatModification Modification { get; private set; }

		public static bool IsEnabled { get; private set; } = true;

		public static LogChannel Logger
			=> Modification.Logger;

		// ReSharper disable once UnusedMember.Global
		[OwlcatModificationEnterPoint]
		public static void Initialize(Kingmaker.Modding.OwlcatModification modification)
		{
			Modification = modification;

			var harmony = new Harmony(modification.Manifest.UniqueName);
			harmony.PatchAll(Assembly.GetExecutingAssembly());

			TestData();
			AddLoadResourceCallback();

			modification.OnDrawGUI += OnGUI;
			modification.IsEnabled += () => IsEnabled;
			modification.OnSetEnabled += enabled => IsEnabled = enabled;
			modification.OnShowGUI += () => Logger.Log("OnShowGUI");
			modification.OnHideGUI += () => Logger.Log("OnHideGUI");
			
			EventBus.Subscribe(new BarkOnAttackWithWeapon());
			EventBus.Subscribe(new AddCubeToProjectileView());
			EventBus.Subscribe(new DuplicateDamage());
			EventBus.Subscribe(new BuffMainCharacterOnAreaLoad());
			EventBus.Subscribe(new PerSaveDataTest());

			ControllersTest.SetupControllers();
		}

		private static void TestData()
		{
			var data = Modification.LoadData<ModificationData>();
			Logger.Log($"TestModification: prev load time {data.LastLoadTime}");
			data.LastLoadTime = DateTime.Now.ToString();
			Logger.Log($"TestModification: current load time {data.LastLoadTime}");
			Modification.SaveData(data);
		}

		private static void AddLoadResourceCallback()
		{
			Modification.OnLoadResource +=
				(resource, guid) =>
				{
					string name = (resource as UnityEngine.Object)?.name ?? resource.ToString();
					Logger.Log($"Resource loaded: {name}, {resource.GetType().Name}, {guid}");
				};
		}

		private static void OnGUI()
		{
			GUILayout.Label("Hello world!");
			GUILayout.Button("Some Button");
		}
	}
}