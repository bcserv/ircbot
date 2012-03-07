
// enforce semicolons after each code statement
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <socket>
#include "ircbot.inc"

#define PLUGIN_VERSION		"0.9"



new IRC_Symbols[] = {

	'+', // 0,
	'%', // 1
	'@', // 2
	'&', // 3
	'~'  // 4
};

new IRC_Letters[] = {

	'v', // 0,
	'h', // 1
	'o', // 2
	'a', // 3
	'q'  // 4
};



/*****************************************************************


			P L U G I N   I N F O


*****************************************************************/

public Plugin:myinfo = {
	name = "Source IRC Bot",
	author = "Berni",
	description = "Source IRC Bot",
	version = PLUGIN_VERSION,
	url = "www.mannisfunhouse.eu"
}



/*****************************************************************


			G L O B A L   V A R S


*****************************************************************/

// Settings
new String:cfg_path[PLATFORM_MAX_PATH];
new String:cfg_server[256];
new cfg_port;
new String:cfg_nickname[IRC_MAX_NAME_LENGTH];
new String:cfg_channel[IRC_MAX_NAME_LENGTH];
new bool:cfg_partUnknownChannels;
new bool:cfg_debug;

// Global accessors
new Handle:irc_socket = INVALID_HANDLE;
new Handle:users = INVALID_HANDLE;
new Handle:channels = INVALID_HANDLE;
new Handle:rights = INVALID_HANDLE;
new String:saveBuffer[IRC_MAX_BUFFER_SIZE];

// IRC commands manager
new Handle:ircCmd_names = INVALID_HANDLE;
new Handle:ircCmd_plugins = INVALID_HANDLE;
new Handle:ircCmd_callbacks = INVALID_HANDLE;
new Handle:ircCmd_levels = INVALID_HANDLE;
new Handle:ircCmdArgs = INVALID_HANDLE;
new String:ircCmdArgStr[256];
new String:ircCmdPlace[IRC_MAX_NAME_LENGTH];

// Global forwards
new Handle:forward_OnIrcConnected		= INVALID_HANDLE;
new Handle:forward_OnIrcDisconnect		= INVALID_HANDLE;
new Handle:forward_OnIrcDisconnected	= INVALID_HANDLE;
new Handle:forward_OnIrcPerform 		= INVALID_HANDLE;
new Handle:forward_OnIrcJoin			= INVALID_HANDLE;
new Handle:forward_OnIrcPart			= INVALID_HANDLE;
new Handle:forward_OnIrcQuit			= INVALID_HANDLE;
new Handle:forward_OnIrcChat			= INVALID_HANDLE;
new Handle:forward_OnIrcMode			= INVALID_HANDLE;
new Handle:forward_OnIrcUserLevel		= INVALID_HANDLE;
new Handle:forward_OnIrcNotice			= INVALID_HANDLE;
new Handle:forward_OnIrcInvite			= INVALID_HANDLE;
new Handle:forward_OnIrcKick			= INVALID_HANDLE;
new Handle:forward_OnIrcBan				= INVALID_HANDLE;
new Handle:forward_OnIrcUnBan			= INVALID_HANDLE;
new Handle:forward_OnIrcNickChange		= INVALID_HANDLE;
new Handle:forward_OnIrcRaw				= INVALID_HANDLE;



/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/

public OnPluginStart() {
	
	users				= CreateArray(IRC_MAX_NAME_LENGTH);
	channels			= CreateArray(IRC_MAX_NAME_LENGTH);
	rights				= CreateArray(IRC_MAX_SYMBOLS+1);
	
	// IRC Commands Manager
	ircCmd_names		= CreateArray(32);
	ircCmd_plugins		= CreateArray();
	ircCmd_callbacks	= CreateArray();
	ircCmd_levels		= CreateArray();
	
	ircCmdArgs			= CreateArray(64);

	// Build pathes here
	BuildPath(Path_SM, cfg_path, sizeof(cfg_path), "configs/ircbot/main.cfg");
	
	LoadSettings();

	forward_OnIrcConnected		= CreateGlobalForward("OnIrcConnected",		ET_Ignore);
	forward_OnIrcDisconnect		= CreateGlobalForward("OnIrcDisconnect",	ET_Ignore);
	forward_OnIrcDisconnected	= CreateGlobalForward("OnIrcDisconnected",	ET_Ignore);
	forward_OnIrcPerform		= CreateGlobalForward("OnIrcPerform",		ET_Ignore);
	forward_OnIrcJoin			= CreateGlobalForward("OnIrcJoin",			ET_Ignore, Param_String, Param_String);
	forward_OnIrcPart			= CreateGlobalForward("OnIrcPart",			ET_Ignore, Param_String, Param_String);
	forward_OnIrcQuit			= CreateGlobalForward("OnIrcQuit",			ET_Ignore, Param_String, Param_String);
	forward_OnIrcChat			= CreateGlobalForward("OnIrcChat",			ET_Ignore, Param_String, Param_String, Param_String);
	forward_OnIrcMode			= CreateGlobalForward("OnIrcMode",			ET_Ignore, Param_String, Param_String, Param_Cell, Param_Cell, Param_String);
	forward_OnIrcUserLevel		= CreateGlobalForward("OnIrcUserLevel",		ET_Ignore, Param_String, Param_String, Param_Cell, Param_Cell, Param_String);
	forward_OnIrcNotice			= CreateGlobalForward("OnIrcNotice",		ET_Ignore, Param_String, Param_String, Param_String);
	forward_OnIrcInvite			= CreateGlobalForward("OnIrcInvite",		ET_Ignore, Param_String, Param_String, Param_String);
	forward_OnIrcKick			= CreateGlobalForward("OnIrcKick",			ET_Ignore, Param_String, Param_String, Param_String, Param_String);
	forward_OnIrcBan			= CreateGlobalForward("OnIrcBan",			ET_Ignore, Param_String, Param_String, Param_String);
	forward_OnIrcUnBan			= CreateGlobalForward("OnIrcUnBan",			ET_Ignore, Param_String, Param_String, Param_String);
	forward_OnIrcNickChange		= CreateGlobalForward("OnIrcNickChange",	ET_Ignore, Param_String, Param_String);
	forward_OnIrcRaw 			= CreateGlobalForward("OnIrcRaw",			ET_Ignore, Param_String, Param_String, Param_String, Param_String);

	RegAdminCmd("irc_reconnect",	Command_Reconnect,		ADMFLAG_ROOT);
	RegAdminCmd("irc_rejoinchannel",Command_RejoinChannel,	ADMFLAG_ROOT);
	RegAdminCmd("irc_sendraw",		Command_SendRaw,		ADMFLAG_ROOT);
	
	RegIrcCmd("command",			IrcCommand_Command,		IRC_Level_Op);
	RegIrcCmd("cmd",				IrcCommand_Command,		IRC_Level_Op);
	RegIrcCmd("cvar",				IrcCommand_Cvar,		IRC_Level_HalfOp);
	RegIrcCmd("gameinfo",			IrcCommand_Gameinfo,	IRC_Level_Voice);
	RegIrcCmd("gi",					IrcCommand_Gameinfo,	IRC_Level_Voice);
	RegIrcCmd("sm",					IrcCommand_Sourcemod,	IRC_Level_Voice);
	RegIrcCmd("say",				IrcCommand_Say,			IRC_Level_Voice);
	RegIrcCmd("say_team",			IrcCommand_SayTeam,		IRC_Level_Voice);

	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_SayTeam);

	HookEvent("player_death", Event_PlayerDeath);
	
	// And finally we connect
	irc_socket = IRC_Connect();

} 

