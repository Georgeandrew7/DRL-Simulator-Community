using BepInEx;
using BepInEx.Logging;
using HarmonyLib;
using System;
using System.Reflection;

namespace DRLCommunityMod
{
    /// <summary>
    /// BepInEx plugin that bypasses the DRL license check for self-hosted multiplayer.
    /// V1.2.0 - Targeted patching - ONLY patches specific license methods, not inherited Unity methods.
    /// </summary>
    [BepInPlugin("com.community.drl.licensebypass", "DRL License Bypass", "1.2.0")]
    public class LicenseBypassPlugin : BaseUnityPlugin
    {
        private static ManualLogSource Log;
        private Harmony harmony;

        void Awake()
        {
            Log = Logger;
            Log.LogInfo("DRL License Bypass Plugin v1.2.0 loading...");
            
            harmony = new Harmony("com.community.drl.licensebypass");
            
            try
            {
                PatchLicenseMethods();
                Log.LogInfo("License bypass patches applied successfully!");
            }
            catch (Exception e)
            {
                Log.LogError($"Failed to apply license patches: {e.Message}");
                Log.LogError(e.StackTrace);
            }
        }

        private void PatchLicenseMethods()
        {
            Assembly assemblyCSharp = null;
            
            foreach (var assembly in AppDomain.CurrentDomain.GetAssemblies())
            {
                if (assembly.GetName().Name == "Assembly-CSharp")
                {
                    assemblyCSharp = assembly;
                    break;
                }
            }
            
            if (assemblyCSharp == null)
            {
                Log.LogError("Assembly-CSharp not found!");
                return;
            }
            
            // ONLY patch these two specific types
            PatchType(assemblyCSharp, "drl.game.LicenseStateModel");
            PatchType(assemblyCSharp, "drl.backend.DRLLicenseResult");
        }

        private void PatchType(Assembly assembly, string typeName)
        {
            Type type = assembly.GetType(typeName);
            if (type == null)
            {
                Log.LogWarning($"Type not found: {typeName}");
                return;
            }
            
            Log.LogInfo($"Patching {typeName}...");
            
            // CRITICAL: Use BindingFlags.DeclaredOnly to only get methods declared IN THIS TYPE
            // This prevents patching inherited methods like isActiveAndEnabled from UnityEngine.Behaviour
            var methods = type.GetMethods(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.DeclaredOnly);
            
            foreach (var method in methods)
            {
                // Only patch bool-returning methods that look like license checks
                if (method.ReturnType != typeof(bool))
                    continue;
                
                // Only patch these specific method names
                string name = method.Name.ToLower();
                if (name == "get_exists" || 
                    name == "get_license" || 
                    name == "get_haslicense" ||
                    name == "get_islicensed" ||
                    name == "get_ispremium" ||
                    name == "get_valid")
                {
                    Log.LogInfo($"  Patching {method.Name} -> true");
                    
                    try
                    {
                        harmony.Patch(
                            method,
                            prefix: new HarmonyMethod(typeof(LicenseBypassPlugin), nameof(ReturnTruePrefix))
                        );
                    }
                    catch (Exception e)
                    {
                        Log.LogWarning($"    Failed to patch {method.Name}: {e.Message}");
                    }
                }
            }
        }
        
        // Prefix that returns true and skips original method
        public static bool ReturnTruePrefix(ref bool __result)
        {
            __result = true;
            return false; // Skip original method
        }
        
        void OnDestroy()
        {
            harmony?.UnpatchSelf();
        }
    }
}
