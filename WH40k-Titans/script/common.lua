require("__core__.lualib.util") -- for table.deepcopy
shared = require("shared")
mod_name = shared.mod_name


----- Script data -----

blank_ctrl_data = {
  assembler_buckets = {}, -- uid => bucket => assembler
  assembler_index = {}, -- entity.unit_number => assembler
  -- assembler_entities = {}, -- bunker parts, entity.unit_number => {assembler=, index=[0:6]}
  assembler_gui = {}, -- player.index => {assembler=, main_frame=}

  titans = {},
  titan_gui = {},
  foots = {},
  by_player = {}, -- user settings
}
ctrl_data = table.deepcopy(blank_ctrl_data)

used_specials = {}


----- Utils -----

function preprocess_ingredients()
  -- Replaces Bridge item objects with names
  if not global.active_mods_cache then return end
  log("preprocess_ingredients, active_mods_cache: "..serpent.line(global.active_mods_cache))
  afci_bridge.active_mods_cache = global.active_mods_cache
  local item
  for _, titan_type in pairs(shared.titan_type_list) do
    for _, stack in pairs(titan_type.ingredients) do
      if stack[1].is_bridge_item then
        item = stack[1]
        item.getter() -- preprocessing
        stack[1] = item.name
      end
    end
  end
  for _, weapon_type in pairs(shared.weapons) do
    for _, stack in pairs(weapon_type.ingredients) do
      if stack[1].is_bridge_item then
        item = stack[1]
        item.getter() -- preprocessing
        stack[1] = item.name
      end
    end
  end
end

function get_in_buckets_count(storage)
  local result = 0
  for _, bucket in pairs(storage) do
    for _, value in pairs(bucket or {}) do
      result = result + 1
    end
  end
  return result
end

function get_keys(tbl)
  if tbl == nil then return nil end
  local result = {}
  for k, v in pairs(tbl) do
    result[#result+1] = k
  end
  return result
end

function merge(a, b, over)
  for k, v in pairs(b) do
    if a[k] == nil or over then
      a[k] = v
    end
  end
  return a
end

-- Long live the Functional programming!
function chain_arrays(lists)
  -- Like Python's itertools.chain
  local result = {}
  for _, ar in pairs(lists) do
    for _, value in pairs(ar) do
      table.insert(result, value)
    end
  end
  return result
end
function partial(func, args_pre, args_post)
  args_pre = args_pre or {}
  args_post = args_post or {}
  return function(...)
    local new_args = chain_arrays(args_pre, {{...}, args_post})
    func(table.unpack(new_args))
  end
end
function func_map(func, args)
  local results = {}
  for _, value in pairs(args) do
    results[#results+1] = func(value)
  end
  return results
end
function func_maps(func, args_arrays)
  local results = {}
  for _, args in pairs(args_arrays) do
    results[#results+1] = func(table.unpack(args))
  end
  return results
end

function points_to_orientation(a, b)
  return 0.25 +math.atan2(b.y-a.y, b.x-a.x) /math.pi /2
end

function orientation_diff(src, dst)
  if dst - src > 0.5 then src = src + 1 end
  if src - dst > 0.5 then dst = dst + 1 end
  return dst - src
end

function point_orientation_shift(ori, oris, length)
  ori = -ori -oris +0.25
  ori = ori * 2 * math.pi
  return {length*math.cos(ori), -length*math.sin(ori)}
end

function math.clamp(v, mn, mx)
  return math.max(math.min(v, mx), mn)
end

function die_all(list, global_storage)
  for _, special_entity in pairs(list) do
    if special_entity.valid then
      if global_storage ~= nil then
        global_storage[special_entity.unit_number] = nil
      end
      special_entity.destroy()
    end
  end
end

function preprocess_entities(list)
  for _, entity in pairs(list) do
    if entity.valid then
      used_specials[entity.unit_number] = true
      entity.active = false -- for crafting machines
    end
  end
end

function is_titan(name)
  return name:find(shared.titan_prefix, 1, true)
end

function list_players(values)
  -- values is a list of player/character/nil
  local result = {}
  for _, obj in pairs(values) do
    if obj then
      if obj.player then
        table.insert(result, obj.player)
      elseif obj.object_name == "LuaPlayer" then
        table.insert(result, obj)
      end
    end
  end
  return result
end
