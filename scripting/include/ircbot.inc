
#if defined _ircbot_included
	#endinput
#endif
#define _ircbot_included

#define IRC_MAX_BUFFER_SIZE 1024
#define IRC_MAX_NAME_LENGTH 32
#define IRC_MAX_SYMBOLS 7


// IRC Protocol

#define RPL_NAMREPLY	"353"

enum IRC_Level {

	IRC_Level_Normal = 0,
	IRC_Level_Voice,
	IRC_Level_HalfOp,
	IRC_Level_Op,
	IRC_Level_Admin,
	IRC_Level_ChanOwner
}

enum IRC_Font {
	
	IRC_Font_Bold = 2,
	IRC_Font_Underlined = 31,
	IRC_Font_Reversed = 22,
	IRC_Font_Colored = 3,
	IRC_Font_Plain = 15

}

enum IRC_Color {
	
	IRC_Color_None = -1,
	IRC_Color_White = 0,
	IRC_Color_Black,
	IRC_Color_Blue,
	IRC_Color_Green,
	IRC_Color_LightRed,
	IRC_Color_Brown,
	IRC_Color_Purple,
	IRC_Color_Orange,
	IRC_Color_Yellow,
	IRC_Color_LightGreen,
	IRC_Color_Cyan,
	IRC_Color_LightCyan,
	IRC_Color_LightBlue,
	IRC_Color_Pink,
	IRC_Color_Grey,
	IRC_Color_LightGrey

}

functag public Action:IrcCmd(const String:user[], args);

/**
 * Registers an IRC command, accessible via IRC only
 *
 * @param cmd		Name of the command (without the !)
 * @param num2		Callback Function (IrcCmd functag)
 * @param num2		The lowest Irc Access level required to use this command
 * @return			nothing
 */
native RegIrcCmd(const String:cmd[], IrcCmd:callback, IRC_Level:ircLevel=IRC_Level_Normal);

/**
 * Gets the highest IRC level a user has on specified channel
 *
 * @param nick		User to check
 * @param num2		Channel where the user is currently on
 * @return			IRC_Level
 */
native IRC_Level:GetUserIrcLevel(const String:nick[], const String:channel[]);
native ParseUserInfo(const String:info[], String:nick[], nickLen=0, String:ident[]="", identLen=0, String:host[]="", hostLen=0);
native ReplyToIrcCommand(const String:format[], any:...);
native GetIrcReplySource(String:buffer[], maxlength);
native bool:GetIrcArg(argnum, String:buffer[], maxlength);
native GetIrcArgString(String:buffer[], maxlength, startAt=1);
native IRC_Reconnect();
native IRC_SendMessage(const String:format[], any:...);
native IRC_PrintToChannel(const String:format[], any:...);
native IRC_PrintToChannelEx(const String:type[], IRC_Color:color=IRC_Color_None, const String:format[], any:...);

forward OnIrcConnected();
forward OnIrcDisconnect();
forward OnIrcDisconnected();
forward OnIrcPerform();
forward OnIrcJoin(const String:user[], const String:channel[]);
forward OnIrcPart(const String:user[], const String:channel[]);
forward OnIrcQuit(const String:user[], const String:message[]);
forward OnIrcChat(const String:message[], const String:user[], const String:place[]);
forward OnIrcMode(const String:place[], const String:user[], bool:give, flag, const String:inflictor[]);
forward OnIrcUserLevel(const String:user[], const String:channel[], IRC_Level:oldLevel, IRC_Level:newLevel, const String:inflictor[]);
forward OnIrcNotice(const String:message[], const String:user[], const String:place[]);
forward OnIrcInvite(const String:channel[], const String:user[], const String:inviter[]);
forward OnIrcKick(const String:user[], const String:channel[], const String:kicker[], const String:reason[]);
forward OnIrcBan(const String:user[], const String:channel[], const String:banner[]);
forward OnIrcUnBan(const String:user[], const String:channel[], const String:unbanner[]);
forward OnIrcNickChange(const String:oldName[], const String:newName[]);
forward OnIrcRaw(const String:message[], const String:code[], const String:from[], const String:to[]);
