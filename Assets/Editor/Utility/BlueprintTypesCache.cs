using System;
using System.Collections.Generic;
using System.Reflection;
using Kingmaker.Blueprints;
using Kingmaker.Blueprints.JsonSystem;

namespace OwlcatModification.Editor.Utility
{
	public static class BlueprintTypesCache
	{
		public class Entry
		{
			public readonly Type Type;
			public readonly string Name;
			public readonly string NameLowerInvariant;
			public readonly string Guid;

			public Entry(Type type, string name, string guid)
			{
				Type = type;
				Name = name;
				NameLowerInvariant = name.ToLowerInvariant();
				Guid = guid;
			}
		}

		private static List<Entry> s_TypeCache;

		public static IEnumerable<Entry> Types {
			get 
			{
				PrepareTypeCache();
				return s_TypeCache;
			}
		}

		private static void PrepareTypeCache()
		{
			if (s_TypeCache != null)
			{
				return;
			}

			s_TypeCache = new List<Entry>();
			foreach (var type in Assembly.GetAssembly(typeof(SimpleBlueprint)).GetTypes())
			{
				if (!typeof(SimpleBlueprint).IsAssignableFrom(type))
				{
					continue;
				}

				var typeId = type.GetCustomAttribute<TypeIdAttribute>();
				if (typeId != null)
				{
					s_TypeCache.Add(new Entry(type, type.Name, typeId.GuidString));
				}
			}
		}
	}
}