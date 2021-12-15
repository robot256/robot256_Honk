soundpath = "__Honk__/sounds/"

-- Custom Inputs
data:extend{
  {
    type = "custom-input",
    name = "honk",
    key_sequence = "H"
  },
  {
    type = "custom-input",
    name = "honk-alt",
    key_sequence = "SHIFT + H"
  },
  {
    type = "custom-input",
    name = "toggle-train-control",
    key_sequence = "J"
  },
}

-- Diesel Train Honks
local honk_single =
  {
    type = "sound",
    name = "honk-single",
    filename = soundpath.."honklong.ogg",
    category = "environment",
    audible_distance_modifier = settings.startup["honk-sound-range"].value,
    volume = settings.startup["honk-sound-volume"].value
  }
local honk_double =
  {
    type = "sound",
    name = "honk-double",
    filename = soundpath.."honk2xshort.ogg",
    category = "environment",
    audible_distance_modifier = settings.startup["honk-sound-range"].value,
    volume = settings.startup["honk-sound-volume"].value
  }

-- Steam Train Honks
local steam_single = table.deepcopy(honk_single)
steam_single.name = "honk-single-steam-train"
steam_single.filename = soundpath.."honk-single-steam-train.ogg"
local steam_double = table.deepcopy(honk_double)
steam_double.name = "honk-double-steam-train"
steam_double.filename = soundpath.."honk-double-steam-train.ogg"

-- Tugboat Honks
local boat_single = table.deepcopy(honk_single)
boat_single.name = "honk-single-boat"
boat_single.filename = soundpath.."honk-single-boat.ogg"
local boat_double = table.deepcopy(honk_double)
boat_double.name = "honk-double-boat"
boat_double.filename = soundpath.."honk-double-boat.ogg"

-- Ship Honks
local ship_single = table.deepcopy(honk_single)
ship_single.name = "honk-single-ship"
ship_single.filename = soundpath.."honk-single-ship.ogg"
--ship_single.volume = ship_single.volume
local ship_double = table.deepcopy(honk_double)
ship_double.name = "honk-double-ship"
ship_double.filename = soundpath.."honk-double-ship.ogg"
--ship_double.volume = ship_double.volume

data:extend{
  honk_single,
  honk_double,
  steam_single,
  steam_double,
  ship_single,
  ship_double,
}
