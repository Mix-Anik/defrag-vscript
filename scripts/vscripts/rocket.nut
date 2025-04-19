::ROCKET_SPEED <- 1000.0;
::ROCKET_SPLASH_RADIUS <- 150.0;
::ROCKET_SPLASH_FORCE <- 600.0;
::EScriptRecipientFilter <- {
	RECIPIENT_FILTER_PAS_ATTENUATION		= 1
	RECIPIENT_FILTER_GLOBAL					= 5
}
::SND <- {
	SND_CHANGE_VOL	= 1,
	SND_STOP		= 4
}
PrecacheModel("models/props/de_nuke/emergency_lighta.mdl");
PrecacheModel("sprites/bluelaser1.vmt");
PrecacheScriptSound("weapons/rpg/rocket1.wav");
PrecacheScriptSound("weapons/rpg/rocketfire1.wav");


::ExplodeRocket <- function(rocket, pos, normal)
{
	local explosion = Entities.CreateByClassname("env_explosion");
	explosion.SetOrigin(pos);
	explosion.KeyValueFromString("spawnflags", "1");
    EntFireByHandle(explosion, "Explode", "", 0.0, null, null);
	explosion.Kill();
	
	local particle = SpawnEntityFromTable("info_particle_system",
	{
		origin       = pos
		angles       = QAngle(0, 0, 0)
		effect_name  = "fire_medium_02_nosmoke"
		start_active = true
	});
	EntFireByHandle(particle, "Kill", "", 0.5, null, null);
	
    local player = rocket.GetOwner();
    local vPlayerViewOrigin = player.EyePosition() + player.EyeAngles().Forward();
	local vForce = vPlayerViewOrigin - pos;
	
	if (DEBUG) {
		DebugDrawBox(vPlayerViewOrigin, Vector(-1, -1, -1), Vector(1, 1, 1), 255, 0, 0, 128, 20.0);
		DebugDrawBox(pos, Vector(-1, -1, -1), Vector(1, 1, 1), 255, 0, 0, 128, 20.0);
		DebugDrawLine(vPlayerViewOrigin, pos, 0, 255, 0, true, 20.0);
		printl(vPlayerViewOrigin + " and " + pos + " (length=" + vForce.Length() + ")")
	}
	
	if (vForce.Length() <= ROCKET_SPLASH_RADIUS) {
		vForce.Norm();
		if (DEBUG) printl("Normalized rocket force vector: " + vForce);
		player.SetAbsVelocity(player.GetAbsVelocity() + vForce * ROCKET_SPLASH_FORCE);
	}
}

::RocketMove <- function()
{
    local origin = self.GetOrigin();
	local trace = {
        start = origin,
        end = origin + self.GetForwardVector() * 10,
        ignore = self
    };
    TraceLineEx(trace);

    if (trace.hit)
    {
        ExplodeRocket(self, origin, trace.plane_normal);
		EmitSoundEx({
			sound_name	= "weapons/rpg/rocket1.wav",
			entity		= self,
			flags		= SND.SND_STOP,
			filter_type	= EScriptRecipientFilter.RECIPIENT_FILTER_GLOBAL
		});
        self.Kill();
        return;
    }

    return -1
}

::FireRocket <- function(player)
{
	local angles = player.EyeAngles();
	local rocketOrigin = player.EyePosition() + angles.Forward() * 64;
	local sRocketUID = "rocket_" + player.entindex() + "_" + Time();
	local rocket = SpawnEntityFromTable("prop_dynamic",
	{
		origin			= rocketOrigin
		targetname		= sRocketUID
		model			= "models/props/de_nuke/emergency_lighta.mdl"
	});
    rocket.SetAbsAngles(QAngle(angles.x + 90, angles.y, angles.z));
    rocket.SetMoveType(8, 0);
	rocket.SetOwner(player);
    rocket.SetAbsVelocity(angles.Forward() * ROCKET_SPEED);
	NetProps.SetPropBool(rocket, "m_bForcePurgeFixedupStrings", true)
	AddThinkToEnt(rocket, "RocketMove");
    
	local trail = SpawnEntityFromTable("env_spritetrail",
	{
		origin			= rocketOrigin
		lifetime		= 0.5
		spritename		= "sprites/bluelaser1.vmt"
		rendercolor		= "255 255 255"
		rendermode		= 5
		renderamt		= 255
		startwidth		= 32.0
		endwidth		= 4.0
	});
	trail.AcceptInput("SetParent", sRocketUID, null, null);

	EmitSoundEx({
		sound_name 		= "weapons/rpg/rocketfire1.wav",
		sound_level		= 75
		volume			= 0.6
		origin 			= rocketOrigin
		entity			= player
		filter_type		= EScriptRecipientFilter.RECIPIENT_FILTER_PAS_ATTENUATION
	});
	// TODO: how do i delay this or change volume after some time?
	EmitSoundEx({
		sound_name 		= "weapons/rpg/rocket1.wav",
		sound_level		= 75
		volume			= 1.0
		origin 			= rocketOrigin
		entity			= rocket
		filter_type		= EScriptRecipientFilter.RECIPIENT_FILTER_PAS_ATTENUATION
	});
}

function CheckWeaponFire()
{
	local tWeapScope = self.GetScriptScope();
	local cur_ammo = NetProps.GetPropInt(self, "m_iClip1");

	if (tWeapScope.last_ammo > cur_ammo)
	{
		local owner = self.GetOwner()
		if (owner) FireRocket(owner);
	}
	
	tWeapScope.last_ammo = cur_ammo
	
	return -1
}

function OnGameEvent_item_pickup(params)
{
	if (params.item == "glock") {
		local player = GetPlayerFromUserID(params.userid);
		local weapon = NetProps.GetPropEntity(player, "m_hActiveWeapon");
		
		weapon.ValidateScriptScope();
		local tWeapScope = weapon.GetScriptScope();
		tWeapScope.last_ammo <- null;
		tWeapScope.CheckWeaponFire <- CheckWeaponFire;
		
		AddThinkToEnt(weapon, "CheckWeaponFire");
	}
}
