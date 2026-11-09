#include <sdkhooks>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#define EF_NODRAW 32
#define HEADTAKER 266
#define HHH_MODEL		"models/player/hhh_player/hhh_player.mdl"
#define AXE_MODEL		"models/weapons/c_models/c_bigaxe/c_bigaxe.mdl"
#define SND_LAUGH		"Halloween.HeadlessBossLaugh"
#define SND_DYING		"Halloween.HeadlessBossDying"
#define SND_DEATH		"Halloween.HeadlessBossDeath"
#define SND_PAIN		"Halloween.HeadlessBossPain"
#define SND_BOO			"Halloween.HeadlessBossBoo"
#define SND_ALERT		"Halloween.HeadlessBossAlert"
#define SND_ATTACK		"Halloween.HeadlessBossAttack"
#define SND_SPAWN		"Halloween.HeadlessBossSpawn"
#define SND_SPAWNRUMBLE	"Halloween.HeadlessBossSpawnRumble"
#define SND_FOOT		"Halloween.HeadlessBossFootfalls"
#define SND_AXEHITFLESH	"Halloween.HeadlessBossAxeHitFlesh"
#define SND_AXEHITWORLD	"Halloween.HeadlessBossAxeHitWorld"

#define PLUGIN_VERSION "1.0.0"

public Plugin myinfo = 
{
	name = "[TF2] Behold, the Horseless Headless Horsemann!",
	author = "Bradasparky",
	description = "Allows for admins and other plugins to turn players into the Horseless Headless Horsemann",
	version = PLUGIN_VERSION,
	url = "https://github.com/Bradasparky/tf-beholdhhh"
}

#define MAX_SHAKE_AMPLITUDE 16.0

enum ShakeCommand_t
{
	SHAKE_START = 0,		// Starts the screen shake for all players within the radius.
	SHAKE_STOP,				// Stops the screen shake for all players within the radius.
	SHAKE_AMPLITUDE,		// Modifies the amplitude of an active screen shake for all players within the radius.
	SHAKE_FREQUENCY,		// Modifies the frequency of an active screen shake for all players within the radius.
	SHAKE_START_RUMBLEONLY,	// Starts a shake effect that only rumbles the controller, no screen effect.
	SHAKE_START_NORUMBLE,	// Starts a shake that does NOT rumble the controller.
};

enum
{
	Taunt_None,
	Taunt_Repurpose,
	Taunt_UsesWeapon,
	Taunt_UsesWeaponWorldModel
}

// This is so players' eardrums don't get blown out
#define SND_COOLDOWN 5.0
enum
{
	LastPlayed_Spawn,
	LastPlayed_Death,
	LastPlayed_Max
}

char g_sModelFiles[][] =
{
	HHH_MODEL,
	"models/player/hhh_player/hhh_player.dx80.vtx",
	"models/player/hhh_player/hhh_player.dx90.vtx",
	"models/player/hhh_player/hhh_player.phy",
	"models/player/hhh_player/hhh_player.vvd"
};

char g_sndFootsteps[][] =
{
	"player/footsteps/giant1.wav",
	"player/footsteps/giant2.wav"
};

char g_sndAttack[][] =
{
	"vo/halloween_boss/knight_attack01.mp3",
	"vo/halloween_boss/knight_attack02.mp3",
	"vo/halloween_boss/knight_attack03.mp3",
	"vo/halloween_boss/knight_attack04.mp3"
};

char g_sndLaugh[][] =
{
	"vo/halloween_boss/knight_laugh01.mp3",
	"vo/halloween_boss/knight_laugh02.mp3",
	"vo/halloween_boss/knight_laugh03.mp3",
	"vo/halloween_boss/knight_laugh04.mp3"
};

ConVar cvDropAmmo;
ConVar cvMaxHealth;
ConVar cvScareCooldown;
ConVar cvScareDuration;
ConVar cvScareDistance;
ConVar cvDisableScreenShake;
ConVar cvMeleeDamageMult;
Handle g_hHudSyncronizer;
Handle g_hSDKCall_GetMaxHealth;
Handle g_hSDKCall_WeaponSwitch;

