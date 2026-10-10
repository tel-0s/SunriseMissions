-- Shared helpers. The sandbox has no pairs, next, string.match or math.random.
local lib = {}

-- A nil constant would end an ipairs list early and hide the missing name.
function lib.one(value, name)
    assert(value ~= nil, "missing mission constant: " .. name)
    return value
end

function lib.list(...)
    local values = {...}
    for index = 1, select("#", ...) do
        assert(values[index] ~= nil, "mission list entry " .. index .. " is missing")
    end
    return values
end

-- All scopes share the native mission variable and timer stores.
local Scope = {}
Scope.__index = Scope

function Scope:key(name)
    return self.tag .. "." .. name
end

function Scope:variable(name)
    return self.state:variable(self:key(name))
end

function Scope:set_variable(name, value)
    self.context:set_variable(self:key(name), value)
end

function Scope:clear_variable(name)
    return self.context:clear_variable(self:key(name))
end

function Scope:start_timer(name, milliseconds)
    return self.context:start_timer(self:key(name), milliseconds)
end

function Scope:cancel_timer(name)
    return self.context:cancel_timer(self:key(name))
end

function lib.scope(context, state, tag)
    assert(type(tag) == "string" and #tag > 0, "a scope needs a tag")
    return setmetatable({context = context, state = state, tag = tag}, Scope)
end

--- @return The unprefixed timer name when this tag owns it, otherwise nil.
function lib.timer_name(tag, elapsed)
    if type(elapsed) ~= "string" then
        return nil
    end
    local head = tag .. "."
    if string.sub(elapsed, 1, #head) ~= head then
        return nil
    end
    return string.sub(elapsed, #head + 1)
end

--- @return True when the event names this slot.
function lib.is_slot(context, event, slot)
    return event.slot ~= nil and event.slot.id == context:slot(slot).id
end

function lib.place_all(context, squads, mode)
    for _, squad in ipairs(squads) do
        context:squad(squad):place{mode = mode}
    end
end

function lib.activate_scenes(context, scenes)
    for _, scene in ipairs(scenes) do
        context:scene(scene):activate{}
    end
end

-- A sensor holds one state. Its object must be active first.
function lib.play_idles(context, idles)
    for _, idle in ipairs(idles) do
        context:slot(idle.sensor):play_performance{state = idle.state}
    end
end

-- Return to orbit after the completion countdown. complete_mission publishes lifetime state 6:
-- the banner and countdown. The client sends nothing when the countdown ends; it waits for the
-- host. Lifetime state 8 is documented as "client returns to orbit" but is not yet confirmed in
-- game. Call schedule_orbit_return right after complete_mission, and pass every
-- on_event_timer_elapsed through orbit_return_elapsed first.
lib.ORBIT_RETURN_TIMER = "lib.orbit_return"
lib.ORBIT_RETURN_STATE = 8
lib.ORBIT_RETURN_MS = 30000

function lib.schedule_orbit_return(context, milliseconds)
    context:start_timer(lib.ORBIT_RETURN_TIMER, milliseconds or lib.ORBIT_RETURN_MS)
end

-- @return true when the event was the orbit timer and the return was requested.
function lib.orbit_return_elapsed(context, event)
    if event.timer_name ~= lib.ORBIT_RETURN_TIMER then return false end
    local log = context.log
    if log ~= nil then log(context, "orbit return: lifetime state " .. lib.ORBIT_RETURN_STATE) end
    context.lifetime:set{state = context.sdk.lifetime_states:at(lib.ORBIT_RETURN_STATE)}
    return true
end

return lib
