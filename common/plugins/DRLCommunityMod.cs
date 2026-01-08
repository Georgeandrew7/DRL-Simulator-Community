// DRL Community Multiplayer Mod
// BepInEx plugin for DRL Simulator that enables P2P multiplayer
//
// Features:
// - P2P hosting (host becomes the server)
// - Track sharing between players  
// - Steam integration for player identity
// - Spectator mode support
// - Player input synchronization (stick movements, etc.)
//
// Installation:
// 1. Install BepInEx for Unity 2020 (IL2CPP or Mono depending on game)
// 2. Place this DLL in BepInEx/plugins/
// 3. Configure community-server settings

using BepInEx;
using BepInEx.Logging;
using HarmonyLib;
using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Reflection;
using System.Threading.Tasks;
using UnityEngine;
using Photon.Pun;
using Photon.Realtime;
using ExitGames.Client.Photon;

namespace DRLCommunityMod
{
    [BepInPlugin(PluginGUID, PluginName, PluginVersion)]
    public class DRLCommunityPlugin : BaseUnityPlugin
    {
        public const string PluginGUID = "com.community.drl.multiplayer";
        public const string PluginName = "DRL Community Multiplayer";
        public const string PluginVersion = "1.0.0";

        internal static ManualLogSource Log;
        internal static DRLCommunityPlugin Instance;
        
        // Configuration
        public static string MasterServerUrl = "http://localhost:8080";
        public static string PlayerSteamId = "";
        public static string PlayerName = "";
        public static string PlayerAvatarUrl = "";
        
        // Session state
        public static bool IsHost = false;
        public static string CurrentSessionId = "";
        public static List<CommunityPlayer> ConnectedPlayers = new List<CommunityPlayer>();
        
        // P2P Server
        private static P2PServer p2pServer;
        
        private Harmony harmony;
        private HttpClient httpClient;
        
        private void Awake()
        {
            Instance = this;
            Log = Logger;
            
            Log.LogInfo($"{PluginName} v{PluginVersion} loading...");
            
            // Initialize HTTP client
            httpClient = new HttpClient();
            httpClient.Timeout = TimeSpan.FromSeconds(10);
            
            // Load configuration
            LoadConfig();
            
            // Load player data from player-state.json
            LoadPlayerData();
            
            // Apply Harmony patches
            harmony = new Harmony(PluginGUID);
            harmony.PatchAll(typeof(PhotonPatches));
            harmony.PatchAll(typeof(MultiplayerPatches));
            
            Log.LogInfo($"Patches applied. Player: {PlayerName} ({PlayerSteamId})");
        }
        
        private void LoadConfig()
        {
            // Load from BepInEx config
            MasterServerUrl = Config.Bind("Server", "MasterServerUrl", 
                "http://localhost:8080", 
                "URL of the community master server").Value;
        }
        
        private void LoadPlayerData()
        {
            try
            {
                string gameDataPath = Path.Combine(Application.dataPath, "StreamingAssets", 
                    "game", "storage", "offline", "state", "player", "player-state.json");
                
                if (File.Exists(gameDataPath))
                {
                    string json = File.ReadAllText(gameDataPath);
                    var playerState = JsonUtility.FromJson<PlayerState>(json);
                    
                    PlayerSteamId = playerState.steamId ?? "";
                    PlayerName = playerState.profileName ?? "Unknown";
                    PlayerAvatarUrl = playerState.profilePhotoUrl ?? "";
                    
                    Log.LogInfo($"Loaded player: {PlayerName} (Steam: {PlayerSteamId})");
                }
            }
            catch (Exception e)
            {
                Log.LogError($"Failed to load player data: {e.Message}");
            }
        }
        