bool g_bIsHHH[MAXPLAYERS + 1];
bool g_bInThrillerTaunt[MAXPLAYERS + 1];
int g_iAxeWorldModel[MAXPLAYERS + 1] = { -1, ... };
int g_iHHHParticle[MAXPLAYERS + 1][2];
float g_flNextScareTime[MAXPLAYERS + 1];
float g_flLastSndPlayTime[LastPlayed_Max];
Handle g_hHudTimer[MAXPLAYERS + 1];
int g_iHHHModelIndex = -1;
int g_iDeathParticleIndex = -1;
int g_iGhostParticleIndex = -1;
int g_iLastWinningTeam = -1;

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("beholdhhh.phrases");

    GameData hGameData = new GameData("sdkhooks.games/engine.ep2v");
    if (!hGameData)
        SetFailState("Failed to find gamedata at sdkhooks.games/engine.ep2v");

    StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "GetMaxHealth");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);

    g_hSDKCall_GetMaxHealth = EndPrepSDKCall();
    if (!g_hSDKCall_GetMaxHealth)
    {
        delete g_hSDKCall_GetMaxHealth;
        SetFailState("Failed to hook SDKCall GetMaxHealth");
    }

    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "Weapon_Switch");
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
    PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_ByValue);

    g_hSDKCall_WeaponSwitch = EndPrepSDKCall();
    if (!g_hSDKCall_WeaponSwitch)
    {
        delete g_hSDKCall_WeaponSwitch;
        SetFailState("Failed to hook SDKCall Weapon_Switch");
    }

    delete hGameData;
	
	g_hHudSyncronizer = CreateHudSynchronizer();

	CreateConVar("sm_beholdhhh_version", PLUGIN_VERSION, "Plugin version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	cvDropAmmo = CreateConVar("sm_beholdhhh_dropammo", "0", "Whether HHH should drop an ammo kit on death.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvMaxHealth = CreateConVar("sm_beholdhhh_maxhealth", "1000", "HHH's max health.",  FCVAR_NOTIFY, true, 1.0);
	cvScareCooldown = CreateConVar("sm_beholdhhh_scare_cooldown", "20.0", "HHH's scare cooldown.", FCVAR_NOTIFY, true, 0.0);
	cvScareDuration = CreateConVar("sm_beholdhhh_scare_duration", "2.0", "HHH's scare duration.", FCVAR_NOTIFY, true, 0.0);
	cvScareDistance = CreateConVar("sm_beholdhhh_scare_distance", "500.0", "HHH's scare distance.", FCVAR_NOTIFY, true, 0.0);
	cvMeleeDamageMult = CreateConVar("sm_beholdhhh_melee_damage_mult", "0.8", "HHH's melee damage mult relative to the victim's max health.", FCVAR_NOTIFY);
	cvDisableScreenShake = CreateConVar("sm_beholdhhh_screenshake_disabled", "0", "Whether to disable HHH screen shake when walking or hitting the world.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	AutoExecConfig(true, "beholdhhh");

	RegAdminCmd("sm_behhh", Command_BeHorsemann, ADMFLAG_ROOT, "Usage: sm_behhh <#userid|name> [health]");

	AddCommandListener(OnCommand_VoiceMenu, "voicemenu");
	AddNormalSoundHook(SoundHook_Horsemann);
	
	HookEvent("player_death", Event_OnPlayerDeath_Post, EventHookMode_Post);
	HookEvent("player_team", Event_OnPlayerChangeTeam);
	HookEvent("post_inventory_application", Event_OnPlayerResupply_Pre, EventHookMode_Pre);
	HookEvent("post_inventory_application", Event_OnPlayerResupply_Post, EventHookMode_Post);
	HookEvent("teamplay_round_win", Event_OnRoundEnd);
	HookEvent("teamplay_round_start", Event_OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Event_OnRoundStart, EventHookMode_PostNoCopy);
	
	for (int i = MaxClients; i; i--)
		if (IsClientInGame(i))
			OnClientPutInServer(i);
}

public void OnPluginEnd()
{
	for (int i = MaxClients; i; i--)
		if (g_bIsHHH[i])
			RemoveHorsemann(i);
}

public void OnMapStart()
{
	for (int i; i < sizeof(g_sModelFiles); i++)
	{
		if (FileExists(g_sModelFiles[i], true))
			AddFileToDownloadsTable(g_sModelFiles[i]);
		else
			SetFailState("Failed to add '%s' to the downloads table. File does not exist.", g_sModelFiles[i]);
	}

	int iTableIndex = FindStringTable("ParticleEffectNames");
	if (iTableIndex != -1)
	{
    	g_iGhostParticleIndex = FindStringIndex(iTableIndex, "ghost_pumpkin");
    	g_iDeathParticleIndex = FindStringIndex(iTableIndex, "halloween_boss_death");
	}

	g_iHHHModelIndex = PrecacheModel(HHH_MODEL, true);

	PrecacheModel(AXE_MODEL, true);
	PrecacheModel("models/bots/gibs/hh_gib_boot_L.mdl", true);
	PrecacheModel("models/bots/gibs/hh_gib_boot_R.mdl", true);
	PrecacheModel("models/bots/gibs/hh_gib_candle.mdl", true);
	PrecacheModel("models/bots/gibs/hh_gib_glove_L.mdl", true);
	PrecacheModel("models/bots/gibs/hh_gib_glove_R.mdl", true);
	PrecacheModel("models/bots/gibs/hh_gib_torso.mdl", true);
	PrecacheModel("models/bots/gibs/hh_gib_upperarm_L.mdl", true);
	PrecacheModel("models/bots/gibs/hh_gib_upperarm_R.mdl", true);
	PrecacheModel("models/bots/gibs/hh_gib_upperleg_L.mdl", true);
	PrecacheModel("models/bots/gibs/hh_gib_upperleg_R.mdl", true);
	PrecacheModel("models/bots/gibs/hh_gib_waist.mdl", true);

	PrecacheSound("ui/halloween_boss_defeated_fx.wav", true);
	PrecacheSound("vo/halloween_boss/knight_dying.wav", true);

	for (int i; i < sizeof(g_sndFootsteps); i++)
		PrecacheSound(g_sndFootsteps[i], true);

	for (int i; i < sizeof(g_sndAttack); i++)
		PrecacheSound(g_sndAttack[i], true);

	for (int i; i < sizeof(g_sndLaugh); i++)
		PrecacheSound(g_sndLaugh[i], true);
	
	PrecacheScriptSound(SND_LAUGH);
	PrecacheScriptSound(SND_DYING);
	PrecacheScriptSound(SND_DEATH);
	PrecacheScriptSound(SND_PAIN);
	PrecacheScriptSound(SND_BOO);
	PrecacheScriptSound(SND_ALERT);
	PrecacheScriptSound(SND_ATTACK);
	PrecacheScriptSound(SND_SPAWN);
	PrecacheScriptSound(SND_SPAWNRUMBLE);
	PrecacheScriptSound(SND_FOOT);
	PrecacheScriptSound(SND_AXEHITFLESH);
	PrecacheScriptSound(SND_AXEHITWORLD);
}

public void OnClientPutInServer(int iClient)
{
	g_bIsHHH[iClient] = false;
	g_bInThrillerTaunt[iClient] = false;
	g_flNextScareTime[iClient] = 0.0;
	g_iAxeWorldModel[iClient] = -1;
	g_iHHHParticle[iClient][0] = -1;
	g_iHHHParticle[iClient][1] = -1;
	SDKHook(iClient, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}

public void OnClientDisconnect(int iClient)
{
	if (g_bIsHHH[iClient])
		RemoveHorsemann(iClient);
}

/*
*	Commands
*/

Action Command_BeHorsemann(int iClient, int iArgs)
{
	if (!iClient && iArgs < 1)
	{
		ReplyToCommand(iClient, "%t", "Command is in-game only");
		return Plugin_Handled;
	}

	if (iArgs < 1)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_behhh <#userid|name> [health]");
		return Plugin_Handled;
	}
	
	char sPattern[MAX_TARGET_LENGTH];
	GetCmdArg(1, sPattern, sizeof(sPattern));

	bool bTargetNameIsMultilingual;
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargetList[MAXPLAYERS], iTargetCount;
	if ((iTargetCount = ProcessTargetString(
			sPattern,
			iClient,
			iTargetList,
			sizeof(iTargetList),
			COMMAND_FILTER_ALIVE | (StrEqual(sPattern, "@me") ? COMMAND_FILTER_NO_IMMUNITY : 0),
			sTargetName,
			sizeof(sTargetName),
			bTargetNameIsMultilingual)) <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);
		return Plugin_Handled;
	}

	int iHealth;
	if (iArgs > 1)
	{
		iHealth = GetCmdArgInt(2);
		if (iHealth < 1)
			iHealth = cvMaxHealth.IntValue;	
	}
	else
		iHealth = cvMaxHealth.IntValue;

	for (int i; i < iTargetCount; i++)
		if (!g_bIsHHH[iTargetList[i]])
			CreateHorsemann(iTargetList[i], iHealth);

	if (bTargetNameIsMultilingual)
        ShowActivity2(iClient, "[SM] ", "%t", "Create Horsemann", sTargetName);
    else
        ShowActivity2(iClient, "[SM] ", "%t", "Create Horsemann", "_s", sTargetName);

	return Plugin_Handled;
}

