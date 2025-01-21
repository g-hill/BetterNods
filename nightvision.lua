-- Initialize variables
ENABLED = false
SOUNDS_ENABLED = true
BATTERY_LEVEL = 100
BATTERY_DRAIN_RATE = 0.0005  -- Battery drains % per minute
NVG_TYPE = 1  -- 1=Green, 2=White, 3=Amber

local nightvision_on = load_WAV_file(SYSTEM_DIRECTORY .. "Resources/plugins/FlyWithLua/scripts/nightvision_sounds/nightvision_on.wav")
local nightvision_off = load_WAV_file(SYSTEM_DIRECTORY .. "Resources/plugins/FlyWithLua/scripts/nightvision_sounds/nightvision_off.wav")
local ev100_sliderVal = get("sim/private/controls/photometric/ev100")
local noise_level = 0.02  -- Default noise level
local gain_level = 1.0    -- Default gain multiplier

-- Function to play sound if enabled
function play_sound_if_enabled(sound)
    if SOUNDS_ENABLED then
        play_sound(sound)
    end
end

-- Battery simulation
function update_battery()
    if ENABLED and BATTERY_LEVEL > 0 then
        BATTERY_LEVEL = BATTERY_LEVEL - BATTERY_DRAIN_RATE
        if BATTERY_LEVEL <= 0 then
            BATTERY_LEVEL = 0
            disable_nightvision()
            logMsg("Night vision disabled - Battery depleted")
        end
    end
end

do_every_frame("update_battery()")

-- Function to enable night vision
function enable_nightvision()
    if BATTERY_LEVEL <= 0 then
        logMsg("Cannot enable night vision - Battery depleted")
        return
    end

    local local_seconds = get("sim/time/local_time_sec")
    local hours_since_midnight = local_seconds / 3600
    if hours_since_midnight >= 4.8 and hours_since_midnight <= 5.3 then
        set("sim/private/controls/photometric/ev100", -10) 
    elseif hours_since_midnight >= 5.4 and hours_since_midnight <= 17 then
        set("sim/private/controls/photometric/ev100", 0/0)
    else 
        set("sim/private/controls/photometric/ev100", -3)
    end
    
    set("sim/private/controls/tonemap/grayscale", 1)
    set("sim/private/controls/photometric/light_storage_scale", 200 * gain_level)
    set("sim/private/controls/stars/gain_photometric", 5000 * gain_level)
    set("sim/private/controls/photometric/interior_lit_boost", 1)
    set("sim/private/controls/photometric/K", 20)
    set("sim/private/controls/lights/spill_cutoff_level", 0.1)
    set("sim/cockpit/electrical/night_vision_on", 1)
    set("sim/private/controls/nightvision/static_alpha", noise_level)
    
    logMsg("Nightvision enabled")
    logMsg(string.format("Current time: %.2f hours since midnight", hours_since_midnight))
    ENABLED = true
end

-- Function to disable night vision
function disable_nightvision()
    set("sim/private/controls/photometric/ev100", 0/0)
    set("sim/private/controls/tonemap/grayscale", 0)
    set("sim/private/controls/photometric/light_storage_scale", 1)
    set("sim/private/controls/stars/gain_photometric", 100)
    set("sim/private/controls/photometric/interior_lit_boost", 2.5)
    set("sim/private/controls/photometric/K", 12.5)
    set("sim/private/controls/lights/spill_cutoff_level", 0.025)
    set("sim/cockpit/electrical/night_vision_on", 0)
    set("sim/private/controls/nightvision/static_alpha", .03)
    logMsg("Nightvision disabled")
    ENABLED = false
end

-- UI STUFF
if not SUPPORTS_FLOATING_WINDOWS then
    logMsg("imgui not supported by your FlyWithLua version")
    return
end

function build_nightvision(nightvision_wnd, x, y)
    imgui.TextUnformatted("BetterNODs Options")
    imgui.TextUnformatted("")

    -- Battery status display (simplified without color)
    if BATTERY_LEVEL > 70 then
        imgui.TextUnformatted(string.format("Battery: %.1f%% (Good)", BATTERY_LEVEL))
    elseif BATTERY_LEVEL > 30 then
        imgui.TextUnformatted(string.format("Battery: %.1f%% (Warning)", BATTERY_LEVEL))
    else
        imgui.TextUnformatted(string.format("Battery: %.1f%% (Critical)", BATTERY_LEVEL))
    end
    
    -- Main controls
    local changed, newValue = imgui.Checkbox("Enable Nightvision", ENABLED)
    if changed then
        if newValue then
            play_sound_if_enabled(nightvision_on)
            enable_nightvision()
        else
            play_sound_if_enabled(nightvision_off)
            disable_nightvision()
        end
    end

    -- Sound toggle
    local sounds_changed, sounds_newValue = imgui.Checkbox("Enable Sounds", SOUNDS_ENABLED)
    if sounds_changed then
        SOUNDS_ENABLED = sounds_newValue
    end

    imgui.TextUnformatted("")
    imgui.TextUnformatted("Visual Settings")

    -- Noise control
    local noise_changed, noise_new = imgui.SliderFloat("Noise Level", noise_level, 0.0, 0.1, "%.3f")
    if noise_changed then
        noise_level = noise_new
        if ENABLED then
            set("sim/private/controls/nightvision/static_alpha", noise_level)
        end
    end

    -- Gain control
    local gain_changed, gain_new = imgui.SliderFloat("Gain", gain_level, 0.1, 2.0, "%.2f")
    if gain_changed then
        gain_level = gain_new
        if ENABLED then
            set("sim/private/controls/photometric/light_storage_scale", 200 * gain_level)
            set("sim/private/controls/stars/gain_photometric", 5000 * gain_level)
        end
    end

    -- Iris control
    imgui.TextUnformatted("More Open")
    imgui.SameLine()
    local change_ev100, ev100_New = imgui.SliderFloat("", ev100_sliderVal, -20, 20, "Iris Value: %.2f")
    if change_ev100 then
        ev100_sliderVal = ev100_New
        set("sim/private/controls/photometric/ev100", ev100_New)
    end
    imgui.SameLine()
    imgui.TextUnformatted("More Closed")

    -- Battery controls
    imgui.TextUnformatted("")
    if imgui.Button("Replace Battery") then
        BATTERY_LEVEL = 100
        logMsg("Battery replaced")
    end
end

function nightvision_show_wnd()
    nightvision_wnd = float_wnd_create(500, 300, 1, true)  -- Made window taller for new controls
    float_wnd_set_title(nightvision_wnd, "BetterNODs v2.3")  -- Updated version number
    float_wnd_set_imgui_builder(nightvision_wnd, "build_nightvision")
end

-- Toggle function for night vision
function toggle_nightvision()
    if ENABLED then
        play_sound_if_enabled(nightvision_off)
        disable_nightvision()
    else
        play_sound_if_enabled(nightvision_on)
        enable_nightvision()
    end
end

-- Create the macro for toggling night vision
add_macro("Toggle Nightvision", "toggle_nightvision()")
add_macro("Nightvision Options", "nightvision_show_wnd()")

-- Create a custom command for toggling night vision and window
create_command("FlyWithLua/Nightvision/toggle", "Toggle Nightvision",
    "toggle_nightvision()", "", "")

create_command("FlyWithLua/Nightvision/showOptions", "Show/Hide Nightvision Options",
    "nightvision_show_wnd()", "", "")