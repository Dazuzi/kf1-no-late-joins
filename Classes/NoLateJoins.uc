class NoLateJoins extends Mutator
	Config(NoLateJoins);

struct WhiteListEntry {
	var String SteamID64;
	var String Name;
};

var config array<WhiteListEntry> WhiteList;
var config float UpdateFrequency;
var config int WaveLimit, iTextDuration;
var config bool bSaveSpectators, bKickPlayers;
var config color TextColour, HighlightColour, SavedColour;
var config string KickReason, KickMessage, PlayersSavedMessage, SpectatorMessage, SpectatorReason;
var string TextCode, HighlightCode, SavedCode, TempKickReason, TempKickMessage, TempSpectatorMessage, TempSpectatorReason;
var bool bPlayersSaved;

static function FillPlayInfo(PlayInfo PlayInfo) {
	Super.FillPlayInfo(PlayInfo);
	PlayInfo.AddSetting("No Late Joins", "WaveLimit",		"Wave limit",			0, 1,	"Text",		"1;1:9");
	PlayInfo.AddSetting("No Late Joins", "UpdateFrequency",		"Update frequency",		0, 2,	"Text",		"2;1:30");
	PlayInfo.AddSetting("No Late Joins", "bSaveSpectators",		"Save spectators",		0, 3,	"Check");
	PlayInfo.AddSetting("No Late Joins", "PlayersSavedMessage",	"Players saved message",	0, 4,	"Text",		"256");
	PlayInfo.AddSetting("No Late Joins", "bKickPlayers",		"Kick players",			0, 5,	"Check");
	PlayInfo.AddSetting("No Late Joins", "KickMessage",		"Kick message",			0, 6,	"Text",		"256");
	PlayInfo.AddSetting("No Late Joins", "KickReason",		"Kick reason",			0, 7,	"Text",		"256");
	PlayInfo.AddSetting("No Late Joins", "SpectatorMessage",	"Spectator message",		0, 8,	"Text",		"256");
	PlayInfo.AddSetting("No Late Joins", "SpectatorReason",		"Spectator reason",		0, 9,	"Text",		"256");
	PlayInfo.AddSetting("No Late Joins", "iTextDuration",		"Text duration",		0, 10,	"Text",		"2;1:99");
}

static event string GetDescriptionText(string Property) {
	switch (Property) {
		case "WaveLimit":
			return "The wave after which no new players can join. Note: waves start at 0, and in long end in 10.";
		case "UpdateFrequency":
			return "How fast should the mutator check for late joiners, in seconds.";
		case "bSaveSpectators":
			return "When enabled, current spectators will be included in the whitelist, which makes them eligible to join the match. Note: this includes only the spectators who are spectating when the saving happens.";
		case "PlayersSavedMessage":
			return "Players saved message gets sent to everyone when current players are saved.";
		case "bKickPlayers":
			return "When enabled, players with perk levels below the limit will be kicked. When disabled, players will be forced into spectator mode, or kicked if there are no spectator slots available.";
		case "KickReason":
			return "Kick reason gets sent to the kicked player. %wave% gets replaced with the wave limit.";
		case "KickMessage":
			return "Kick message gets sent to everyone notifying them about the kick. %name% gets replaced with player's name and %wave% with the wave limit.";
		case "SpectatorMessage":
			return "When kicking is disabled, players will be forced into spectator mode, and this message will be sent to everyone notifying them about it. %name% gets replaced with player's name and %wave% with wave limit.";
		case "SpectatorReason":
			return "When kicking is disabled, players will be forced into spectator mode and shown this message in the middle of the screen. %wave% gets replaced with wave limit.";
		case "iTextDuration":
			return "How long, in seconds,  should the spectator reason stay on the player's screen.";
		default:
			return Super.GetDescriptionText(Property);
	}
}

function MatchStarting() {
	SetTimer(UpdateFrequency, True);
}

function Timer() {
	local Controller C;
	local PlayerController PC;
	local string SteamID64;
	if (KFGameType(Level.Game).WaveNum < WaveLimit)
		return;
	if (!bPlayersSaved)
		SaveCurrentPlayers();
	for (C = Level.ControllerList; C != None; C = C.NextController) {
		PC = PlayerController(C);
		if (PC != None && PC.bIsPlayer && PC.PlayerReplicationInfo != None && !PC.PlayerReplicationInfo.bOnlySpectator && !PC.PlayerReplicationInfo.bBot && !PC.PlayerReplicationInfo.bAdmin) {
			SteamID64 = PC.PlayerReplicationInfo.SteamStatsAndAchievements.GetSteamUserID();
			if (WhiteListCheck(SteamID64))
				continue;
			if (!bKickPlayers && Level.Game.NumSpectators < Level.Game.MaxSpectators) {
				PC.BecomeSpectator();
				SendMessage(Repl(TempSpectatorMessage, "%name%", HighlightCode$PC.PlayerReplicationInfo.PlayerName$TextCode));
				PC.ClearProgressMessages();
				PC.SetProgressTime(iTextDuration);
				PC.SetProgressMessage(0, TempSpectatorReason, TextColour);
			}
			else {
				Level.Game.AccessControl.KickPlayer(PC);
				PC.ClientNetworkMessage("AC_Kicked", TempKickReason);
				SendMessage(Repl(TempKickMessage, "%name%", HighlightCode$PC.PlayerReplicationInfo.PlayerName$TextCode));
			}
		}
	}
}

