#include <sdktools>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

bool repick[NEO_MAXPLAYERS+1];
bool loadout[NEO_MAXPLAYERS+1];
int playerClass[NEO_MAXPLAYERS+1];
int oldPlayerClass[NEO_MAXPLAYERS+1];

public Plugin myinfo = {
	name = "NT Repick Class and weapon",
	author = "bauxite",
	description = "Repick your class and weapon by typing !re in freeze time",
	version = "0.1.3",
	url = "",
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
	repick[client] = false;
	loadout[client] = false;
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
	if(!repick[client] || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}
	
	if(loadout[client])
	{
		SetPlayerClass(client, oldPlayerClass[client]);
	}
	
	ResetClient(client);
	return Plugin_Continue;
}

public Action OnClass(int client, const char[] command, int argc)
{
	if(!repick[client] || !IsClientInGame(client) || argc != 1)
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
	playerClass[client] = iClass;
	return Plugin_Continue;
}

public Action OnVariant(int client, const char[] command, int argc)
{
	if(!repick[client] || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}
	
	if(!GameRules_GetProp("m_bFreezePeriod") || !IsPlayerAlive(client))
	{
		ResetClient(client);
		return Plugin_Continue;
	}
	
	loadout[client] = true;
	SetPlayerClass(client, playerClass[client]);
	RequestFrame(ShowLoadoutMenu, client);
	return Plugin_Continue;
}

void ShowLoadoutMenu(int client)
{
	ClientCommand(client, "loadoutmenu");
}

public Action OnLoadout(int client, const char[] command, int argc)
{
	if(!repick[client] || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}
	
	if(!GameRules_GetProp("m_bFreezePeriod") || !IsPlayerAlive(client) || argc != 1)
	{
		SetPlayerClass(client, oldPlayerClass[client]);
		ResetClient(client);
		return Plugin_Continue;
	}
	
	StripPlayerWeapons(client, false);
	SetPlayerClass(client, oldPlayerClass[client]);
	RequestFrame(Repick, client);
	return Plugin_Continue;
}

void Repick(int client)
{
	ResetClient(client);
	
	if(!IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}

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
	
	if(!IsClientInGame(client) || !IsPlayerAlive(client) || repick[client])
	{
		return Plugin_Handled;
	}
	
	oldPlayerClass[client] = GetPlayerClass(client);
	
	if(oldPlayerClass[client] <= CLASS_NONE || oldPlayerClass[client] > CLASS_SUPPORT)
	{
		PrintToChat(client, "failed to get class, try again");
		return Plugin_Handled;
	}
	
	repick[client] = true;
	RequestFrame(ShowClassMenu, client);
	return Plugin_Continue;
}

void ShowClassMenu(int client)
{
	ClientCommand(client, "classmenu");
}
