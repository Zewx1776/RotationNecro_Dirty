local my_utility = require("my_utility/my_utility")
local spell_data = require("my_utility/spell_data")

local menu_elements =
{
    tree_tab            = tree_node:new(1),
    main_boolean        = checkbox:new(true, get_hash(my_utility.plugin_label .. "blood_wave_main_boolean")),
    targeting_mode      = combo_box:new(3, get_hash(my_utility.plugin_label .. "blood_wave_targeting_mode")),
    gather_blood_orbs   = checkbox:new(true, get_hash(my_utility.plugin_label .. "blood_wave_gather_blood_orbs")),
    evade_blood_orbs    = checkbox:new(true, get_hash(my_utility.plugin_label .. "blood_wave_evade_blood_orbs")),
    reset_rathmas_vigor = checkbox:new(true, get_hash(my_utility.plugin_label .. "blood_wave_evade_blood_orbs")),
    min_hits            = slider_int:new(0, 30, 5, get_hash(my_utility.plugin_label .. "blood_wave_min_hits_base")),
    effect_size_affix_mult = slider_float:new(0.0, 200.0, 0.0, get_hash(my_utility.plugin_label .. "blood_wave_effect_size_affix_mult_slider_base")),
}

local function menu()
    if menu_elements.tree_tab:push("Blood Wave") then
        menu_elements.main_boolean:render("Enable Spell", "")

        if menu_elements.main_boolean:get() then
            menu_elements.gather_blood_orbs:render("Gather blood orbs", "Ultimat cooldown reduction with Fastblood")

            if menu_elements.gather_blood_orbs:get() then
                menu_elements.evade_blood_orbs:render("Use evade as well", "If enabled uses evade to gather blood orbs")
                menu_elements.reset_rathmas_vigor:render("Reset Rathma's Vigor",
                    "If enabled collects blood orbs even after cooldown is reset but not at 15 stacks of Rathma's Vigor for a guaranteed overpower.")
            end

            menu_elements.min_hits:render("Min Hits", "Minimum enemies to hit for Blood Wave to cast")
            menu_elements.effect_size_affix_mult:render("Effect Size Affix Mult", "Increase Blood Wave radius (%)", 1)
            menu_elements.targeting_mode:render("Targeting Mode", my_utility.targeting_modes,
                my_utility.targeting_mode_description)
        end

        menu_elements.tree_tab:pop()
    end
end

local next_time_allowed_cast = 0.0;
local function logics(target)
    local menu_boolean = menu_elements.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        spell_data.blood_wave.spell_id);
    if not is_logic_allowed then return false end;

    local reset_rathmas_vigor = menu_elements.reset_rathmas_vigor:get();
    local rathmas_vigor_stacks = my_utility.buff_stack_count(spell_data.rathmas_vigor.spell_id,
        spell_data.rathmas_vigor.stack_counter);
    if reset_rathmas_vigor and rathmas_vigor_stacks < 15 then
        local blood_orb_data = my_utility.get_blood_orb_data();
        if blood_orb_data.is_valid then
            return false;
        end
    end

    -- Enhanced logic: Use min hits targeting if enabled
    local use_min_hits = menu_elements.min_hits:get() and menu_elements.min_hits:get() > 0
    if use_min_hits then
        local menu_module = nil
        local menu_settings = nil
        local success, result = pcall(require, 'menu')
        if success and result and type(result) == 'table' and result.menu_elements then
            menu_settings = result.menu_elements
        end
        local raw_radius = 7.0
        local multiplier = menu_elements.effect_size_affix_mult:get() / 100
        local wave_radius = raw_radius * (1.0 + multiplier)
        local player_position = get_player_position()
        local area_data = target_selector.get_most_hits_target_circular_area_heavy(player_position, 8.0, wave_radius)
        local best_target = area_data.main_target
        if not best_target then
            return false
        end
        local best_target_position = best_target:get_position()
        -- Wall/line-of-sight check: do not target through walls
        local is_wall_collision = false
        if prediction and prediction.is_wall_collision then
            local player_position = get_player_position()
            is_wall_collision = prediction.is_wall_collision(player_position, best_target_position, 1)
        elseif my_utility and my_utility.is_wall_collision then
            local player_position = get_player_position()
            is_wall_collision = my_utility.is_wall_collision(player_position, best_target_position, 1)
        end
        if is_wall_collision then
            return false
        end
        local best_cast_data = my_utility.get_best_point(best_target_position, wave_radius, area_data.victim_list)
        local victim_list = best_cast_data.victim_list or {}

        -- Get custom enemy weights from menu (fallback to defaults if not set)
        local normal_weight = 2
        local elite_weight = 10
        local champion_weight = 15
        local boss_weight = 50
        if menu_settings then
            normal_weight = (menu_settings.enemy_weight_normal and menu_settings.enemy_weight_normal:get()) or normal_weight
            elite_weight = (menu_settings.enemy_weight_elite and menu_settings.enemy_weight_elite:get()) or elite_weight
            champion_weight = (menu_settings.enemy_weight_champion and menu_settings.enemy_weight_champion:get()) or champion_weight
            boss_weight = (menu_settings.enemy_weight_boss and menu_settings.enemy_weight_boss:get()) or boss_weight
        end

        -- Sum weighted value of all enemies in victim_list
        local total_weight = 0
        for _, unit in ipairs(victim_list) do
            if unit:is_boss() then
                total_weight = total_weight + boss_weight
            elseif unit:is_champion() then
                total_weight = total_weight + champion_weight
            elseif unit:is_elite() then
                total_weight = total_weight + elite_weight
            else
                total_weight = total_weight + normal_weight
            end
        end

        if total_weight < menu_elements.min_hits:get() then
            return false
        end
        pathfinder.request_move(best_target_position)
        local in_range = my_utility.is_in_range(best_target, 3.5)
        if not in_range then
            return false
        end
        if cast_spell.target(best_target, spell_data.blood_wave.spell_id, 0, false) then
            local current_time = get_time_since_inject();
            next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast;
            console.print("Cast Blood Wave - Target (Weighted Min Hits): " .. total_weight)
            return true
        end
        return false
    end

    -- Fallback to original logic if min hits is not enabled
    if not target then return false end;
    local target_position = target:get_position()
    pathfinder.request_move(target_position)
    local in_range = my_utility.is_in_range(target, 3.5)
    if not in_range then
        return false;
    end
    if cast_spell.target(target, spell_data.blood_wave.spell_id, 0, false) then
        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + my_utility.spell_delays.regular_cast;
        console.print("Cast Blood Wave - Target: " ..
            my_utility.targeting_modes[menu_elements.targeting_mode:get() + 1]);
        return true;
    end;
    return false;
end

return
{
    menu = menu,
    logics = logics,
    menu_elements = menu_elements
}
