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

    -- ---- Part 4: the plaza (region 48; the client streams into it) --------------------------
    -- Dawn graphs 4 ("Plaza") and 5 ("Plaza assaults"). Zavala is one actor cell
    -- (SQ_ZAVALA_BANSHEE) reused by all four plaza scenes, so a scene is stopped before the next one
    -- activates, with a short stagger. Completions the script cannot observe (Zavala's arrival
    -- kills, each Ward, the strike, the revival animation) are timers or proxies.

    c.lines.traveler = 40       -- the Traveler sighting; the Cabal ship prop appears when it plays
    c.lines.meet = 50
    c.lines.first_assault = 52
    c.lines.ward_1 = 53
    c.lines.second_assault = 51
    c.lines.second_clear = 55
    c.lines.ward_2 = 57        -- only once row 55 has finished
    c.lines.zavala_down = 47
    c.lines.last_assault = 54
    c.lines.held = 59

    local function wave(objective, ...)
        local out = {}
        for index, entry in ipairs({...}) do
            out[index] = {squad = squad(entry[1]), source = slot(entry[1]), counts = entry[2]}
        end
        return {members = out, objective = objective}
    end

    c.plaza = {
        state = state("STATE_80B500BC_0006_0000_80B500B6"),
        goals = {
            fight = {directive = directive("FIGHT_WITH_ZAVALA"), navpoint = slot("AP_PLAZA")},     -- objective 5
            assaults = directive("ASSAULTS_REPELLED"),                                          -- objective 7
            leave = {directive = directive("LEAVE_THE_PLAZA_AND_FIND_THE_SPEAKER_E68735ED"),
                navpoint = slot("SLOT_000E_80B51058")},                                         -- objective 9
        },
        triggers = {
            military_500 = slot("PT_TOWERFALL_MILITARY_500"),   -- shares its polygon with the tv_dialog volume
            goto_plaza = slot("PT_GOTO_PLAZA_80B51058"),
            spawn_init = slot("PT_PLAZA_SPAWN_INIT"),
            meet = slot("PT_PLAZA_ZAVALA_MEET"),
            goto_boulevard = slot("PT_GOTO_BOULEVARD"),         -- armed only once the plaza is held
        },
        trigger_order = {"military_500", "goto_plaza", "spawn_init", "meet"},
        -- Off on arrival. BUBBLE_SHIELD_1 is a second, premature Ward: it is never turned on.
        off_on_arrival = slots("BUBBLE_SHIELD_1", "O_ROCKET_KILLS_ZAVALA", "O_DEAD_ZAVALA_INTERACT",
            "O_DEAD_ZAVALA_GHOST", "O_MISSILE_SPAWNER", "O_MISSILE_SPAWNER_SCRIPT"),
        bubble_shield = slot("BUBBLE_SHIELD_1"),
        skybox = slots("OP_ZAVALA_PINNED", "SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_5",
            "SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_0", "SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_1",
            "SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_2", "SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_3",
            "SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_4", "SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_6",
            "SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_7", "SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_LEFT_0",
            "SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_LEFT_1", "SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_LEFT_2"),
        cabal_ship = slot("SPECOPS_PLAZA_SHIP_BATTLE_O_CABAL_SHIP"),
        zavala_pinned = slot("OP_ZAVALA_PINNED"),
        zavala_grenade = slot("O_ZAVALA_GRENADE_1"),
        orb_spawner = slot("O_ORB_SPAWNER"),
        rocket = slot("O_ROCKET_KILLS_ZAVALA"),
        missile_spawner = slot("O_MISSILE_SPAWNER"),
        missile_script = slots("O_ROCKET_KILLS_ZAVALA", "O_MISSILE_SPAWNER", "O_MISSILE_SPAWNER_SCRIPT"),
        missile_device = slot("D_MISSILE_SPAWNER_SCRIPT"),
        dead_interact = slot("O_DEAD_ZAVALA_INTERACT"),
        dead_ghost = slot("O_DEAD_ZAVALA_GHOST"),
        dead_ghost_device = slot("D_DEAD_ZAVALA_GHOST"),
        zavala_cell = slot("SQ_ZAVALA_BANSHEE"),
        zavala = squad("SQ_ZAVALA"),
        carriers_first = {
            objects = slots("O_CABAL_CARRIER_L_80B5103A", "O_CABAL_CARRIER_R_80B5103A"),
            devices = slots("D_CABAL_CARRIER_L_80B5103A", "D_CABAL_CARRIER_R_80B5103A"),
        },
        carriers_last = {
            objects = slots("O_CABAL_CARRIER_B", "O_CABAL_CARRIER_FAR_A", "O_CABAL_CARRIER_FAR_A_1",
                "O_CABAL_CARRIER_FAR_A_2", "O_CABAL_CARRIER_FAR_B", "O_CABAL_CARRIER_FAR_B_1",
                "O_CABAL_CARRIER_FAR_B_2", "O_CABAL_CARRIER_FAR_C", "O_CABAL_CARRIER_FAR_C_1",
                "O_CABAL_CARRIER_FAR_C_2"),
            devices = slots("D_CABAL_CARRIER_B", "D_CABAL_CARRIER_FAR_A", "D_CABAL_CARRIER_FAR_A_1",
                "D_CABAL_CARRIER_FAR_A_2", "D_CABAL_CARRIER_FAR_B", "D_CABAL_CARRIER_FAR_B_1",
                "D_CABAL_CARRIER_FAR_B_2", "D_CABAL_CARRIER_FAR_C", "D_CABAL_CARRIER_FAR_C_1",
                "D_CABAL_CARRIER_FAR_C_2"),
        },
        -- Zavala kills these in his arrival branch (0x1BED1ED3); all at 0 stands in for its end.
        arrival_kills = squads("SQUAD_KILL_CABAL_5", "SQUAD_KILL_CABAL_6", "SQUAD_KILL_CABAL_7",
            "SQUAD_KILL_CABAL_8"),
        -- Waves with Dawn's lane counts. SQ_PLAZA_REINFORCE_A_C's lane 1 has no actor class in the
        -- SDK, so only its lane 2 is requested.
        init = wave(slot("OBJ_PLAZA_KILL_CABAL"), {"SQUAD_KILL_CABAL_3", {1}}, {"SQUAD_KILL_CABAL_4", {1}},
            {"SQUAD_CABAL_DROPOFF_1", {1}}),
        first = wave(slot("OBJ_PLAZA_REINFORCE"), {"SQ_PLAZA_REINFORCE_START_A", {1}},
            {"SQ_PLAZA_REINFORCE_START_B", {3}}, {"SQ_PLAZA_INTERIM_A_A", {3}}, {"SQ_PLAZA_INTERIM_A_B", {3}}),
        second = wave(slot("OBJ_PLAZA_REINFORCE"), {"SQ_PLAZA_REINFORCE_A_A_EXTRA", {4}},
            {"SQ_PLAZA_REINFORCE_A_C", {0, 1}}, {"SQ_PLAZA_REINFORCE_A_D", {3}},
            {"SQ_PLAZA_REINFORCE_A_D_EXTRA", {3}}),
        last = wave(slot("OBJ_PLAZA_REINFORCE"), {"SQ_PLAZA_REINFORCE_B_A", {3}},
            {"SQ_PLAZA_REINFORCE_B_A_EXTRA", {3}}, {"SQ_PLAZA_REINFORCE_B_B", {3}},
            {"SQ_PLAZA_REINFORCE_B_B_EXTRA", {3}}),
        -- Timings the script cannot observe. Ward from PR #8 (the performer casts at 5.3 s); the rest
        -- are estimates to tune in playtests.
        ward_ms = 12000,
        strike_ms = 10000,
        arrival_fallback_ms = 15000,
        revive_fallback_ms = 20000,
        revival_ms = 6000,
        revival_fallback_ms = 10000,
        stagger_ms = 500,
    }
    local function loose(w)
        local out = {}
        for index, member in ipairs(w.members) do out[index] = member.squad end
        return {loose = out, scene = {}}
    end
    c.plaza.init_clear = loose(c.plaza.init)
    c.plaza.first_clear = loose(c.plaza.first)
    c.plaza.second_clear = loose(c.plaza.second)
    c.plaza.last_clear = loose(c.plaza.last)

    -- Plaza scenes. Zavala's cell is bound for his own scene; the others reuse the cast pairing.
    -- Never an objective on SQ_ZAVALA, never place{} a scene squad.
    local kill = slot("OBJ_PLAZA_KILL_CABAL")
    local reinforce = slot("OBJ_PLAZA_REINFORCE")
    c.heroes.zavala_arrival = {
        scene = scene("SC_ZAVALA"), slot = slot("SC_ZAVALA"),
        entry = 0xB8C5C0A5, extra = {0x1BED1ED3},
        bind = slots("SQ_ZAVALA_BANSHEE"),
        reserve = squads("SQUAD_KILL_CABAL_5", "SQUAD_KILL_CABAL_6", "SQUAD_KILL_CABAL_7", "SQUAD_KILL_CABAL_8"),
        objectives = {
            {source = slot("SQUAD_KILL_CABAL_5"), objective = kill}, {source = slot("SQUAD_KILL_CABAL_6"), objective = kill},
            {source = slot("SQUAD_KILL_CABAL_7"), objective = kill}, {source = slot("SQUAD_KILL_CABAL_8"), objective = kill},
        },
    }
    c.heroes.combat_1 = {
        scene = scene("SC_ZAVALA_COMBAT"), slot = slot("SC_ZAVALA_COMBAT"),
        reserve = squads("SQUAD_KILL_CABAL_1", "SQUAD_KILL_CABAL_2", "SQ_PLAZA_REINFORCE_A_A", "SQ_PLAZA_REINFORCE_A_B"),
        objectives = {
            {source = slot("SQUAD_KILL_CABAL_1"), objective = kill}, {source = slot("SQUAD_KILL_CABAL_2"), objective = kill},
            {source = slot("SQ_PLAZA_REINFORCE_A_A"), objective = reinforce},
            {source = slot("SQ_PLAZA_REINFORCE_A_B"), objective = reinforce},
        },
    }
    c.heroes.combat_2 = {scene = scene("SC_ZAVALA_COMBAT"), slot = slot("SC_ZAVALA_COMBAT")}
    c.heroes.combat_3 = {scene = scene("SC_ZAVALA_COMBAT"), slot = slot("SC_ZAVALA_COMBAT")}
    c.heroes.ward_1 = {scene = scene("SC_ZAVALA_BUNKER_SHIELD_BUNKER"), slot = slot("SC_ZAVALA_BUNKER_SHIELD_BUNKER"),
        entry = 0xC021F76C}
    c.heroes.ward_2 = {scene = scene("SC_ZAVALA_BUNKER_SHIELD_BUNKER"), slot = slot("SC_ZAVALA_BUNKER_SHIELD_BUNKER"),
        entry = 0xC021F76C}
    c.heroes.death = {scene = scene("SC_ZAVALA_SHIELD_DEATH"), slot = slot("SC_ZAVALA_SHIELD_DEATH"),
        entry = 0xC021F76F}
    -- The revival: only 0xB8C5C0A5. 0x1BED1ED3 would replay the four scripted kills.
    c.heroes.revival = {scene = scene("SC_ZAVALA"), slot = slot("SC_ZAVALA"),
        entry = 0xB8C5C0A5, bind = slots("SQ_ZAVALA_BANSHEE")}
    c.hero_order_c = {"zavala_arrival", "combat_1", "ward_1"}
    c.hero_order_d = {"combat_2", "ward_2", "death", "revival", "combat_3"}

    return c
end
