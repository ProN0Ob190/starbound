--- Stubs for global functions monster scripts can define, which will be called by C++

--- Called (once) when the monster is added to the world.
--
-- Note that the monster's position may not yet be valid.
function init() end

--- Update loop handler, called once every scriptDelta (defined in *.monstertype) ticks
function main() end

--- Called when shouldDie has returned true and the monster and is about to be removed from the world
function die() end

--- Called after the NPC has taken damage
--
-- @tab args Map of info about the damage, structured as:
--    {
--      sourceId = <entity id of entity that caused the damage>,
--      damage = <numeric amount of damage that was taken>,
--      sourceDamage = <numeric amount of damage that was originally dealt>,
--      sourceKind = <string kind of damage being applied, as defined in "damageKind" value in a *.projectile config>
--    }
-- Note that "sourceDamage" can be higher than "damage" if - for
-- instance - some damage was blocked by a shield.
function damage(args) end

--- Called each update to determine if the monster should die.
--
-- If not defined in the monster's lua, will default to returning true when
-- the monster's health has been depleted.
--
-- @treturn bool true if the monster can die, false to keep the monster alive
function shouldDie() end
