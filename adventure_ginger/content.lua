local lib = require("lib.mission_lib")

return function(mission)
    -- A Skiff flight: stopping entrance at one command point, a hover, departure at another.
    local function skiff(actor, abilities, enter_point, exit_point)
        local flight = lib.one(lib.one(abilities, "Skiff abilities").GROUP_07EBF354,
            "Skiff flight group")
        return {
            actor = lib.one(actor, "Skiff actor"),
            enter = lib.one(flight.KEY_052C60A0, "Skiff stopping entrance"),
            exit = lib.one(flight.KEY_7D0D39A9, "Skiff departure"),
            enter_point = lib.one(enter_point, "Skiff entrance point"),
            exit_point = lib.one(exit_point, "Skiff exit point"),
        }
    end
    -- A line and the authored filter volume the player must enter before it plays.
    local function line(cue, filter)
        return {cue = lib.one(cue, "DialogueCue"),
            filter = filter ~= nil and lib.one(filter, "Dialogue filter") or nil}
    end
    local cues = mission.DialogueCue.M_DIALOG_SENSOR_80B2ED51
    local content = {
        initial_state = lib.one(mission.states.STATE_80B2E043_0033_0000_80B2E039, "town state"),
        -- The three launch points of the town. Without it the client scores every loaded point
        -- named `default` and lands anywhere on the map. The SDK names no spawn sets.
        arrival_spawn_set = 0x43954D08,
        alleys_a = lib.one(mission.states.STATE_80B2E043_0000_0000_80B2E009, "alleys A state"),
        alleys_b = lib.one(mission.states.STATE_80B2E043_0001_0000_80B2E00E, "alleys B state"),
        walker = lib.one(mission.Slot.OVERPASS_FALLEN_SPIDER01_SQUAD_TANK, "Walker"),
        barrier = lib.one(mission.Slot.OVERPASS_FALLEN_BARRIER_SHIELD_DEVICE, "barrier"),
        pedestal = lib.one(mission.Slot.LAIR_REVIVE_INTERACT_OBJECT, "pedestal"),
        ghost_link = lib.one(mission.Slot.OSIRIS_GHOST_REVIVE_GHOSTLINK, "Ghost link"),
        directive_sensor = lib.one(mission.Slot.M_DIRECTIVE_SENSOR_80B2ED51, "directive sensor"),
        -- The type-35 sensor whose enabled flag restricts respawns in the activity's bubble.
        darkness = lib.one(mission.Slot.HARD_WIPE_GLOBALS, "darkness zone"),
        -- A wipe in the outpost restarts the party at its north-west edge. The set must belong to
        -- the alleys B bubble alone; the client may take a shared set's points in another bubble.
        -- The SDK names no spawn sets.
        outpost_spawn_set = 0x36F9462A,
        dialogue_sensor = lib.one(mission.Slot.M_DIALOG_SENSOR_80B2ED51, "dialogue sensor"),
        skiff = skiff(mission.Slot.OVERPASS_DROPSHIP_CLIFF01_SQUAD_DROPSHIP,
            mission.ActorAbility.OVERPASS_DROPSHIP_CLIFF01_SQUAD_DROPSHIP,
            mission.Slot.OVERPASS_DROPSHIP_CLIFF01_ENTER_COMMAND,
            mission.Slot.OVERPASS_DROPSHIP_CLIFF01_EXIT_COMMAND),
        outpost_skiff = skiff(mission.Slot.OUTPOST_FALLEN_DROPSHIP01_SQUAD_DROPSHIP,
            mission.ActorAbility.OUTPOST_FALLEN_DROPSHIP01_SQUAD_DROPSHIP,
            mission.Slot.OUTPOST_FALLEN_DROPSHIP01_ENTER_COMMAND,
            mission.Slot.OUTPOST_FALLEN_DROPSHIP01_EXIT_COMMAND),
        encounters = {
            square = {
                -- Live had six Fallen here: two dregs at a's point, three dregs beside the
                -- vandal from b on c's rule, and the vandal. The counts are the host's.
                {
                    squad = lib.one(mission.Squad.HUB_FALLEN_INF01A_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.HUB_FALLEN_INF01A_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.HUB_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.HUB_FALLEN_OBJECTIVE.GROUP_0, "TaskGroup"),
                    count = 2,
                },
                {
                    squad = lib.one(mission.Squad.HUB_FALLEN_INF01B_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.HUB_FALLEN_INF01B_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.HUB_FALLEN_OBJECTIVE, "Slot"),
                    -- The vandal's task group, so they hold the firing area they spawn in.
                    group = lib.one(mission.TaskGroup.HUB_FALLEN_OBJECTIVE.GROUP_2, "TaskGroup"),
                    count = 3,
                    spawn_rule = lib.one(mission.Slot.HUB_FALLEN_INF01C_SQUAD_SPAWNRULE, "Slot"),
                },
                {
                    squad = lib.one(mission.Squad.HUB_FALLEN_INF01C_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.HUB_FALLEN_INF01C_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.HUB_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.HUB_FALLEN_OBJECTIVE.GROUP_2, "TaskGroup"),
                },
            },
            streets = {
                {
                    squad = lib.one(mission.Squad.STREETS_FALLEN_INF01_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.STREETS_FALLEN_INF01_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.STREETS_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.STREETS_FALLEN_OBJECTIVE.GROUP_4, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.STREETS_FALLEN_FIRST_SNIPER1_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.STREETS_FALLEN_FIRST_SNIPER1_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.STREETS_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.STREETS_FALLEN_OBJECTIVE.GROUP_0, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.STREETS_FALLEN_FIRST_SNIPER2_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.STREETS_FALLEN_FIRST_SNIPER2_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.STREETS_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.STREETS_FALLEN_OBJECTIVE.GROUP_1, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.STREETS_FALLEN_SHANK_HORDE1_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.STREETS_FALLEN_SHANK_HORDE1_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.STREETS_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.STREETS_FALLEN_OBJECTIVE.GROUP_2, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.STREETS_FALLEN_SHANK_HORDE2_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.STREETS_FALLEN_SHANK_HORDE2_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.STREETS_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.STREETS_FALLEN_OBJECTIVE.GROUP_8, "TaskGroup"),
                },
            },
            choke = {
                {
                    squad = lib.one(mission.Squad.STREETS_FALLEN_CHOKEPOINT_SNIPER01_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.STREETS_FALLEN_CHOKEPOINT_SNIPER01_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.STREETS_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.STREETS_FALLEN_OBJECTIVE.GROUP_7, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.STREETS_FALLEN_CHOKEPOINT_SNIPER02_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.STREETS_FALLEN_CHOKEPOINT_SNIPER02_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.STREETS_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.STREETS_FALLEN_OBJECTIVE.GROUP_8, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.STREETS_FALLEN_CHOKEPOINT_INF01_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.STREETS_FALLEN_CHOKEPOINT_INF01_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.STREETS_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.STREETS_FALLEN_OBJECTIVE.GROUP_6, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.STREETS_FALLEN_CHOKEPOINT_INF02_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.STREETS_FALLEN_CHOKEPOINT_INF02_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.STREETS_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.STREETS_FALLEN_OBJECTIVE.GROUP_9, "TaskGroup"),
                },
            },
            walker = {
                {
                    squad = lib.one(mission.Squad.OVERPASS_FALLEN_SPIDER01_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OVERPASS_FALLEN_SPIDER01_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OVERPASS_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OVERPASS_FALLEN_OBJECTIVE.GROUP_1, "TaskGroup"),
                },
            },
            overpass_support = {
                {
                    squad = lib.one(mission.Squad.OVERPASS_FALLEN_FRONT01_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OVERPASS_FALLEN_FRONT01_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OVERPASS_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OVERPASS_FALLEN_OBJECTIVE.GROUP_6, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.OVERPASS_FALLEN_BUS01_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OVERPASS_FALLEN_BUS01_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OVERPASS_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OVERPASS_FALLEN_OBJECTIVE.GROUP_6, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.OVERPASS_FALLEN_PIT01_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OVERPASS_FALLEN_PIT01_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OVERPASS_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OVERPASS_FALLEN_OBJECTIVE.GROUP_7, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.OVERPASS_FALLEN_TUNNEL_DEFENCE01_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OVERPASS_FALLEN_TUNNEL_DEFENCE01_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OVERPASS_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OVERPASS_FALLEN_OBJECTIVE.GROUP_7, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.OVERPASS_FALLEN_SHANKS01_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OVERPASS_FALLEN_SHANKS01_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OVERPASS_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OVERPASS_FALLEN_OBJECTIVE.GROUP_7, "TaskGroup"),
                },
            },
            cliff = {
                {
                    squad = lib.one(mission.Squad.CLIFFSIDE_FALLEN_SNIPER01_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.CLIFFSIDE_FALLEN_SNIPER01_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.CLIFFSIDE_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.CLIFFSIDE_FALLEN_OBJECTIVE.GROUP_0, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.CLIFFSIDE_FALLEN_SNIPER02_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.CLIFFSIDE_FALLEN_SNIPER02_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.CLIFFSIDE_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.CLIFFSIDE_FALLEN_OBJECTIVE.GROUP_4, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.CLIFFSIDE_FALLEN_INF01_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.CLIFFSIDE_FALLEN_INF01_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.CLIFFSIDE_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.CLIFFSIDE_FALLEN_OBJECTIVE.GROUP_1, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.CLIFFSIDE_FALLEN_INF02A_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.CLIFFSIDE_FALLEN_INF02A_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.CLIFFSIDE_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.CLIFFSIDE_FALLEN_OBJECTIVE.GROUP_2, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.CLIFFSIDE_FALLEN_INF02B_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.CLIFFSIDE_FALLEN_INF02B_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.CLIFFSIDE_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.CLIFFSIDE_FALLEN_OBJECTIVE.GROUP_3, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.CLIFFSIDE_FALLEN_INF03_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.CLIFFSIDE_FALLEN_INF03_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.CLIFFSIDE_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.CLIFFSIDE_FALLEN_OBJECTIVE.GROUP_8, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.CLIFFSIDE_FALLEN_INF04_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.CLIFFSIDE_FALLEN_INF04_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.CLIFFSIDE_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.CLIFFSIDE_FALLEN_OBJECTIVE.GROUP_7, "TaskGroup"),
                },
            },
            tunnel = {
                {
                    squad = lib.one(mission.Squad.ALLEYS_B_TUNNEL_2_SHANK_SQUAD_1, "Squad"),
                    source = lib.one(mission.Slot.ALLEYS_B_TUNNEL_2_SHANK_SQUAD_1, "Slot"),
                    objective = lib.one(mission.Slot.ALLEYS_B_TUNNEL_2_AI_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.ALLEYS_B_TUNNEL_2_AI_OBJECTIVE.GROUP_0, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.ALLEYS_B_TUNNEL_2_MID_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.ALLEYS_B_TUNNEL_2_MID_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.ALLEYS_B_TUNNEL_2_AI_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.ALLEYS_B_TUNNEL_2_AI_OBJECTIVE.GROUP_1, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.ALLEYS_B_TUNNEL_2_SHANK_SQUAD_2, "Squad"),
                    source = lib.one(mission.Slot.ALLEYS_B_TUNNEL_2_SHANK_SQUAD_2, "Slot"),
                    objective = lib.one(mission.Slot.ALLEYS_B_TUNNEL_2_AI_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.ALLEYS_B_TUNNEL_2_AI_OBJECTIVE.GROUP_2, "TaskGroup"),
                },
            },
            -- The tunnel exit guards stand apart from the outpost; the tower clear does not wait
            -- on them, since one can be left behind or out of reach.
            tunnel_exit = {
                {
                    squad = lib.one(mission.Squad.OUTPOST_FALLEN_TUNNEL_EXIT01_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OUTPOST_FALLEN_TUNNEL_EXIT01_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OUTPOST_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OUTPOST_FALLEN_OBJECTIVE.GROUP_2, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.OUTPOST_FALLEN_TUNNEL_EXIT02_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OUTPOST_FALLEN_TUNNEL_EXIT02_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OUTPOST_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OUTPOST_FALLEN_OBJECTIVE.GROUP_3, "TaskGroup"),
                },
            },
            tower = {
                {
                    squad = lib.one(mission.Squad.OUTPOST_FALLEN_BOWL_MID01_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OUTPOST_FALLEN_BOWL_MID01_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OUTPOST_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OUTPOST_FALLEN_OBJECTIVE.GROUP_0, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.OUTPOST_FALLEN_BOWL_MID02_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OUTPOST_FALLEN_BOWL_MID02_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OUTPOST_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OUTPOST_FALLEN_OBJECTIVE.GROUP_0, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.OUTPOST_FALLEN_BOWL_FLANK01_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OUTPOST_FALLEN_BOWL_FLANK01_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OUTPOST_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OUTPOST_FALLEN_OBJECTIVE.GROUP_4, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.OUTPOST_FALLEN_TOWER_MID_SNIPER01_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OUTPOST_FALLEN_TOWER_MID_SNIPER01_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OUTPOST_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OUTPOST_FALLEN_OBJECTIVE.GROUP_16, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.OUTPOST_FALLEN_TOWER_BASE_FRONT_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OUTPOST_FALLEN_TOWER_BASE_FRONT_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OUTPOST_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OUTPOST_FALLEN_OBJECTIVE.GROUP_15, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.OUTPOST_FALLEN_TOWER_BASE_ANCHOR_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OUTPOST_FALLEN_TOWER_BASE_ANCHOR_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OUTPOST_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OUTPOST_FALLEN_OBJECTIVE.GROUP_5, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.OUTPOST_FALLEN_TOWER_MID_FRONT_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OUTPOST_FALLEN_TOWER_MID_FRONT_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OUTPOST_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OUTPOST_FALLEN_OBJECTIVE.GROUP_10, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.OUTPOST_FALLEN_TOWER_MID_BACK_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OUTPOST_FALLEN_TOWER_MID_BACK_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OUTPOST_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OUTPOST_FALLEN_OBJECTIVE.GROUP_7, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.OUTPOST_FALLEN_TOWER_MID_ANCHOR_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OUTPOST_FALLEN_TOWER_MID_ANCHOR_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OUTPOST_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OUTPOST_FALLEN_OBJECTIVE.GROUP_7, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.OUTPOST_FALLEN_TOWER_LOWER_BACK_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OUTPOST_FALLEN_TOWER_LOWER_BACK_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OUTPOST_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OUTPOST_FALLEN_OBJECTIVE.GROUP_12, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.OUTPOST_FALLEN_TOWER_STEALTH1_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OUTPOST_FALLEN_TOWER_STEALTH1_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OUTPOST_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OUTPOST_FALLEN_OBJECTIVE.GROUP_12, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.OUTPOST_FALLEN_TOWER_STEALTH2_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OUTPOST_FALLEN_TOWER_STEALTH2_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OUTPOST_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OUTPOST_FALLEN_OBJECTIVE.GROUP_12, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.OUTPOST_FALLEN_TOWER_STEALTH3_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OUTPOST_FALLEN_TOWER_STEALTH3_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OUTPOST_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OUTPOST_FALLEN_OBJECTIVE.GROUP_12, "TaskGroup"),
                },
            },
            -- The two infantry squads whose rule points sit below the outpost Skiff's hover
            -- point. The task group is not authored by name; the bowl group is a choice.
            outpost_drop = {
                {
                    squad = lib.one(mission.Squad.OUTPOST_FALLEN_ASSAULT_INF01_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OUTPOST_FALLEN_ASSAULT_INF01_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OUTPOST_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OUTPOST_FALLEN_OBJECTIVE.GROUP_0, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.OUTPOST_FALLEN_ASSAULT_INF02_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.OUTPOST_FALLEN_ASSAULT_INF02_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.OUTPOST_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.OUTPOST_FALLEN_OBJECTIVE.GROUP_0, "TaskGroup"),
                },
            },
            lair = {
                {
                    squad = lib.one(mission.Squad.LAIR_FALLEN_CLOAKED1_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.LAIR_FALLEN_CLOAKED1_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.LAIR_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.LAIR_FALLEN_OBJECTIVE.GROUP_2, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.LAIR_FALLEN_CLOAKED2_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.LAIR_FALLEN_CLOAKED2_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.LAIR_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.LAIR_FALLEN_OBJECTIVE.GROUP_2, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.LAIR_FALLEN_CLOAKED3_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.LAIR_FALLEN_CLOAKED3_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.LAIR_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.LAIR_FALLEN_OBJECTIVE.GROUP_0, "TaskGroup"),
                },
                {
                    squad = lib.one(mission.Squad.LAIR_FALLEN_INF01_SQUAD, "Squad"),
                    source = lib.one(mission.Slot.LAIR_FALLEN_INF01_SQUAD, "Slot"),
                    objective = lib.one(mission.Slot.LAIR_FALLEN_OBJECTIVE, "Slot"),
                    group = lib.one(mission.TaskGroup.LAIR_FALLEN_OBJECTIVE.GROUP_0, "TaskGroup"),
                },
            },
        },
        goals = {
            -- The town leg points at the crossing into alleys A; the trigger registers its object.
            town = {
                directive = lib.one(mission.Directive.RENDEZVOUS_WITH_THE_FOLLOWERS_OF_OSIRIS_TO_REVIVE_SAGIRA_EC217779, "Directive"),
                navpoint = lib.one(mission.Slot.GINGER_TOWN_GOTO_ALLEYS_A_NAV_POINT, "Slot"),
                trigger = lib.one(mission.Slot.GINGER_TOWN_GOTO_ALLEYS_A_TRIGGER, "Slot"),
            },
            coordinates = {
                directive = lib.one(mission.Directive.RENDEZVOUS_WITH_THE_FOLLOWERS_OF_OSIRIS_TO_REVIVE_SAGIRA_EC217779, "Directive"),
                navpoint = lib.one(mission.Slot.GINGER_ALLEYS_A_GOTO_NAV_POINT, "Slot"),
            },
            -- "Commandeer a Fallen Pike": shown when the square is clear and its Pikes appear. The
            -- steal-pikes object owns both the marker and the trigger that ends this step.
            pike = {
                directive = lib.one(mission.Directive.RENDEZVOUS_WITH_THE_FOLLOWERS_OF_OSIRIS_TO_REVIVE_SAGIRA_DA95AE49, "Directive"),
                navpoint = lib.one(mission.Slot.GINGER_ALLEYS_A_STEAL_PIKES_NAV_POINT, "Slot"),
                waypoint = lib.one(mission.Slot.WAYPOINT_VOLUME, "Slot"),
            },
            path = {
                directive = lib.one(mission.Directive.RENDEZVOUS_WITH_THE_FOLLOWERS_OF_OSIRIS_TO_REVIVE_SAGIRA, "Directive"),
                navpoint = lib.one(mission.Slot.GINGER_ALLEYS_A_GOTO_TANK_NAV_POINT, "Slot"),
            },
            -- A waypoint is the step's authored volume; inside it the HUD marker hides.
            walker = {
                directive = lib.one(mission.Directive.CLEAR_THE_ROADBLOCK, "Directive"),
                navpoint = lib.one(mission.Slot.GINGER_ALLEYS_A_KILL_TANK_NAV_POINT, "Slot"),
                waypoint = lib.one(mission.Slot.GINGER_ALLEYS_A_KILL_TANK_WAYPOINT_VOLUME, "Slot"),
            },
            -- The temple goal is three authored steps with one text: the tunnel, the crossing
            -- into alleys B, and the outpost. Each step's object owns its navpoint.
            temple = {
                directive = lib.one(mission.Directive.RENDEZVOUS_WITH_THE_FOLLOWERS_OF_OSIRIS_TO_REVIVE_SAGIRA_E58BB2F6, "Directive"),
                navpoint = lib.one(mission.Slot.NAV_POINT_80B2E62A, "Slot"),
            },
            observatory = {
                directive = lib.one(mission.Directive.RENDEZVOUS_WITH_THE_FOLLOWERS_OF_OSIRIS_TO_REVIVE_SAGIRA_E58BB2F6, "Directive"),
                navpoint = lib.one(mission.Slot.GINGER_ALLEYS_B_OBSERVATORY_GOTO_NAV_POINT_80B2EC52, "Slot"),
            },
            tower = {
                directive = lib.one(mission.Directive.RENDEZVOUS_WITH_THE_FOLLOWERS_OF_OSIRIS_TO_REVIVE_SAGIRA_E58BB2F6, "Directive"),
                navpoint = lib.one(mission.Slot.GINGER_ALLEYS_B_OBSERVATORY_GOTO_NAV_POINT_80B2EC61, "Slot"),
                waypoint = lib.one(mission.Slot.GINGER_ALLEYS_B_OBSERVATORY_DESTROY_WAYPOINT_VOLUME, "Slot"),
            },
            -- After the clear the outpost object shows its second directive with its own marker,
            -- the way into the tower. Its waypoint covers the whole outpost, so it is not sent.
            descend = {
                directive = lib.one(mission.Directive.RENDEZVOUS_WITH_THE_FOLLOWERS_OF_OSIRIS_TO_REVIVE_SAGIRA_882DD31E, "Directive"),
                navpoint = lib.one(mission.Slot.GINGER_ALLEYS_B_OBSERVATORY_GOTO_NAV_POINT_80B2EC61, "Slot"),
            },
            search = {
                directive = lib.one(mission.Directive.RENDEZVOUS_WITH_THE_FOLLOWERS_OF_OSIRIS_TO_REVIVE_SAGIRA_882DD31E, "Directive"),
                navpoint = lib.one(mission.Slot.NAV_POINT_80B2EC45, "Slot"),
                waypoint = lib.one(mission.Slot.DIRECTIVE_WAYPOINT_VOLUME_80B2EC45, "Slot"),
            },
            revive = {
                directive = lib.one(mission.Directive.REVIVE_SAGIRA, "Directive"),
                navpoint = lib.one(mission.Slot.GINGER_ALLEYS_B_REVIVE_NAV_POINT, "Slot"),
                waypoint = lib.one(mission.Slot.DIRECTIVE_WAYPOINT_VOLUME_80B2EC6C, "Slot"),
            },
        },
        -- Each step object names its cue and filter volume beside its directive; the filter is
        -- where the player must be when the line plays.
        dialogue = {
            -- "The coordinates Brother Vance gave us are just beyond the village."
            opening = line(cues.CUE_0),
            -- "So, are the Followers all as passionate as Brother Vance?"
            followers = line(cues.CUE_1, mission.Slot.EDZ_A_GINGER_TOWN_020_FILTER_80B2E67F),
            -- "I feel bad for anyone who has to live out here." Its authored filter is the tunnel
            -- mouth, where the pikes spawn, so a rider never enters it; it plays unfiltered.
            survival = line(cues.CUE_2),
            -- "It really is just a radio tower. And the Fallen got here first." Sent when the
            -- observatory trigger reports, from inside its filter `alleys_b_030_filter`.
            tower = line(cues.CUE_4, mission.Slot.SLOT_0002_80B2EC61),
            -- "I think we need to head down, not up." No object names it; it plays when the tower
            -- top monitor reports the player.
            descend = line(cues.CUE_5),
            -- "The Followers! We're too late."
            bodies = line(cues.CUE_7),
            -- "Maybe there's still something here we can use to help Sagira."
            hope = line(cues.CUE_8),
            -- Cues 9 and 10 (the device and the revival) play from the interaction's own scene.
        },
        triggers = {
            ["overpass.dropship"] = mission.Slot.OVERPASS_ENCOUNTER_DROPSHIP_SPAWN_TRIGGER,
            ["overpass.directive"] = mission.Slot.OBJECTIVE_PROGRESS_TRIGGER_80B2E67F,
            ["trial.directive"] = mission.Slot.DIRECTIVE_TRIGGER_80B2E62A,
            ["tower.directive"] = mission.Slot.GINGER_ALLEYS_B_GOTO_OBSERVATORY_TRIGGER,
            ["square.entered"] = mission.Slot.GINGER_ALLEYS_A_GOTO_TRIGGER,
            ["pikes.reached"] = mission.Slot.OBJECTIVE_PROGRESS_TRIGGER_80B2E716,
            ["outpost.entered"] = mission.Slot.OUTPOST_FALLEN_INIT_TRIGGER,
            -- The outpost step's own trigger is the drop into the tower.
            ["tower.inside"] = mission.Slot.DIRECTIVE_TRIGGER_80B2EC61,
            ["streets.entered"] = mission.Slot.STREETS_FALLEN_SHANK_HORDE1_SPAWN_TRIGGER,
            ["choke.entered"] = mission.Slot.STREETS_FALLEN_CHOKEPOINT01_SPAWN_TRIGGER,
            ["overpass.entered"] = mission.Slot.OVERPASS_ENCOUNTER_START_TRIGGER,
            ["cliff.entered"] = mission.Slot.CLIFFSIDE_FALLEN_SPAWN_TRIGGER,
            ["tunnel.entered"] = mission.Slot.ALLEYS_B_TUNNEL_2_SPAWN_FRONT_AI_PLAYER_TRIGGER,
            ["lair.entered"] = mission.Slot.LAIR_FALLEN_SPAWN_TRIGGER,
            ["bodies.entered"] = mission.Slot.PLAYER_TRIGGER,
        },
        pikes = {
            square = lib.list(
                mission.Slot.HUB_PLAYERPIKE_OBJECT_0,
                mission.Slot.HUB_PLAYERPIKE_OBJECT_1,
                mission.Slot.HUB_PLAYERPIKE_OBJECT_2
            ),
            roadblock = lib.list(
                mission.Slot.OVERPASS_PLAYERPIKE_OBJECT_0,
                mission.Slot.OVERPASS_PLAYERPIKE_OBJECT_1,
                mission.Slot.OVERPASS_PLAYERPIKE_OBJECT_2,
                mission.Slot.SPIDER_PLAYERPIKE_OBJECT_0,
                mission.Slot.SPIDER_PLAYERPIKE_OBJECT_1,
                mission.Slot.SPIDER_PLAYERPIKE_OBJECT_2
            ),
            temple = lib.list(
                mission.Slot.CLIFFSIDE_PLAYERPIKE_OBJECT_0,
                mission.Slot.CLIFFSIDE_PLAYERPIKE_OBJECT_1,
                mission.Slot.CLIFFSIDE_PLAYERPIKE_OBJECT_2,
                mission.Slot.OUTPOST_PLAYERPIKE_OBJECT_0,
                mission.Slot.OUTPOST_PLAYERPIKE_OBJECT_1,
                mission.Slot.OUTPOST_PLAYERPIKE_OBJECT_2
            ),
        },
    }
    -- A wipe re-arms these; each trigger reports once per arming.
    content.outpost_triggers = lib.list(
        mission.Slot.OUTPOST_FALLEN_INIT_TRIGGER,
        mission.Slot.GINGER_ALLEYS_B_GOTO_OBSERVATORY_TRIGGER
    )
    -- The player monitor on the top of the tower (alleys B volume 127, z 209 to 219). No trigger
    -- watches that volume. The name's spelling is authored.
    content.tower_top = lib.one(mission.Slot.OUTPSOT_MID_BACK_EXPAND_MONITOR, "tower top monitor")
    content.watchers = {
        {state = content.alleys_a, triggers = lib.list(
            mission.Slot.OVERPASS_ENCOUNTER_DROPSHIP_SPAWN_TRIGGER,
            mission.Slot.OBJECTIVE_PROGRESS_TRIGGER_80B2E67F,
            mission.Slot.DIRECTIVE_TRIGGER_80B2E62A,
            mission.Slot.GINGER_ALLEYS_A_GOTO_TRIGGER,
            mission.Slot.OBJECTIVE_PROGRESS_TRIGGER_80B2E716,
            mission.Slot.STREETS_FALLEN_SHANK_HORDE1_SPAWN_TRIGGER,
            mission.Slot.STREETS_FALLEN_CHOKEPOINT01_SPAWN_TRIGGER,
            mission.Slot.OVERPASS_ENCOUNTER_START_TRIGGER
        )},
        {state = content.alleys_b, triggers = lib.list(
            mission.Slot.GINGER_ALLEYS_B_GOTO_OBSERVATORY_TRIGGER,
            mission.Slot.DIRECTIVE_TRIGGER_80B2EC61,
            mission.Slot.OUTPOST_FALLEN_INIT_TRIGGER,
            mission.Slot.CLIFFSIDE_FALLEN_SPAWN_TRIGGER,
            mission.Slot.ALLEYS_B_TUNNEL_2_SPAWN_FRONT_AI_PLAYER_TRIGGER,
            mission.Slot.LAIR_FALLEN_SPAWN_TRIGGER,
            mission.Slot.PLAYER_TRIGGER
        )},
    }
    return content
end
