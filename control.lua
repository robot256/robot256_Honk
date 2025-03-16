local function buildHonkGroup(groupname)
  -- build a table in the form honkgroup[current_state][previous_state] = sound to play
  local group = {}
  
  group.disabled = false

  local start = settings.global["honk-sound-start-"..groupname].value
  if start ~= "none" and helpers.is_valid_sound_path(start) then
    group[defines.train_state.on_the_path] = {
      -- play start honk if previous state was one of the below
      [defines.train_state.destination_full] = start,
      [defines.train_state.no_schedule] = start,
      [defines.train_state.no_path] = start,
      [defines.train_state.wait_signal] = start,
      [defines.train_state.wait_station] = start,
      [defines.train_state.manual_control_stop] = start,
      [defines.train_state.manual_control] = start
    }
    -- definition for auto-selected keypress starting honk
    group.manual_start = start
  end

  local station = settings.global["honk-sound-station-"..groupname].value
  if station ~= "none" and helpers.is_valid_sound_path(station) then
    group[defines.train_state.arrive_station] = {
      -- play station honk only if previous state was normal pathing
      [defines.train_state.on_the_path] = station
    }
    -- fallback definition for auto-selected keypress braking honk
    group.manual_stop = group.manual_stop or station
  end

  local signal = settings.global["honk-sound-signal-"..groupname].value
  if signal ~= "none" and helpers.is_valid_sound_path(signal) then
    group[defines.train_state.arrive_signal] = {
      -- play signal honk only if previous state was normal pathing
      [defines.train_state.on_the_path] = signal
    }
    -- second fallback definition for auto-selected keypress braking honk
    group.manual_stop = group.manual_stop or signal
  end

  local manual = settings.global["honk-sound-manual-"..groupname].value
  if manual == "auto" then
    group.auto = true
  elseif manual ~= "none" and helpers.is_valid_sound_path(manual) then
    -- not auto, use this value
    group.manual = manual
  end

  local manual_alt = settings.global["honk-sound-manual-alt-"..groupname].value
  if manual_alt ~= "none" and helpers.is_valid_sound_path(manual_alt) then
    group.alt = manual_alt
  end

  -- Extract list of locomotives to apply this sound to
  local namelist = settings.global["honk-sound-locos-"..groupname].value
  group.names = {}
  if namelist and namelist ~= "" then
    for name in string.gmatch(namelist, "([^,]+)") do
      group.names[name] = true
      group.names[name.."-mu"] = true  -- Compatibility with Multiple Unit Train Control
    end
  end

  return group
end


local function buildHonks()
  -- Clear existing maps and rebuild
  storage.honks = nil  -- clear old table
  storage.honkgroups = {}

  -- Make a list of the honk groups mapping each train state to a sound name
  local groups = {}
  local grouplist = settings.startup["honk-groups"].value
  if grouplist and grouplist ~= "" then
    for group in string.gmatch(grouplist, "([^,]+)") do
      if group ~= "none" then
        storage.honkgroups[group] = buildHonkGroup(group)
      end
    end
  end

  local default_group = settings.global["honk-default-sound"].value

  local namelist = settings.global["honk-sound-locos-none"].value
  storage.honkgroups["none"] = {names = {}}
  if namelist and namelist ~= "" then
    for name in string.gmatch(namelist, "([^,]+)") do
      storage.honkgroups["none"].names[name] = true
      storage.honkgroups["none"].names[name.."-mu"] = true  -- Compatibility with Multiple Unit Train Control
    end
  end

  -- Make a list of locomotive entities mapping each to a honk group name
  storage.honkmap = {}
  for name, _ in pairs(prototypes.get_entity_filtered{{filter="type",type="locomotive"}}) do
    -- check if this locomotive is listed for any of the groups
    for groupname, group in pairs(storage.honkgroups) do
      if group.names[name] then
        storage.honkmap[name] = groupname
      end
    end
    storage.honkmap[name] = storage.honkmap[name] or default_group
  end

  log("Honk Global Map updated:\n"..serpent.block(storage))
end

script.on_configuration_changed(buildHonks)
script.on_init(buildHonks)
script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if string.find(event.setting, "honk") then
    buildHonks()
  end
end)

function playSoundAtEntity(sound, entity)
  -- Play sound
  if sound and entity then
    entity.surface.play_sound{path = sound, position = entity.position}
  end
end