Action OnCommand_VoiceMenu(int iClient, const char[] sCmd, int iArgC)
{
	if (!g_bIsHHH[iClient])
		return Plugin_Continue;
	
	int iArg1 = GetCmdArgInt(1);
	int iArg2 = GetCmdArgInt(2);
	bool bMedic = iArg1 == 0 && iArg2 == 0;
	bool bIncoming = iArg1 == 1 && iArg2 == 0;
	bool bHelp = iArg1 == 2 && iArg2 == 0;
	if ((bMedic || bIncoming || bHelp))
	{
		if (g_flNextScareTime[iClient] > GetGameTime() || IsOnLosingTeam(iClient))
			return Plugin_Handled;
	}
	else
		return Plugin_Handled;
	
	if (TF2_IsPlayerInCondition(iClient, TFCond_Taunting) || IsControlStunned(iClient))
		return Plugin_Handled;
	
	int iMelee = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
	if (iMelee != -1)
	{
		float flNextPrimaryAttack = GetEntPropFloat(iMelee, Prop_Send, "m_flNextPrimaryAttack");
		if (flNextPrimaryAttack > GetGameTime())
			return Plugin_Handled;
		
		static const float BOO_ANIM_TIME = 1.2;
		SetEntPropFloat(iMelee, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + BOO_ANIM_TIME);
	}

	CreateTimer(0.6, Timer_Boo, GetClientSerial(iClient), TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Continue;
}

/*
*	Events
*/

void Event_OnPlayerChangeTeam(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if (hEvent.GetInt("disconnect"))
		return;
	
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if (g_bIsHHH[iClient])
		RemoveHorsemann(iClient);
}

void Event_OnPlayerResupply_Pre(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	// This removes the axe for human players ...
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if (g_bIsHHH[iClient] && !IsFakeClient(iClient))
		TF2_RemoveAllWeapons(iClient);
}

void Event_OnPlayerResupply_Post(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));

	// ... however bots still drop their weapon for some reason
	if (IsFakeClient(iClient))
		RemoveClientDroppedWeapons(iClient);

	if (g_bIsHHH[iClient])
		RemoveHorsemann(iClient);
}

void Event_OnPlayerDeath_Post(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if (hEvent.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)
		return;
	
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if (!g_bIsHHH[iClient])
		return;

	float vPos[3];
	GetClientAbsOrigin(iClient, vPos);
	TE_SetupTFParticleEffect(g_iDeathParticleIndex, vPos);
	TE_SendToAll();

	BfWrite bf = UserMessageToBfWrite(StartMessageAll("BreakModel", USERMSG_RELIABLE));
	bf.WriteShort(g_iHHHModelIndex);

	float vAng[3];
	GetClientAbsAngles(iClient, vAng);
	bf.WriteVecCoord(vPos);
	bf.WriteAngles(vAng);
	bf.WriteShort(0);
	EndMessage();
	
	if (GetGameTime() - g_flLastSndPlayTime[LastPlayed_Death] > SND_COOLDOWN)
	{
		EmitGameSoundToAll(SND_DEATH);
		g_flLastSndPlayTime[LastPlayed_Death] = GetGameTime();
	}
	
	EmitGameSoundToAll(SND_SPAWN, _, SND_STOP);
	EmitGameSoundToAll(SND_SPAWNRUMBLE, _, SND_STOP);

	RemoveClientDroppedWeapons(iClient);

	if (!cvDropAmmo.BoolValue)
	{
		for (int iEnt; (iEnt = FindEntityByClassname(iEnt, "tf_ammo_pack")) != -1;)
		{
			int iOwner = GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity");
			if (IsEntityClient(iOwner))
			{
				RemoveEntity(iEnt);
				break;
			}
		}
	}

	RequestFrame(NextFrame_HorsemannDeath, GetClientSerial(iClient));
}

void NextFrame_HorsemannDeath(int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (!iClient)
		return;
	
	RemoveHorsemann(iClient);
	
	int iRagdoll = GetEntPropEnt(iClient, Prop_Send, "m_hRagdoll");
	if (iRagdoll != -1)
		SetEdictFlags(iRagdoll, FL_EDICT_DONTSEND);
}

void Event_OnRoundStart(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	g_iLastWinningTeam = -1;
}

