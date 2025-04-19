//======================================================
// Author:      Mixanik
// Version:     1.0
// Description: Simulates DeFRaG movement mechanics.
// Contact:     https://github.com/Mix-Anik/defrag-vscript
//======================================================

IncludeScript("rocket");


::DEBUG <- false;
::FButtons <- {
	IN_JUMP			= 2
	IN_DUCK			= 4
	IN_FORWARD		= 8
	IN_BACK			= 16
	IN_MOVELEFT		= 512
	IN_MOVERIGHT	= 1024
};
::FPlayer <- {
	FL_ONGROUND		= 1
};
::fFrametime <- 0.01; // 100 tick
::fMaxWishSpeed <- 260.0;
::fAccel <- 1500.0;


::SlickThink <- function()
{
	local vCurPos = self.GetOrigin();
	local vCurVel = self.GetAbsVelocity();
	local iButtons = NetProps.GetPropInt(self, "m_nButtons");
	local iPlayerFlags = self.GetFlags();
	
	if (iPlayerFlags & FPlayer.FL_ONGROUND)
	{
		self.SetAbsOrigin(Vector(vCurPos.x, vCurPos.y, vCurPos.z + 8));
	}
	
	if (iButtons & FButtons.IN_MOVELEFT ||
		iButtons & FButtons.IN_MOVERIGHT ||
		iButtons & FButtons.IN_FORWARD ||
		iButtons & FButtons.IN_BACK)
	{
		local vWishDir = GetWishDirection(self, iButtons);
		local fWishSpeed = vWishDir.Length();
		//printl(fWishSpeed);
		local newSpeed = Accelerate(vCurVel, vWishDir, fMaxWishSpeed);
		
		if (iButtons & FButtons.IN_JUMP) newSpeed.z += 50;
		
		self.SetAbsVelocity(newSpeed);
	}
	
	if (DEBUG) DebugDrawLine(vCurPos, vCurPos + vCurVel, 255, 0, 0, true, 0.1);

	return -1
}

::Accelerate <- function(vVelocity, vWishDir, fWishSpeed)
{
    local fCurSpeed = vVelocity.Dot(vWishDir);
    local fDeltaSpeed = fWishSpeed - fCurSpeed;

    if (fDeltaSpeed <= 0)
        return vVelocity;

    local fAccelSpeed = fAccel * fFrametime * fWishSpeed;
    if (fAccelSpeed > fDeltaSpeed)
        fAccelSpeed = fDeltaSpeed;

    return vVelocity + vWishDir * fAccelSpeed;
}

::GetWishDirection <- function(player, buttons)
{
    local vForward = player.GetForwardVector();
    local vRight = player.GetRightVector();
    local vDir = Vector(0, 0, 0);
	if (DEBUG) printl("before: " + vForward);
	
	if (buttons & FButtons.IN_DUCK) {
		printl("DUCK");
		vForward *= 0.25;
		printl("after: " + vForward);
	}
	
    if (buttons & FButtons.IN_FORWARD)		vDir += vForward;
    if (buttons & FButtons.IN_BACK)			vDir -= vForward;
    if (buttons & FButtons.IN_MOVERIGHT)	vDir += vRight;
    if (buttons & FButtons.IN_MOVELEFT)		vDir -= vRight;
	//printl(vDir.Length());
	vDir.Norm();

    return vDir;
}

::MovementTick <- function()
{
	local tPlayerScope = self.GetScriptScope();
	local result = -1;
	
	if (tPlayerScope.ONSLICK)
		result = SlickThink();
	
	return result;
}

function SlickStart() {
	local vCurVel = activator.GetAbsVelocity();
	activator.ValidateScriptScope();
	local tPlayerScope = activator.GetScriptScope();

	tPlayerScope.ONSLICK <- true;
	activator.SetAbsVelocity(Vector(vCurVel.x, vCurVel.y, 0));
	activator.SetGravity(0.000000001);

	AddThinkToEnt(activator, "MovementTick");
}

function SlickEnd() {
	local tPlayerScope = activator.GetScriptScope();
	
	tPlayerScope.ONSLICK <- false;
	activator.SetGravity(1);
	AddThinkToEnt(activator, null);
}

function OnGameEvent_player_spawn(params)
{
	if (Entities.FindByName(null, "falldmg") == null) {
		SpawnEntityFromTable("filter_damage_type",
		{
			targetname		= "falldmg"
			Negated			= 1
			damagetype		= 32 // DMG_FALL
		});
	}

	local player = GetPlayerFromUserID(params.userid);
	player.AcceptInput("SetDamageFilter", "falldmg", null, null);
}

__CollectGameEventCallbacks(this)
