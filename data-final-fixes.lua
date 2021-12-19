
-- Programmable speaker sounds
if settings.startup["honk-speakers"].value then
  local instrument = {name="honk-horns", notes={}}
  local grouplist = settings.startup["honk-groups"].value
  if grouplist and grouplist ~= "" then
    for group in string.gmatch(grouplist, "([^,%S]+)") do
      table.insert(instrument.notes, {name="honk-single-"..group, sound=data.raw.sound["honk-single-"..group]})
      table.insert(instrument.notes, {name="honk-double-"..group, sound=data.raw.sound["honk-double-"..group]})
    end
  end
  if #instrument.notes > 0 then
    table.insert(data.raw["programmable-speaker"]["programmable-speaker"].instruments, instrument)
  end
end
