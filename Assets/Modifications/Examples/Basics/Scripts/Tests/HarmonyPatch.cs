using HarmonyLib;
using Kingmaker.EntitySystem.Entities;

namespace OwlcatModification.Modifications.Examples.Basics.Tests
{    
    [HarmonyPatch(typeof(UnitEntityData), "CurrentSpeedMps", MethodType.Getter)]
    internal static class UnitEntityData_CalculateCurrentSpeed_Patch
    {
        internal static void Postfix(ref float __result)
        {
            // set speed of all units to 10 meters per seconds
            __result = 10f;
        }
    }
}