void Event_OnRoundEnd(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	g_iLastWinningTeam = hEvent.GetInt("team");
}

/*
*	Hooks
*/

Action SoundHook_Horsemann(int iClients[MAXPLAYERS], int &iNumClients, char sSample[PLATFORM_MAX_PATH], int &iEntity, int &iChannel, float &iVolume, int &iLevel, int &iPitch, int &iFlags, char sSoundEntry[256], int &iSeed)
{
	if (!IsEntityClient(iEntity) || !g_bIsHHH[iEntity]) 
		return Plugin_Continue;

	if (strncmp(sSample, "player/footsteps/", 17, false) == 0)
	{
		strcopy(sSample, sizeof(sSample), g_sndFootsteps[GetRandomInt(0, 1)]);
		EmitSoundToAll(sSample, iEntity);

		if (cvDisableScreenShake.BoolValue)
			return Plugin_Changed;
		
		float vPos[3], vOtherPos[3];
		GetClientAbsOrigin(iEntity, vPos);
		for (int i = MaxClients; i; i--)
		{
			if (i == iEntity || !IsClientInGame(i) || !IsPlayerAlive(i))
				continue;
			
			GetClientAbsOrigin(i, vOtherPos);

			float flDistance = GetVectorDistance(vPos, vOtherPos);			
			if (flDistance <= 1000.0)
				UTIL_ScreenShake(i, vPos, 15.0, 5.0, 1.0, 1000.0, SHAKE_START, false);
		}
	
		return Plugin_Changed;
	}

	if (StrContains(sSample, "sword_swing") != -1 || StrContains(sSample, "cbar_miss") != -1)
	{
		// 1/3 chance so it doesn't become too annoying
		if (GetRandomInt(0, 2) == 0)
		{
			strcopy(sSample, sizeof(sSample), g_sndAttack[GetRandomInt(0, sizeof(g_sndAttack) - 1)]);
			EmitSoundToAll(sSample, iEntity, SNDCHAN_VOICE, 95);
		}
		
		return Plugin_Changed;
	}

	if (StrContains(sSample, "knight_axe_miss") != -1 || StrContains(sSample, "knight_axe_hit") != -1)
	{
		if (cvDisableScreenShake.BoolValue)
			return Plugin_Changed;

		float vPos[3], vOtherPos[3];
		GetClientAbsOrigin(iEntity, vPos);
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (i == iEntity || !IsClientInGame(i) || !IsPlayerAlive(i))
				continue;

			GetClientAbsOrigin(i, vOtherPos);

			float flDistance = GetVectorDistance(vPos, vOtherPos);
			if (flDistance <= 1000.0)
				UTIL_ScreenShake(i, vPos, 15.0, 5.0, 1.0, 1000.0, SHAKE_START, false);
		}

		return Plugin_Continue;
	}

	if (StrContains(sSample, "vo/demo", 7) == 0 || StrContains(sSample, "vo\\demo", 7) == 0)
	{
		if (StrContains(sSample, "_medic0") != -1 || StrContains(sSample, "_help") != -1 || StrContains(sSample, "_incoming") != -1)
		{
			Format(sSample, sizeof(sSample), "vo/halloween_boss/knight_alert.mp3");
			return Plugin_Changed;
		}
		else if (StrContains(sSample, "laugh") > -1)
		{
			strcopy(sSample, sizeof(sSample), g_sndLaugh[GetRandomInt(0, sizeof(g_sndLaugh) - 1)]);
			return Plugin_Changed;
		}
		else
			return Plugin_Handled;
	}
	else if (StrContains(sSample, "vo/taunts/demo", 14) == 0 || StrContains(sSample, "vo\\taunts\\demo", 14) == 0)
		return Plugin_Handled;

	return Plugin_Continue;
}

public void TF2_OnConditionAdded(int iClient, TFCond eCond)
{
	if (eCond != TFCond_Taunting)
		return;
	
	char sName[8];
	strcopy(sName, sizeof(sName), TF2_GetPlayerClass(iClient) == TFClass_Medic ? "taunt07" : "taunt06");

	for (int iEnt = -1; (iEnt = FindEntityByClassname(iEnt, "instanced_scripted_scene")) != -1;)
	{
		if (iClient != GetEntPropEnt(iEnt, Prop_Data, "m_hOwner"))
			continue;
		
		char sFile[PLATFORM_MAX_PATH];
		GetEntPropString(iEnt, Prop_Data, "m_szInstanceFilename", sFile, sizeof(sFile));
		if (StrContains(sFile, sName) != -1)
		{
			g_bInThrillerTaunt[iClient] = true;
			return;
		}
	}
}

public void TF2_OnConditionRemoved(int iClient, TFCond eCond)
{
	if (eCond == TFCond_Taunting && g_bIsHHH[iClient])
		g_bInThrillerTaunt[iClient] = false;
}

Action Hook_OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &flDamage, int &iDamageType, int &iWeapon, float flDamageForce[3], float flDamagePosition[3], int iDamageCustom)
{
	if (!IsEntityClient(iAttacker) || !g_bIsHHH[iAttacker])
		return Plugin_Continue;
	
	int iMelee = GetPlayerWeaponSlot(iAttacker, TFWeaponSlot_Melee);
	if (iMelee == -1 || iMelee != iWeapon || !(iDamageType & DMG_CLUB))
		return Plugin_Continue;
	
	if (iDamageCustom == TF_CUSTOM_TAUNT_BARBARIAN_SWING)
		flDamage = float(GetMaxHealth(iVictim));
	else
		flDamage = GetMaxHealth(iVictim) * cvMeleeDamageMult.FloatValue;

	return Plugin_Changed;
}

