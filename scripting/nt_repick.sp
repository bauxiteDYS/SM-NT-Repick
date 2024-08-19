#include <sourcemod>
#include <sdktools>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

bool g_repick[NEO_MAXPLAYERS+1];
bool g_loadout[NEO_MAXPLAYERS+1];
int g_playerClass[NEO_MAXPLAYERS+1];
int g_oldPlayerClass[NEO_MAXPLAYERS+1];
int g_playerLoadout[NEO_MAXPLAYERS+1];
int g_PrimaryAmmo[3+1][12] = 
{
	{0,0,0,0,0,0,0,0,0,0,0,0},
	{120,150,120,150,120,30,90,21,60,0,0,0},
	{150,200,150,120,120,28,60,60,120,120,64,18},
	{150,200,150,60,28,120,60,120,200,0,0,0}, 
};
//int g_secondaryAmmo[3+1] = {0, 45, 45, 45};

public Plugin myinfo = {
	name = "NT Repick Class and weapon",
	author = "bauxite, rain",
	description = "Repick your class and weapon by typing !re or !repick in freeze time",
	version = "0.1.6",
	url = "https://github.com/bauxiteDYS/SM-NT-Repick",
};

public void OnPluginStart()	
{
	RegConsoleCmd("sm_re", RepickWeapon);
	RegConsoleCmd("sm_repick", RepickWeapon);
	AddCommandListener(OnClass, "setclass");
	AddCommandListener(OnVariant, "setvariant");
	AddCommandListener(OnLoadout, "loadout");
	AddCommandListener(OnCancel, "playerstate_reverse");
}

void ResetClient(int client)
{
	g_repick[client] = false;
	g_loadout[client] = false;
	g_playerLoadout[client] = -1;
}

public void OnClientDisconnect_Post(int client)
{
	ResetClient(client);
}

public void OnClientPutInServer(int client)
{
	ResetClient(client);
}

public Action OnCancel(int client, const char[] command, int argc)
{	
	if(!g_repick[client] || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}
	
	if(g_loadout[client])
	{
		SetPlayerClass(client, g_oldPlayerClass[client]);
	}
	
	ResetClient(client);
	return Plugin_Continue;
}

public Action OnClass(int client, const char[] command, int argc)
{
	if(argc != 1 || !g_repick[client] || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}

	int iClass = GetCmdArgInt(1);
	if(iClass <= CLASS_NONE || iClass > CLASS_SUPPORT)
	{
		PrintToChat(client, "Error: Somehow tried to pick invalid class");
		ResetClient(client);
		return Plugin_Continue;
	}
	g_playerClass[client] = iClass;
	return Plugin_Continue;
}

public Action OnVariant(int client, const char[] command, int argc)
{
	if(!g_repick[client] || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}
	
	if(!GameRules_GetProp("m_bFreezePeriod") || !IsPlayerAlive(client))
	{
		ResetClient(client);
		return Plugin_Continue;
	}
	
	g_loadout[client] = true;
	SetPlayerClass(client, g_playerClass[client]);
	RequestFrame(ShowLoadoutMenu, client);
	return Plugin_Continue;
}

void ShowLoadoutMenu(int client)
{
	if (IsClientInGame(client))
	{
		ClientCommand(client, "loadoutmenu");
	}
}

public Action OnLoadout(int client, const char[] command, int argc)
{
	if(!g_repick[client] || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}
	
	
	if(argc != 1 || !GameRules_GetProp("m_bFreezePeriod") || !IsPlayerAlive(client))
	{
		SetPlayerClass(client, g_oldPlayerClass[client]);
		ResetClient(client);
		return Plugin_Continue;
	}
	
	
	int iLoadout = GetCmdArgInt(1);
	
	if(iLoadout < 0 || iLoadout > 11)
	{
		PrintToChat(client, "Error: Somehow tried to pick invalid loadout");
		SetPlayerClass(client, g_oldPlayerClass[client]);
		ResetClient(client);
		return Plugin_Continue;
	}
	
	g_playerLoadout[client] = iLoadout;
	PrintToServer("load %d", iLoadout);
	StripPlayerWeapons(client, false);
	SetPlayerClass(client, g_oldPlayerClass[client]);
	RequestFrame(Repick, client);
	return Plugin_Continue;
}

