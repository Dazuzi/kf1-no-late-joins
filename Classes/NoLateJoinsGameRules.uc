class NoLateJoinsGameRules extends GameRules;

var NoLateJoins ParentMutator;

function bool CheckEndGame(PlayerReplicationInfo Winner, string Reason) {
	ParentMutator.SetTimer(0, False);
	if (NextGameRules != None)
		return NextGameRules.CheckEndGame(Winner, Reason);
	return True;
}