function SaveCurrentPlayers() {
	local Controller C;
	local PlayerController PC;
	local string SteamID64;
	bPlayersSaved = True;
	for (C = Level.ControllerList; C != None; C = C.NextController) {
		PC = PlayerController(C);
		if (PC != None && PC.bIsPlayer && PC.PlayerReplicationInfo != None && (!PC.PlayerReplicationInfo.bOnlySpectator && !bSaveSpectators || bSaveSpectators) && !PC.PlayerReplicationInfo.bBot) {
			SteamID64 = PC.PlayerReplicationInfo.SteamStatsAndAchievements.GetSteamUserID();
			if (!WhiteListCheck(SteamID64)) {
				default.WhiteList.Insert(0, 1);
				default.WhiteList[0].SteamID64 = SteamID64;
				default.WhiteList[0].Name = PC.PlayerReplicationInfo.PlayerName;
			}
		}
	}
	SendMessage(SavedCode$PlayersSavedMessage);
}

function bool WhiteListCheck(string SteamID64) {
	local int i;
	for (i = 0; i < default.WhiteList.Length; i++)
		if (default.WhiteList[i].SteamID64 == SteamID64)
			return True;
	return False;
}

function SendMessage(string Message) {
	local controller C;
	for (C = Level.ControllerList; C != None; C = C.nextController) {
		if (C.IsA('PlayerController')) {
			if (C.PlayerReplicationInfo.PlayerName ~= "WebAdmin" && C.PlayerReplicationInfo.PlayerID == 0)
				PlayerController(C).TeamMessage(None, Repl(Repl(Message, TextCode, ""), HighlightCode, ""), 'NoLateJoins');
			else
				PlayerController(C).TeamMessage(None, Message, 'NoLateJoins');
		}
	}
}

function PostBeginPlay() {
	local GameRules GR;
	Super.PostBeginPlay();
	GR = spawn(class'NoLateJoinsGameRules');
	NoLateJoinsGameRules(GR).ParentMutator = Self;
	if (Level.Game.GameRulesModifiers == None)
		Level.Game.GameRulesModifiers = GR;
	else Level.Game.GameRulesModifiers.AddGameRules(GR);
	TextCode = class'Engine.GameInfo'.static.MakeColorCode(TextColour);
	HighlightCode = class'Engine.GameInfo'.static.MakeColorCode(HighlightColour);
	SavedCode = class'Engine.GameInfo'.static.MakeColorCode(SavedColour);
	TempKickReason = TextCode$Repl(KickReason, "%wave%", HighlightCode$WaveLimit$TextCode);
	TempKickMessage = Repl(TextCode$KickMessage, "%wave%", HighlightCode$WaveLimit$TextCode);
	TempSpectatorMessage = TextCode$Repl(SpectatorMessage, "%wave%", HighlightCode$WaveLimit$TextCode);
	TempSpectatorReason = TextCode$Repl(SpectatorReason, "%wave%", HighlightCode$WaveLimit + 1$TextCode);
}

defaultproperties {
	bSaveSpectators=False
	WaveLimit=7
	UpdateFrequency=3.0
	PlayersSavedMessage="Current players saved, late joiners won't be allowed in."
	bKickPlayers=False
	KickReason="Sorry, no joins allowed after wave %wave%. Please try again in a moment, as the team finishes the match. You can spectate the match in the meantime."
	KickMessage="%name% was kicked for joining after wave %wave%, no late joins allowed."
	iTextDuration=30
	SpectatorMessage="%name% was forced into spectator mode for joining after wave %wave%."
	SpectatorReason="Sorry, no joins allowed after wave %wave%. Please wait until the next match."
	TextColour=(B=255,G=255,R=255,A=255)
	HighlightColour=(B=0,G=0,R=255,A=255)
	SavedColour=(B=0,G=255,R=0,A=255)
	GroupName="KF-NoLateJoins"
	FriendlyName="No Late Joins"
	Description="Kicks players who join after a set wave."
}
