--- Stubs for global functions NPC scripts can define, which will be called by C++

--- Called when the NPC is added to the world.
function init() end

--- Update loop handler.
-- Called once every `scriptDelta` (as defined in *.npctype) game ticks
function main() end

--- Called when the npc has died and is about to be removed.
function die() end

--- Called after the NPC has taken damage.
--
-- @tab args Map of info about the damage, structured as:
--    {
--      sourceId = <entity id of entity that caused the damage>,
--      damage = <numeric amount of damage that was taken>,
--      sourceDamage = <numeric amount of damage that was originally dealt>,
--      sourceKind = <string kind of damage being applied, as defined in "damageKind" value in a *.projectile config>
--    }
-- Note that "sourceDamage" can be higher than "damage" if - for instance -
-- some damage was blocked by a shield.
function damage(args) end

--- Called when the NPC is interacted with.
-- Available interaction responses are:
--    "OpenCockpitInterface"
--    "SitDown"
--    "OpenCraftingInterface"
--    "OpenCookingInterface"
--    "OpenTechInterface"
--    "Teleport"
--    "OpenStreamingVideoInterface"
--    "PlayCinematic"
--    "OpenSongbookInterface"
--    "OpenNpcInterface"
--    "OpenNpcCraftingInterface"
--    "OpenTech3DPrinterDialog"
--    "ShowPopup"
--
-- @tab args Map of interaction event arguments:
--    {
--      sourceId = <Entity id of the entity interacting with this NPC>
--      sourcePosition = <The {x,y} position of the interacting entity>
--    }
--
-- @return[1] nil (no interaction response)
-- @treturn[2] string the interaction response that should be performed
-- @treturn[3] array the interaction response and configuration:
--    {
--       <interaction response string>,
--       <interaction response config table (map)>
--    }
function interact(args) end
