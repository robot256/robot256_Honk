
-- Interface to add custom sounds for specific entities
local function set_custom_honks(entity_name, honk_single_name, honk_double_name)
  --if settings.global["honk-allow-custom-sounds"].value and global.custom_honks then
    global.custom_honks["honk-single"][entity_name] = honk_single_name
    global.custom_honks["honk-double"][entity_name] = honk_double_name
  --end
end
remote.add_interface('Honk', {set_custom_honks = set_custom_honks})


local function addCustomHonks()
  -- Add steam trains with MU versions
  for _,name in pairs(steam_locos) do
    if game.entity_prototypes[name] then
      set_custom_honks(name, "honk-single-steam-train", "honk-double-steam-train")
    end
    if game.entity_prototypes[name.."-mu"] then
      set_custom_honks(name.."-mu", "honk-single-steam-train", "honk-double-steam-train")
    end
  end
  
  -- Add boat and cargo ship
  for _,name in pairs(boat_locos) do
    if game.entity_prototypes[name] then
      set_custom_honks(name, "honk-single-boat", "honk-double-boat")
    end
  end
  for _,name in pairs(ship_locos) do
    if game.entity_prototypes[name] then
      set_custom_honks("cargo_ship_engine", "honk-single-ship", "honk-double-ship")
    end
  end
  
  -- Disable default honks by setting them to "none"
  local default_single = nil
  local default_double = nil
  
  set_custom_honks("default", default_single, default_double)
end

local function buildHonks()
  global = global or {}
  -- build a table in the form global.honks[current_state][previous_state] = sound to play
  global.honks = { }
  if settings.global["honk-sound-start"].value ~= "none" then
    global.honks[defines.train_state.on_the_path] = {
      -- play start honk if previous state was one of the below
      [defines.train_state.path_lost] = settings.global["honk-sound-start"].value,
      [defines.train_state.no_schedule] = settings.global["honk-sound-start"].value,
      [defines.train_state.no_path] = settings.global["honk-sound-start"].value,
      [defines.train_state.arrive_signal] = nil,
      [defines.train_state.wait_signal] = settings.global["honk-sound-start"].value,
      [defines.train_state.arrive_station] = nil,
      [defines.train_state.wait_station] = settings.global["honk-sound-start"].value,
      [defines.train_state.manual_control_stop] = settings.global["honk-sound-start"].value,
      [defines.train_state.manual_control] = settings.global["honk-sound-start"].value
    }
    -- definition for auto-selected keypress starting honk
    global.honks.manual_start = settings.global["honk-sound-start"].value
  end
  if settings.global["honk-sound-lost"].value ~= "none" then
    global.honks[defines.train_state.path_lost] = {
      -- play lost honk if previous state was one of the below
      [defines.train_state.on_the_path] = settings.global["honk-sound-lost"].value,
      [defines.train_state.arrive_signal] = settings.global["honk-sound-lost"].value,
      [defines.train_state.arrive_station] = settings.global["honk-sound-lost"].value
    }
    global.honks[defines.train_state.manual_control_stop] = {
      -- play lost honk if previous state was one of the below
      [defines.train_state.on_the_path] = settings.global["honk-sound-lost"].value,
      [defines.train_state.arrive_signal] = settings.global["honk-sound-lost"].value,
      [defines.train_state.arrive_station] = settings.global["honk-sound-lost"].value
    }
    -- definition for auto-selected keypress braking honk
    global.honks.manual_stop = settings.global["honk-sound-lost"].value
  end
  if settings.global["honk-sound-station"].value ~= "none" then
    global.honks[defines.train_state.arrive_station] = {
      -- play station honk only if previous state was normal pathing
      [defines.train_state.on_the_path] = settings.global["honk-sound-station"].value
    }
    -- fallback definition for auto-selected keypress braking honk
    global.honks.manual_stop = global.honks.manual_stop or settings.global["honk-sound-station"].value
  end
  if settings.global["honk-sound-signal"].value ~= "none" then
    global.honks[defines.train_state.arrive_signal] = {
      -- play signal honk only if previous state was normal pathing
      [defines.train_state.on_the_path] = settings.global["honk-sound-signal"].value
    }
    -- second fallback definition for auto-selected keypress braking honk
    global.honks.manual_stop = global.honks.manual_stop or settings.global["honk-sound-signal"].value
  end
  if settings.global["honk-sound-manual"].value == "auto" then
    global.honks.auto = true
  elseif settings.global["honk-sound-manual"].value ~= "none" then
    -- not auto, use this value
    global.honks.manual = settings.global["honk-sound-manual"].value
  end
  if settings.global["honk-sound-manual-alt"].value ~= "none" then
    global.honks.alt = settings.global["honk-sound-manual-alt"].value
  end
  -- game.print("Honks (re)built")

  -- List of custom honks
  -- Stored as a dictionary of [default_honk_type][entity_name] -> custom_honk_name
  -- If custom_honk_name is "" or "none", no sound will be played
  -- If custom_honk_name is set to nil or an invalid sound, default sound will be played
  -- If an entry exists for entity_name="default", it will override the standard default sounds
  global.custom_honks = {["honk-single"]={}, ["honk-double"]={}}
  
  -- Populate list of custom sounds based on installed mods
  addCustomHonks()
  
  log("Custom Honk Library updated:\n"..serpent.block(global.custom_honks))
