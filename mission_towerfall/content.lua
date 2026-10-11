-- Homecoming (mission_towerfall) constants. Every name is resolved through lib.one, so a missing
-- symbol fails at load (and in `sdev check`), not mid-mission.
--
-- Sources: Dawn's native Homecoming (isinternets/Dawn, src/state/activity/vanilla/homecoming) for the
-- beat order and fixes, the "Homecoming v40" Sunrise script (Dawn PR #8) for mechanics. Dawn's
-- indices are kept in comments for cross-checking.
local lib = require("lib.mission_lib")

return function(mission)
    local Slot, Squad, Scene, Directive = mission.Slot, mission.Squad, mission.Scene, mission.Directive
    local function slot(name) return lib.one(Slot[name], "Slot " .. name) end
    local function squad(name) return lib.one(Squad[name], "Squad " .. name) end
    local function scene(name) return lib.one(Scene[name], "Scene " .. name) end
    local function directive(name) return lib.one(Directive[name], "Directive " .. name) end
    local function state(name) return lib.one(mission.states[name], "state " .. name) end
    local function slots(...)
        local out = {}
        for index, name in ipairs({...}) do out[index] = slot(name) end
        return out
    end
    local function squads(...)
        local out = {}
        for index, name in ipairs({...}) do out[index] = squad(name) end
        return out
    end

    local c = {}

    c.sensors = {
        directive = slot("M_DIRECTIVE_SENSOR_80B50913"),
        music = slot("M_MUSIC_SENSOR_80B50913"),
        dialogue = slot("M_DIALOG_SENSOR_80B50913"),
    }

    -- Music sections of bank 80B5090F. Dawn writes one exclusive section at a time.
    c.music = {
        underwatch_ruins = 0, first_cabal = 1, after_cayde = 3, shaxx_door = 4, first_pod = 6,
        cabal_ship_reveal = 7, plaza = 8, leaving_plaza = 12, battleship_deck = 16,
        battleship_sabotage = 17, run = 18, ending = 19,
    }

    -- Dialogue windows in ms, [row + 1], from Dawn's table for bank 80C2AF61 (rows = CUE_n). Zero:
    -- no decoded speech, or a row a native scene speaks itself (0, 10, 21-24, 66-69, 72); the
    -- queue never sends either.
    c.dialogue_windows = {
        0, 3933, 0, 7728, 2500, 2500, 9161, 4651, 11198, 0,  -- rows 0-9
        0, 2500, 2500, 2500, 0, 6467, 2500, 0, 0, 0,  -- rows 10-19
        0, 0, 0, 0, 0, 0, 0, 2867, 4667, 0,  -- rows 20-29
        8533, 0, 0, 0, 4133, 4133, 4600, 25172, 6733, 3281,  -- rows 30-39
        4267, 2800, 0, 9836, 2500, 0, 2500, 2898, 2500, 0,  -- rows 40-49
        2500, 4333, 9133, 2500, 3600, 3800, 0, 2500, 2500, 14238,  -- rows 50-59
        2533, 2533, 3009, 2507, 4867, 0, 0, 0, 0, 0,  -- rows 60-69
        0, 2500, 0, 0, 2680, 3533, 2500, 5800, 3067, 4861,  -- rows 70-79
        2667, 3800, 14704, 4060, 2509, 3067, 4148, 2500, 2500, 0,  -- rows 80-89
        2814, 7803, 7500, 5000,  -- rows 90-93
    }

    -- Intro: the HRO fly-in plays in region 17 with the spawn held, then Underwatch (region 72).
    -- No spawn set hash: Dawn uses the absent hash so the authored arrival point is used.
    c.intro = {
        state = state("STATE_80B500BC_0002_0001_80B500B1"),
        cinematic = slot("PREFAB_HRO_CINEMATIC"),
    }
    c.underwatch = state("STATE_80B500BC_0009_0000_80B500BB")
    -- Weapon racks spawn with their seed; the armory turns 103 on. 104-106 are unused beta racks.
    c.omit = slots("AUTO_RIFLE_INTERACTABLE", "HAND_CANNON_INTERACTABLE",
        "PULSE_RIFLE_INTERACTABLE", "SCOUT_RIFLE_INTERACTABLE")

    c.goals = {
        defend = {directive = directive("DEFEND_YOUR_HOME"), navpoint = slot("AP_IKORA")},
        gear_up = {directive = directive("GEAR_UP_FOR_THE_FIGHT"), navpoint = slot("SLOT_0009_80B5168C")},
    }

    c.wall = slot("D_UNDERWATCH_COLLAPSING_WALL")                       -- 108
    c.shaxx_doors = slots("O_SHAXX_DOOR_EXIT", "O_SHAXX_DOOR_ENTER")      -- 71, 72
    c.shaxx_blocker = slot("O_SHAXX_BLOCKER")                           -- 81

    -- Underwatch triggers, armed on arrival. Each is a flow fact named by its key.
    c.triggers = {
        wall = slot("PT_WALL_EXPLODE"),                                 -- 152
        centurion = slot("PT_CENTURION_INTRO"),                         -- 153
        centurion_reinforce = slot("PT_CENTURION_INTRO_REINFORCE"),     -- 154
        drop_pod = slot("PT_DROP_POD"),                                 -- 158
        civ_run = slot("PT_CIV_RUN_B"),                                 -- 160
        hero_moment = slot("PT_HERO_MOMENT"),                           -- 171
        shaxx_enters = slot("PT_SHAXX_ENTERS"),                         -- 161
        shaxx_enters_backup = slot("PT_SHAXX_ENTERS_BACKUP"),           -- 163
        start_shaxx = slot("PT_START_SHAXX_SCENE"),                     -- 156
        near_shaxx = slot("PT_PLAYER_NEAR_SHAXX"),                      -- 157
    }
    c.trigger_order = {"wall", "centurion", "centurion_reinforce", "drop_pod", "civ_run",
        "hero_moment", "shaxx_enters", "shaxx_enters_backup", "start_shaxx", "near_shaxx"}

    -- Loose squads at landing. Dawn never places 36, 39 or 113: they stood in doorways and overlapped
    -- the player at Shaxx's door. Civilians a scene owns are never placed loose.
    c.landing_squads = squads("SQ_RED_GUARD", "SQ_FRAME_FAKE_FIGHT", "SQ_RED_GUARD_FAKE_FIGHT",
        "SQ_CIVILIAN_WALL_SIT_A", "SQ_CIVILIAN_WALL_SIT_B")             -- 42, 12, 13, 37, 38

    -- Scenes started on arrival, no events. Frames vs the Mosquito, and the wounded civilians.
    c.ambient_scenes = {
        scene("SCENE_FRAMES_VS_MOSQUITO"),                              -- 5
        scene("SC_CIVILIAN_CATATONIC"), scene("SC_CIVILIAN_GROUND_1"),  -- 51, 52
        scene("SC_CIVILIAN_GROUND_2"), scene("SC_CIVILIAN_ON_KNEES_CRYING"), -- 53, 54
        scene("SC_CIVILIAN_KNEEL"),                                     -- 55
        scene("PF_SC_T0_UNDERWATCH_CIVILIAN_REACT_BENT_DOOR_SC_CIVILIAN_REACT"),     -- 83
        scene("PF_SC_T0_UNDERWATCH_CIVILIAN_REACT_BENT_INJURED_SC_CIVILIAN_REACT"),  -- 85
        scene("PF_SC_T0_UNDERWATCH_CIVILIAN_REACT_ARMS_WRAPPED_SC_CIVILIAN_REACT"),  -- 87
        scene("PF_SC_T0_UNDERWATCH_CIVILIAN_REACT_CROUCH_SC_CIVILIAN_REACT"),        -- 89
        scene("PF_SC_T0_UNDERWATCH_CIVILIAN_REACT_WORRIED_1_SC_CIVILIAN_REACT"),     -- 91
        scene("PF_SC_T0_UNDERWATCH_CIVILIAN_REACT_INJURED_WALL_SC_CIVILIAN_REACT"),  -- 93
        scene("PF_SC_T0_UNDERWATCH_CIVILIAN_REACT_CLASPED_SC_CIVILIAN_REACT"),       -- 95
        scene("PF_SC_T0_UNDERWATCH_CIVILIAN_REACT_CLASPED_FEMALE_SC_CIVILIAN_REACT"), -- 97
        scene("PF_SC_T0_UNDERWATCH_CIVILIAN_REACT_TIRED_SC_CIVILIAN_REACT"),         -- 99
    }
    -- The civilians running from the blast. 57 and 58 stay off: their civilians are also in Cayde's
    -- cast, and starting them early sent them through his closed door.
    c.civ_run_scenes = {
        scene("SC_CIVILIAN_RUN_EXPLOSION"),                             -- 56
        scene("SC_CIVILIAN_RUN_FRONT_B_A"), scene("SC_CIVILIAN_RUN_FRONT_B_B"), -- 59, 60
        scene("SC_CIVILIAN_RUN_FRONT_B_C"),                             -- 61
    }
    c.hero_moment = scene("SC_HERO_MOMENT_UNDERWATCH")                  -- 64

    -- Hero scenes. Entry events are the scenes' own keys.
    -- activate{spawn=true} casts only squads that have an actor cell (a type-2 slot) in the scene's
    -- state; it counts the rest as omitted ("ev=scene_cast result=partial") and leaves them to the
    -- client, which binds only squads that exist. Playtest 1 lost the breach Cabal that way. So each
    -- scene's cell-less squads are reserved first (the v40 script reserved every cast squad), and
    -- cells are bound. Never place a scene's squads with reinforce/replace: Dawn got a duplicate
    -- Centurion that way.
    c.heroes = {
        breach = {
            scene = scene("SCENE_CABAL_FIRST_CONTACT"), slot = slot("SCENE_CABAL_FIRST_CONTACT"), -- 10
            entry = 0xAE7CC69C,
            reserve = squads("SQUAD_FIRST_CONTACT_CABAL", "SQ_FRAME_DIE"),                      -- 6, 7
            objectives = {{source = slot("SQUAD_FIRST_CONTACT_CABAL"), objective = slot("OBJ_CABAL_FIRST_CONTACT")}},
        },
        centurion = {
            scene = scene("SC_CENTURION_INTRO"), slot = slot("SC_CENTURION_INTRO"), -- 18
            entry = 0x6F51AC66,
            bind = slots("SQ_CENTURION_INTRO_CELL_1"),                                          -- 21
            reserve = squads("SQ_FRAME"),                                                       -- 24
            objectives = {{source = slot("SQ_CENTURION_INTRO"), objective = slot("OBJ_CENTURION_INTRO")}},
        },
        cayde = {
            scene = scene("SCENE_CAYDE_GOLDEN_GUN"), slot = slot("SCENE_CAYDE_GOLDEN_GUN"), -- 17
            entry = 0x6F51AC66,
            bind = slots("SQ_LEGIONARYA_CELL_1", "SQ_LEGIONARYB_CELL_1", "SQ_LEGIONARYC_CELL_1"), -- 29, 31, 33
            reserve = squads("SQ_CAYDE", "SQUAD_INVISIBLE_SHOOT_TARGET_1"),                     -- 27, 50
        },
        shaxx = {
            scene = scene("SCENE_SHAXX"), slot = slot("SCENE_SHAXX"),    -- 14
            entry = 0x6F51AC66,
            reserve = squads("SQ_SHAXX"),                                -- 15
        },
    }
    c.hero_order = {"breach", "centurion", "cayde", "shaxx"}

    -- Reinforcements, staggered at their triggers. Objective first: a squad body that changes after
    -- its members exist reports alive 0 for about a second.
    c.encounters = {
        breach_backup = {
            {squad = squad("SQUAD_FIRST_CONTACT_CABAL_BACKUP_A"), source = slot("SQUAD_FIRST_CONTACT_CABAL_BACKUP_A"),
                objective = slot("OBJ_CABAL_FIRST_CONTACT")},          -- 8, objective 11
            {squad = squad("SQUAD_FIRST_CONTACT_CABAL_BACKUP_B"), source = slot("SQUAD_FIRST_CONTACT_CABAL_BACKUP_B"),
                objective = slot("OBJ_CABAL_FIRST_CONTACT")},          -- 9
        },
        centurion_rush = {
            {squad = squad("SQ_CENTURION_INTRO_RUSH"), source = slot("SQ_CENTURION_INTRO_RUSH"),
                objective = slot("OBJ_CENTURION_INTRO")},              -- 22, objective 19
        },
        drop_pod = {
            {squad = squad("SQ_CENTURION_INTRO_BACKUP"), source = slot("SQ_CENTURION_INTRO_BACKUP"),
                objective = slot("OBJ_CENTURION_INTRO")},              -- 23
        },
    }
    -- Clears: Dawn holds each clear for 3 s before it counts. Loose squads must be fully spawned and
    -- dead; a scene's squad blocks only while it is known to be alive, so a scene that failed to
    -- spawn its cast cannot hold the mission.
    c.first_contact = {
        loose = squads("SQUAD_FIRST_CONTACT_CABAL_BACKUP_A", "SQUAD_FIRST_CONTACT_CABAL_BACKUP_B"), -- 8, 9
        scene = squads("SQUAD_FIRST_CONTACT_CABAL"),                                         -- 6
    }
    c.approach = {
        loose = squads("SQUAD_FIRST_CONTACT_CABAL_BACKUP_A", "SQUAD_FIRST_CONTACT_CABAL_BACKUP_B",
            "SQ_CENTURION_INTRO_RUSH", "SQ_CENTURION_INTRO_BACKUP"),                         -- 8, 9, 22, 23
        scene = squads("SQUAD_FIRST_CONTACT_CABAL", "SQ_CENTURION_INTRO"),                   -- 6, 20
    }

    -- Dialogue rows (CUE_n). Row 4 is dropped (Dawn); row 6 waits for the first-contact clear.
    c.lines = {landing = 1, breach = 5, first_contact = 6, civ_run = 7}

    return c
end
