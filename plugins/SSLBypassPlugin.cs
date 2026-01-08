using BepInEx;
using BepInEx.Logging;
using HarmonyLib;
using System;
using System.Reflection;
using UnityEngine;
using UnityEngine.Networking;

namespace DRLCommunity
{
    /// <summary>
    /// BepInEx plugin to bypass SSL certificate validation for self-hosted servers.
    /// This allows the game to connect to local mock servers using self-signed certificates.
    /// </summary>
    [BepInPlugin("com.drlcommunity.sslbypass", "DRL SSL Bypass", "1.0.0")]
    public class SSLBypassPlugin : BaseUnityPlugin
    {
        internal static ManualLogSource Log;
        private Harmony _harmony;

        void Awake()
        {
            Log = Logger;
            Log.LogInfo("DRL SSL Bypass Plugin loaded!");
            Log.LogInfo("This plugin allows connection to self-hosted servers with self-signed certificates.");
            
            // Apply Harmony patches
            _harmony = new Harmony("com.drlcommunity.sslbypass");
            _harmony.PatchAll();
            
            Log.LogInfo("SSL certificate validation bypass enabled.");
        }

        void OnDestroy()
        {
            _harmony?.UnpatchSelf();
        }
    }

    /// <summary>
    /// Custom certificate handler that accepts all certificates.
    /// Used for self-hosted server connections.
    /// </summary>
    public class AcceptAllCertificates : CertificateHandler
    {
        protected override bool ValidateCertificate(byte[] certificateData)
        {
            // Accept all certificates for self-hosted server
            SSLBypassPlugin.Log?.LogDebug("Accepting certificate (self-hosted mode)");
            return true;
        }
    }

    /// <summary>
    /// Harmony patches to inject our certificate handler into all UnityWebRequests.
    /// </summary>
    [HarmonyPatch]
    public static class UnityWebRequestPatches
    {
        /// <summary>
        /// Patch UnityWebRequest constructor to inject our certificate handler.
        /// </summary>
        [HarmonyPatch(typeof(UnityWebRequest), MethodType.Constructor)]
        [HarmonyPostfix]
        public static void ConstructorPostfix(UnityWebRequest __instance)
        {
            try
            {
                __instance.certificateHandler = new AcceptAllCertificates();
                SSLBypassPlugin.Log?.LogDebug("Injected AcceptAllCertificates handler into new UnityWebRequest");
            }
            catch (Exception e)
            {
                SSLBypassPlugin.Log?.LogError($"Failed to inject certificate handler: {e.Message}");
            }
        }

        /// <summary>
        /// Patch UnityWebRequest.Get to ensure certificate handler is set.
        /// </summary>
        [HarmonyPatch(typeof(UnityWebRequest), "Get", new Type[] { typeof(string) })]
        [HarmonyPostfix]
        public static void GetPostfix(UnityWebRequest __result)
        {
            try
            {
                if (__result != null && __result.certificateHandler == null)
                {
                    __result.certificateHandler = new AcceptAllCertificates();
                    SSLBypassPlugin.Log?.LogDebug($"Injected AcceptAllCertificates into Get request: {__result.url}");
                }
            }
            catch (Exception e)
            {
                SSLBypassPlugin.Log?.LogError($"Failed to patch Get request: {e.Message}");
            }
        }

        /// <summary>
        /// Patch UnityWebRequest.Post to ensure certificate handler is set.
        /// </summary>
        [HarmonyPatch(typeof(UnityWebRequest), "Post", new Type[] { typeof(string), typeof(string) })]
        [HarmonyPostfix]
        public static void PostPostfix(UnityWebRequest __result)
        {
            try
            {
                if (__result != null && __result.certificateHandler == null)
                {
                    __result.certificateHandler = new AcceptAllCertificates();
                    SSLBypassPlugin.Log?.LogDebug($"Injected AcceptAllCertificates into Post request: {__result.url}");
                }
            }
            catch (Exception e)
            {
                SSLBypassPlugin.Log?.LogError($"Failed to patch Post request: {e.Message}");
            }
        }

        /// <summary>
        /// Patch SendWebRequest to ensure our handler is in place before sending.
        /// </summary>
        [HarmonyPatch(typeof(UnityWebRequest), "SendWebRequest")]
        [HarmonyPrefix]
        public static void SendWebRequestPrefix(UnityWebRequest __instance)
        {
            try
            {
                if (__instance.certificateHandler == null)
                {
                    __instance.certificateHandler = new AcceptAllCertificates();
                    SSLBypassPlugin.Log?.LogDebug($"Injected AcceptAllCertificates before SendWebRequest: {__instance.url}");
                }
            }
            catch (Exception e)
            {
                SSLBypassPlugin.Log?.LogError($"Failed to patch SendWebRequest: {e.Message}");
            }
        }
    }
}