void Repick(int client)
{
	
	if(!IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}
	

	SetNewClassProps(client);
	
	static Handle call = INVALID_HANDLE;
	if (call == INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetSignature(SDKLibrary_Server, "\x56\x8B\xF1\x8B\x06\x8B\x90\xBC\x04\x00\x00\x57\xFF\xD2\x8B\x06", 16);
		call = EndPrepSDKCall();
		if (call == INVALID_HANDLE)
		{
			SetFailState("Failed to prepare SDK call");
		}
	}
	SDKCall(call, client);
	
	AdjustAmmo(client);
	
	PrintToChatAll("%N has repicked their class", client);
}

void AdjustAmmo(int client)
{
	int correctAmmo;
	int wep;
	
	correctAmmo = g_PrimaryAmmo[g_playerClass[client]][g_playerLoadout[client]];
	wep = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", 0);
	
	SetWeaponAmmo(client, GetAmmoType(wep), correctAmmo);
	SetWeaponAmmo(client, AMMO_SECONDARY, 45);
	//might need to set nades
	ResetClient(client);
}

void SetNewClassProps(int client)
{
	SetEntProp(client, Prop_Send, "m_iLives", 1);
	SetEntProp(client, Prop_Data, "m_iObserverMode", 0);
	SetEntProp(client, Prop_Data, "m_iHealth", 100);
	SetEntProp(client, Prop_Data, "m_lifeState", 0);
	SetEntProp(client, Prop_Data, "m_fInitHUD", 1);
	SetEntProp(client, Prop_Data, "m_takedamage", 2);
	SetEntProp(client, Prop_Send, "deadflag", 0);
	SetEntPropFloat(client, Prop_Send, "m_flDeathTime", 0.0);
	SetEntPropEnt(client, Prop_Data, "m_hObserverTarget", -1, 0);
}

public Action RepickWeapon(int client, int args)
{
	if(client <= 0 || client > MaxClients)
	{
		return Plugin_Handled;
	}
	
	if(!GameRules_GetProp("m_bFreezePeriod"))
	{
		return Plugin_Handled;
	}
	
	if(!IsClientInGame(client) || !IsPlayerAlive(client) || g_repick[client])
	{
		return Plugin_Handled;
	}
	
	g_oldPlayerClass[client] = GetPlayerClass(client);
	
	if(g_oldPlayerClass[client] <= CLASS_NONE || g_oldPlayerClass[client] > CLASS_SUPPORT)
	{
		PrintToChat(client, "failed to get class, try again");
		return Plugin_Handled;
	}
	
	g_repick[client] = true;
	RequestFrame(ShowClassMenu, client);
	return Plugin_Continue;
}

void ShowClassMenu(int client)
{
	if (IsClientInGame(client))
	{
		ClientCommand(client, "classmenu");
	}
}

// Backported from SourceMod/SourcePawn SDK for SM 1.8-1.10 compatibility.
// Used here under GPLv3 license: https://www.sourcemod.net/license.php
// SourceMod (C)2004-2023 AlliedModders LLC.  All rights reserved.
#if SOURCEMOD_V_MAJOR == 1 && SOURCEMOD_V_MINOR <= 10
/**
 * Retrieves a numeric command argument given its index, from the current
 * console or server command. Will return 0 if the argument can not be
 * parsed as a number. Use GetCmdArgIntEx to handle that explicitly.
 *
 * @param argnum        Argument number to retrieve.
 * @return              Value of the command argument.
 */
stock int GetCmdArgInt(int argnum)
{
    char str[12];
    GetCmdArg(argnum, str, sizeof(str));

    return StringToInt(str);
}
#endif
