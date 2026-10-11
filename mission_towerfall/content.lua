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
    -- Its cast has no actor cells (omitted=3 in playtest 2), so it is reserved first.
    c.hero_moment_reserve = squads("SQ_CABAL_HERO_MOMENT", "SQ_CABAL_HERO_MOMENT_B",
        "SQ_CIVILIAN_HERO_MOMENT")                                      -- 65, 66, 67

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
        -- No combat objective on SQ_CENTURION_INTRO: it is cast through its cell, and a cast source
        -- that already runs an objective program makes the scene refuse (playtest 2).
        centurion = {
            scene = scene("SC_CENTURION_INTRO"), slot = slot("SC_CENTURION_INTRO"), -- 18
            entry = 0x6F51AC66,
            bind = slots("SQ_CENTURION_INTRO_CELL_1"),                                          -- 21
            reserve = squads("SQ_FRAME"),                                                       -- 24
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
    -- Armory/military: 28 after the weapon, 30 at the post-gun fight, 34 at the hangar window once
    -- the destroyer exists, 35 at hangar combat, 37 at the corridor exit. 36/38/39 are never sent.
    c.lines = {landing = 1, breach = 5, first_contact = 6, civ_run = 7,
        weapon = 28, post_gun = 30, hangar_window = 34, hangar_combat = 35, goto_plaza = 37}

    -- ---- Part 2: armory (still region 72, the Underwatch exit registry) ----------------------

    c.armory = {
        gun_door = slot("D_GUN_DOOR"),                                  -- 117
        rack = slot("AUTO_RIFLE_INTERACTABLE"),                         -- 103
        -- The rack's rewards, in Dawn's order: the sidearm first, so the Origin Story auto rifle is
        -- the last one picked up.
        rewards = {0x654C35C4, 0xEFD9F21F},
        goal = {directive = directive("FIND_ZAVALA_432D2C96"),         -- objective 2
            navpoint = slot("AP_GOTO_MILITARY_80B5168C"), waypoint = slot("TV_GOTO_MILITARY")},
        triggers = {
            weapon = slot("PT_WEAPON"),
            post_gun = slot("PT_POSTGUN"),                              -- 169
            weapon_complete = slot("PT_WEAPON_COMPLETE"),
            goto_military = slot("PT_GOTO_MILITARY"),
        },
        trigger_order = {"weapon", "post_gun", "weapon_complete", "goto_military"},
    }

    -- ---- Part 3: military / hangar (region 32; the client streams into it on its own) --------

    c.military = {
        state = state("STATE_80B500BC_0004_0000_80B500B3"),
        goal = {directive = directive("JOIN_ZAVALA_IN_THE_PLAZA"),     -- objective 4
            navpoint = slot("SLOT_0008_80B50B91")},
        gate_start = slot("D_GATING_AMANDA_START"),                     -- 40
        gate_hangar = slot("D_GATING_AMANDA_HANGAR"),                   -- 41
        drop_pod = slot("O_CABAL_DROP_POD_MILITARY_HALLWAY"),           -- 2
        destroyer = slot("CABAL_DESTROYER"),                            -- 0
        missiles = slots("O_CABAL_MISSILE_1_80B5036A", "O_CABAL_MISSILE_2_80B5036A",
            "O_CABAL_MISSILE_3_80B5036A", "O_CABAL_MISSILE_4", "O_CABAL_MISSILE_5",
            "O_CABAL_MISSILE_6"),                                       -- 48-53
        objective = slot("OBJ_HANGAR"),                                 -- 1
        triggers = {
            hangar_spawn = slot("PT_HANGAR_SPAWN"),                     -- 87
            hangar_combat = slot("PT_HANGAR_COMBAT"),                   -- 96
            hangar_window = slot("PT_DIALOGUE_HANGAR_WINDOW"),
            goto_plaza = slot("PT_GOTO_PLAZA_80B50B91"),
        },
        trigger_order = {"hangar_spawn", "hangar_combat", "hangar_window", "goto_plaza"},
        -- The hangar checkpoint. Dawn requests one actor per authored lane; OVERLOOK_B_B carries
        -- the Legionaries of OVERLOOK_B_C (17), whose authored point is outside the corridor and
        -- which is never placed.
        checkpoint = {
            {squad = squad("SQ_HANGAR_OVERLOOK_A_A"), source = slot("SQ_HANGAR_OVERLOOK_A_A")},           -- 5
            {squad = squad("SQ_HANGAR_OVERLOOK_A_A_CENT"), source = slot("SQ_HANGAR_OVERLOOK_A_A_CENT")}, -- 6
            {squad = squad("SQ_HANGAR_OVERLOOK_A_B"), source = slot("SQ_HANGAR_OVERLOOK_A_B")},           -- 7
            {squad = squad("SQ_HANGAR_OVERLOOK_A_C"), source = slot("SQ_HANGAR_OVERLOOK_A_C")},           -- 8
            {squad = squad("SQ_HANGAR_OVERLOOK_B_A"), source = slot("SQ_HANGAR_OVERLOOK_B_A")},           -- 11
            {squad = squad("SQ_FRIENDLIES_EARLY"), source = slot("SQ_FRIENDLIES_EARLY")},                 -- 32
            {squad = squad("SQ_FRIENDLIES_EARLY_UPPER"), source = slot("SQ_FRIENDLIES_EARLY_UPPER")},     -- 33
            {squad = squad("SQ_HANGAR_OVERLOOK_B_B"), source = slot("SQ_HANGAR_OVERLOOK_B_B"),
                counts = {1, 3, 2}},                                                                       -- 13
            {squad = squad("SQ_HANGAR_OVERLOOK_SNIPER"), source = slot("SQ_HANGAR_OVERLOOK_SNIPER")},     -- 18
            {squad = squad("SQ_HANGAR_A_A"), source = slot("SQ_HANGAR_A_A")},                             -- 19
            {squad = squad("SQ_HANGAR_A_A_FLANK"), source = slot("SQ_HANGAR_A_A_FLANK")},                 -- 24
            {squad = squad("SQ_HANGAR_A_B"), source = slot("SQ_HANGAR_A_B")},                             -- 26
            {squad = squad("SQ_HANGAR_A_B_SNIPER"), source = slot("SQ_HANGAR_A_B_SNIPER")},               -- 30
            {squad = squad("SQ_HANGAR_FODDER_A"), source = slot("SQ_HANGAR_FODDER_A")},                   -- 34
            {squad = squad("SQ_HANGAR_FODDER_B"), source = slot("SQ_HANGAR_FODDER_B")},                   -- 36
            {squad = squad("SQ_HANGAR_FODDER_C"), source = slot("SQ_HANGAR_FODDER_C")},                   -- 38
        },
        -- The hallway Legionary drops with the pod, on Dawn's spawn-rule override (rule 172).
        hallway = {squad = squad("SQ_MILITARY_HALLWAY_DESTRUCTION"), source = slot("SQ_MILITARY_HALLWAY_DESTRUCTION"),
            spawn_rule = slot("SR_MILITARY_HALLWAY_DESTRUCTION")},                                         -- 4
        -- Gate clears. The overlook squad 7 is left out: it fights the allied Frames forever.
        gate_start_clear = {
            loose = squads("SQ_MILITARY_HALLWAY_DESTRUCTION", "SQ_HANGAR_OVERLOOK_A_A",
                "SQ_HANGAR_OVERLOOK_A_A_CENT", "SQ_HANGAR_OVERLOOK_A_C", "SQ_HANGAR_OVERLOOK_B_A"), -- 4, 5, 6, 8, 11
            scene = {},
        },
        gate_hangar_clear = {
            loose = squads("SQ_HANGAR_OVERLOOK_B_B", "SQ_HANGAR_OVERLOOK_SNIPER"),                  -- 13, 18
            scene = {},
        },
        scene_order = {"cover_a", "cover_b", "cover_c", "throw_a"},
    }

    -- Part 2-3 scenes. Every cast squad here is cell-less, so all are reserved and none is bound.
    -- 0x38857CF3 starts the post-gun fight; 0x18EF2ABC is the only key that makes the scene's Cabal
    -- damageable, so it is sent late, from a trigger: sent before the scene's native wait is
    -- active it can be lost and leave the Cabal immune.
    c.heroes.post_gun = {
        scene = scene("SC_FRAME_COVER_SHOOT_DIE"), slot = slot("SC_FRAME_COVER_SHOOT_DIE"), -- 111
        entry = 0x38857CF3,
        reserve = squads("SQ_FRAME_POST_GUN", "SQ_RED_GUARD_POST_GUN", "SQ_RED_GUARD_POST_GUN_JUMP"), -- 112, 114, 115
        objectives = {
            {source = slot("SQ_FRAME_POST_GUN"), objective = slot("OBJ_POST_GUN")},
            {source = slot("SQ_RED_GUARD_POST_GUN"), objective = slot("OBJ_POST_GUN")},
            {source = slot("SQ_RED_GUARD_POST_GUN_JUMP"), objective = slot("OBJ_POST_GUN")},
        },                                                                  -- objective 116
    }
    -- The military fake fights: no entry key and no objectives; 0x18EF2ABC once, at least 5 s after
    -- each was staged, when the player reaches the hangar spawn.
    local function fake_fight(scene_name, frame, cabal)
        return {scene = scene(scene_name), slot = slot(scene_name), entry_delay_ms = 5000,
            reserve = squads(frame, cabal)}
    end
    c.heroes.cover_a = fake_fight("SC_FRAME_COVER_A", "SQ_FRAME_COVER_A", "SQ_RED_GUARD_FAKE_FIGHT_A") -- 70
    c.heroes.cover_b = fake_fight("SC_FRAME_COVER_B", "SQ_FRAME_COVER_B", "SQ_RED_GUARD_FAKE_FIGHT_B") -- 72
    c.heroes.cover_c = fake_fight("SC_FRAME_COVER_C", "SQ_FRAME_COVER_C", "SQ_RED_GUARD_FAKE_FIGHT_C") -- 74
    c.heroes.throw_a = fake_fight("SC_FRAME_THROW_A", "SQ_FRAME_THROW_A", "SQ_RED_GUARD_THROW_A")     -- 77
    c.release_key = 0x18EF2ABC
    c.hero_order_b = {"post_gun", "cover_a", "cover_b", "cover_c", "throw_a"}

    return c
end
