local titan = require("script/titan")
local supplier = require("script/supplier")

local states = lib_asmb.states

local main_frame_name = "wh40k_titans_assembly_frame"
-- local main_frame_name = "wh40k_titans_main_frame"

local main_frame_buttons_line = "buttons_line"
local main_frame_init_progress = "init_progress"
local main_frame_assembly_progress = "assembly_progress"
local act_main_frame_close = "wh40k-titans-assembly-frame-close"
local act_change_state = "wh40k-titans-assembly-change-state"
local act_set_class = "wh40k-titans-assembly-set-class"
local act_set_weapon = "wh40k-titans-assembly-set-weapon"
local act_toggle_auto = "wh40k-titans-assembly-toggle-auto-build"

local gui_maker = {}
local gui_updater = {}


function gui_maker.disabled(assembler, main_frame)
  main_frame.status_line.add{type="sprite-button", tags={action=act_change_state, state=states.initialising}, sprite="virtual-signal/"..shared.mod_prefix.."signal-play", tooltip={"WH40k-Titans-gui.assembly-act-init"} }
end


function gui_maker.initialising(assembler, main_frame)
  main_frame.status_line.add{type="sprite-button", index=1, tags={action=act_change_state, state=states.deactivating, need_confirm=true}, sprite="virtual-signal/"..shared.mod_prefix.."signal-close", tooltip={"WH40k-Titans-gui.assembly-act-cancel"} }
  main_frame.main_room.add{ type="progressbar", name=main_frame_init_progress, direction="horizontal", value=assembler.init_progress/lib_asmb.get_bunker_init_time() }
end


function gui_maker.deactivating(assembler, main_frame)
  main_frame.main_room.add{ type="progressbar", name=main_frame_init_progress, direction="horizontal", value=assembler.init_progress/lib_asmb.get_bunker_init_time() }
end


function gui_maker.idle(assembler, main_frame)
  local top_line = main_frame.main_room.add{ type="flow", name=main_frame_buttons_line, direction="horizontal" }
  top_line.add{type="sprite-button", tags={action=act_change_state, state=states.deactivating, need_confirm=true}, sprite="virtual-signal/"..shared.mod_prefix.."signal-close", tooltip={"WH40k-Titans-gui.assembly-act-disable"} }
  top_line.add{type="sprite-button", tags={action=act_change_state, state=states.prepare_assembly}, sprite="virtual-signal/"..shared.mod_prefix.."signal-assembling", tooltip={"WH40k-Titans-gui.assembly-act-prepare-assemble"} }
  top_line.add{type="sprite-button", tags={action=act_change_state, state=states.waiting_disassembly}, sprite="virtual-signal/"..shared.mod_prefix.."signal-disassembling", tooltip={"WH40k-Titans-gui.assembly-act-prepare-disassemble"} }
  top_line.add{type="sprite-button", tags={action=act_change_state, state=states.restock}, sprite="virtual-signal/"..shared.mod_prefix.."signal-unpacking", tooltip={"WH40k-Titans-gui.assembly-act-restock"} }
  top_line.add{type="sprite-button", tags={action=act_change_state, state=states.clearing}, sprite="virtual-signal/"..shared.mod_prefix.."signal-packing", tooltip={"WH40k-Titans-gui.assembly-act-clearing"} }
end

-- https://lua-api.factorio.com/latest/concepts/RecipePrototypeFilter.html
local no_recipes_filter = {
  {filter="category", category=shared.craftcat_empty, mode="and"},
  {filter="enabled", mode="and"},
}

local function get_category_filters_by_research(player, category, research, mn, mx)
  local has_character = not not player.character
  local filters = {}
  for i = mn, mx do
    if not has_character or player.force.technologies[shared.mod_prefix..i..research].researched then
      table.insert(filters, {filter="category", category=category..i, mode="or"})
    end
  end
  if #filters == 0 then
    filters = no_recipes_filter
  end
  return filters
end