void Hook_OnPostThinkPost(int iClient)
{
	int iMelee = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
	if (iMelee == -1)
	{
		if (EntRefToEntIndex(g_iAxeWorldModel[iClient]) != -1)
			AddEffectFlags(g_iAxeWorldModel[iClient], EF_NODRAW);
		return;
	}

	int iActiveWep = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iMelee != iActiveWep || IsControlStunned(iClient) || IsOnLosingTeam(iClient))
	{
		if (EntRefToEntIndex(g_iAxeWorldModel[iClient]) != -1)
			AddEffectFlags(g_iAxeWorldModel[iClient], EF_NODRAW);
	}
	else if (TF2_IsPlayerInCondition(iClient, TFCond_Taunting)) 
	{
		if (g_bInThrillerTaunt[iClient])
		{
			SetEntityInvis(iMelee, true);
			if (EntRefToEntIndex(g_iAxeWorldModel[iClient]) != -1)
				AddEffectFlags(g_iAxeWorldModel[iClient], EF_NODRAW);
			return;
		}
		
		int iTauntIndex = GetEntProp(iClient, Prop_Send, "m_iTauntItemDefIndex");
		switch (GetTauntWeaponState(iTauntIndex))
		{
			case Taunt_None: 
			{
				SetEntityInvis(iMelee, true);
				if (EntRefToEntIndex(g_iAxeWorldModel[iClient]) != -1)
					AddEffectFlags(g_iAxeWorldModel[iClient], EF_NODRAW);
			}
			case Taunt_Repurpose: 
			{
				SetEntityInvis(iMelee, false);
				if (EntRefToEntIndex(g_iAxeWorldModel[iClient]) != -1)
					AddEffectFlags(g_iAxeWorldModel[iClient], EF_NODRAW);
			}
			case Taunt_UsesWeaponWorldModel:
			{
				SetEntityInvis(iMelee, true);
				if (EntRefToEntIndex(g_iAxeWorldModel[iClient]) != -1)
					RemoveEffectFlags(g_iAxeWorldModel[iClient], EF_NODRAW);
			}
			case Taunt_UsesWeapon:
			{
				SetEntityInvis(iMelee, false);
				if (EntRefToEntIndex(g_iAxeWorldModel[iClient]) != -1)
					AddEffectFlags(g_iAxeWorldModel[iClient], EF_NODRAW);
			}
		}
	}
	else
	{
		SetEntityInvis(iMelee, true);
		if (EntRefToEntIndex(g_iAxeWorldModel[iClient]) != -1)
			RemoveEffectFlags(g_iAxeWorldModel[iClient], EF_NODRAW);
	}
}

/*
*	Horsemann Creation
*/

void CreateHorsemann(int iClient, int iHealth = 0)
{
	RemoveHorsemann(iClient);
	TF2_RemoveCondition(iClient, TFCond_Taunting);
	TF2_SetPlayerClass(iClient, TFClass_DemoMan);
	TF2_RegeneratePlayer(iClient);
	TF2_RemoveAllItems(iClient);

	int iRagdoll = GetEntPropEnt(iClient, Prop_Send, "m_hRagdoll");
	if (IsValidEntity(iRagdoll)) 
		RemoveEntity(iRagdoll);
	
	GiveAxe(iClient, iHealth);
	SetVariantString(HHH_MODEL);
	AcceptEntityInput(iClient, "SetCustomModelWithClassAnimations");

	SetVariantInt(1);
	AcceptEntityInput(iClient, "SetForcedTauntCam");
	
	SetVariantString("1.5");
	AcceptEntityInput(iClient, "SetModelScale");
	
	if (GetGameTime() - g_flLastSndPlayTime[LastPlayed_Spawn] > SND_COOLDOWN)
	{
		EmitGameSoundToAll(SND_SPAWN);
		EmitGameSoundToAll(SND_SPAWNRUMBLE);
		g_flLastSndPlayTime[LastPlayed_Spawn] = GetGameTime();
	}
	
	EmitGameSoundToAll(SND_DEATH, _, SND_STOP);

	g_bIsHHH[iClient] = true;
	g_flNextScareTime[iClient] = GetGameTime() + cvScareCooldown.FloatValue;

	DoHorsemannParticles(iClient);
	
	int iWep = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
	if (iWep != -1)
		SwitchPlayerWeapon(iClient, iWep);

	SDKHook(iClient, SDKHook_PostThinkPost, Hook_OnPostThinkPost);

	g_hHudTimer[iClient] = CreateTimer(0.1, Timer_Hud, GetClientSerial(iClient), TIMER_REPEAT);
}

void GiveAxe(int iClient, int iHealth)
{
	int iWep = CreateEntityByName("tf_weapon_sword");
	SetEntProp(iWep, Prop_Send, "m_bInitialized", true);
	SetEntProp(iWep, Prop_Send, "m_bValidatedAttachedEntity", true);
	SetEntProp(iWep, Prop_Send, "m_iItemDefinitionIndex", HEADTAKER);
	SetEntProp(iWep, Prop_Send, "m_iEntityLevel", 100);
	SetEntProp(iWep, Prop_Send, "m_bOnlyIterateItemViewAttributes", true);
	SetEntProp(iWep, Prop_Send, "m_iAccountID", GetSteamAccountID(iClient));

	char sNetClass[32];
	GetEntityNetClass(iWep, sNetClass, sizeof(sNetClass));
    SetEntData(iWep, FindSendPropInfo(sNetClass, "m_iEntityQuality"), 5); // Unusual

	char sAttrib[128];
	FormatEx(sAttrib, sizeof(sAttrib), "self.AddAttribute(\"max health additive bonus\", %i, -1)", iHealth - 175);
	RunScriptCode(iWep, sAttrib);
	RunScriptCode(iWep, "self.AddAttribute(\"fire rate penalty\", 1.45, -1)");
	RunScriptCode(iWep, "self.AddAttribute(\"health from packs decreased\", 0.0, -1)");
	RunScriptCode(iWep, "self.AddAttribute(\"health from healers reduced\", 0.0, -1)");
	RunScriptCode(iWep, "self.AddAttribute(\"cancel falling damage\", 1.0, -1)");
	RunScriptCode(iWep, "self.AddAttribute(\"cannot be backstabbed\", 1.0, -1)");
	RunScriptCode(iWep, "self.AddAttribute(\"crit mod disabled\", 0.0, -1)");
	RunScriptCode(iWep, "self.AddAttribute(\"SPELL: set Halloween footstep type\", 2.0, -1)");
	SetEntProp(iClient, Prop_Send, "m_iHealth", iHealth);

	DispatchSpawn(iWep);
	EquipPlayerWeapon(iClient, iWep);

	SetVariantString("!activator");
    AcceptEntityInput(iWep, "SetParent", iClient, iWep);

	// Very rarely the client won't be considered in third person quick enough for the axe world model to show up
	RequestFrame(NextFrame_CreateAxeWorldModel, GetClientSerial(iClient));
}

