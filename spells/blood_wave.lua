local my_utility = require("my_utility/my_utility")
local spell_data = require("my_utility/spell_data")

local menu_elements =
{
    tree_tab          = tree_node:new(1),
    main_boolean      = checkbox:new(true, get_hash(my_utility.plugin_label .. "blood_wave_main_boolean")),
    targeting_mode    = combo_box:new(3, get_hash(my_utility.plugin_label .. "blood_wave_targeting_mode")),
    gather_blood_orbs = checkbox:new(true, get_hash(my_utility.plugin_label .. "blood_wave_gather_blood_orbs")),
    -- max_orb_range     = slider_int:new(12, 30, 16,
    --     get_hash(my_utility.plugin_label .. "blood_wave_max_orb_range_armored_hide")),
}

local function menu()
    if menu_elements.tree_tab:push("Blood Wave") then
        menu_elements.main_boolean:render("Enable Spell", "")

        if menu_elements.main_boolean:get() then
            menu_elements.gather_blood_orbs:render("Gather blood orbs", "Ultimat cooldown reduction with Fastblood")
            menu_elements.targeting_mode:render("Targeting Mode", my_utility.targeting_modes,
                my_utility.targeting_mode_description)

            -- if menu_elements.gather_blood_orbs:get() then
            --     menu_elements.max_orb_range:render("Evaluation Range", "Max range for gathering blood orbs")
            -- end
        end

        menu_elements.tree_tab:pop()
    end
end



local next_time_allowed_cast = 0.0;
local function logics(target)
    if not target then return false end;
    local menu_boolean = menu_elements.main_boolean:get();

    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean,
        next_time_allowed_cast,
        spell_data.blood_wave.spell_id);

    if not is_logic_allowed then return false end;

    -- Checking for target distance
    local in_range = my_utility.is_in_range(target, 4.5) -- 4.5 is the max range for blood wave
    if not in_range then
        -- move to target
        local target_position = target:get_position()
        pathfinder.request_move(target_position)
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
