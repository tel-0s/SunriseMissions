local missions = require("missions")
local mission = require(missions.ADVENTURE_GINGER)
local lib = require("lib.mission_lib")
local flow = require("lib.flow")
local content = require("adventure_ginger.content")(mission)

-- Wipe state outlives the attempt a restart retires.
local WIPED = "deadly_trial.wiped"
local WIPE_REQUEST = "deadly_trial.wipe_request"
local RESPAWNING = "deadly_trial.respawning"
-- The revival scene's last line (row 10) ends about 11.2 s after the ghost link closes
-- (48.675 s + 250 ms tail against the link's ~37.75 s).
local TAIL_TIMER = "deadly_trial.tail"
local TAIL_MS = 11200

local function population(encounter)
    local squads = {}
    for _, member in ipairs(encounter) do squads[#squads + 1] = member.squad end
    return squads
end

-- Assign the objective before the placement. A squad body that changes after its members exist
-- reports alive 0 for about a second, and the cohort reads that as cleared.
local function spawn(encounter)
    return function(context)
        for _, member in ipairs(encounter) do
            context:slot(member.source):assign_combat_objective{
                objective = context:slot(member.objective), task_group = member.group,
            }
            local squad = context:squad(member.squad)
            local args = {}
            if member.count ~= nil then
                args.counts = squad:counts()
                args.counts:set(1, member.count)
            end
            if member.spawn_rule ~= nil then
                args.spawn_rule = context:slot(member.spawn_rule)
            end
            squad:place(args)
        end
    end
end

-- Zero counts send the squad inactive, so the client destroys its members.
local function despawn(encounter)
    return function(context)
        for _, member in ipairs(encounter) do
            local squad = context:squad(member.squad)
            local counts = squad:counts()
            for index = 1, counts.count do counts:set(index, 0) end
            squad:place{counts = counts}
        end
    end
end

local function cleared(encounter)
    local squads = population(encounter)
    return function(context) return context:cohort{squads = squads}.cleared end
end

-- The client holds a filtered line until the player enters the filter volume.
local function say(context, line)
    context:slot(content.dialogue_sensor):play_dialogue_cue{
        cue = line.cue,
        filter = line.filter ~= nil and context:slot(line.filter) or nil,
    }
end

-- A goal without a navpoint keeps its text and shows no marker.
local function show(context, goal, line)
    context:slot(content.directive_sensor):set_directive{
        directive = goal.directive,
        navpoint = goal.navpoint ~= nil and context:slot(goal.navpoint) or nil,
        waypoint = goal.waypoint ~= nil and context:slot(goal.waypoint) or nil,
    }
    if line ~= nil then
        say(context, line)
    end
end

-- The Skiff is spawned, stops at its entrance point, hovers, then leaves.
local function fly(context, skiff)
    context:slot(skiff.actor):run_atoms{spawn = true, atoms = {
        {kind = context.sdk.atom_kinds.ability, ability = skiff.enter,
            target = context:slot(skiff.enter_point)},
        {kind = context.sdk.atom_kinds.sleep, seconds = 6},
        {kind = context.sdk.atom_kinds.ability, ability = skiff.exit,
            target = context:slot(skiff.exit_point)},
    }}
end

-- A trigger fires once per arming. Every arm after its first fires on each update while the
-- player stays inside, so the script disarms a trigger when it reports.
local function armed_key(slot)
    return "armed/" .. slot.id
end

local function arm(context, source)
    local slot = context:slot(source)
    context:set_variable(armed_key(slot), true)
    slot:fire_trigger()
end

local function trigger_fact(name)
    local source = lib.one(content.triggers[name], name)
    return {id = name, observe = function(context, _, event)
        return lib.is_slot(context, event, source)
    end}
end

local graph
local facts = {
    -- `entered` marks the host's arrival answer, the roster the client spawns on. The leg report
    -- and the client's empty reports all come while it is still loading.
    {id = "arrival", observe = function(_, _, event)
        return event.entered == true
            and event.held_region_index == content.initial_state.region_index
    end},
    {id = "alleys_a", observe = function(_, _, event)
        return event.region_index == content.alleys_a.region_index
    end},
    {id = "alleys_b", observe = function(_, _, event)
        return event.region_index == content.alleys_b.region_index
    end},
    {id = "pedestal.used", observe = function(context, state, event)
        return graph:started(context, state, "revive")
            and lib.is_slot(context, event, content.pedestal)
    end},
    {id = "revival.started", observe = function(context, state, event)
        return graph:started(context, state, "revive")
            and lib.is_slot(context, event, content.ghost_link)
            and event.active == true and (event.progress or 0) > 0
    end},
    {id = "tower.top", observe = function(context, _, event)
        return lib.is_slot(context, event, content.tower_top)
    end},
    {id = "revival.finished", observe = function(context, state, event)
        return graph:fact(context, state, "revival.started")
            and lib.is_slot(context, event, content.ghost_link)
            and event.active == false
    end},
    {id = "revival.tail", observe = function(_, _, event)
        return event.timer_name == TAIL_TIMER
    end},
}
for _, name in ipairs({
    "square.entered", "pikes.reached", "outpost.entered", "tower.inside",
    "streets.entered", "choke.entered", "overpass.entered",
    "overpass.dropship", "overpass.directive", "trial.directive", "cliff.entered",
    "tunnel.entered", "tower.directive", "lair.entered", "bodies.entered",
}) do
    facts[#facts + 1] = trigger_fact(name)
end

local overpass = flow.any(flow.fact("overpass.entered"), flow.fact("overpass.dropship"),
    flow.fact("overpass.directive"))
local choke = flow.any(flow.fact("choke.entered"), overpass)
local streets = flow.any(flow.fact("streets.entered"), choke)
-- Only the Walker's arena has a barrier. Every other fight can be skipped, so a step that waits
-- on a clear also ends when the player reaches a later trigger.
local bodies = flow.fact("bodies.entered")
local lair = flow.any(flow.fact("lair.entered"), bodies)
local tower = flow.any(flow.fact("tower.directive"), flow.fact("outpost.entered"), lair)
local tunnel = flow.any(flow.fact("tunnel.entered"), tower)
local cliff = flow.any(flow.fact("cliff.entered"), tunnel)
local trial = flow.any(flow.fact("trial.directive"), cliff)
local past_square = flow.any(flow.fact("pikes.reached"), streets)
local below_tower = flow.any(flow.fact("tower.inside"), lair)

local function cleared_or(encounter, moved_on)
    return flow.any(cleared(encounter), moved_on)
end

graph = flow.new{key = "deadly_trial", facts = facts, steps = {
    {id = "arrival", await = flow.fact("arrival")},
    -- In the town the marker points at the crossing; the trigger registers the navpoint's object.
    {id = "coordinates", after = {"arrival"}, run = function(context)
        arm(context, content.goals.town.trigger)
        show(context, content.goals.town, content.dialogue.opening)
    end},
    {id = "prepare_a", await = flow.fact("alleys_a")},
    {id = "initial_a", after = {"prepare_a"}, run = function(context)
        context:slot(content.barrier):transition{transition = context.sdk.device_transitions.close}
    end},
    -- Past the crossing the same goal points at the square, so no popup shows. The square's
    -- squads stand there before the player arrives.
    {id = "alleys_marker", after = {"coordinates", "initial_a"}, run = function(context)
        show(context, content.goals.coordinates)
        spawn(content.encounters.square)(context)
    end},
    {id = "prepare_b", await = flow.fact("alleys_b")},
    {id = "initial_b", after = {"prepare_b"}},
    {id = "square", after = {"alleys_marker"},
        await = flow.any(flow.fact("square.entered"), past_square)},
    -- The goto marker is reached at the square; the goal text stays with no marker until the
    -- fight is over.
    {id = "square_fight", after = {"square"}, run = function(context)
        show(context, {directive = content.goals.coordinates.directive})
    end, await = cleared_or(content.encounters.square, past_square)},
    -- After the square the followers' Pikes appear and the goal asks the player to take one
    -- ("Commandeer a Fallen Pike"). The Pikes stay out of the seed until now.
    {id = "rendezvous_marker", after = {"square_fight"}, run = function(context)
        context:activate_objects{slots = content.pikes.square, active = true}
        show(context, content.goals.pike)
    end},
    -- The pike trigger just past the square starts the next goal; its line waits in the filter
    -- volume beyond it.
    {id = "followers", after = {"rendezvous_marker"},
        await = flow.any(flow.fact("pikes.reached"), streets)},
    {id = "faith", after = {"followers"}, run = function(context)
        show(context, content.goals.path, content.dialogue.followers)
    end},
    {id = "streets", after = {"faith"}, await = streets},
    {id = "street_resistance", after = {"streets"}, run = spawn(content.encounters.streets)},
    {id = "choke", after = {"street_resistance"}, await = choke},
    {id = "choke_resistance", after = {"choke"}, run = spawn(content.encounters.choke)},
    {id = "overpass", after = {"choke_resistance"}, await = overpass},
    {id = "roadblock", after = {"overpass"}, run = function(context)
        show(context, content.goals.walker)
        spawn(content.encounters.overpass_support)(context)
        spawn(content.encounters.walker)(context)
        fly(context, content.skiff)
    end},
    {id = "walker_clear", after = {"roadblock"}, await = cleared(content.encounters.walker)},
    {id = "tower_enable", after = {"walker_clear", "initial_b"}, run = function(context)
        spawn(content.encounters.tunnel_exit)(context)
    end},
    -- The Walker's death starts the tunnel goal.
    {id = "barrier", after = {"walker_clear"}, run = function(context)
        context:slot(content.barrier):transition{transition = context.sdk.device_transitions.open}
        show(context, content.goals.temple)
        context:activate_objects{slots = content.pikes.roadblock, active = true}
    -- The barrier's applied report ends the wait. Reaching the trial past it does too, so a lost
    -- device report cannot stall every later step.
    end, await = flow.any(function(context)
        return context:slot(content.barrier):applied{channel = context.sdk.device_channels.position}
    end, trial)},
    -- The tunnel is open once the barrier is down; the line's authored pause is three seconds.
    {id = "tunnel_line", after = {"barrier"}, run = function(context)
        say(context, content.dialogue.survival)
    end},
    {id = "temple_pikes", after = {"walker_clear", "initial_b"}, run = function(context)
        context:activate_objects{slots = content.pikes.temple, active = true}
    end},
    {id = "trial", after = {"barrier"}, await = trial},
    -- Past the tunnel the same goal points at the alleys B crossing. Its object registers when
    -- the alleys B watcher arms its trigger.
    {id = "survival", after = {"trial", "initial_b"}, run = function(context)
        show(context, content.goals.observatory)
    end},
    {id = "cliff", after = {"survival", "initial_b"}, await = cliff},
    {id = "cliff_resistance", after = {"cliff"}, run = spawn(content.encounters.cliff)},
    {id = "tunnel", after = {"cliff_resistance"}, await = tunnel},
    {id = "tunnel_resistance", after = {"tunnel"}, run = spawn(content.encounters.tunnel)},
    {id = "tower", after = {"tunnel_resistance", "tower_enable"}, await = tower},
    {id = "tower_fight", after = {"tower"}, run = function(context)
        show(context, content.goals.tower)
    end, await = cleared_or(content.encounters.tower, below_tower)},
    -- A darkness wipe restarts here, and every outpost step below runs again. The tunnel-exit
    -- squads and the temple pikes come back at once, and the outpost triggers are armed again.
    {id = "outpost", after = {"initial_b"}, checkpoint = true,
        reset_facts = {"outpost.entered", "tower.directive", "tower.top"},
        run = function(context, state)
            if state:variable(WIPED) == true then
                context:clear_variable(WIPED)
                spawn(content.encounters.tunnel_exit)(context)
                context:activate_objects{slots = content.pikes.temple, active = true}
                for _, source in ipairs(content.outpost_triggers) do
                    arm(context, source)
                end
            end
        end, await = flow.fact("outpost.entered")},
    -- Entering the outpost places its squads and brings a Skiff that drops infantry below its
    -- hover point. Squads placed from the alleys B entry, far away, did not all spawn.
    {id = "outpost_skiff", after = {"outpost"}, run = function(context)
        spawn(content.encounters.tower)(context)
        -- No filter: the client measures its default player set in the tower top volume.
        context:slot(content.tower_top):set_occupancy_condition{value = 1}
        fly(context, content.outpost_skiff)
        spawn(content.encounters.outpost_drop)(context)
    end},
    -- A filtered line plays reliably only when the player is already in its volume, so each
    -- outpost line is sent when a trigger inside that volume reports. The observatory trigger lies
    -- in the bowl; it also makes the outpost a darkness zone.
    {id = "observatory", after = {"outpost"}, await = flow.fact("tower.directive")},
    {id = "outpost_dark", after = {"observatory"}, run = function(context)
        context:slot(content.darkness):set_darkness_zone{enabled = true}
        say(context, content.dialogue.tower)
    end},
    -- "Head down, not up" plays on top of the tower; a player who went down never hears it.
    -- TODO: confirm live that the unfiltered tower-top monitor reports the player at the top.
    {id = "climb", after = {"outpost_skiff"}, await = flow.fact("tower.top")},
    {id = "climb_line", after = {"climb"}, run = function(context, state)
        if not graph:fact(context, state, "tower.inside")
            and not graph:fact(context, state, "lair.entered") then
            say(context, content.dialogue.descend)
        end
    end},
    -- Respawns return once the outpost is cleared or the player goes into the tower.
    {id = "outpost_light", after = {"outpost_dark"},
        await = cleared_or(content.encounters.tower, below_tower)},
    {id = "outpost_lifted", after = {"outpost_light"}, run = function(context)
        context:slot(content.darkness):set_darkness_zone{enabled = false}
    end},
    -- The cleared outpost points at the way into the tower; going down moves the marker to the
    -- search step's own object.
    {id = "descend_goal", after = {"tower_fight"}, run = function(context)
        show(context, content.goals.descend)
    end},
    {id = "down", after = {"tower_fight"}, await = below_tower},
    {id = "search", after = {"descend_goal", "down"}, run = function(context)
        show(context, content.goals.search)
    end},
    {id = "lair", after = {"search"}, await = lair},
    {id = "ambush", after = {"lair"}, run = spawn(content.encounters.lair),
        await = cleared_or(content.encounters.lair, bodies)},
    {id = "bodies", after = {"ambush"}, await = bodies},
    -- Entering the room arms the ghost link, then spawns the device with its interaction row in one
    -- body. Without the row the client never reports a use; a row not yet used shows a generic
    -- prompt first, so it is sent used. The link also registers the revive object that owns the
    -- goal's marker.
    {id = "revive", after = {"bodies"}, run = function(context)
        context:slot(content.ghost_link):set_ghost_link{active = true}
        show(context, content.goals.revive, content.dialogue.bodies)
        context:slot(content.pedestal):set_interactable_object{used = true}
    end},
    -- The "hope" hint (row 8) is not sent: in the same tick as row 7 it overlapped the revival
    -- scene's own lines, and the accepted reference never queues it either.
    -- Using the device starts the revival; either report ends the wait.
    {id = "revive_scene", after = {"revive"},
        await = flow.any(flow.fact("pedestal.used"), flow.fact("revival.started"))},
    {id = "revival", after = {"revive_scene"}, await = flow.fact("revival.started")},
    {id = "revival_done", after = {"revival"}, await = flow.fact("revival.finished")},
    -- The Ikora/Sagira exchange runs on after the link closes; the banner waits for its last line.
    {id = "revival_tail", after = {"revival_done"}, run = function(context)
        context:start_timer(TAIL_TIMER, TAIL_MS)
    end, await = flow.fact("revival.tail")},
    -- The finished mission shows no goal and no map marker.
    {id = "finish", after = {"revival_tail"}, run = function(context)
        context:slot(content.directive_sensor):clear_directives()
        context:complete_mission{}
    end},
}}

-- The replay after a wipe waits for the respawn, so the squads' removal and their return reach
-- the client apart. A trigger report also means the player is up again.
local function respawned(context, state)
    context:clear_variable(RESPAWNING)
    graph:advance(context, state)
end

local function handle(context, state, event)
    if state:variable(RESPAWNING) == true then return end
    graph:handle(context, state, event)
end

local function player_trigger(context, state, event)
    if event.slot ~= nil and state:variable(armed_key(event.slot)) == true then
        context:clear_variable(armed_key(event.slot))
        event.slot:disarm_trigger()
    end
    if state:variable(RESPAWNING) == true then respawned(context, state) end
    handle(context, state, event)
end

-- The outpost wipe: the last death in the darkness zone clears the outpost and restarts the
-- party at the checkpoint.
local function darkness_on(context, state)
    return graph:started(context, state, "outpost_dark")
        and not graph:started(context, state, "outpost_lifted")
end

-- The restart is the callback's only request, so the wipe starts at once.
local function fireteam_state(context, state, event)
    if state:variable(RESPAWNING) == true then
        if event.alive_count > 0 then respawned(context, state) end
        return
    end
    local wiped = event.dead_count > 0 and event.alive_count == 0 and event.unknown_count == 0
    if not wiped or state:variable(WIPE_REQUEST) ~= nil or not darkness_on(context, state) then
        return
    end
    context:set_variable(WIPED, true)
    local request = context:restart_checkpoint{
        region = content.alleys_b.region_index, spawn_set_hash = content.outpost_spawn_set,
    }
    context:set_variable(WIPE_REQUEST, request.value)
end

-- The accepted restart opens the new attempt. Release the client's wait, then clear the outpost.
local function effect_result(context, state, event)
    local request = state:variable(WIPE_REQUEST)
    if request == nil or event.request_key.value ~= request then return end
    context:clear_variable(WIPE_REQUEST)
    if event.outcome ~= "transport_staged" then
        context:clear_variable(WIPED)
        return
    end
    context:restart_checkpoint{
        region = content.alleys_b.region_index, spawn_set_hash = content.outpost_spawn_set,
        release_request = request,
    }
    context:slot(content.darkness):set_darkness_zone{enabled = false}
    despawn(content.encounters.tunnel_exit)(context)
    despawn(content.encounters.tower)(context)
    despawn(content.encounters.outpost_drop)(context)
    context:activate_objects{slots = content.pikes.temple, active = false}
    context:set_variable(RESPAWNING, true)
end

-- A seeded object spawns when its group registers, and each activation generation spawns it
-- again, so the pikes and the pedestal stay out of every seed until their step activates them.
local seed_omit = {}
for _, list in ipairs({content.pikes.square, content.pikes.roadblock, content.pikes.temple}) do
    for _, id in ipairs(list) do seed_omit[#seed_omit + 1] = id end
end
seed_omit[#seed_omit + 1] = content.pedestal

return {
    initial_state = {
        region_index = content.initial_state.region_index,
        spawn_set_hash = content.arrival_spawn_set,
        omit = seed_omit,
    },
    on_start = function(context, state) graph:advance(context, state) end,
    on_load = function(context, state) graph:advance(context, state) end,
    on_event_region_changed = function(context, state, event)
        for _, watcher in ipairs(content.watchers) do
            if event.region_index == watcher.state.region_index then
                for _, source in ipairs(watcher.triggers) do arm(context, source) end
            end
        end
        handle(context, state, event)
    end,
    -- Only the arrival answer feeds the graph. A leg report carries `region_index` too, and the
    -- pending leg names a region the client has not loaded, so the region facts must not see it.
    on_event_client_state_changed = function(context, state, event)
        if event.entered == true then handle(context, state, event) end
    end,
    on_event_player_trigger = player_trigger,
    on_event_squad_state = handle,
    on_event_actor_path_state = handle,
    on_event_object_interacted = handle,
    on_event_device_state = handle,
    on_event_ghost_link_state = handle,
    on_event_trigger_entered = handle,
    on_event_timer_elapsed = handle,
    on_event_fireteam_state = fireteam_state,
    on_event_effect_result = effect_result,
}
