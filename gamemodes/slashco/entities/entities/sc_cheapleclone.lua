AddCSLuaFile()

-- Shared stuff
ENT.Base = "base_nextbot"
ENT.Type = "nextbot"
ENT.PrintName = "SLASHER"
ENT.PingType = "SLASHER"
ENT.AutomaticFrameAdvance = true

-- Server only stuff
local model = "models/humans/group01/male_cheaple.mdl"

function ENT:UpdateTransmitState()
	return TRANSMIT_PVS
end

-- Server only stuff
if SERVER then
	function ENT:Initialize()
		self:SetModel(model)
		self:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
	end

	-- This is done to prevent warnings and shit in the console due to this entity being a next bot
	-- Will be used in the future tho
	function ENT:RunBehaviour()
		local sequence = "idle"
		while true do
			self:PlaySequenceAndWait(sequence)

			coroutine.yield()
		end
	end
end