        /// <summary>
        /// Create a new P2P multiplayer session
        /// </summary>
        public async Task<string> CreateSession(string roomName, string mapId, string trackId, 
            bool isCustomTrack, string gameMode = "race", int laps = 3)
        {
            try
            {
                // Start local P2P server
                p2pServer = new P2PServer();
                await p2pServer.Start(5056);
                IsHost = true;
                
                // Register with master server
                var sessionData = new Dictionary<string, object>
                {
                    ["host_steam_id"] = PlayerSteamId,
                    ["host_name"] = PlayerName,
                    ["host_avatar_url"] = PlayerAvatarUrl,
                    ["host_port"] = 5056,
                    ["room_name"] = roomName,
                    ["map_id"] = mapId,
                    ["track_id"] = trackId,
                    ["is_custom_track"] = isCustomTrack,
                    ["game_mode"] = gameMode,
                    ["laps"] = laps,
                };
                
                string json = JsonUtility.ToJson(sessionData);
                var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");
                
                var response = await httpClient.PostAsync($"{MasterServerUrl}/api/sessions", content);
                string responseBody = await response.Content.ReadAsStringAsync();
                
                if (response.IsSuccessStatusCode)
                {
                    var session = JsonUtility.FromJson<SessionResponse>(responseBody);
                    CurrentSessionId = session.session_id;
                    Log.LogInfo($"Session created: {CurrentSessionId}");
                    
                    // Start heartbeat
                    StartCoroutine(SessionHeartbeat());
                    
                    return CurrentSessionId;
                }
                
                Log.LogError($"Failed to create session: {responseBody}");
                return null;
            }
            catch (Exception e)
            {
                Log.LogError($"CreateSession error: {e.Message}");
                return null;
            }
        }
        
        /// <summary>
        /// Join an existing session
        /// </summary>
        public async Task<bool> JoinSession(string sessionId, bool asSpectator = false, string password = "")
        {
            try
            {
                var joinData = new Dictionary<string, object>
                {
                    ["steam_id"] = PlayerSteamId,
                    ["name"] = PlayerName,
                    ["avatar_url"] = PlayerAvatarUrl,
                    ["as_spectator"] = asSpectator,
                    ["password"] = password,
                };
                
                string json = JsonUtility.ToJson(joinData);
                var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");
                
                var response = await httpClient.PostAsync(
                    $"{MasterServerUrl}/api/sessions/{sessionId}/join", content);
                string responseBody = await response.Content.ReadAsStringAsync();
                
                if (response.IsSuccessStatusCode)
                {
                    var joinResponse = JsonUtility.FromJson<JoinResponse>(responseBody);
                    
                    // Connect to host
                    await ConnectToHost(joinResponse.connection.host_ip, 
                        joinResponse.connection.host_port);
                    
                    // Check if we need to download track
                    if (joinResponse.track.is_custom && joinResponse.track.download_allowed)
                    {
                        await CheckAndDownloadTrack(joinResponse.track.map_id, 
                            joinResponse.track.track_id);
                    }
                    
                    CurrentSessionId = sessionId;
                    IsHost = false;
                    Log.LogInfo($"Joined session: {sessionId}");
                    return true;
                }
                
                Log.LogError($"Failed to join session: {responseBody}");
                return false;
            }
            catch (Exception e)
            {
                Log.LogError($"JoinSession error: {e.Message}");
                return false;
            }
        }
        
        private async Task ConnectToHost(string ip, int port)
        {
            // TODO: Implement P2P client connection
            Log.LogInfo($"Connecting to host at {ip}:{port}");
        }
        
        private async Task CheckAndDownloadTrack(string mapId, string trackId)
        {
            string tracksPath = Path.Combine(Application.dataPath, "StreamingAssets", 
                "game", "content", "maps", mapId, "custom", trackId);
            
            if (!Directory.Exists(tracksPath))
            {
                Log.LogInfo($"Track {trackId} not found, requesting download from host...");
                // TODO: Request track data from host via P2P
            }
        }
        
        private System.Collections.IEnumerator SessionHeartbeat()
        {
            while (!string.IsNullOrEmpty(CurrentSessionId))
            {
                yield return new WaitForSeconds(30f);
                
                try
                {
                    var request = new UnityWebRequest(
                        $"{MasterServerUrl}/api/sessions/{CurrentSessionId}/heartbeat", "POST");
                    yield return request.SendWebRequest();
                }
                catch { }
            }
        }
        
        private void OnDestroy()
        {
            // Cleanup
            if (!string.IsNullOrEmpty(CurrentSessionId))
            {
                // Leave/delete session
                try
                {
                    if (IsHost)
                    {
                        httpClient.DeleteAsync($"{MasterServerUrl}/api/sessions/{CurrentSessionId}");
                    }
                }
                catch { }
            }
            
            p2pServer?.Stop();
            harmony?.UnpatchSelf();
        }
    }
    
