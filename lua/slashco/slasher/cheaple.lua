--[[
2011x INFO:

CREDITS:
krazy: i made him
Enzobezo: Chase + Enraged chase theme (https://www.youtube.com/watch?v=UgjKOcLUexA)

]]

-- Enable to see a bunch of debug information that was used during this slasher's development
DEBUG = true

local SLASHER = {}

-- Stock SlashCo parameters
SLASHER.Name = "cheaple_name"

SLASHER.Class = SlashCo.SlasherClass.Unknown
SLASHER.DangerLevel = SlashCo.DangerLevel.Unknown
SLASHER.IsSelectable = true
SLASHER.Model = "models/humans/group01/male_cheaple.mdl"
SLASHER.GasCanMod = 0
SLASHER.KillDelay = 0
SLASHER.ProwlSpeed = 300
SLASHER.ChaseSpeed = 305
SLASHER.Perception = 0.9
SLASHER.Eyesight = 3
SLASHER.KillDistance = 100

SLASHER.JumpscareDuration = 1
SLASHER.ChaseMusic = "slashco/slasher/cheaple/chase.mp3"
SLASHER.ChaseRange = 300
SLASHER.ChaseFOV = 90
SLASHER.ChaseRadius = math.cos(math.rad(SLASHER.ChaseFOV))

SLASHER.Description = "cheaple_desc"
SLASHER.ProTip = "cheaple_tip"
SLASHER.SpeedRating = "★★★☆☆"
SLASHER.EyeRating = "★★☆☆☆"
SLASHER.DiffRating = "★★★☆☆"
SLASHER.StunTime = 1

SLASHER.Config = {
	-- Abilities
	-- Every ability has a shared globalCooldown variable.

	-- Left Click (normal attack)
	primaryFire = {
		cooldown = 1,
		globalCooldown = 1,
	},

	-- Right Click
	secondaryFire = {
		cooldown = 1,
		globalCooldown = 1,
	},

	-- R
	mainAbility = {
		cooldown = 1,
		globalCooldown = 1,
	},

	-- F
	specialAbility = {
		cooldown = 1,
		globalCooldown = 1,

		cloneEntity = "sc_cheapleclone"
	}
}

--[[
	A bunch of helper functions used here and there, will remove some that are only used once in the future.
]]

-- Spawn the clones used to teleport (need to add Stage5 Behavior)
function SLASHER.spawnTpClone(pos, ang)
	local clone = ents.Create(SLASHER.Config.specialAbility.cloneEntity)

	clone:SetPos(pos)
	clone:SetAngles(ang or Angle(0,math.random(360),0))

	clone:Spawn()
	clone:Activate()
end

-- Used for damaging a player
function SLASHER.damagePlayer(slasher, victim, damage, knockback)
	if victim:IsValid() and victim:IsPlayer() then
		-- If the victim is one hit, we jumpscare them instead (need to add jumps)
		-- Have to make my own jumpscare logic cause stock one wouldn't work
		if victim:Health() <= damage then
			return true
		end

		local effect = EffectData()
		local dmg = DamageInfo()

		dmg:SetDamageType(DMG_SLASH)
		dmg:SetAttacker(slasher)
		dmg:SetInflictor(slasher)
		dmg:SetDamage(damage)
		victim:TakeDamageInfo(dmg)

		-- We do this cause set damage force doesn't work for some reason
		victim:SetVelocity(slasher:GetAimVector() * knockback)

		effect:SetOrigin(victim:GetPos() + Vector(0,0,40))
		util.Effect("BloodImpact", effect)
		return true
	end
	return false
end

--[[
	Stock SlashCo functions
]]
-- Happens when the slasher first spawns
function SLASHER.OnSpawn(slasher)
	slasher:SetEyeSight(SLASHER.Eyesight)
	slasher:SetPerception(SLASHER.Perception)

	-- Timer set to happen infinitely, timer.IsPaused isnt available yet so we just do the comparing init
	-- Need a way to pause this time when there is no 2011x, i can't find a function for it though, help
	--[[ timer.Create("passiveClones" .. slasher:EntIndex(),SLASHER.Config.Clones.spawnTimer, -1, function()
		if not IsValid(slasher) then return end
		if (#ents.FindByClass(SLASHER.Config.specialAbility.cloneEntity) >= SLASHER.Config.Clones.maxAmount) then return end

		SLASHER.spawnTpClone(SlashCo.RandomPosLocator())
	end) ]]
end

-- This happens on every tick, lord have mercy this shit sucks
-- Sorry to whoever wants to take a look into this
function SLASHER.OnTickBehaviour(slasher)
	-- Automatic Chase logic
	-- Just starts the chase automatically when a survivor is within the range and FOV of the slasher
	local foundPlayers = slasher:FindPlayersInView(SLASHER.ChaseRange, SLASHER.ChaseRadius, false)
	for _, chasePlayer in ipairs(foundPlayers) do
		if IsValid(chasePlayer) and chasePlayer:Team() == TEAM_SURVIVOR and not slasher:GetNW2Bool("InSlasherChaseMode") then
			SlashCo.StartChaseMode(slasher, true)
		end
	end

	-- Cooldown Ability logic
	-- Used for a proper cooldown system
	-- Will update this to no longer use networked variables in the future, unfortunately rn I'm too fucking lazy

	if (slasher:GetNW2Float("primaryFireCooldown") > 0) then slasher:SetNW2Float("primaryFireCooldown", slasher:GetNW2Float("primaryFireCooldown") - FrameTime()) end
	if (slasher:GetNW2Float("secondaryFireCooldown") > 0) then slasher:SetNW2Float("secondaryFireCooldown", slasher:GetNW2Float("secondaryFireCooldown") - FrameTime()) end
	if (slasher:GetNW2Float("mainAbilityCooldown") > 0) then slasher:SetNW2Float("mainAbilityCooldown", slasher:GetNW2Float("mainAbilityCooldown") - FrameTime()) end
	if (slasher:GetNW2Float("specialAbilityCooldown") > 0) then slasher:SetNW2Float("specialAbilityCooldown", slasher:GetNW2Float("specialAbilityCooldown") - FrameTime()) end
	if (slasher:GetNW2Float("globalCooldown") > 0) then slasher:SetNW2Float("globalCooldown", slasher:GetNW2Float("globalCooldown") - FrameTime()) end

	-- Ability use logic
	-- Basically this dictate at one point can an ability is allowed to be used

	-- This is used to detect when the slasher is looking at a clone
	local traceAim = util.TraceLine({
		start = slasher:EyePos(),
		endpos = slasher:EyePos() + slasher:GetAimVector() * 2048,
		ignoreworld = true,
		filter = { SLASHER.Config.specialAbility.cloneEntity },
		whitelist = true
	}).Hit

	local onGlobalCooldown = slasher:GetNW2Float("globalCooldown") > 0

	slasher:SetNW2Bool("canPrimaryFire",
		slasher:GetNW2Float("primaryFireCooldown") <= 0
		and not onGlobalCooldown
	)

	slasher:SetNW2Bool("canSecondaryFire",
		slasher:GetNW2Float("secondaryFireCooldown") <= 0
		and not onGlobalCooldown
	)

	slasher:SetNW2Bool("canMainAbility",
		slasher:GetNW2Float("mainAbilityCooldown") <= 0
		and not onGlobalCooldown
	)

	slasher:SetNW2Bool("canSpecialAbility",
		slasher:GetNW2Float("specialAbilityCooldown") <= 0
		and traceAim
		and not onGlobalCooldown
	)
end

--[[
    Seperated the abilities themselves into their own file cause why not.
]]

-- Left click
function SLASHER.OnPrimaryFire(slasher)
	if not IsValid(slasher) then return end
	if not slasher:GetNW2Bool("canPrimaryFire") then return end

	slasher:SetNW2Float("primaryFireCooldown", SLASHER.Config.primaryFire.cooldown)
	slasher:SetNW2Float("globalCooldown", SLASHER.Config.primaryFire.globalCooldown or 0)
end

-- Right click
function SLASHER.OnSecondaryFire(slasher)
	if not slasher:GetNW2Bool("canSecondaryFire") then return end

	slasher:SetNW2Float("secondaryFireCooldown", SLASHER.Config.secondaryFire.cooldown)
	slasher:SetNW2Float("globalCooldown", SLASHER.Config.secondaryFire.globalCooldown or 0)
end

-- R
function SLASHER.OnMainAbilityFire(slasher)
	if not slasher:GetNW2Bool("canMainAbility") then return end

	slasher:SetNW2Float("mainAbilityCooldown", SLASHER.Config.mainAbility.cooldown)
	slasher:SetNW2Float("globalCooldown", SLASHER.Config.mainAbility.globalCooldown or 0)
end

-- F
function SLASHER.OnSpecialAbilityFire(slasher)
	if not slasher:GetNW2Bool("canSpecialAbility") then return end

	local trace = util.TraceLine(
		{
			start = slasher:EyePos(),
			endpos = slasher:EyePos() + slasher:GetAimVector() * 64,
			ignoreworld = true,
			filter = { SLASHER.Config.specialAbility.cloneEntity },
			whitelist = true
		}
	)

	-- We swap em
	if (trace.Hit and trace.Entity:IsValid()) then

		local entity = trace.Entity

		if not isValid(entity) then
			return false
		end

		local tempPos, tempAngle = slasher:GetPos(), slasher:GetAngles()

		slasher:SetPos(trace.Entity:GetPos())
		slasher:SetEyeAngles(trace.Entity:GetAngles())

		entity:SetPos(tempPos)
		entity:SetAngles(tempAngle)

		slasher:SetNW2Float("specialAbilityCooldown", SLASHER.Config.specialAbility.cooldown)
		slasher:SetNW2Float("globalCooldown", SLASHER.Config.specialAbility.globalCooldown)
		return true
	end
end

-- Animator function, will be finished when animations are done
function SLASHER.Animator(ply)
	local stunned = ply:GetNW2Bool("stunned")

	if not stunned then
		ply.anim_antispam = false
	end

	if ply:IsOnGround() then
		ply.CalcIdeal = ACT_HL2MP_WALK
		ply.CalcSeqOverride = ply:LookupSequence("run")

		if ply:GetVelocity():LengthSqr() == 0 then
			ply.CalcIdeal = ACT_IDLE
		ply.CalcSeqOverride = ply:LookupSequence("idle")
		end
	else
		ply.CalcSeqOverride = ply:LookupSequence("float")
	end

	if stunned then
		ply.CalcSeqOverride = ply:LookupSequence("stunned")
		if not ply.anim_antispam then
			ply:SetCycle(0)
			ply.anim_antispam = true
		end
	end

	return ply.CalcIdeal, ply.CalcSeqOverride
end

-- The stun function basically, added stuntime variable
function SLASHER.OnHitByPocketSand(slasher, ply, stunTime)
	slasher:SetNW2Bool("stunned", true)
	slasher:Freeze(true)

	stunTime = stunTime or SLASHER.StunTime

	slasher:SetNW2Float("globalCooldown", stun)

	timer.Simple(stun, function()
		if not IsValid(slasher) then return end

		slasher:SetNW2Bool("stunned", false)
		slasher:Freeze(false)
	end)
end

SLASHER.OnHitByBeerKeg = function(slasher) SLASHER.OnHitByPocketSand(slasher, nil) end
SLASHER.OnHitByTeslaCoil = function(slasher) SLASHER.OnHitByPocketSand(slasher, nil) end

function SLASHER.OnPlayerDeath(slasher, victim)
	timer.Simple(1, function()
		SlashCo.AudioSystem.PlaySound({
			soundPath = "slashco/slasher/2011x/dylan_laugh.mp3",
			identifier = "2011xLaugh" .. slasher:EntIndex(),
			minDistance = 5000,
			maxDistance = 1000,
			entity = slasher,
			volume = 0.5,
			fadeIn = 0,
		})
	end)
end

-- Function used for when the slasher should be in third person (the return is the state, so if you return true they're in thirdperson)
function SLASHER.Thirdperson(ply)
	return ply:GetNW2Bool("stunned")
end

-- The footsteps, will be finished eventually lmfao
function SLASHER.Footstep(ply)
	return true
end

--[[
Will be done later

function SLASHER.OnBalanceForPlayers(totalSurvivors, additionalSurvivors)
	local SO = SlashCo.CurRound.OfferingData.Singularity

	-- For every 5 additional or missing survivors we increase/decrease by 1 second.
	SLASHER.CooldownReduction = math.max((SO * 4) + (0.2 * additionalSurvivors), 0) -- math.max so we don't go below 0

	if additionalSurvivors > 0 then
		SLASHER.ProwlSpeed = 200 + (3 * additionalSurvivors)
		SLASHER.ChaseSpeed = 325 + (0.5 * additionalSurvivors)
		SLASHER.KillDistance = 150 + (2 * additionalSurvivors)
	end
end
]]

-- This will be used to highlight players close enough to a clone, thank you very much Xerk
function SLASHER.PreDrawHalos(slasher)
	SlashCo.DrawHalo("sc_cheapleclone", Color(255,0,0), nil, true)
end

-- For server stuff
if SERVER then
	hook.Add( "StartCommand", "MouseWheel", function( ply, cmd )
		if ply:Team() ~= TEAM_SLASHER or ply:GetNWString("Slasher") ~= "2011x" then return end
		if ( cmd:GetMouseWheel() ~= 0) then

			ply:SetNWInt("2011xCurFakeItemSelection", math.Clamp(ply:GetNWInt("2011xCurFakeItemSelection") + -cmd:GetMouseWheel(), 1, #SLASHER.Config.FakeItem.spawnList))
		end

		if (ply:GetNW2Bool("2011xCharging")) then
			cmd:ClearMovement()
		end
	end)

-- For client stuff, this goes on EVERY client, watch out for that, use LocalPlayer() if you wanna check for stuff
elseif CLIENT then
	local iconTable = {
	}

	function SLASHER.InitHud(_, hud)
		hud:SetTitle(SLASHER.Name)
		hud:SetCrosshairEnabled(true)
		hud:SetCrosshairAlpha(255)
		hud:SetCrosshairSpin(0)
		hud:SetCrosshairTighten(5)
		hud:SetCrosshairProngs(4)

		hud:TieCrosshair({
			"canSpecialAbility",
			InvertOutput = true,
			IsOr = true
		}, {
			TightenOn = 20,
			TightenOff = 0
		})

		-- Control Stuff
		-- This was made to make creating the controls and editing them easier for the cooldown system
		-- Do NOT make this a hash table, otherwise you won't be able to control the order in the hud
		local handleCooldowns = {
			{
				key = "F",
				controlName = "cheaple_teleport",
				netVarCD = "specialAbilityCooldown",
				netVarTie = "canSpecialAbility",
				icon = iconTable.specialAbility,
			},
			{
				key = "R",
				controlName = "cheaple_lookatme",
				netVarCD = "mainAbilityCooldown",
				netVarTie = "canMainAbility",
				icon = iconTable.mainAbility,
			},
			{
				key = "RMB",
				controlName = "start chasing",
				netVarCD = "secondaryFireCooldown",
				netVarTie = "CanChase",
				icon = "chase",
			},
			{
				key = "LMB",
				controlName = "kill survivor",
				netVarCD = "primaryFireCooldown",
				netVarTie = "canPrimaryFire",
				icon = iconTable.primaryFire,
			},
		}

		for _, control in pairs(handleCooldowns) do
			hud:AddControl(control.key, "", control.icon)
			hud:TieControl(control.key, control.netVarTie, false, true, nil)
		end

		local slasher = GameData.LocalPlayer

		-- This is mainly used to update the hud for the cooldowns

		function hud.AlsoThink()
			for _, control in ipairs(handleCooldowns) do
				local cooldown = math.max(slasher:GetNW2Float(control.netVarCD, 0), slasher:GetNW2Float("globalCooldown", 0))

				hud:SetControlText(control.key, (cooldown <= 0) and SlashCo.LangTable[control.controlName] or string.format( "[ %.1f ] %s", cooldown, SlashCo.LangTable[control.controlName]))
			end
		end
	end
end

SlashCo.RegisterSlasher(SLASHER, "Cheaple")