public bool:AskPluginLoad(Handle:myself, bool:late, String:error[], err_max) {

	CreateNative("RegIrcCmd",				Native_RegIrcCmd);
	CreateNative("GetUserIrcLevel",			Native_GetUserIrcLevel);
	CreateNative("ParseUserInfo",			Native_ParseUserInfo);
	CreateNative("ReplyToIrcCommand",		Native_ReplyToIrcCommand);
	CreateNative("GetIrcReplySource",		Native_GetIrcReplySource);
	CreateNative("GetIrcArg",				Native_GetIrcArg);
	CreateNative("GetIrcArgString",			Native_GetIrcArgString);
	CreateNative("IRC_Reconnect",			Native_IRC_Reconnect);
	CreateNative("IRC_SendMessage",			Native_IRC_SendMessage);
	CreateNative("IRC_PrintToChannel",		Native_IRC_PrintToChannel);
	CreateNative("IRC_PrintToChannelEx",	Native_IRC_PrintToChannelEx);

	return true;
}

public OnPluginEnd() {

	IRC_Disconnect();
}

public bool:OnClientConnect(client, String:rejectmsg[], maxlen) {
	
	decl String:address[24];
	GetClientIP(client, address, sizeof(address), false);
	
	IRC_PrintToChannelEx("Connect", IRC_Color_None, "Player \x03%d%N\x03 (%s) connected", GetClientColor(client), client, address);
	
	return true;
}

public OnClientPostAdminCheck(client) {
	
	IRC_PrintToChannelEx("Join", IRC_Color_None, "Player \x03%d%L\x03 joined the game", GetClientColor(client), client);
}

public OnClientDisconnect(client) {
	
	IRC_PrintToChannelEx("Disconnect", IRC_Color_None, "Player \x03%d%L\x03 disconnected", GetClientColor(client), client);
}



/*****************************************************************


			N A T I V E   F U N C T I O N S


*****************************************************************/

public Native_ReplyToIrcCommand(Handle:plugin, numParams) {
	
	decl String:buffer[IRC_MAX_BUFFER_SIZE], written;
	FormatNativeString(0, 1, 2, sizeof(buffer), written, buffer); 

	IRC_SendMessage("PRIVMSG %s :%s", ircCmdPlace, buffer);
}

public Native_GetIrcReplySource(Handle:plugin, numParams) {

	decl String:buffer[IRC_MAX_BUFFER_SIZE];
	new maxlength = GetNativeCell(2);
	
	strcopy(buffer, maxlength, ircCmdPlace);
	SetNativeString(1, buffer, sizeof(buffer));
}

public Native_GetIrcArg(Handle:plugin, numParams) {
	
	decl String:buffer[64];
	
	new argnum = GetNativeCell(1);
	new maxlength = GetNativeCell(3);
	
	if (argnum >= GetArraySize(ircCmdArgs)) {
		return false;
	}
	
	GetArrayString(ircCmdArgs, argnum, buffer, maxlength);
	SetNativeString(2, buffer, sizeof(buffer));
	
	return true;
}

public Native_GetIrcArgString(Handle:plugin, numParams) {
	
	decl String:buffer[256];
	new maxLength = GetNativeCell(2);
	new startAt = GetNativeCell(3);
	
	new pos=0;
	
	if (startAt > 1) {
		
		new x=0, count=1;
		while (ircCmdArgStr[x] != '\0') {
			
			if (ircCmdArgStr[x] == ' ') {
				count++;
				
				if (count == startAt) {
					pos = x+1;
					break;
				}
			}
			
			++x;
		}
		
		if (ircCmdArgStr[x] == '\0') {
			pos = x;
		}
	}
	
	strcopy(buffer, maxLength, ircCmdArgStr[pos]);
	
	SetNativeString(1, buffer, maxLength);
}