-- Find loco(s) to emit honks in train
-- A stationary train will honk at front- and rear-facing locos if both are present
function findLocoToHonk(train)
  if train.speed >= 0 and #train.locomotives.front_movers > 0 then
    return train.locomotives.front_movers[1]
  end
  if train.speed <= 0 and #train.locomotives.back_movers > 0 then
    return train.locomotives.back_movers[#train.locomotives.back_movers]
  end
end

-- Manual honk
script.on_event("honk", function(event)
  local player = game.players[event.player_index]
  if player.vehicle and player.vehicle.type == "locomotive" then
    local honktype = storage.honkmap[player.vehicle.name]
    if honktype then
      local honkgroup = storage.honkgroups[honktype]
      if honkgroup.auto then
        if player.vehicle.train.speed == 0 then
          if honkgroup.manual_start then
            playSoundAtEntity(honkgroup.manual_start, player.vehicle)
          end
        else
          if honkgroup.manual_stop then
            playSoundAtEntity(honkgroup.manual_stop, player.vehicle)
          end
        end
      else -- not automatic mode, play the player-selected sound
        if honkgroup.manual then
          playSoundAtEntity(honkgroup.manual, player.vehicle)
        end
      end
    end
  end
end)

-- Manual alt honk
script.on_event("honk-alt", function(event)
  local player = game.players[event.player_index]
  if player.vehicle and player.vehicle.type == "locomotive" then
    local loco = player.vehicle
    local honktype = storage.honkmap[loco.name]
    if honktype then
      local honkgroup = storage.honkgroups[honktype]
      if honkgroup and honkgroup.alt then
        playSoundAtEntity(honkgroup.alt, player.vehicle)
      end
    end
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

-- Play sound when train changes state
function onTrainChangedState(event)
  if storage.all_disabled then return end
  local entity = findLocoToHonk(event.train)
  if entity then
    local honktype = storage.honkmap[entity.name]
    if honktype then
      local honkgroup = storage.honkgroups[honktype]
      if honkgroup and (not honkgroup.disabled) and honkgroup[event.train.state] and honkgroup[event.train.state][event.old_state] then
        if event.train.state == defines.train_state.on_the_path and event.old_state == defines.train_state.manual_control and
               ( (event.train.get_rail_end(defines.rail_direction.back).rail.name == "se-space-elevator-curved-rail") or
                 (event.train.get_rail_end(defines.rail_direction.back).rail.name == "se-space-elevator-curved-rail") ) then
          -- leaving space elevator, do nothing
        elseif event.train.state == defines.train_state.arrive_station and 
           event.train.path_end_stop and event.train.path_end_stop.name == "se-space-elevator-train-stop" then
          -- approaching space elevator, do nothing
        else
          playSoundAtEntity(honkgroup[event.train.state][event.old_state], entity)
        end
      end
    end
  end
end
script.on_event(defines.events.on_train_changed_state, onTrainChangedState)

-- Console command to disable/enable honks globally or by group, for integration with RCON & streaming
commands.add_command("honk_disable",
  "Usage: /honk_disable <group> where <group> is empty for global disable or one of [diesel,steam,boat,ship,all]",
  function(command)
    if storage.honkgroups[command.parameter] then
      -- disable this group
      storage.honkgroups[command.parameter].disabled = true
    else
      if command.parameter == "all" then
        for name,group in pairs(storage.honkgroups) do
          group.disabled = true
        end
      end
      storage.all_disabled = true
    end
  end
  )

commands.add_command("honk_enable",
  "Usage: /honk_enable <group> where <group> is empty for global enable or one of [diesel,steam,boat,ship,all]",
  function(command)
    if storage.honkgroups[command.parameter] then
      -- disable this group
      storage.honkgroups[command.parameter].disabled = false
    else
      if command.parameter == "all" then
        for name,group in pairs(storage.honkgroups) do
          group.disabled = false
        end
      end
      storage.all_disabled = false
    end
  end
  )



-- Debug command
function cmd_debug(params)
  local cmd = params.parameter
  if cmd == "dump" then
    for v, data in pairs(storage) do
      print_game(v, ": ", data)
    end
  elseif cmd == "dumplog" then
    for v, data in pairs(storage) do
      print_file(v, ": ", data)
    end
    print_game("Dump written to log file")
  end
end
commands.add_command("honk-debug", "", cmd_debug)


------------------------------------------------------------------------------------
--                    FIND LOCAL VARIABLES THAT ARE USED GLOBALLY                 --
--                              (Thanks to eradicator!)                           --
------------------------------------------------------------------------------------
--[[setmetatable(_ENV,{
  __newindex=function (self,key,value) --locked_global_write
    error('\n\n[ER Global Lock] Forbidden global *write*:\n'
      .. serpent.line{key=key or '<nil>',value=value or '<nil>'}..'\n')
    end,
  __index   =function (self,key) --locked_global_read
    error('\n\n[ER Global Lock] Forbidden global *read*:\n'
      .. serpent.line{key=key or '<nil>'}..'\n')
    end ,
  })
--]]
if script.active_mods["gvv"] then require("__gvv__.gvv")() end
