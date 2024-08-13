#include <sdktools>
#include <neotokyo>

bool repick[32+1];
bool loadout[32+1];
int playerClass[32+1];
int oldPlayerClass[32+1];

public Plugin myinfo = {
	name = "NT Repick Class and weapon",
	author = "bauxite",
	description = "Repick your class and weapon by typing !re in freeze time",
	version = "0.1.0",
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

public void OnClientDisconnect_Post(int client)
{
	repick[client] = false;
	loadout[client] = false;
}

public Action OnCancel(int client, const char[] command, int argc)
{	
	if(!repick[client])
	{
		return Plugin_Continue;
	}
	
	if(loadout[client])
	{
		SetPlayerClass(client, oldPlayerClass[client]);
	}
	
	repick[client] = false;
	loadout[client] = false;
	return Plugin_Continue;
}

public Action OnClass(int client, const char[] command, int argc)
{
	if(!repick[client])
	{
		return Plugin_Continue;
	}

	char sClass[2];
	GetCmdArg(1, sClass, sizeof(sClass));
	int iClass = StringToInt(sClass);
	playerClass[client] = iClass;
	return Plugin_Continue;
}

public Action OnVariant(int client, const char[] command, int argc)
{
	if(!repick[client])
	{
		return Plugin_Continue;
	}
	
	if(!GameRules_GetProp("m_bFreezePeriod"))
	{
		repick[client] = false;
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
	if(!repick[client])
	{
		return Plugin_Continue;
	}
	
	if(!GameRules_GetProp("m_bFreezePeriod"))
	{
		SetPlayerClass(client, oldPlayerClass[client]);
		repick[client] = false;
		loadout[client] = false;
		return Plugin_Continue;
	}
	
	StripPlayerWeapons(client, false);
	SetPlayerClass(client, oldPlayerClass[client]);
	RequestFrame(Repick, client);
	return Plugin_Continue;
}

void Repick(int client)
{
	loadout[client] = false;
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
	repick[client] = false;	
}

public Action RepickWeapon(int client, int args)
{
	if(client <= 0 || client >= 33)
	{
		return Plugin_Handled;
	}
	
	if(!IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Handled;
	}
	
	if(repick[client])
	{
		return Plugin_Handled;
	}
	
	if(!GameRules_GetProp("m_bFreezePeriod"))
	{
		return Plugin_Handled;
	}
	
	oldPlayerClass[client] = GetPlayerClass(client);
	
	if(oldPlayerClass[client] <= 0 || oldPlayerClass[client] > 3)
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