public Native_ParseUserInfo(Handle:plugin, numParams) {
	
	decl String:info[512];
	
	GetNativeString(1, info, sizeof(info));
	new nickLen = GetNativeCell(3);
	new identLen = GetNativeCell(5);
	new hostLen = GetNativeCell(7);
	
	decl String:toks_info[2][256];
	Tokenizer(info, '!', toks_info, sizeof(toks_info), sizeof(toks_info[])); 

	SetNativeString(2, toks_info[0], nickLen);
	
	if (identLen > 0) {
		
		decl String:toks_identHost[2][256];
		Tokenizer(toks_info[1], '@', toks_identHost, sizeof(toks_identHost), sizeof(toks_identHost[]));
		SetNativeString(4, toks_identHost[0], identLen);
		
		if (hostLen > 0) {
			SetNativeString(6, toks_identHost[1], hostLen);
		}
	}
	
}

public Native_RegIrcCmd(Handle:plugin, numParams) {
	
	decl String:cmd[32];

	GetNativeString(1, cmd, sizeof(cmd));
	new IrcCmd:callback = GetNativeCell(2);
	new IRC_Level:ircLevel = GetNativeCell(3);
	
	PushArrayString(ircCmd_names, cmd);
	PushArrayCell(ircCmd_plugins, plugin);
	PushArrayCell(ircCmd_callbacks, callback);
	PushArrayCell(ircCmd_levels, ircLevel);
}

public Native_GetUserIrcLevel(Handle:plugin, numParams) {
	
	decl String:nick[IRC_MAX_NAME_LENGTH], String:channel[IRC_MAX_NAME_LENGTH];
	decl String:str_levels[IRC_MAX_SYMBOLS];
	
	GetNativeString(1, nick, sizeof(nick));
	GetNativeString(2, channel, sizeof(channel));
	
	new x = FindUserOnChannel(nick, channel);
	
	if (x == -1) {
		return _:IRC_Level_Normal;
	}
	
	GetArrayString(rights, x, str_levels, sizeof(str_levels));
	
	return _:IRCSymbolToLevel(str_levels[0]);
}

public Native_IRC_Reconnect(Handle:plugin, numParams) {

	if (irc_socket != INVALID_HANDLE) {
		IRC_Disconnect();
	}

	irc_socket = IRC_Connect();
}

public Native_IRC_SendMessage(Handle:plugin, numParams) {
	 
	decl String:buffer[IRC_MAX_BUFFER_SIZE], written;
	IRC_FormatNativeString(0, 1, 2, sizeof(buffer), written, buffer);
	
	if (cfg_debug) {
		PrintToServer("IRC-BOT: %s", buffer);
	}

	StrCat(buffer, sizeof(buffer), "\n");
	SocketSend(irc_socket, buffer);
}

public Native_IRC_PrintToChannel(Handle:plugin, numParams) {

	decl String:buffer[IRC_MAX_BUFFER_SIZE], written;

	IRC_FormatNativeString(0, 1, 2, sizeof(buffer), written, buffer);
	IRC_SendMessage("PRIVMSG %s :%s", cfg_channel, buffer);
}

public Native_IRC_PrintToChannelEx(Handle:plugin, numParams) {
	
	decl String:type[32];
	GetNativeString(1, type, sizeof(type));
	new IRC_Color:color = GetNativeCell(2);
	
	decl String:buffer[IRC_MAX_BUFFER_SIZE], written;
	IRC_FormatNativeString(0, 3, 4, sizeof(buffer), written, buffer);
	
	if (color == IRC_Color_None) {
		IRC_SendMessage("PRIVMSG %s :\x03%d[%s]\x03 %s", cfg_channel, IRC_Color_Green, type, buffer);
	}
	else {
		IRC_SendMessage("PRIVMSG %s :\x03%d[%s]\x03 \x03%d%s\x03", cfg_channel, IRC_Color_Green, type, color, buffer);
	}
}

IRC_FormatNativeString(out_param, fmt_param, vararg_param, out_len, &written=0, String:out_string[]="", const String:fmt_string[]="") {
	
	/*decl String:format[IRC_MAX_BUFFER_SIZE];
	
	if (fmt_param > 0) {
		GetNativeString(fmt_param, format, sizeof(format));
	}
	else {
		strcopy(format, sizeof(format), fmt_string);
	}
	
	new x=0, count=-1, bool:formatter=false;
	while (format[x] != '\0') {
		
		if (format[x] == '%') {
			formatter = true;
			count++;
		}
		else if (formatter) {
			
			if (format[x] == 'N' || format[x] == 'L') {
				
				new client = GetNativeCell(vararg_param+count);
				PrintToServer("Debug: %d %d", GetNativeCell(vararg_param+count), vararg_param+count);
				new IRC_Color:color = GetClientColor(client);
				
				decl String:colorFormat[8];
				Format(colorFormat, sizeof(colorFormat), "\x03%d\\\%%c\x03", color, format[x]);
				
				Format(format[x-1], sizeof(format)-x+1, "%s%s", colorFormat, format[x+1]);
				x += strlen(colorFormat)-2;
				
			}
			
			formatter = false;
		}
		
		++x;
	}*/
	
	FormatNativeString(out_param, fmt_param, vararg_param, out_len, written, out_string, fmt_string);
}



/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/

public Action:Command_Say(client, args) {
	
	new IRC_Color:color = GetClientColor(client);
	
	decl String:argStr[192];
	GetCmdArgString(argStr, sizeof(argStr));
	StripQuotes(argStr);

	IRC_PrintToChannelEx("Public-Chat", IRC_Color_None, "\x03%d%N\x03: %s", color, client, argStr);
	
	return Plugin_Continue;
}

