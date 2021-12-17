
-- Programmable speaker sounds
if settings.startup["honk-speakers"].value then
  local instrument = {name="honk-horns", notes={}}
  for _,group in pairs(settings.global["honk-groups"].allowed_values) do
    table.insert(instrument.notes, {name="honk-single-"..group, sound=data.raw.sound["honk-single-"..group]})
    table.insert(instrument.notes, {name="honk-double-"..group, sound=data.raw.sound["honk-double-"..group]})
  end
  table.insert(data.raw["programmable-speaker"]["programmable-speaker"].instruments, instrument)
end
