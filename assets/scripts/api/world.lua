--- Stubs for world.* callbacks defined in C++.
--
-- DO NOT INCLUDE this file in your scripts, it is for documentation purposes only.
--
world = {
  --- Gets the type and level of liquid at the given position
  --
  -- @param position The {x,y} position to check.
  --
  -- @return null if no liquid is present at the given location, or a table
  --          (array) of { <liquid id>, <liquid level> } where liquid id can be:
  --            1 -> water
  --            2 -> endless water
  --            3 -> lava
  --            4 -> acid
  --            5 -> endless lava
  --            6 -> tentacle juice
  --            7 -> tar
  liquidAt = function(position) end,

  --- Creates liquid at the given location
  --
  -- @param position The {x,y} position to place the liquid at
  -- @param liquidId The numeric (integer) liquid type to spawn - see return
  --        values of world.liquidAt for valid options.
  -- @param quantity The amount of liquid to spawn.
  --
  -- @return true if the requested liquid was spawned, false otherwise
  spawnLiquid = function(position, liquidId, quantity) end,

  --- Removes liquid at the given location
  --
  -- @param position The {x,y} position to remove liquid from
  --
  -- @return nil if there was no liquid at the given position or the liquid
  --          could not be removed, a table (array) of { <liquidId>, <liquidLevel> }
  --          if the liquid was removed
  destroyLiquid = function(position) end,

  --- Places an object at the given position
  --
  -- @param objectName Name of object to spawn, as specified in an *.object file
  -- @param position { x, y } anchor position of the object
  -- @param direction (optional) -1 for Left, 1 for Right (defaults to Right)
  -- @param config (optional) Additional table (hash) of configuration options
  --        that will be merged in with the final object configuration.
  placeObject = function(objectName, position, direction, config) end,

  --- Removes the given object from the world
  -- Note that this cannot currently be called from tech.
  --
  -- @param entityId The id of an object entity to smash
  -- @param smash (optional) If true, object will be smashed - otherwise object
  --              will just be broken. Defaults to false.
  --
  -- @return true if the given entity exists and is an object, false otherwise
  breakObject = function(entityId, smash) end,

  --- Spawns an item drop at the given position
  --
  -- @param objectName Name of object to spawn, as specified in an *.object file
  -- @param spawnPosition World position { x, y } to spawn item at
  -- @param count (optional) Number of items to spawn (stacked), defaults to 1.
  -- @param config (optional) Table (hash) of additional configuration values
  --               that will be merged into the final object configuration.
  spawnItem = function(objectName, spawnPosition, count, config) end,

  --- Spawns a monster at the specified location with the corresponding flags
  --
  -- @param type Monster type as specified in a .monstertype file
  -- @param spawnPosition {x,y} in world coordinates.
  -- @param config (optional) configuration table (hash) that will be merged
  --               into the final monster configuration built from the .monstertype
  --
  -- @return (int) entity id of the spawned monster
  spawnMonster = function(type, spawnPosition, config) end,

  --- Spawns an NPC at the specified location with the corresponding flags
  --
  -- @param spawnPosition {x,y} in world coordinates.
  -- @param species name of the species of the NPC as defined by the "kind"
  --        value in a *.species file.
  -- @param type The type of npc to spawn, as defined by the "type" value in a
  --        *.npctype file
  -- @param level The level of the npc to spawn
  -- @param seed (optional)
  -- @param config (optional) Configuration options that will be merged into
  --        the final configuration for the NPC.
  --
  -- @return (int) entity id of the spawned npc
  spawnNpc = function(spawnPosition, species, type, level, seed, config) end,

  --- Spawns a projectile at the given location
  --
  -- @param projectileName The (string) name of a projectile, as specified in a *.projectile file
  -- @param spawnPosition  {x,y} in world coordinates of where to spawn.
  -- @param sourceEntityId (optional) Entity id that will be set as the source of the projectile
  -- @param projectileDirection 2-vector direction for projectile to travel
  -- @param trackSourceEntity If true, projectile position will be relative to source entity position (even if the source entity moves)
  -- @param config Additional config options that will be merged in to the projectile configuration
  --
  -- @return (int) entity id of the spawned projectile
  spawnProjectile = function(projectileName, spawnPosition, sourceEntityId, projectileDirection, trackSourceEntity, config) end,

  --- Gets the epoch time of the currently active planet
  --
  -- @return Time since the epoch start (day zero)
  time = function(...) end,

  --- Gets the current day
  --
  -- @return Days since the epoch start (day zero)
  day = function(...) end,

  --- Gets the time of day, based on the current planet's day length
  --
  -- @return Time of day as a ratio, ranging from 0.0 to 1.0
  timeOfDay = function() end,

  --- Gets info about the current world
  --
  -- @return nil if on a ship, or a table (hash) with the following keys:
  --          name - friendly name of the world, e.g.: "Alpha Iota Cnc 6335 IV b"
  --          handle - world identifier string, e.g.: "alpha:63052862:92521378:-8389600:9:7"
  --          sector - name of the sector the world is in, e.g.: "alpha"
  info = function() end,

  --- Gets the general type of an item
  --
  -- @param itemDescriptor Descriptor of an item, could be a string (e.g.
  --        an objectName value from a *.object config file) or a descriptor
  --        as listed in a blueprint list (e.g. { "item" : "copperarmorhead" })
  --
  -- @return (string) Item type name, mapped from config file type as:
  --    *.item            -> "generic"
  --    *.matitem         -> "material"
  --    *.miningtool      -> "miningtool"
  --    *.flashlight      -> "flashlight"
  --    *.wiretool        -> "wiretool"
  --    *.beamaxe         -> "beamminingtool"
  --	  *.tillingtool     -> "tillingtool"
  --	  *.painttool       -> "paintingbeamtool"
  --	  *.gun             -> "gun"
  --	  *.sword           -> "sword"
  --	  *.shield          -> "shield"
  --	  *.harvestingtool  -> "harvestingtool"
  --	  *.head            -> "headarmor"
  --	  *.chest           -> "chestarmor"
  --	  *.legs            -> "legsarmor"
  --	  *.back            -> "backarmor"
  --	  *.coinitem        -> "coin"
  --	  *.consumable      -> "consumable"
  --	  *.blueprint       -> "blueprint"
  --	  *.codexitem       -> "codex"
  --	  *.techitem        -> "techitem"
  --	  *.instrument      -> "instrument"
  --	  *.grapplinghook   -> "grapplinghook"
  --	  *.thrownitem      -> "thrownitem"
  --	  *.celestial       -> "celestialitem"
  itemType = function(itemDescriptor) end,

  --- Log text to the starbound.log file
  --
  -- @param format A string to log, or a format specifier string.
  -- @param ... Arguments that will be used if format is a format specifier
  --            string. A maximum of 4 arguments are supported.
  --
  -- @return nil
  logInfo = function(format, ...) end,

  --- Render a point that can be viewed when /debug is enabled.
  -- Note that scripted entities are generally not updated every tick, so this
  -- point may flicker if the entity's scriptDelta is greater than 1.
  --
  -- @param position The {x,y} position to render the point at
  -- @param color The color of the point as a string (e.g. "red") or as a table
  --        (array) of { r, g, b } or { r, g, b, a }
  --
  -- @return nil
  debugPoint = function(position, color) end,

  --- Render a line that can be viewed when /debug is enabled.
  -- Note that scripted entities are generally not updated every tick, so this
  -- line may flicker if the entity's scriptDelta is greater than 1.
  --
  -- @param startPoint The {x,y} position of the line's starting point
  -- @param endPoint The {x,y} position of the line's ending point
  -- @param color The color of the line as a string (e.g. "red") or as a table
  --        (array) of { r, g, b } or { r, g, b, a }
  --
  -- @return nil
  debugLine = function(startPoint, endPoint, color) end,

  --- Render text that can be viewed when /debug is enabled.
  -- Note that scripted entities are generally not updated every tick, so this
  -- text may flicker if the entity's scriptDelta is greater than 1.
  --
  -- @param format A string of text, or format specifier string.
  -- @param ... Arguments used if the format param is a format specifier
  --        string. A maximum of 3 arguments are supported.
  -- @param position The {x,y} position to render the text at
  -- @param color The color of the text as a string (e.g. "red") or as a table
  --        (array) of { r, g, b } or { r, g, b, a }
  --
  -- @return nil
  debugText = function(format, ..., position, color) end,
}