local function get_weapon_category_filters(player, titan_type, wi)
  local has_character = not not player.character
  local filters = {}

  local mn = 0
  local mx = 5

  local mounting
  if titan_type then
    mounting = titan_type.mounts[wi]
    if not mounting then
      return {{filter="category", category=shared.craftcat_nomount}}
    end
    mn = math.max(mn, mounting.grade - 1)
    mx = math.min(mx, mounting.grade)
  end

  for i = mn, mx do
    if not has_character or player.force.technologies[shared.mod_prefix..i.."-grade"].researched then
      if not mounting or mounting.is_top then
        table.insert(filters, {filter="category", category=shared.craftcat_weapon..i.."a", mode="or"})
      end
      if not mounting or not mounting.top_only then
        table.insert(filters, {filter="category", category=shared.craftcat_weapon..i.."b", mode="or"})
      end
      if not mounting or mounting.is_arm then
        table.insert(filters, {filter="category", category=shared.craftcat_weapon..i.."m", mode="or"})
      end
    end
  end

  if #filters == 0 then
    -- filters = no_recipes_filter
    return {{filter="category", category=shared.craftcat_noknownweapon}}
  end
  return filters
end


function gui_updater.prepare_assembly(assembler, main_frame)
  -- TODO: update other elements?
  -- TODO: translate text
  main_frame.main_room.label.caption = {"", "Status: ", assembler.message or "unknown"}
  main_frame.main_room.label.tooltip = assembler.status_tooltip
  main_frame.main_room.last_line.auto_toggler.sprite = assembler.auto_build and ("virtual-signal/"..shared.mod_prefix.."signal-stop") or ("virtual-signal/"..shared.mod_prefix.."signal-play")
end


