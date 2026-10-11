-- Homecoming (Red War). A clean script on lib.flow, written section by section from Dawn's native
-- Homecoming (beat order and fixes) and the "Homecoming v40" Sunrise script (Dawn PR #8).
--
-- Done: intro (HRO fly-in) and Underwatch, up to Shaxx sending the player to gear up.
-- Next: armory, military/hangar, plaza, boulevard, command ship, generator, escape.
--
-- Progress is traced to sunrise.log through context:log (sdev log -Match script_log).
local missions = require("missions")
local mission = require(missions.MISSION_TOWERFALL)
local lib = require("lib.mission_lib")
local flow = require("lib.flow")
local dialogue = require("lib.dialogue")
local content = require("mission_towerfall.content")(mission)

local KEY = "hc"
-- Dawn sends a scene's entry inputs no sooner than this after its activation reaches transport.
local SCENE_ENTRY_MS = 500
-- Dawn holds a clear for this long before it counts.
local SETTLE_MS = 3000

local INTRO = "hc.intro"
local INTRO_PLAYING, INTRO_ENDED = 1, 2
local CAYDE_FINISHED = "hc.cayde.finished"

local talk = dialogue.new{key = KEY, sensor = content.sensors.dialogue, windows = content.dialogue_windows}

local function trace(context, text)
    local log = context.log
    if log ~= nil then log(context, "homecoming: " .. text) end
end

-- ---- presentation ------------------------------------------------------------------------------

-- A goal without a navpoint keeps its text and shows no marker.
local function show(context, goal)
    context:slot(content.sensors.directive):set_directive{
        directive = goal.directive,
        state = goal.state,
        navpoint = goal.navpoint ~= nil and context:slot(goal.navpoint) or nil,
        waypoint = goal.waypoint ~= nil and context:slot(goal.waypoint) or nil,
    }
end

-- One music section at a time: the previous one is switched off first.
local MUSIC = "hc.music"
local function music(context, state, section)
    local previous = state:variable(MUSIC)
    if previous == section then return end
    local sensor = context:slot(content.sensors.music)
    if previous ~= nil then sensor:set_music_section{section = previous, enabled = false} end
    sensor:set_music_section{section = section, enabled = true}
    context:set_variable(MUSIC, section)
end

-- ---- triggers ----------------------------------------------------------------------------------

-- A trigger fires once per arming. Every arm after its first fires on each update while the player
-- stays inside, so a trigger is disarmed when it reports.
local function armed_key(slot) return "armed/" .. slot.id end

local function arm(context, source)
    local slot = context:slot(source)
    context:set_variable(armed_key(slot), true)
    slot:fire_trigger()
end

local function trigger_fact(name)
    local source = lib.one(content.triggers[name], name)
    return {id = "pt." .. name, observe = function(context, _, event)
        return lib.is_slot(context, event, source)
    end}
end

local function pt(name) return flow.fact("pt." .. name) end

-- ---- squads ------------------------------------------------------------------------------------

-- Objective first, then placement.
local function spawn(encounter)
    return function(context)
        for _, member in ipairs(encounter) do
            context:slot(member.source):assign_combat_objective{objective = context:slot(member.objective)}
            context:squad(member.squad):place{}
        end
    end
end

-- An encounter is down when its loose squads were fully spawned and are dead, and none of its
-- scene squads is known to be alive. A scene squad that never reported (its scene did not spawn it)
-- does not block: the cohort knows nothing about it, so its alive count is nil.
local function scene_squads_down(context, squads)
    for _, squad in ipairs(squads) do
        local alive = context:cohort{squads = {squad}}.alive_count
        if alive ~= nil and alive > 0 then return false end
    end
    return true
end

local function down(encounter)
    return function(context)
        return context:cohort{squads = encounter.loose}.cleared
            and scene_squads_down(context, encounter.scene)
    end
end

-- A clear counts after it has held for SETTLE_MS. The timer re-arms itself while the encounter is
-- not down, so a squad that comes back resets the wait instead of passing it.
local function settle_timer(name) return "hc.settle." .. name end
local function settled_fact(name, encounter)
    local timer = settle_timer(name)
    local is_down = down(encounter)
    return {id = "settled." .. name, observe = function(context, _, event)
        if event.timer_name ~= timer then return false end
        if is_down(context) then return true end
        context:start_timer(timer, SETTLE_MS)
        return false
    end}
end

-- ---- hero scenes -------------------------------------------------------------------------------

-- activate{spawn=true} spawns the scene's authored cast. Its entry event is sent SCENE_ENTRY_MS
-- after the activation reaches transport ("staged"). A refused activation is logged and still
-- releases the step after it, so a broken scene cannot block the mission.
local function hero_request_key(name) return "hc.scene." .. name .. ".request" end
local function hero_timer(name) return "hc.scene." .. name .. ".entry" end

local function activate_hero(context, name)
    local hero = content.heroes[name]
    -- Combat objectives first, so the cast fights once the scene lets go of it.
    for _, entry in ipairs(hero.objectives or {}) do
        context:slot(entry.source):assign_combat_objective{objective = context:slot(entry.objective)}
    end
    -- Squads without an actor cell are left out of the cast; reserved, the client binds them.
    for _, squad in ipairs(hero.reserve or {}) do
        context:squad(squad):place{mode = context.sdk.squad_modes.reserve}
    end
    for _, cell in ipairs(hero.bind or {}) do context:slot(cell):bind_combatant_to_squad() end
    local request = context:scene(hero.scene):activate{spawn = true}
    context:set_variable(hero_request_key(name), request.value)
    trace(context, "scene " .. name .. " activated")
end

local function hero_event(context, name, key, label)
    context:scene(content.heroes[name].scene):send_event{key = key}
    trace(context, "scene " .. name .. " " .. label)
end

local function hero_entry(context, name)
    hero_event(context, name, content.heroes[name].entry, "entry event")
end

local function hero_ready_fact(name)
    local timer = hero_timer(name)
    return {id = "scene." .. name .. ".ready", observe = function(_, _, event)
        return event.timer_name == timer
    end}
end

-- ---- flow --------------------------------------------------------------------------------------

local graph
local facts = {
    -- The arrival answer for Underwatch: the client has loaded region 72 and placed the player.
    {id = "arrival", observe = function(_, _, event)
        return event.entered == true and event.held_region_index == content.underwatch.region_index
    end},
    settled_fact("first_contact", content.first_contact),
    settled_fact("approach", content.approach),
}
for _, name in ipairs(content.trigger_order) do facts[#facts + 1] = trigger_fact(name) end
for _, name in ipairs(content.hero_order) do facts[#facts + 1] = hero_ready_fact(name) end

local function cayde_finished(_, state) return state:variable(CAYDE_FINISHED) == true end

graph = flow.new{key = "homecoming", facts = facts, steps = {
    {id = "arrival", await = flow.fact("arrival")},

    -- U0: landing. Goal, music, the wall shut, Shaxx's doors and blocker, the hallway cast, Ghost.
    {id = "landing", after = {"arrival"}, run = function(context, state)
        show(context, content.goals.defend)
        music(context, state, content.music.underwatch_ruins)
        context:slot(content.wall):transition{transition = context.sdk.device_transitions.close}
        local doors = {content.shaxx_doors[1], content.shaxx_doors[2], content.shaxx_blocker}
        context:activate_objects{slots = doors, active = true}
        for _, squad in ipairs(content.landing_squads) do context:squad(squad):place{} end
        for _, name in ipairs(content.trigger_order) do arm(context, content.triggers[name]) end
        talk:say(context, state, content.lines.landing)
    end},
    -- U1: ambient scenes.
    {id = "ambient", after = {"arrival"}, run = function(context)
        for _, ambient in ipairs(content.ambient_scenes) do context:scene(ambient):activate{spawn = true} end
    end},

    -- U2-U3: the wall. Music, the backups, then the breach scene; its entry blows the wall.
    {id = "wall", after = {"landing"}, await = pt("wall")},
    {id = "breach", after = {"wall"}, run = function(context, state)
        music(context, state, content.music.first_cabal)
        spawn(content.encounters.breach_backup)(context)
        activate_hero(context, "breach")
    end, await = flow.fact("scene.breach.ready")},
    {id = "breach_entry", after = {"breach"}, run = function(context, state)
        hero_entry(context, "breach")
        context:slot(content.wall):transition{transition = context.sdk.device_transitions.open}
        talk:say(context, state, content.lines.breach)
    end},
    -- U4: "Cabal" purpose line once the first contact is down (no fixed delay).
    {id = "first_contact_down", after = {"breach_entry"}, await = down(content.first_contact)},
    {id = "first_contact_settle", after = {"first_contact_down"}, run = function(context)
        context:start_timer(settle_timer("first_contact"), SETTLE_MS)
    end, await = flow.fact("settled.first_contact")},
    {id = "first_contact_line", after = {"first_contact_settle"}, run = function(context, state)
        talk:say(context, state, content.lines.first_contact)
    end},

    -- U5-U7: the Centurion's scene, then its rush and drop-pod reinforcements at their triggers.
    {id = "centurion", after = {"landing"}, await = pt("centurion")},
    {id = "centurion_scene", after = {"centurion"}, run = function(context)
        activate_hero(context, "centurion")
    end, await = flow.fact("scene.centurion.ready")},
    {id = "centurion_entry", after = {"centurion_scene"}, run = function(context)
        hero_entry(context, "centurion")
    end},
    {id = "centurion_rush", after = {"landing"}, await = pt("centurion_reinforce")},
    {id = "centurion_rush_spawn", after = {"centurion_rush"}, run = spawn(content.encounters.centurion_rush)},
    {id = "drop_pod", after = {"landing"}, await = pt("drop_pod")},
    {id = "drop_pod_spawn", after = {"drop_pod"}, run = spawn(content.encounters.drop_pod)},

    -- U8-U9: civilians running from the blast; the hero moment.
    {id = "civ_run", after = {"landing"}, await = pt("civ_run")},
    {id = "civ_run_scenes", after = {"civ_run"}, run = function(context, state)
        for _, run_scene in ipairs(content.civ_run_scenes) do context:scene(run_scene):activate{spawn = true} end
        talk:say(context, state, content.lines.civ_run)
    end},
    {id = "hero_moment", after = {"landing"}, await = pt("hero_moment")},
    {id = "hero_moment_scene", after = {"hero_moment"}, run = function(context)
        for _, squad in ipairs(content.hero_moment_reserve) do
            context:squad(squad):place{mode = context.sdk.squad_modes.reserve}
        end
        context:scene(content.hero_moment):activate{spawn = true}
    end},

    -- U10: the approach is clear once every wave so far is down and has stayed down.
    {id = "approach_down", after = {"breach_entry", "centurion_entry", "centurion_rush_spawn", "drop_pod_spawn"},
        await = down(content.approach)},
    {id = "approach_settle", after = {"approach_down"}, run = function(context)
        context:start_timer(settle_timer("approach"), SETTLE_MS)
    end, await = flow.fact("settled.approach")},

    -- U11-U12: Cayde. His entry also drops Shaxx's blocker and quietly starts Shaxx's scene, so
    -- Shaxx exists by the time the player reaches him.
    {id = "cayde_near", after = {"approach_settle"},
        await = flow.any(pt("shaxx_enters"), pt("shaxx_enters_backup"))},
    {id = "cayde", after = {"cayde_near"}, run = function(context)
        activate_hero(context, "cayde")
    end, await = flow.fact("scene.cayde.ready")},
    {id = "cayde_entry", after = {"cayde"}, run = function(context)
        hero_entry(context, "cayde")
        context:activate_objects{slots = {content.shaxx_blocker}, active = false}
        activate_hero(context, "shaxx")
    end},
    -- U13: music changes when Cayde's scene is done. Sunrise delivered no scene_finished at all in
    -- playtest 2, so reaching Shaxx also counts; only the music waits on this.
    {id = "cayde_done", after = {"cayde_entry"},
        await = flow.any(cayde_finished, pt("start_shaxx"), pt("near_shaxx"))},
    {id = "after_cayde", after = {"cayde_done"}, run = function(context, state)
        music(context, state, content.music.after_cayde)
    end},
    -- U14: Shaxx sends the player to gear up once Cayde's scene has started and the player is near.
    -- Never wait on Shaxx's (or Cayde's) scene finishing.
    {id = "shaxx_near", after = {"cayde_entry"},
        await = flow.all(flow.any(pt("start_shaxx"), pt("near_shaxx")), flow.fact("scene.shaxx.ready"))},
    {id = "shaxx", after = {"shaxx_near"}, run = function(context)
        hero_entry(context, "shaxx")
        show(context, content.goals.gear_up)
        trace(context, "Underwatch complete; the armory is not scripted yet")
    end},
}}

-- ---- parts 2-3: armory and military -----------------------------------------------------------
-- A second graph: lib.flow keeps at most 64 steps and 64 facts per graph. It starts once Shaxx has
-- sent the player to gear up.

local armory, military = content.armory, content.military

local function arm_all(context, triggers, order)
    for _, name in ipairs(order) do arm(context, triggers[name]) end
end

local function timer_fact(id, timer)
    return {id = id, observe = function(_, _, event) return event.timer_name == timer end}
end

local function object_present_fact(id, object)
    return {id = id, observe = function(context, _, event)
        return lib.is_slot(context, event, object) and event.present == true
    end}
end

local function slot_fact(prefix, name, source)
    return {id = prefix .. name, observe = function(context, _, event)
        return lib.is_slot(context, event, source)
    end}
end

-- One actor per authored lane unless the member names its own counts (Dawn's request policy).
local function place_lanes(context, member, objective)
    context:slot(member.source):assign_combat_objective{objective = context:slot(objective)}
    local squad = context:squad(member.squad)
    local counts = squad:counts()
    for lane = 1, counts.count do
        counts:set(lane, member.counts ~= nil and member.counts[lane] or 1)
    end
    squad:place{counts = counts}
end

local function device_open(device)
    return function(context)
        return context:slot(device):applied{channel = context.sdk.device_channels.position}
    end
end

local function open(context, device)
    context:slot(device):transition{transition = context.sdk.device_transitions.open}
end

local function close(context, device)
    context:slot(device):transition{transition = context.sdk.device_transitions.close}
end

local POST_GUN_MIN = "hc.postgun.min"     -- 18EF2ABC no sooner than 3 s after 38857CF3
local POD_FALLBACK = "hc.pod.fallback"     -- the pod's presence report, or 5 s
local DESTROYER_FALLBACK = "hc.destroyer.fallback"

local facts_b = {
    {id = "military", observe = function(_, _, event)
        local region = military.state.region_index
        return (event.previous_region_index ~= nil and event.region_index == region)
            or (event.entered == true and event.held_region_index == region)
    end},
    {id = "rack.used", observe = function(context, _, event)
        return lib.is_slot(context, event, armory.rack) and event.has_owner == true
    end},
    object_present_fact("pod.present", military.drop_pod),
    object_present_fact("destroyer.present", military.destroyer),
    timer_fact("postgun.min", POST_GUN_MIN),
    timer_fact("pod.fallback", POD_FALLBACK),
    timer_fact("destroyer.fallback", DESTROYER_FALLBACK),
    settled_fact("gate_start", military.gate_start_clear),
    settled_fact("gate_hangar", military.gate_hangar_clear),
}
for _, name in ipairs(armory.trigger_order) do facts_b[#facts_b + 1] = slot_fact("pt.", name, armory.triggers[name]) end
for _, name in ipairs(military.trigger_order) do facts_b[#facts_b + 1] = slot_fact("pt.", name, military.triggers[name]) end
for _, name in ipairs(content.hero_order_b) do facts_b[#facts_b + 1] = hero_ready_fact(name) end

local function scenes_ready(order)
    local list = {}
    for index, name in ipairs(order) do list[index] = flow.fact("scene." .. name .. ".ready") end
    return flow.all(table.unpack(list))
end

local graph_b = flow.new{key = "homecoming.b", facts = facts_b, steps = {
    -- A0: the armory opens as soon as Shaxx sends the player to gear up.
    {id = "armory", await = function(context, state) return graph:started(context, state, "shaxx") end},
    {id = "armory_open", after = {"armory"}, run = function(context)
        arm_all(context, armory.triggers, armory.trigger_order)
        open(context, armory.gun_door)
        context:slot(armory.rack):set_interactable_object{active = true, used = false, track_owner = true}
        activate_hero(context, "post_gun")
    end},
    -- A1: armory music on the weapon room trigger (stands in for the music volume).
    {id = "armory_music", after = {"armory_open"}, await = pt("weapon")},
    {id = "armory_music_on", after = {"armory_music"}, run = function(context, state)
        music(context, state, content.music.shaxx_door)
    end},
    -- Post-gun fight: start it, then release its Cabal from a trigger, late.
    {id = "post_gun_start", after = {"armory_open"}, await = flow.fact("scene.post_gun.ready")},
    {id = "post_gun_entry", after = {"post_gun_start"}, run = function(context)
        hero_entry(context, "post_gun")
        context:start_timer(POST_GUN_MIN, 3000)
    end},
    {id = "post_gun_release", after = {"post_gun_entry"},
        await = flow.all(flow.any(pt("post_gun"), pt("weapon_complete")), flow.fact("postgun.min"))},
    {id = "post_gun_released", after = {"post_gun_release"}, run = function(context)
        hero_event(context, "post_gun", content.release_key, "release event")
    end},
    -- A2: the evacuation announcement.
    {id = "post_gun_line", after = {"armory_open"}, await = pt("post_gun")},
    {id = "post_gun_said", after = {"post_gun_line"}, run = function(context, state)
        talk:say(context, state, content.lines.post_gun)
    end},
    -- A3: the rifle. An owned report from the rack, or the weapon-complete trigger, ends the step.
    -- The rewards go through context:grant_reward (the world-reward queue); builds without it skip
    -- the grant and the player keeps their loadout.
    {id = "weapon", after = {"armory_open"}, await = flow.any(flow.fact("rack.used"), pt("weapon_complete"))},
    {id = "weapon_taken", after = {"weapon"}, run = function(context, state)
        context:slot(armory.rack):set_interactable_object{active = false, used = true}
        local grant = context.grant_reward
        if grant ~= nil then
            for _, item in ipairs(armory.rewards) do grant(context, {item = item}) end
            trace(context, "armory weapons granted")
        else
            trace(context, "no context:grant_reward in this build; weapons not granted")
        end
        talk:say(context, state, content.lines.weapon)
        show(context, armory.goal)
    end},
    -- A4: leaving the armory.
    {id = "armory_exit", after = {"weapon_taken", "post_gun_released"}, await = pt("goto_military")},

    -- M0: military. Goal, both Amanda gates shut, triggers, the hangar checkpoint, the fake fights.
    {id = "military", after = {"armory_open"}, await = flow.fact("military")},
    {id = "military_enter", after = {"military"}, run = function(context)
        show(context, military.goal)
        close(context, military.gate_start)
        close(context, military.gate_hangar)
        arm_all(context, military.triggers, military.trigger_order)
        for _, member in ipairs(military.checkpoint) do place_lanes(context, member, military.objective) end
        for _, name in ipairs(military.scene_order) do activate_hero(context, name) end
        trace(context, "military entered")
    end},
    -- M1-M2: the drop pod lands, then the hallway Legionary comes out of it.
    {id = "pod", after = {"military_enter"}, await = pt("hangar_spawn")},
    {id = "pod_drop", after = {"pod"}, run = function(context)
        context:slot(military.drop_pod):set_object_active{active = true}
        context:start_timer(POD_FALLBACK, 5000)
    end},
    {id = "pod_landed", after = {"pod_drop"}, await = flow.any(flow.fact("pod.present"), flow.fact("pod.fallback"))},
    {id = "pod_legionary", after = {"pod_landed"}, run = function(context, state)
        local hallway = military.hallway
        context:slot(hallway.source):assign_combat_objective{objective = context:slot(military.objective)}
        context:squad(hallway.squad):place{spawn_rule = context:slot(hallway.spawn_rule)}
        music(context, state, content.music.first_pod)
    end},
    -- The fake fights' Cabal become damageable when the player reaches the hangar spawn.
    {id = "fake_fights", after = {"military_enter"},
        await = flow.all(pt("hangar_spawn"), scenes_ready(military.scene_order))},
    {id = "fake_fights_released", after = {"fake_fights"}, run = function(context)
        for _, name in ipairs(military.scene_order) do
            hero_event(context, name, content.release_key, "release event")
        end
    end},
    -- M3-M6: gate 40 when the overlook is down, gate 41 when the far overlook is down.
    {id = "gate_start_down", after = {"pod_legionary"}, await = down(military.gate_start_clear)},
    {id = "gate_start_settle", after = {"gate_start_down"}, run = function(context)
        context:start_timer(settle_timer("gate_start"), SETTLE_MS)
    end, await = flow.fact("settled.gate_start")},
    {id = "gate_start_open", after = {"gate_start_settle"}, run = function(context)
        open(context, military.gate_start)
    end, await = device_open(military.gate_start)},
    {id = "gate_hangar_down", after = {"gate_start_open"}, await = down(military.gate_hangar_clear)},
    {id = "gate_hangar_settle", after = {"gate_hangar_down"}, run = function(context)
        context:start_timer(settle_timer("gate_hangar"), SETTLE_MS)
    end, await = flow.fact("settled.gate_hangar")},
    {id = "gate_hangar_open", after = {"gate_hangar_settle"}, run = function(context)
        open(context, military.gate_hangar)
    end, await = device_open(military.gate_hangar)},
    -- M7-M8: the destroyer, then its missiles.
    {id = "destroyer", after = {"gate_hangar_open"}, run = function(context)
        context:slot(military.destroyer):set_object_active{active = true}
        context:start_timer(DESTROYER_FALLBACK, 5000)
    end, await = flow.any(flow.fact("destroyer.present"), flow.fact("destroyer.fallback"))},
    {id = "missiles", after = {"destroyer"}, run = function(context)
        context:activate_objects{slots = military.missiles, active = true}
    end},
    -- M9: the hangar window line needs the window and the ship.
    {id = "window_line", after = {"destroyer"}, await = pt("hangar_window")},
    {id = "window_said", after = {"window_line"}, run = function(context, state)
        talk:say(context, state, content.lines.hangar_window)
    end},
    -- M10: hangar combat: line and the ship-reveal music.
    {id = "hangar_combat", after = {"military_enter"}, await = pt("hangar_combat")},
    {id = "hangar_combat_on", after = {"hangar_combat"}, run = function(context, state)
        talk:say(context, state, content.lines.hangar_combat)
        music(context, state, content.music.cabal_ship_reveal)
    end},
    -- M11: out toward the plaza: needs gate 41 open (pt_skip_hangar overlaps the exit trigger).
    {id = "goto_plaza", after = {"gate_hangar_open", "fake_fights_released"}, await = pt("goto_plaza")},
    {id = "military_done", after = {"goto_plaza"}, run = function(context, state)
        talk:say(context, state, content.lines.goto_plaza)
        trace(context, "military complete; the plaza is not scripted yet")
    end},
}}

-- ---- intro -------------------------------------------------------------------------------------

-- The client holds the cutscene region, so only its start is owed. The spawn is held through the
-- cutscene: a body built there would be placed inside Underwatch's geometry.
local function start_intro(context, state, region)
    if region ~= content.intro.state.region_index or state:variable(INTRO) ~= nil then return end
    context:set_variable(INTRO, INTRO_PLAYING)
    context:slot(content.intro.cinematic):set_cinematic_active{active = true}
    trace(context, "intro cinematic started")
end

local function end_intro(context, state)
    if state:variable(INTRO) ~= INTRO_PLAYING then return end
    context:set_variable(INTRO, INTRO_ENDED)
    -- Stop before the state change, or the rebuilt component plays the cutscene again.
    context:slot(content.intro.cinematic):set_cinematic_active{active = false}
    context:select_state(content.underwatch, content.omit)
    context:hold_spawn{active = false}
    trace(context, "intro ended; selecting Underwatch")
end

local function end_reported_intro(context, state, event)
    if lib.is_slot(context, event, content.intro.cinematic) then end_intro(context, state) end
end

-- ---- event plumbing ----------------------------------------------------------------------------

local function handle(context, state, event)
    graph:handle(context, state, event)
    graph_b:handle(context, state, event)
end

local function advance(context, state)
    graph:advance(context, state)
    graph_b:advance(context, state)
end

local function player_trigger(context, state, event)
    if event.slot ~= nil and state:variable(armed_key(event.slot)) == true then
        context:clear_variable(armed_key(event.slot))
        event.slot:disarm_trigger()
    end
    handle(context, state, event)
end

-- A hero activation reaching transport starts its entry timer; a refusal is logged and starts it
-- anyway, so the steps after the scene still run.
local function hero_activation_result(context, state, event, order)
    for _, name in ipairs(order) do
        local key = hero_request_key(name)
        local pending = state:variable(key)
        if pending ~= nil and event.request_key.value == pending then
            context:clear_variable(key)
            if event.outcome ~= "transport_staged" then
                trace(context, "scene " .. name .. " activation " .. tostring(event.outcome))
            end
            context:start_timer(hero_timer(name), content.heroes[name].entry_delay_ms or SCENE_ENTRY_MS)
            return true
        end
    end
    return false
end

local function effect_result(context, state, event)
    if event.request_key == nil then return end
    if hero_activation_result(context, state, event, content.hero_order) then return end
    hero_activation_result(context, state, event, content.hero_order_b)
end

local function scene_finished(context, state, event)
    if lib.is_slot(context, event, content.heroes.cayde.slot) then
        context:set_variable(CAYDE_FINISHED, true)
        trace(context, "scene cayde finished")
    end
    handle(context, state, event)
end

return {
    initial_state = {
        region_index = content.intro.state.region_index,
        omit = content.omit,
    },
    on_start = function(context, state)
        context:hold_spawn{active = true}
        advance(context, state)
    end,
    -- A reattach lands in the world, so a cutscene still marked playing is ended, not replayed.
    on_load = function(context, state)
        end_intro(context, state)
        talk:resume(context, state)
        advance(context, state)
    end,
    on_event_region_changed = function(context, state, event)
        start_intro(context, state, event.region_index)
        handle(context, state, event)
    end,
    -- Only the arrival answer feeds the graph: a pending leg report names a region not yet loaded.
    on_event_client_state_changed = function(context, state, event)
        if event.entered == true then
            start_intro(context, state, event.held_region_index)
            handle(context, state, event)
        end
    end,
    on_event_cinematic_terminated = end_reported_intro,
    on_event_cinematic_skip_requested = end_reported_intro,
    on_event_player_trigger = player_trigger,
    on_event_effect_result = effect_result,
    on_event_timer_elapsed = function(context, state, event)
        if talk:handle_timer(context, state, event) then return end
        if lib.orbit_return_elapsed(context, event) then return end
        handle(context, state, event)
    end,
    on_event_scene_finished = scene_finished,
    on_event_squad_state = handle,
    on_event_trigger_entered = handle,
    on_event_object_state = handle,
    on_event_object_interacted = handle,
    on_event_device_state = handle,
}