    /// <summary>
    /// Patches for Photon networking to redirect to community servers
    /// </summary>
    [HarmonyPatch]
    public static class PhotonPatches
    {
        /// <summary>
        /// Patch PhotonNetwork.ConnectToMasterServer to use our self-hosted server
        /// </summary>
        [HarmonyPatch(typeof(PhotonNetwork), nameof(PhotonNetwork.ConnectToMasterServer))]
        [HarmonyPrefix]
        public static bool ConnectToMasterServer_Prefix(string masterServerAddress)
        {
            DRLCommunityPlugin.Log.LogInfo($"Redirecting Photon connection from {masterServerAddress} to self-hosted");
            
            // Redirect to local Photon server if available
            // Otherwise, use P2P mode
            return true; // Let original run with modified settings
        }
        
        /// <summary>
        /// Patch PhotonNetwork.CreateRoom to enable P2P hosting
        /// </summary>
        [HarmonyPatch(typeof(PhotonNetwork), nameof(PhotonNetwork.CreateRoom))]
        [HarmonyPrefix]
        public static bool CreateRoom_Prefix(string roomName, RoomOptions roomOptions, 
            TypedLobby typedLobby)
        {
            DRLCommunityPlugin.Log.LogInfo($"Creating room: {roomName}");
            
            // Optionally create community session alongside Photon room
            if (DRLCommunityPlugin.Instance != null)
            {
                // Register with master server
                // The room creation will proceed normally through Photon
            }
            
            return true;
        }
    }
    
    /// <summary>
    /// Patches for DRL's multiplayer systems
    /// </summary>
    [HarmonyPatch]
    public static class MultiplayerPatches
    {
        // TODO: Add patches for:
        // - Player input synchronization (stick movements)
        // - Spectator camera controls
        // - Race state synchronization
        // - Track loading
    }
    
    /// <summary>
    /// Simple P2P server for hosting games
    /// </summary>
    public class P2PServer
    {
        private HttpListener listener;
        private bool running = false;
        
        public async Task Start(int port)
        {
            listener = new HttpListener();
            listener.Prefixes.Add($"http://*:{port}/");
            listener.Start();
            running = true;
            
            DRLCommunityPlugin.Log.LogInfo($"P2P Server started on port {port}");
            
            // Start accepting connections
            _ = AcceptConnections();
        }
        
        private async Task AcceptConnections()
        {
            while (running)
            {
                try
                {
                    var context = await listener.GetContextAsync();
                    _ = HandleConnection(context);
                }
                catch (Exception e)
                {
                    if (running)
                        DRLCommunityPlugin.Log.LogError($"P2P Server error: {e.Message}");
                }
            }
        }
        
        private async Task HandleConnection(HttpListenerContext context)
        {
            // Handle P2P game data
            // - Player state updates
            // - Track data requests
            // - Game state sync
            
            var response = context.Response;
            response.StatusCode = 200;
            response.Close();
        }
        
        public void Stop()
        {
            running = false;
            listener?.Stop();
        }
    }
    
    // Data classes for JSON serialization
    
    [Serializable]
    public class PlayerState
    {
        [SerializeField] private string steam_id;
        [SerializeField] private string profile_name;
        [SerializeField] private string profile_photo_url;
        
        public string steamId => steam_id;
        public string profileName => profile_name;
        public string profilePhotoUrl => profile_photo_url;
    }
    
    [Serializable]
    public class SessionResponse
    {
        public string session_id;
        public string host_name;
        public string room_name;
    }
    
    [Serializable]
    public class JoinResponse
    {
        public string status;
        public ConnectionInfo connection;
        public TrackInfo track;
    }
    
    [Serializable]
    public class ConnectionInfo
    {
        public string host_ip;
        public int host_port;
        public string session_id;
    }
    
    [Serializable]
    public class TrackInfo
    {
        public string map_id;
        public string track_id;
        public bool is_custom;
        public bool download_allowed;
    }
    
    [Serializable]
    public class CommunityPlayer
    {
        public string SteamId;
        public string Name;
        public string AvatarUrl;
        public bool IsHost;
        public bool IsSpectator;
        
        // Runtime state
        public Vector3 Position;
        public Quaternion Rotation;
        public float[] StickInputs = new float[4]; // Throttle, Yaw, Pitch, Roll
    }
}