void NextFrame_CreateAxeWorldModel(int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (!iClient || !g_bIsHHH[iClient])
		return;
	
	g_iAxeWorldModel[iClient] = EntIndexToEntRef(CreateClientWorldModel(iClient, AXE_MODEL));
	SetEntPropFloat(EntRefToEntIndex(g_iAxeWorldModel[iClient]), Prop_Send, "m_flModelScale", 0.6666667);
}

void RemoveHorsemann(int iClient)
{
	if (!g_bIsHHH[iClient])
		return;
	
	ClearHorsemannParticles(iClient);
	SetVariantInt(0);
	AcceptEntityInput(iClient, "SetForcedTauntCam");

	SetVariantString("1.0");
	AcceptEntityInput(iClient, "SetModelScale");

	SetVariantString("");
	AcceptEntityInput(iClient, "SetCustomModel");

	g_bIsHHH[iClient] = false;
	g_bInThrillerTaunt[iClient] = false;
	delete g_hHudTimer[iClient];
	
	int iModel = EntRefToEntIndex(g_iAxeWorldModel[iClient]);
	if (iModel != INVALID_ENT_REFERENCE)
	{
		RemoveEntity(iModel);
		g_iAxeWorldModel[iClient] = -1;
	}
	
	if (IsPlayerAlive(iClient))
	{
		TF2_RemoveCondition(iClient, TFCond_Taunting);
		TF2_RemoveAllItems(iClient);
		TF2_RegeneratePlayer(iClient);
		SetEntProp(iClient, Prop_Send, "m_iHealth", GetMaxHealth(iClient));
	}
	
	SDKUnhook(iClient, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
}

void DoHorsemannParticles(int iClient)
{
	float vPos[3], vAng[3];
	GetClientAbsOrigin(iClient, vPos);
	GetClientEyeAngles(iClient, vAng);
	vAng[0] *= -1;
	vAng[1] += 180.0;
	vAng[2] = 0.0;
	if (vAng[1] > 180.0) 
		vAng[1] -= 360.0;

	static const char sAttachments[][] =
	{
		"righteye",
		"lefteye"
	};

	for (int i; i < 2; i++)
	{
		int iParticle = CreateEntityByName("info_particle_system");
		if (iParticle == -1) 
			continue;
		
		TeleportEntity(iParticle, vPos, vAng);
		DispatchKeyValue(iParticle, "effect_name", "halloween_boss_eye_glow");
		SetVariantString("!activator");
		AcceptEntityInput(iParticle, "SetParent", iClient, iParticle, 0);
		SetVariantString(sAttachments[i]);
		AcceptEntityInput(iParticle, "SetParentAttachmentMaintainOffset", iParticle, iParticle, 0);
		
		DispatchSpawn(iParticle);
		ActivateEntity(iParticle);
		SetEntPropEnt(iParticle, Prop_Send, "m_hOwnerEntity", iClient);
		AcceptEntityInput(iParticle, "Start");
		g_iHHHParticle[iClient][i] = iParticle;
	}
	
	TE_SetupTFParticleEffect(g_iGhostParticleIndex, _, _, _, iClient);
	TE_SendToAll();
}

void ClearHorsemannParticles(int iClient)
{
	RunScriptCode(iClient, "self.RemoveCustomAttribute(\"SPELL: set Halloween footstep type\")");
	
	for (int i; i < 2; i++)
	{
		int iEnt = EntRefToEntIndex(g_iHHHParticle[iClient][i]);
		if (iEnt != -1)
			RemoveEntity(iEnt);
		g_iHHHParticle[iClient][i] = INVALID_ENT_REFERENCE;
	}
}

/*
*	Ability
*/

void Timer_Boo(Handle hTimer, int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (!iClient || !g_bIsHHH[iClient] || !IsPlayerAlive(iClient))
		return;
	
	float vPos[3], vTargetPos[3];
	GetClientCenter(iClient, vPos);

	float flDeltaDist;
	float flDuration = cvScareDuration.FloatValue;
	float flDist = cvScareDistance.FloatValue;
	float flDistSqr = flDist * flDist;
	int iTeam = GetClientTeam(iClient);
	for (int i = MaxClients; i; i--)
	{
		if (i == iClient || !IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) == iTeam)
			continue;
		
		GetClientCenter(i, vTargetPos);
		flDeltaDist = GetVectorDistance(vPos, vTargetPos, true);	
		if (flDeltaDist > flDistSqr)
			continue;

		TR_TraceRayFilter(vPos, vTargetPos, MASK_OPAQUE | CONTENTS_IGNORE_NODRAW_OPAQUE, RayType_EndPoint, TraceFilter_Scare);
		if (TR_GetFraction() == 1.0)
			TF2_StunPlayer(i, flDuration, 0.0, TF_STUNFLAG_THIRDPERSON | TF_STUNFLAG_GHOSTEFFECT);
	}

	g_flNextScareTime[iClient] = GetGameTime() + cvScareCooldown.FloatValue;
}

bool TraceFilter_Scare(int iEntity, int iContentsMask)
{
	return !IsEntityClient(iEntity);
}