end

script.on_configuration_changed(buildHonks)
script.on_init(buildHonks)

-- Detect setting changes during session
script.on_event(defines.events.on_runtime_mod_setting_changed, buildHonks)

function playSoundAtEntity(sound, entity)
  -- Check if there is a custom sound for this entity, or if a custom default sound has been set
  if global.custom_honks and global.custom_honks[sound] then
    local custom_sound = global.custom_honks[sound][entity.name]
    local custom_default = global.custom_honks[sound]["default"]
    if custom_sound ~= nil then
      if custom_sound == "" or custom_sound == "none" then
        -- This sound has been explicitly disabled for this entity
        sound = nil
      elseif game.is_valid_sound_path(custom_sound) then
        sound = custom_sound
      else
        -- Invalid sound, use custom default
        custom_sound = nil
      end
    end
    if custom_sound == nil then
      if custom_default ~= nil then
        if custom_default == "" or custom_default == "none" then
          -- This sound has been explicitly disabled for this entity
          sound = nil
        elseif game.is_valid_sound_path(custom_default) then
          sound = custom_default
        end
      end
    end
  end

  -- Play sound
  if sound then
    entity.surface.play_sound{path = sound, position = entity.position}
  end
end

-- Find loco(s) to emit honks in train
-- A stationary train will honk at front- and rear-facing locos if both are present
function findLocoToHonk(sound, train)
  if train.speed >= 0 and #train.locomotives.front_movers > 0 then
    playSoundAtEntity(sound, train.locomotives.front_movers[1])
  end
  if train.speed <= 0 and #train.locomotives.back_movers > 0 then
    playSoundAtEntity(sound, train.locomotives.back_movers[#train.locomotives.back_movers])
  end
end

-- Manual honk
script.on_event("honk", function(event)
  local player = game.players[event.player_index]
  if player.vehicle and
  player.vehicle.type == "locomotive" then
    if global.honks.auto then -- choose honk based on whether or not train is moving
      if player.vehicle.train.speed == 0 then
        if global.honks.manual_start then
          playSoundAtEntity(global.honks.manual_start, player.vehicle)
        end
      else
        if global.honks.manual_stop then
          playSoundAtEntity(global.honks.manual_stop, player.vehicle)
        end
      end
    else -- not automatic mode, play the player-selected sound
      if global.honks.manual then
        playSoundAtEntity(global.honks.manual, player.vehicle)
      end
    end
  end
end)

-- Manual alt honk
script.on_event("honk-alt", function(event)
  local player = game.players[event.player_index]
  if player.vehicle and
  player.vehicle.type == "locomotive" and
  global.honks.alt then
    playSoundAtEntity(global.honks.alt, player.vehicle)
  end
end)


-- Toggle manual/automatic control
script.on_event("toggle-train-control", function(event)
  local player = game.players[event.player_index]
  if player.vehicle then
    if player.vehicle.type == "locomotive" then
      player.vehicle.train.manual_mode = not player.vehicle.train.manual_mode
      if player.vehicle.train.manual_mode then
        player.create_local_flying_text{text={"gui-train.manual-mode"}, position=player.vehicle.position}
      else
        player.create_local_flying_text{text={"gui-train.automatic-mode"}, position=player.vehicle.position}
      end
    end
  end
end)

script.on_event(defines.events.on_train_changed_state, function(event)
  if global.honks[event.train.state] and
  global.honks[event.train.state][event.old_state] then
    findLocoToHonk(global.honks[event.train.state][event.old_state], event.train)
  end
end)

------------------------------------------------------------------------------------
--                    FIND LOCAL VARIABLES THAT ARE USED GLOBALLY                 --
--                              (Thanks to eradicator!)                           --
------------------------------------------------------------------------------------
setmetatable(_ENV,{
  __newindex=function (self,key,value) --locked_global_write
    error('\n\n[ER Global Lock] Forbidden global *write*:\n'
      .. serpent.line{key=key or '<nil>',value=value or '<nil>'}..'\n')
    end,
  __index   =function (self,key) --locked_global_read
    error('\n\n[ER Global Lock] Forbidden global *read*:\n'
      .. serpent.line{key=key or '<nil>'}..'\n')
    end ,
  })