local function make_weapon_tooltip(titan_type, recipe_name, wi)
  if not titan_type or not weapon_type then
    return nil
  end
  -- if recipe_name == shared.craftcat_nomount then
  --   return {"recipe-name."..shared.craftcat_nomount}
  -- end
  -- if recipe_name == shared.craftcat_noknownweapon then
  --   return {"recipe-name."..shared.craftcat_noknownweapon}
  -- end

  local weapon_type = assembler.weapon_recipes[wi] and shared.weapons[recipe_name]

  if not titan_type.mounts[wi] and not weapon_type then
    return {"WH40k-Titans-gui.assembly-blocked-weapon"}
  end
  -- TODO: highlight errors with some colors/styles?
  if titan_type.mounts[wi] and not weapon_type then
    return {"WH40k-Titans-gui.assembly-er-weapon-missing"}
  end
  if weapon_type and not titan_type.mounts[wi] then
    return {"WH40k-Titans-gui.assembly-er-extra-weapon"}
  else
    local error = lib_asmb.check_weapon_is_appropriate(titan_type, wi, weapon_type)
    -- nil value gets considered as a string :(
    if error then return error end
  end
  return nil
end


function gui_maker.prepare_assembly(assembler, main_frame)
  main_frame.status_line.add{type="sprite-button", index=1, tags={action=act_change_state, state=states.idle}, sprite="virtual-signal/"..shared.mod_prefix.."signal-back", tooltip={"WH40k-Titans-gui.assembly-act-cancel"} }
  -- TODO: show expected assembly time

  -- TODO: translate text
  main_frame.main_room.add{
    type="label", name="label",
    caption={"", "Status: ", assembler.message or "unknown"},
    tooltip=assembler.status_tooltip,
  }

  local player = game.get_player(main_frame.player_index)
  local filters
  local btn
  local grid = main_frame.main_room.add{ type="frame", name="row", direction="horizontal" }

  filters = get_category_filters_by_research(player, shared.craftcat_titan, "-class", 1, 5)
  btn = grid.add{
    type="choose-elem-button",
    name="body",
    elem_type="recipe",
    elem_filters = filters,
    recipe = assembler.class_recipe,
    tags={action=act_set_class},
  }
  local titan_type
  if assembler.class_recipe then
    titan_type = shared.titan_types[assembler.class_recipe]
  end
  -- filters = get_category_filters_by_research(player, shared.craftcat_weapon, "-grade", 0, 5)
  for wi = 1, 6 do
    filters = get_weapon_category_filters(player, titan_type, wi)
    btn = grid.add{
      type="choose-elem-button",
      name="w"..wi,
      elem_type="recipe",
      elem_filters=filters,
      recipe=assembler.weapon_recipes[wi],
      tags={action=act_set_weapon, wi=wi},
    }
    if titan_type then
      -- TODO: sadly, tooltips seem be overriden by selected content, so maybe remove it to simplify the code?
      btn.tooltip = make_weapon_tooltip(titan_type, assembler.weapon_recipes[wi], wi)
    end
  end

  main_frame.main_room.add{ type="flow", name="last_line", direction="horizontal" }
  main_frame.main_room.last_line.add{ type="label", name="label", caption={"WH40k-Titans-gui.assembly-auto"} }
  main_frame.main_room.last_line.add{
    type="sprite-button", name="auto_toggler", tags={action=act_toggle_auto},
    sprite=assembler.auto_build and ("virtual-signal/"..shared.mod_prefix.."signal-stop") or ("virtual-signal/"..shared.mod_prefix.."signal-play"),
  }
end


function gui_maker.assembling(assembler, main_frame)
  main_frame.status_line.add{type="sprite-button", index=1, tags={action=act_change_state, state=states.disassembling}, sprite="virtual-signal/"..shared.mod_prefix.."signal-close", tooltip={"WH40k-Titans-gui.assembly-act-cancel"} }
  main_frame.main_room.add{ type="progressbar", name=main_frame_assembly_progress, direction="horizontal", value=assembler.assembly_progress/assembler.assembly_progress_max }

  main_frame.main_room.add{ type="label", name="expected_time" }
  main_frame.main_room.expected_time.caption = {"WH40k-Titans-gui.assembly-expected-time", beautify_time(lib_asmb:estimate_remaining_time(assembler))}

  local line = main_frame.main_room.add{ type="flow", name="recipes", direction="horizontal" }
  line.add{
    type="sprite-button", sprite=("recipe/"..assembler.class_recipe),
    tooltip={"entity-name."..assembler.class_recipe},
  }
  for k = 1, 6 do
    if assembler.weapon_recipes[wi] then
      line.add{
        type="sprite-button", sprite=("recipe/"..assembler.weapon_recipes[wi]),
        tooltip={"item-name."..assembler.weapon_recipes[wi]},
      }
    end
  end
end


function gui_maker.waiting_disassembly(assembler, main_frame)
  main_frame.status_line.add{type="sprite-button", index=1, tags={action=act_change_state, state=states.idle}, sprite="virtual-signal/"..shared.mod_prefix.."signal-back", tooltip={"WH40k-Titans-gui.assembly-act-cancel"} }
end


function gui_maker.disassembling(assembler, main_frame)
  main_frame.main_room.add{ type="progressbar", name=main_frame_assembly_progress, direction="horizontal", value=assembler.assembly_progress/assembler.assembly_progress_max }

  main_frame.main_room.add{ type="label", name="expected_time" }
  main_frame.main_room.expected_time.caption = {"WH40k-Titans-gui.assembly-expected-time", beautify_time(lib_asmb:estimate_remaining_time(assembler))}

  local line = main_frame.main_room.add{ type="flow", name="recipes", direction="horizontal" }
  line.add{
    type="sprite-button", sprite=("recipe/"..assembler.class_recipe),
    tooltip={"entity-name."..assembler.class_recipe},
  }
  for k = 1, 6 do
    if assembler.weapon_recipes[wi] then
      line.add{
        type="sprite-button", sprite=("recipe/"..assembler.weapon_recipes[wi]),
        tooltip={"item-name."..assembler.weapon_recipes[wi]},
      }
    end
  end
end


function gui_maker.restock(assembler, main_frame)
  main_frame.status_line.add{type="sprite-button", index=1, tags={action=act_change_state, state=states.idle}, sprite="virtual-signal/"..shared.mod_prefix.."signal-back", tooltip={"WH40k-Titans-gui.assembly-act-cancel"} }
end


function gui_maker.clearing(assembler, main_frame)
  main_frame.status_line.add{type="sprite-button", index=1, tags={action=act_change_state, state=states.idle}, sprite="virtual-signal/"..shared.mod_prefix.."signal-back", tooltip={"WH40k-Titans-gui.assembly-act-cancel"} }
end


local function create_assembly_gui(player, assembler)
  local main_frame, gui_info
  if player.gui.screen[main_frame_name] then
    if ctrl_data.assembler_gui[player.index].assembler == assembler then
      main_frame = player.gui.screen[main_frame_name]
      gui_info = ctrl_data.assembler_gui[player.index]
      gui_info.state = nil -- Do full reload
      player.opened = main_frame
      main_frame.focus()
      main_frame.bring_to_front()
      lib_asmb.update_assembler_gui(gui_info)
      return
    else
    player.gui.screen[main_frame_name].destroy()
    end
  end

  main_frame = player.gui.screen.add{ type="frame", name=main_frame_name, direction="vertical", }
  main_frame.style.minimal_width = 256
  main_frame.style.maximal_width = 640
  main_frame.style.minimal_height = 128
  main_frame.style.maximal_height = 320

  main_frame.auto_center = true
  player.opened = main_frame
  main_frame.focus()
  main_frame.bring_to_front()

  local flowtitle = main_frame.add{ type="flow", name="title" }
  local title = flowtitle.add{ type="label", style="frame_title", caption={"WH40k-Titans-gui.assembly-caption"} }
  title.drag_target = main_frame
  local pusher = flowtitle.add{ type="empty-widget", style="draggable_space_header" }
  pusher.style.vertically_stretchable = true
  pusher.style.horizontally_stretchable = true
  pusher.drag_target = main_frame
  pusher.style.maximal_height = 24
  flowtitle.add{ type="sprite-button", style="frame_action_button", tags={action=act_main_frame_close}, sprite="utility/close" }

  -- if settings.global["wh40k-titans-debug-info"].value then
  --   local tf = main_frame.add{ type="text-box", name="debugging",
  --     text=table.concat(func_map(serpent.line, {
  --       {"wentity", assembler.wentity},
  --       {"is it valid", assembler.wentity and assembler.wentity.valid},
  --       {"sentity", assembler.sentity},
  --       {"is it valid", assembler.sentity and assembler.sentity.valid},
  --     }), "\n") }
  --   tf.style.minimal_width = 256
  -- end

  main_frame.add{ type="flow", name="status_line", direction="horizontal" }
  main_frame.add{ type="flow", name="main_room", direction="vertical" }

  gui_info = { assembler=assembler, main_frame=main_frame, player_index=player.index }
  ctrl_data.assembler_gui[player.index] = gui_info
  lib_asmb.update_assembler_gui(ctrl_data.assembler_gui[player.index])
end


function lib_asmb.update_assembler_gui(gui_info)
  if gui_info.state == gui_info.assembler.state and gui_updater[gui_info.assembler.state] then
    gui_updater[gui_info.assembler.state](gui_info.assembler, gui_info.main_frame)
  else
    gui_info.main_frame.status_line.clear()
    gui_info.main_frame.status_line.add{ type="label", name="label" }
    gui_info.main_frame.status_line.label.caption = {"WH40k-Titans-gui.assembly-state-"..gui_info.assembler.state}
    gui_info.main_frame.main_room.clear()
    gui_maker[gui_info.assembler.state](gui_info.assembler, gui_info.main_frame)
    gui_info.state = gui_info.assembler.state
  end
end


lib_asmb:on_event(defines.events.on_gui_opened, function(event)
  local player = game.get_player(event.player_index)
  if event.entity and ctrl_data.assembler_index[event.entity.unit_number] then
    player.opened = nil
    create_assembly_gui(player, ctrl_data.assembler_index[event.entity.unit_number])

  elseif event.entity and (event.entity.name == shared.bunker_minable or event.entity.name == shared.bunker_active) then
    player.print("The bunker is improper, sorry :(")
    player.opened = nil

  elseif event.entity and (event.entity.name == shared.bunker_wrecipeh or event.entity.name == shared.bunker_wrecipev) then
    player.opened = nil
    create_assembly_gui(player, ctrl_data.assembler_index[event.entity.unit_number])
  end
end)


lib_asmb:on_event(defines.events.on_gui_click, function(event)
  local player = game.get_player(event.player_index)
  local assembler = nil
  if ctrl_data.assembler_gui[event.player_index] then
    assembler = ctrl_data.assembler_gui[event.player_index].assembler
  end
  local action = event.element and event.element.valid and event.element.tags.action

  if action == act_main_frame_close then
    if player.gui.screen[main_frame_name] and player.gui.screen[main_frame_name].valid then
      player.gui.screen[main_frame_name].destroy()
      ctrl_data.assembler_gui[event.player_index] = nil
    end
  elseif action == act_toggle_auto then
    assembler.auto_build = not assembler.auto_build
  elseif action == act_change_state then
    if event.element.tags.need_confirm then
      -- TODO: save goal, create a modal window, return
    end
    if event.element.tags.state and states[event.element.tags.state] then
      lib_asmb.change_assembler_state(assembler, event.element.tags.state)
    else
      error("Request for change to unknown state: "..serpent.line(event.element.tags))
    end
  end
end)


function lib_asmb.update_assembler_guis(assembler)
  for player_index, gui_info in pairs(ctrl_data.assembler_gui) do
    if gui_info.assembler == assembler then
      lib_asmb.update_assembler_gui(gui_info)
    end
  end
end


lib_asmb:on_event(defines.events.on_gui_elem_changed, function(event)
  local player = game.get_player(event.player_index)
  local assembler = nil
  if ctrl_data.assembler_gui[event.player_index] then
    assembler = ctrl_data.assembler_gui[event.player_index].assembler
  else
    return
  end
  local main_frame = player.gui.screen[main_frame_name]

  if event.element.tags.action == act_set_class then
    assembler.class_recipe = event.element.elem_value
    local titan_type = shared.titan_types[assembler.class_recipe]
    local btn
    if titan_type then
      for wi = 1, 6 do
        btn = main_frame.main_room.row["w"..wi]
        btn.tooltip = nil
        btn.elem_filters = get_weapon_category_filters(player, titan_type, wi)
        if titan_type.mounts[wi] then
          -- Clear "no mount position" fake recipe on positions which are available now
          if btn.elem_value == shared.craftcat_nomount then
            btn.elem_value = nil
            assembler.weapon_recipes[wi] = nil
            btn.tooltip = {"WH40k-Titans-gui.assembly-er-weapon-missing"}
          end
        else
          -- Set "no mount position" fake recipe
          local weapon_type = assembler.weapon_recipes[wi] and shared.weapons[assembler.weapon_recipes[wi]]
          if not weapon_type then
            btn.elem_value = shared.craftcat_nomount
            assembler.weapon_recipes[wi] = shared.craftcat_nomount
          end
        end
      end
    end

  elseif event.element.tags.action == act_set_weapon then
    local wi = event.element.tags.wi
    assembler.weapon_recipes[wi] = event.element.elem_value
    if assembler.class_recipe then
      local titan_type = shared.titan_types[assembler.class_recipe]
      event.element.tooltip = make_weapon_tooltip(titan_type, assembler.weapon_recipes[wi], wi)
    else
      event.element.tooltip = nil
    end
  end
  lib_asmb.update_assembler_guis(assembler)
end)


lib_asmb:on_event(defines.events.on_gui_closed, function(event)
  local player = game.get_player(event.player_index)
  if event.element and event.element.valid and event.element.name == main_frame_name then
    event.element.destroy()
    ctrl_data.assembler_gui[event.player_index] = nil
  end
end)