Action Timer_Hud(Handle hTimer, int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (!iClient)
		return Plugin_Stop;
	
	if (GetClientButtons(iClient) & IN_SCORE || IsOnLosingTeam(iClient))
		return Plugin_Continue;
	
	float flCooldown = g_flNextScareTime[iClient] - GetGameTime();
	SetHudTextParams(-1.0, 0.70, 0.35, 255, 0, 255, 255, 0, 0.0, 0.0, 0.1);

	if (flCooldown > 0.0)
		ShowSyncHudText(iClient, g_hHudSyncronizer, "%t: %.1fs", "Scare", flCooldown);
	else
		ShowSyncHudText(iClient, g_hHudSyncronizer, "%t: %t", "Scare", "Ready!");

	return Plugin_Continue;
}

/*
*	Utility
*/

void SwitchPlayerWeapon(int iClient, int iWeapon)
{
	SDKCall(g_hSDKCall_WeaponSwitch, iClient, iWeapon, 0);
}

int GetMaxHealth(int iClient)
{
	return SDKCall(g_hSDKCall_GetMaxHealth, iClient);
}

bool IsOnLosingTeam(int iClient)
{
	return g_iLastWinningTeam != -1 && g_iLastWinningTeam != GetClientTeam(iClient);
}

void RemoveClientDroppedWeapons(int iClient)
{
	for (int iEnt; (iEnt = FindEntityByClassname(iEnt, "tf_dropped_weapon")) != -1;)
	{
		int iAccountID = GetSteamAccountID(iClient, false);
		if (iAccountID == GetEntProp(iEnt, Prop_Send, "m_iAccountID"))
			RemoveEntity(iEnt);
	}
}

// This determines which taunts should hide the tf_wearable world model. Covers every taunt up until Halloween 2026.
int GetTauntWeaponState(int iTauntIndex)
{
	switch (iTauntIndex)
	{
		case 167, 438, 463, 1106, 1107, 1110, 1111, 1116, 1118, 1157, 1162, 1183, 31162, 31288, 31413, 31441, 31467, 31577: return Taunt_None;
		case 1015, 1114, 1120, 30671, 31153, 31201, 31291, 31292, 31492, 31493, 31576: return Taunt_Repurpose;
		case 30840: return Taunt_UsesWeapon;
		case -1, 31380: return Taunt_UsesWeaponWorldModel;
		default: return Taunt_None;
	}
}

/*
*	Natives
*/

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iSize)
{
	RegPluginLibrary("beholdhhh");

	CreateNative("BeholdHHH_Create", Native_BeholdHHH_CreateHorsemann);
	CreateNative("BeholdHHH_Remove", Native_BeholdHHH_RemoveHorsemann);
	CreateNative("BeholdHHH_IsBoss", Native_BeholdHHH_IsHorsemann);

	return APLRes_Success;
}

any Native_BeholdHHH_CreateHorsemann(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (g_bIsHHH[iClient])
		return false;
	
	int iHealth = GetNativeCell(2);
	if (iHealth < 1)
		iHealth = cvMaxHealth.IntValue;

	CreateHorsemann(GetNativeCell(1), iHealth);
	return true;
}

any Native_BeholdHHH_RemoveHorsemann(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (g_bIsHHH[iClient])
	{
		RemoveHorsemann(iClient);
		return true;
	}

	return false;
}

any Native_BeholdHHH_IsHorsemann(Handle hPlugin, int iNumParams)
{
	return g_bIsHHH[GetNativeCell(1)];
}

/*
*	Stocks
*/

stock bool IsEntityClient(int iEntity)
{
	return 0 < iEntity <= MaxClients;
}

stock bool IsControlStunned(int iClient)
{
	return GetEntProp(iClient, Prop_Send, "m_iStunFlags") & (TF_STUNFLAG_THIRDPERSON | TF_STUNFLAG_BONKSTUCK);
}

stock void GetClientCenter(int iClient, float vCenter[3])
{
    float vOrigin[3], vMaxs[3];
    GetClientMaxs(iClient, vMaxs);
    GetClientAbsOrigin(iClient, vOrigin);
    vCenter[0] = vOrigin[0];
    vCenter[1] = vOrigin[1];
    vCenter[2] = vMaxs[2] * 0.5 + vOrigin[2];
}

stock void TF2_RemoveAllItems(int iClient)
{
    TF2_RemoveAllWeapons(iClient);
    TF2_RemoveAllWearables(iClient);
}

stock void TF2_RemoveAllWearables(int iClient)
{
	int iNextMovePeer = -1;
	int iMoveChild = GetEntPropEnt(iClient, Prop_Data, "m_hMoveChild");
    if (iMoveChild == -1)
		return;
	
	do
	{
		char sChildName[12];
		GetEntityClassname(iMoveChild, sChildName, sizeof(sChildName));
		iNextMovePeer = GetEntPropEnt(iMoveChild, Prop_Data, "m_hMovePeer");
		
		if (StrContains(sChildName, "tf_wearable") == 0 || StrContains(sChildName, "tf_powerup") == 0)
			TF2_RemoveWearable(iClient, iMoveChild);
	}
	while ((iMoveChild = iNextMovePeer) != -1);
}

stock int CreateClientWorldModel(int iClient, char[] sModelName)
{
    int iWorldModel = CreateEntityByName("tf_wearable");
    
    PrecacheModel(sModelName, true);
    SetEntityModel(iWorldModel, sModelName);
    SetEntProp(iWorldModel, Prop_Data, "m_bForcePurgeFixedupStrings", true);
    SetEntProp(iWorldModel, Prop_Send, "m_bValidatedAttachedEntity", true);
    SetEntProp(iWorldModel, Prop_Send, "m_bInitialized", true);
    SetEntPropEnt(iWorldModel, Prop_Data, "m_hOwnerEntity", iClient);
    DispatchSpawn(iWorldModel);
    SetVariantString("!activator");
    AcceptEntityInput(iWorldModel, "SetParent", iClient);
	SetEdictFlags(iWorldModel, GetEdictFlags(iWorldModel) & ~FL_EDICT_ALWAYS);
	
    // Removes preserved entity status, won't persist through rounds
    SetEntPropString(iWorldModel, Prop_Data, "m_iClassname", "tf_custom_wearable"); 
    
    return iWorldModel;
}