public Action:Command_SayTeam(client, args) {
	
	new IRC_Color:color = GetClientColor(client);
	
	decl String:argStr[192];
	GetCmdArgString(argStr, sizeof(argStr));
	StripQuotes(argStr);
	
	IRC_PrintToChannelEx("Team-Chat", IRC_Color_None, "\x03%d%N\x03: %s", color, client, argStr);
	
	return Plugin_Continue;
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) {

	decl String:weapon[64];

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (
	
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	
	IRC_PrintToChannelEx("Kill", IRC_Color_None, "Player \x03%d%N\x03 killed player \x03%d%N\x03 with \x03%d%s\x03", GetClientColor(attacker), attacker, GetClientColor(client), client, IRC_Color_Green, weapon);
	
	return Plugin_Continue;
}

public Action:IrcCommand_Command(const String:user[], args) {
	
	decl String:argStr[64];
	GetIrcArgString(argStr, sizeof(argStr));
	
	ServerCommand("%s", argStr);
	ReplyToIrcCommand("Command executed");
	
	return Plugin_Handled;
}

public Action:IrcCommand_Cvar(const String:user[], args) {
	
	decl String:arg1[64], String:arg2[64];
	
	GetIrcArg(1, arg1, sizeof(arg1));
	
	new Handle:cvar = FindConVar(arg1);
	
	if (cvar == INVALID_HANDLE) {
		
		ReplyToIrcCommand("ConVar %s not found", arg1);
	}
	else {
	
		if (args > 1) {
			
			GetIrcArg(2, arg2, sizeof(arg2));
			
			SetConVarString(cvar, arg2);
			ReplyToIrcCommand("ConVar %s set to: %s", arg1, arg2);
		}
		else {
			
			decl String:cvar_value[64];
			GetConVarString(cvar, cvar_value, sizeof(cvar_value));
			ReplyToIrcCommand("ConVar %s value: %s", arg1, cvar_value);
		}
	}
	
	return Plugin_Handled;
}

public Action:IrcCommand_Gameinfo(const String:user[], args) {
	
	new seconds = RoundToFloor(GetGameTime()/GetTickInterval());
	new hours = seconds/3600;
	new minutes = seconds-(hours/3600);
	new restSeconds = seconds-(hours/3600)-(minutes/60);
	
	new sfps = RoundToNearest(1/GetTickInterval());
	
	decl String:currentMap[64];
	GetCurrentMap(currentMap, sizeof(currentMap));
	new maxClients = GetMaxClients();
	ReplyToIrcCommand(
		"\x0314Gameinfo: Map: %s \x0312CT: %d/%d players %0.f points \x0304T: %d/%d players %0.f points \x0314%02u:%02u:%02u mins played SFPS: %d Average Ping: %d",
		currentMap, GetTeamClientCount(2), maxClients, GetTeamScore(2), GetTeamClientCount(3), maxClients, GetTeamScore(3), hours, minutes, restSeconds, sfps, GetAveragePing()
	);
	
	return Plugin_Handled;
}

public Action:IrcCommand_Sourcemod(const String:user[], args) {
	
	decl String:argStr[256];
	GetIrcArgString(argStr, sizeof(argStr));

	ServerCommand("sm %s", argStr);
	ReplyToIrcCommand("Command executed");

	return Plugin_Handled;
}

public Action:IrcCommand_Say(const String:user[], args) {
	
	decl String:argStr[256];
	GetIrcArgString(argStr, sizeof(argStr));

	PrintToChatAll("\x04\x01(IRC) \x04%s \x01:  %s", user, argStr);
	IRC_PrintToChannelEx("Say", IRC_Color_None, "\x03%d%s\x03: %s", IRC_Color_Pink, user, argStr);
	
	return Plugin_Handled;
}

public Action:IrcCommand_SayTeam(const String:user[], args) {

	decl String:strTeam[32];
	GetIrcArg(1, strTeam, sizeof(strTeam));
	
	new team = StringToInt(strTeam);
	
	if (!isStringNumeric(strTeam)) {
		
		team = FindTeamByName(strTeam);

		if (team == -2) {
			ReplyToIrcCommand("Error: Multiple teams with this phrase found");
			return Plugin_Handled;
		}
	}
	
	if (team == -1 || team > GetTeamCount()) {
		ReplyToIrcCommand("Error: No team matched");
		return Plugin_Handled;
	}
	
	decl String:argStr[256], String:teamName[64];
	GetIrcArgString(argStr, sizeof(argStr), 2);
	GetTeamName(team, teamName, sizeof(teamName));
	
	PrintToChatTeam(team, "\x04\x01(IRC) (TEAM) \x04%s \x01:  %s", user, argStr);
	IRC_PrintToChannelEx("Say_Team", IRC_Color_None, "(\x03%d%s\x03) \x03%d%s\x03: %s", GetTeamColor(team), teamName, IRC_Color_Pink, user, argStr);
	
	return Plugin_Handled;
}

public OnSocketConnected(Handle:socket, any:arg) {

	IRC_SendMessage("NICK %s", cfg_nickname);
	IRC_SendMessage("USER %s \"\" \"%s\" :%s", cfg_nickname, cfg_server, cfg_nickname);
	IRC_SendMessage("PROTOCTL NAMESX");
	IRC_SendMessage("JOIN %s", cfg_channel);
	
	decl Action:result;
	Call_StartForward(forward_OnIrcConnected);
	Call_Finish(result);


	IRC_PrintToChannel("\x2Starting Source IRC-Bot v%s", PLUGIN_VERSION);
}

public OnSocketReceive(Handle:socket, String:receiveData[], const dataSize, any:value) {
	
	decl String:toks[2][256];
	Tokenizer(receiveData, ' ', toks, sizeof(toks), sizeof(toks[]));
		
	decl String:line[IRC_MAX_BUFFER_SIZE];
	new bool:isFirst=true;
	new n=0;

	while ((n = StrSplit(receiveData, "\r\n", line, sizeof(line), n)) != -1) {
		
		if (isFirst && !StrEqual(saveBuffer, "")) {
			
			Format(line, sizeof(line), "%s%s", saveBuffer, line);
			isFirst=false;
		}
		
		if (cfg_debug) {

			PrintToServer("IRC-SRV: %s", line);
		}

		ParseIRCMessage_raw(line);
	}
	
	// This is in case we have to wait for the next receive
	new len=strlen(receiveData);
	if (!StrEqual(receiveData[len-2], "\r\n")) {
		strcopy(saveBuffer, sizeof(saveBuffer), line);
	}
	else {
		saveBuffer[0] = '\0';
	}
}

public OnSocketDisconnected(Handle:socket, any:hFile) {

	irc_socket = INVALID_HANDLE;
	
	decl Action:result;
	Call_StartForward(forward_OnIrcDisconnected);
	Call_Finish(result);
	
	ClearArray(users);
	ClearArray(channels);
	ClearArray(rights);
	
	irc_socket = IRC_Connect();
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:hFile) {

	LogError("socket error %d (errno %d)", errorType, errorNum);
	CloseHandle(socket);
	
	irc_socket = IRC_Connect();
}

public Action:Command_Reconnect(client, args) {
	
	IRC_Reconnect();
	
	return Plugin_Handled;
}

public Action:Command_RejoinChannel(client, args) {
	
	IRC_SendMessage("PART %s", cfg_channel);
	IRC_SendMessage("JOIN %s", cfg_channel);
}

public Action:Command_SendRaw(client, args) {
	
	decl String:argStr[256];
	GetCmdArgString(argStr, sizeof(argStr));
	
	IRC_SendMessage("%s", argStr);

}



/*****************************************************************


			P L U G I N   F U N C T I O N S


*****************************************************************/

bool:isStringNumeric(const String:str[]) {

	new x=0;
	while (str[x] != '\0') {
		
		if (!IsCharNumeric(str[x])) {
			return false;
		}
		
		++x;
	}
	
	return true;
}

stock PrintToChatTeam(team, const String:format[], any:...) {

	decl String:buffer[192];
	new clientTeam;
	
	VFormat(buffer, sizeof(buffer), format, 2);

	for (new client = 1; client <= MaxClients; client++) {
		
		if (IsClientInGame(client)) {
			
			clientTeam = GetClientTeam(client);
			
			if (clientTeam == team) {
				
				PrintToChat(client, buffer);
			}
		}
	}
}

bool:KvGetBool(Handle:kv, const String:key[], const String:defvalue[]="yes") {
	
	decl String:value[4];
	
	KvGetString(kv, key, value, sizeof(value), defvalue);
	
	if (StrEqual(value, "1") || StrEqual(value, "yes", false)) {
		return true;
	}
	
	return false;
}

bool:LoadSettings() {

	new Handle:kv = CreateKeyValues("IrcBot");
	FileToKeyValues(kv, cfg_path);

	KvGetString(kv, "server"	, cfg_server	, sizeof(cfg_server)	, "localhost");
	cfg_port = KvGetNum(kv, "port", 6667);
	KvGetString(kv, "nickname"	, cfg_nickname	, sizeof(cfg_nickname)	, "ircbot");
	KvGetString(kv, "channel"	, cfg_channel	, sizeof(cfg_channel)	, "#ircbot");
	
	cfg_partUnknownChannels = KvGetBool(kv, "partunknkownchannels");
	cfg_debug = KvGetBool(kv, "debug", "no");
	
	CloseHandle(kv);

	return true;

}


IRC_Color:GetClientColor(client) {
	
	if (client == 0) {
		return IRC_Color_LightGreen;
	}

	if (IsClientInGame(client)) {

		new team = GetClientTeam(client);
		
		return GetTeamColor(team);
	}
	
	return IRC_Color_Grey;
}

IRC_Color:GetTeamColor(team) {
		
	switch (team) {
		
		case 2: {
			return IRC_Color_LightRed;
		}
		case 3: {
			return IRC_Color_LightBlue;
		}
	}
	
	return IRC_Color_Grey;
}

StrSplit(const String:str[], const String:split[], String:buffer[], maxlength, startPos=0, bool:caseSensitive=false) {
	
	if (str[startPos] == '\0') {
		return -1;
	}
	
	new pos = StrContains(str[startPos], split, caseSensitive);
	new num;
	
	if (pos == -1) {
		num = strcopy(buffer, maxlength, str[startPos]);
	}
	else {
		num = strcopy(buffer, pos+1, str[startPos]) + strlen(split);
	}
	
	return startPos+num;
}

ParseIRCMessage_raw(const String:msg[]) {
	
	new pos0=0, pos1=0, pos2=0, pos3=0;
	decl String:toks[4][IRC_MAX_BUFFER_SIZE];
	Tokenizer(msg, ' ', toks, sizeof(toks), sizeof(toks[]));
	
	if (toks[0][0] == ':') {
		pos0 = 1;
	}
	if (toks[1][0] == ':') {
		pos1 = 1;
	}
	if (toks[2][0] == ':') {
		pos2 = 1;
	}
	if (toks[3][0] == ':') {
		pos3 = 1;
	}
	
	if (StrEqual(toks[0][pos0], "PING", false)) {
	
		IRC_SendMessage("PONG :%s", toks[1][pos1]);
	}
	
	ParseIRCMessage(toks[0][pos0], toks[1][pos1], toks[2][pos2], toks[3][pos3]);
}

ParseIRCMessage(const String:from[], const String:code[], const String:to[], const String:message[]) {
	
	decl String:user[IRC_MAX_NAME_LENGTH], String:ident[32], String:host[256];
	ParseUserInfo(from, user, sizeof(user), ident, sizeof(ident), host, sizeof(host));
	
	OnIrcRaw(from, code, to, message);
	
	if (StrEqual(code,"001")) {
		
		OnIrcPerform();
	}
	else if (StrEqual(code, RPL_NAMREPLY)) {
		
		OnIrcNameReply(message);
	}
	else if (StrEqual(code, "PRIVMSG", false)) {
		
		OnIrcChat(user, message, to);
	}
	else if (StrEqual(code, "JOIN", false)) {
		
		OnIrcJoin(user, to);
	}
	else if (StrEqual(code, "PART", false)) {

		OnIrcPart(user, to);
	}
	else if (StrEqual(code, "MODE", false)) {
		
		decl String:toks_mode[2][32];
		Tokenizer(message, ' ', toks_mode, sizeof(toks_mode), sizeof(toks_mode[]));

		OnIrcModeRaw(to, toks_mode[0], toks_mode[1], from);
	}
	else if (StrEqual(code, "NICK", false)) {

		OnIrcNickChange(user, message);
	}
	else if (StrEqual(code, "INVITE", false)) {

		OnIrcInvite(message, to, user);
	}
	else if (StrEqual(code, "KICK", false)) {
		
		decl String:toks_kick[2][32];
		Tokenizer(message, ' ', toks_kick, sizeof(toks_kick), sizeof(toks_kick[]));

		OnIrcKick(toks_kick[0], to, user, toks_kick[1][1]),
		OnIrcPart(toks_kick[0], to);
	}
	else if (StrEqual(code, "NOTICE", false)) {

		OnIrcNotice(user, message, to);
	}
	else if (StrEqual(code, "QUIT", false)) {

		OnIrcQuit(user, message);
	}}

OnIrcPerform() {
	
	decl Action:result;
	Call_StartForward(forward_OnIrcPerform);
	Call_Finish(result);
	
	new Handle:kv = CreateKeyValues("IrcBot");
	FileToKeyValues(kv, cfg_path);
	
	decl String:command[255];
	
	KvJumpToKey(kv, "perform");
	
	if (KvGotoFirstSubKey(kv)) {

		do {

			KvGetSectionName(kv, command, sizeof(command));
			IRC_SendMessage(command);

		} while (KvGotoNextKey(kv));
	}

}

OnIrcJoin(const String:nickName[], const String:channel[]) {

	if (cfg_partUnknownChannels && StrEqual(nickName, cfg_nickname, false) && !StrEqual(channel, cfg_channel, false)) {
		IRC_SendMessage("PART %s", channel);
		return;
	}

	PushArrayString(users, nickName);
	PushArrayString(channels, channel);
	PushArrayString(rights, "");
	
	decl Action:result;
	Call_StartForward(forward_OnIrcJoin);
	Call_PushString(nickName);
	Call_PushString(channel);
	Call_Finish(result);
}

OnIrcPart(const String:nickName[], const String:channel[]) {
	
	if (StrEqual(nickName, cfg_nickname, false)) {
		
		ClearChannelUsers(channel);
	}
	
	decl Action:result;
	Call_StartForward(forward_OnIrcPart);
	Call_PushString(nickName);
	Call_PushString(channel);
	Call_Finish(result);
	
	new x = FindUserOnChannel(nickName, channel);
	
	if (x != -1) {
		
		RemoveFromArray(users, x);
		RemoveFromArray(channels, x);
		RemoveFromArray(rights, x);
	}
}

OnIrcChat(const String:user[], const String:message[], const String:to[]) {
	
	new Action:result;
	Call_StartForward(forward_OnIrcChat);
	Call_PushString(message);
	Call_PushString(user);
	Call_PushString(to);
	Call_Finish(result);
	
	if (!StrEqual(to, cfg_channel, false)) {
		return;
	}
	
	if (message[0] == '!') {

		// Loop trough all IRC commands
		strcopy(ircCmdPlace, sizeof(ircCmdPlace), to);

		decl String:arg[64], String:arg0[32];
		new n=0, numArgs=0;
		while ((n = StrSplit(message, " ", arg, sizeof(arg), n)) != -1) {
			
			PushArrayString(ircCmdArgs, arg);
			numArgs++;
		}
		
		GetArrayString(ircCmdArgs, 0, arg0, sizeof(arg0));
		strcopy(ircCmdArgStr, sizeof(ircCmdArgStr), message[strlen(arg0)+1]);
		
		new IRC_Level:userLevel = GetUserIrcLevel(user, to);
	
		decl String:command[32];
		new size=GetArraySize(ircCmd_names);
		for (new i=0; i<size; i++) {
			
			GetArrayString(ircCmd_names, i, command, sizeof(command));
			
			if (StrEqual(command, arg0[1], false)) {
				
				if (userLevel < GetArrayCell(ircCmd_levels, i)) {
					ReplyToIrcCommand("[Source IRC-Bot] Access denied to IRC command");
					continue;
				}
				
				
				Call_StartFunction(GetArrayCell(ircCmd_plugins, i), GetArrayCell(ircCmd_callbacks, i));
				Call_PushString(user);
				Call_PushCell(numArgs);
				Call_Finish(result);

			}
		}

		ClearArray(ircCmdArgs);
		ircCmdArgStr[0] = '\0';
		
		if (result == Plugin_Handled || result == Plugin_Stop) {
			return;
		}

		// Iterate through all srcds commands
		decl String:name[64];
		new Handle:cvar;
		new bool:isCommand;
		new flags;
		
		cvar = FindFirstConCommand(name, sizeof(name), isCommand, flags);
		if (cvar ==INVALID_HANDLE) {
			SetFailState("Could not load cvar list");
		}
		
		do {
			if (!isCommand) {
				continue;
			}
			
			if (StrEqual(name, arg0[1])) {
				
				if (userLevel < IRC_Level_Op) {
					ReplyToIrcCommand("[Source IRC-Bot] Access denied to srcds command");
				}
				else {
			
					ServerCommand(message[1]);
				}
				
				break;
			}
			
		} while (FindNextConCommand(cvar, name, sizeof(name), isCommand, flags));
	}
}

OnIrcModeRaw(const String:place[], const String:flags[], const String:nickNames[], const String:inflictor[]) {
	
	if (!StrEqual(place, cfg_channel, false)) {
		return;
	}
	
	new Handle:userNames = CreateArray(IRC_MAX_NAME_LENGTH);
	
	decl String:nick[IRC_MAX_NAME_LENGTH];
	new n=0;
	while ((n = StrSplit(nickNames, " ", nick, sizeof(nick), n)) != -1) {
		
		PushArrayString(userNames, nick);
	}

	new bool:give;
	
	new x=0; n=0;
	while (flags[x] != '\0') {
		
		if (flags[x] == '+') {
			give=true;
		}
		else if (flags[x] == '-') {
			give=false;
		}
		else {
			
			GetArrayString(userNames, n, nick, sizeof(nick));
			
			OnIrcMode(place, nick, give, flags[x], inflictor);
			
			if (flags[x] == 'b') {
				
				if (give) {
					OnIrcBan(nick, place, inflictor); 
				}
				else {
					OnIrcUnBan(nick, place, inflictor); 
				}
			}
			else if (IsCharIRCLevelLetter(flags[x])) {
				
				new IRC_Level:oldLevel = GetUserIrcLevel(nick, place);
				
				if (give) {
					GiveUserSymbol(nick, place, IRCLetterToSymbol(flags[x]));
				}
				else {
					TakeUserSymbol(nick, place, IRCLetterToSymbol(flags[x]));
				}
				
				OnIrcUserLevel(nick, place, oldLevel, GetUserIrcLevel(nick, place), inflictor);
				
				++n;
			}
		}
		
		++x;
	}
}

OnIrcMode(const String:place[], const String:user[], bool:give, flag, const String:inflictor[]) {
	
	Call_StartForward(forward_OnIrcMode);
	Call_PushString(place);
	Call_PushString(user);
	Call_PushCell(give);
	Call_PushCell(flag);
	Call_PushString(inflictor);
	Call_Finish();
}

OnIrcUserLevel(const String:user[], const String:channel[], IRC_Level:oldLevel, IRC_Level:newLevel, const String:inflictor[]) {
	
	Call_StartForward(forward_OnIrcUserLevel);
	Call_PushString(user);
	Call_PushString(channel);
	Call_PushCell(oldLevel);
	Call_PushCell(newLevel);
	Call_PushString(inflictor);
	Call_Finish();
}

OnIrcNickChange(const String:oldName[], const String:newName[]) {
	
	Call_StartForward(forward_OnIrcNickChange);
	Call_PushString(oldName);
	Call_PushString(newName);
	Call_Finish();
}

OnIrcInvite(const String:channel[], const String:user[], const String:inviter[]) {
	
	Call_StartForward(forward_OnIrcInvite);
	Call_PushString(channel);
	Call_PushString(user);
	Call_PushString(inviter);
	Call_Finish();
}

OnIrcKick(const String:user[], const String:channel[], const String:kicker[], const String:reason[]) {
	
	Call_StartForward(forward_OnIrcKick);
	Call_PushString(user);
	Call_PushString(channel);
	Call_PushString(kicker);
	Call_PushString(reason);
	Call_Finish();
}

OnIrcNotice(const String:user[], const String:message[], const String:to[]) {
	
	Call_StartForward(forward_OnIrcNotice);
	Call_PushString(user);
	Call_PushString(message);
	Call_PushString(to);
	Call_Finish();
}

OnIrcQuit(const String:user[], const String:message[]) {
	
	Call_StartForward(forward_OnIrcQuit);
	Call_PushString(user);
	Call_PushString(message);
	Call_Finish();
}

OnIrcRaw(const String:message[], const String:code[], const String:from[], const String:to[]) {
	
	Call_StartForward(forward_OnIrcRaw);
	Call_PushString(message);
	Call_PushString(code);
	Call_PushString(from);
	Call_PushString(to);
	Call_Finish();
}

OnIrcBan(const String:user[], const String:channel[], const String:banner[]) {
	
	Call_StartForward(forward_OnIrcBan);
	Call_PushString(user);
	Call_PushString(channel);
	Call_PushString(banner);
	Call_Finish();
}

OnIrcUnBan(const String:user[], const String:channel[], const String:unbanner[]) {
	
	Call_StartForward(forward_OnIrcUnBan);
	Call_PushString(user);
	Call_PushString(channel);
	Call_PushString(unbanner);
	Call_Finish();
}

OnIrcNameReply(const String:message[]) {
	
	decl String:toks2[3][64];
	Tokenizer(message, ' ', toks2, sizeof(toks2), sizeof(toks2[]));
	
	ClearChannelUsers(toks2[1]);

	decl String:levels[IRC_MAX_SYMBOLS];
	decl String:nick[IRC_MAX_NAME_LENGTH];
	new n=0;
	while ((n = StrSplit(toks2[2][1], " ", nick, sizeof(nick), n)) != -1) {
		
		if (nick[0] == ':') {
			break;
		}
		
		new pos=0;
		while (nick[pos] != '\0' && IsCharIRCLevelSymbol(nick[pos])) {
			pos++;
		}
		
		strcopy(levels, pos+1, nick);

		PushArrayString(users, nick[pos]);
		PushArrayString(channels, toks2[1]);
		PushArrayString(rights, levels);
	}
}

ClearChannelUsers(const String:channel[]) {
	
	decl String:x_channel[IRC_MAX_NAME_LENGTH];
	new size=GetArraySize(users);

	for (new i=0; i<size; i++) {

		GetArrayString(channels, i, x_channel, sizeof(x_channel));
		
		if (StrEqual(channel, x_channel, false)) {
			
			RemoveFromArray(users, i);
			RemoveFromArray(channels, i);
			RemoveFromArray(rights, i);
			break;
		}
	}
}

FindUserOnChannel(const String:user[], const String:channel[]) {
	
	new x = -1;
	decl String:x_user[IRC_MAX_NAME_LENGTH], String:x_channel[IRC_MAX_NAME_LENGTH];

	new size = GetArraySize(users);
	for (new i=0; i<size; i++) {
		
		GetArrayString(users, i, x_user, sizeof(x_user));
		
		if (StrEqual(user, x_user, false)) {
			
			GetArrayString(channels, i, x_channel, sizeof(x_channel));
			
			if (StrEqual(channel, x_channel, false)) {
				
				x = i;
				break;
			}
		}
	}
	
	return x;
}

GiveUserSymbol(const String:user[], const String:channel[], symbol) {
	
	new x = FindUserOnChannel(user, channel);
	
	if (x == -1) {
		
		x = PushArrayString(users, user);
		PushArrayString(channels, channel);
		PushArrayString(rights, "");
	}
	
	decl String:levels[IRC_MAX_SYMBOLS], String:levels_new[IRC_MAX_SYMBOLS];
	GetArrayString(rights, x, levels, sizeof(levels));
	
	new n=0, i=0;
	new bool:symbolSet = false;
	while (levels[n] != '\0') {
		
		levels_new[i] = levels[n];
		i++;
		
		if (!symbolSet && (IRCSymbolToLevel(levels[n+1]) < IRCSymbolToLevel(symbol) || levels[n+1] == '\0')) {
			
			if (IRCSymbolToLevel(levels[n+1]) != IRCSymbolToLevel(symbol)) {
				
				levels_new[i] = symbol;
				i++;
			}

			symbolSet = true;
		}

		n++;
	}

	if (i==0) {
		levels_new[0] = symbol;
		i++;
	}

	levels_new[i] = '\0';

	SetArrayString(rights, x, levels_new);
}

TakeUserSymbol(const String:user[], const String:channel[], symbol) {
	
	if (symbol == '\0') {
		return;
	}
	
	new x = FindUserOnChannel(user, channel);
	
	if (x == -1) {
		
		x = PushArrayString(users, user);
		PushArrayString(channels, channel);
		PushArrayString(rights, "");
	}
	
	decl String:levels[IRC_MAX_SYMBOLS], String:str_symbol[2];
	GetArrayString(rights, x, levels, sizeof(levels));
	Format(str_symbol, sizeof(str_symbol), "%c", symbol);
	ReplaceString(levels, sizeof(levels), str_symbol, "");
	
	SetArrayString(rights, x, levels);
}

Tokenizer(const String:text[], split, String:buffers[][], maxStrings, maxStringLength) {
	
	new n=0, i=0, x=0;

	while (text[x] != '\0') {
		
		if (text[x] == split) {
			buffers[n][i] = '\0';
			i=0;
			n++;
			
			if (n == maxStrings-1) {
				strcopy(buffers[n], maxStringLength, text[x+1]);
				break;
			}
		}
		else {
			
			if (i < maxStringLength-1) {
				buffers[n][i] = text[x];
				i++;
			}
		}
		
		++x;
	}
	
	if (n < maxStrings-1) {
		buffers[n][i] = '\0';
	}
	
	n++;
	
	for (i=n; i<maxStrings; i++) {
		buffers[i][0] = '\0';
	}
	
	return n;
}

Handle:IRC_Connect() {
	// create a new tcp socket
	new Handle:socket = SocketCreate(SOCKET_TCP, OnSocketError);

	// connect the socket
	SocketConnect(socket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, cfg_server, cfg_port);
	
	return socket;
}

IRC_Disconnect() {

	Call_StartForward(forward_OnIrcDisconnect);
	Call_Finish();

	IRC_SendMessage("QUIT :und tschau :)");
	irc_socket = INVALID_HANDLE;
}

stock Debug(String:format[], any:...) {

	decl String:buffer[IRC_MAX_BUFFER_SIZE];
	VFormat(buffer, sizeof(buffer), format, 2);
	IRC_SendMessage("PRIVMSG %s :%s", cfg_channel, buffer);
}

GetAveragePing() {
	
	new pingSum=0;
	new numPlayers=0;
	
	for (new player=1; player<MaxClients; ++player) {
		
		if (IsClientInGame(player) && !IsFakeClient(player)) {
			
			pingSum += GetClientAvgLatency(player, NetFlow_Both);
			++numPlayers;
		}
	}
	
	if (numPlayers == 0) {
		return 0;
	}
	
	return pingSum/numPlayers;
}

IsCharIRCLevelSymbol(char) {
	
	new size=sizeof(IRC_Symbols);
	for (new i=0; i<size; ++i) {
		
		if (IRC_Symbols[i] == char) {
			return true;
		}
	}

	return false;
}

IsCharIRCLevelLetter(char) {
	
	new size=sizeof(IRC_Letters);
	for (new i=0; i<size; ++i) {
		
		if (IRC_Letters[i] == char) {
			return true;
		}
	}
	
	return false;
}

IRC_Level:IRCSymbolToLevel(symbol) {
	
	switch (symbol) {
		
		case '+': {
			return IRC_Level_Voice;
		}
		case '%': {
			return IRC_Level_HalfOp;
		}
		case '@': {
			return IRC_Level_Op;
		}
		case '&': {
			return IRC_Level_Admin;
		}
		case '~': {
			return IRC_Level_ChanOwner;
		}
	}
	
	return IRC_Level_Normal;
}

stock IRC_Level:IRCLetterToLevel(letter) {
	
	switch (symbol) {
		
		case 'v': {
			return IRC_Level_Voice;
		}
		case 'h': {
			return IRC_Level_HalfOp;
		}
		case 'o': {
			return IRC_Level_Op;
		}
		case 'a': {
			return IRC_Level_Admin;
		}
		case 'q': {
			return IRC_Level_ChanOwner;
		}
	}
	
	return IRC_Level_Normal;
}

IRCLetterToSymbol(letter) {
	
	switch (letter) {
		
		case 'v': {
			return '+';
		}
		case 'h': {
			return '%';
		}
		case 'o': {
			return '@';
		}
		case 'a': {
			return '&';
		}
		case 'q': {
			return '~';
		}
	}
	
	return '\0';
}