stock void RunScriptCode(int iEntity, char[] sScript)
{
	SetVariantString(sScript);
    AcceptEntityInput(iEntity, "RunScriptCode");
}

stock void SetEntityInvis(int iEntity, bool bInvis)
{
	int iColor = GetEntProp(iEntity, Prop_Send, "m_clrRender");
	if (bInvis)
	{
		SetEntPropFloat(iEntity, Prop_Send, "m_flModelScale", 0.0);
		if ((iColor & 0xFF000000) != 0)
			SetEntProp(iEntity, Prop_Send, "m_clrRender", iColor & ~0xFF000000);
	}
	else
	{
		SetEntPropFloat(iEntity, Prop_Send, "m_flModelScale", 1.0);
		if ((iColor & 0xFF000000) != 0xFF000000)
			SetEntProp(iEntity, Prop_Send, "m_clrRender", iColor | 0xFF000000);
	}
}

stock void AddEffectFlags(int iEntity, int iFlags)
{
	int iEffects = GetEntProp(iEntity, Prop_Send, "m_fEffects");
	if ((iEffects & iFlags) != iFlags)
		SetEntProp(iEntity, Prop_Send, "m_fEffects", iEffects | iFlags);
}

stock void RemoveEffectFlags(int iEntity, int iFlags)
{
	int iEffects = GetEntProp(iEntity, Prop_Send, "m_fEffects");
	if ((iEffects & iFlags))
		SetEntProp(iEntity, Prop_Send, "m_fEffects", iEffects & ~iFlags);
}

stock void UTIL_ScreenShake(int iClient, float vShakePos[3], float flAmplitude, float flFrequency, float flDuration, float flRadius, ShakeCommand_t eCommand = SHAKE_START, bool bAirShake = true)
{
    float flLocalAmplitude;

    if (flAmplitude > MAX_SHAKE_AMPLITUDE)
        flAmplitude = MAX_SHAKE_AMPLITUDE;

    if (!bAirShake && eCommand == SHAKE_START && !(GetEntityFlags(iClient) & FL_ONGROUND))
        return;

    float vClientCenter[3];
    GetClientCenter(iClient, vClientCenter);
    flLocalAmplitude = ComputeShakeAmplitude(vShakePos, vClientCenter, flAmplitude, flRadius);
    if (flLocalAmplitude < 0.0)
        return;
        
    BfWrite bf = UserMessageToBfWrite(StartMessageOne("Shake", iClient));
    bf.WriteByte(view_as<int>(eCommand));
    bf.WriteFloat(flLocalAmplitude);
    bf.WriteFloat(flFrequency);
    bf.WriteFloat(flDuration);
    EndMessage();
}

stock float ComputeShakeAmplitude(float vClientCenter[3], float vShakePos[3], float flAmplitude, float flRadius)
{
    if (flRadius <= 0)
        return flAmplitude;

    float flLocalAmplitude = -1.0;
    float vDelta[3];
    SubtractVectors(vClientCenter, vShakePos, vDelta);

    float flDistance = GetVectorLength(vDelta);
    if (flDistance <= flRadius)
    {
        float flPercent = 1.0 - (flDistance / flRadius);
        flLocalAmplitude = flAmplitude * flPercent;
    }

    return flLocalAmplitude;
}

enum ParticleAttachment_t
{
	PATTACH_ABSORIGIN = 0,
	PATTACH_ABSORIGIN_FOLLOW,
	PATTACH_CUSTOMORIGIN,
	PATTACH_POINT,
	PATTACH_POINT_FOLLOW,
	PATTACH_WORLDORIGIN,
	PATTACH_ROOTBONE_FOLLOW
};

stock void TE_SetupTFParticleEffect(
	int iParticleIndex, 
	const float vOrigin[3] = NULL_VECTOR, 
	const float vStart[3] = NULL_VECTOR,
	const float vAngles[3] = NULL_VECTOR, 
	int iEntity = -1, 
	ParticleAttachment_t iAttachType = view_as<ParticleAttachment_t>(-1), 
	int iAttachPoint = -1,
	int iControlPoint1 = -1,
	ParticleAttachment_t eParticleAttachment = view_as<ParticleAttachment_t>(-1),
	float vParticleOffset[3] = { 0.0, 0.0, 0.0 })
{
	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", vOrigin[0]);
	TE_WriteFloat("m_vecOrigin[1]", vOrigin[1]);
	TE_WriteFloat("m_vecOrigin[2]", vOrigin[2]);
	TE_WriteFloat("m_vecStart[0]", vStart[0]);
	TE_WriteFloat("m_vecStart[1]", vStart[1]);
	TE_WriteFloat("m_vecStart[2]", vStart[2]);
	TE_WriteVector("m_vecAngles", vAngles);
	TE_WriteNum("m_iParticleSystemIndex", iParticleIndex);
	TE_WriteNum("entindex", iEntity);
	TE_WriteNum("m_iAttachType", view_as<int>(iAttachType));
	TE_WriteNum("m_iAttachmentPointIndex", iAttachPoint);
	TE_WriteNum("m_bResetParticles", true);
	TE_WriteNum("m_bControlPoint1", iControlPoint1);
	TE_WriteNum("m_ControlPoint1.m_eParticleAttachment", eParticleAttachment);
	TE_WriteFloat("m_ControlPoint1.m_vecOffset[0]", vParticleOffset[0]);
	TE_WriteFloat("m_ControlPoint1.m_vecOffset[1]", vParticleOffset[1]);
	TE_WriteFloat("m_ControlPoint1.m_vecOffset[2]", vParticleOffset[2]);
}
