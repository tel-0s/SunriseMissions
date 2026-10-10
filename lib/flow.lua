local flow = {}

-- A flow uses at most 131 mission variables, including its owner, cancellation and checkpoint.
local LIMIT = 64
local DEPTH_LIMIT = 16
local KEY_LIMIT = 63
local ENTERED = 1
local FINISHED = 2

local function name(value)
    assert(type(value) == "string" and #value > 0, "flow names must be nonempty strings")
    return value
end

-- Progress lines for sunrise.log. Builds without context:log return nil for it, so this is a no-op
-- there. The log keeps 16 lines per callback, so each step transition writes one line.
local function trace(context, flow_key, text)
    local log = context.log
    if log ~= nil then log(context, flow_key .. ": " .. text) end
end

function flow.fact(id)
    return {fact = name(id)}
end

function flow.all(...)
    return {all = {...}}
end

function flow.any(...)
    return {any = {...}}
end

local function compile_condition(value, facts, depth)
    assert(depth <= DEPTH_LIMIT, "flow condition is too deep")
    if value == nil then return function() return true end end
    if type(value) == "function" then return value end
    assert(type(value) == "table", "flow condition must be a fact, group or predicate")
    if value.fact then
        assert(value.all == nil and value.any == nil, "flow condition has several operators")
        local key = assert(facts[value.fact], "unknown flow fact: " .. value.fact).key
        return function(_, state) return state:variable(key) == true end
    end
    assert((value.all ~= nil) ~= (value.any ~= nil), "flow condition needs all or any")
    local source = value.all or value.any
    assert(type(source) == "table" and #source > 0 and #source <= LIMIT,
        "flow condition group must be a bounded nonempty list")
    local children = {}
    for index = 1, #source do
        assert(source[index] ~= nil, "flow condition list has a hole")
        children[index] = compile_condition(source[index], facts, depth + 1)
    end
    local all = value.all ~= nil
    return function(context, state)
        for _, child in ipairs(children) do
            local result = child(context, state) == true
            if result ~= all then return result end
        end
        return all
    end
end

local function state_key(prefix, category, id)
    local key = prefix .. "." .. category .. "." .. name(id)
    assert(#key <= KEY_LIMIT, "flow state key is too long")
    return key
end

local function ordered_steps(source, prefix, facts)
    assert(type(source) == "table" and #source > 0 and #source <= LIMIT,
        "flow needs a bounded nonempty step list")
    local by_id, pending, ordered = {}, {}, {}
    for index = 1, #source do
        local item = source[index]
        assert(type(item) == "table", "flow step list has a hole")
        local id = name(item.id)
        assert(by_id[id] == nil, "duplicate flow step: " .. id)
        assert(item.run == nil or type(item.run) == "function", "flow action must be a function")
        assert(item.checkpoint == nil or type(item.checkpoint) == "boolean",
            "flow checkpoint must be a boolean")
        local reset = item.reset_facts or {}
        assert(type(reset) == "table" and #reset <= LIMIT, "flow reset facts must be bounded")
        assert(#reset == 0 or item.checkpoint == true, "only a checkpoint resets facts")
        local reset_keys = {}
        for index = 1, #reset do
            reset_keys[index] = assert(facts[name(reset[index])],
                "unknown flow fact: " .. tostring(reset[index])).key
        end
        local step = {id = id, key = state_key(prefix, "step", id), run = item.run,
            checkpoint = item.checkpoint == true, reset_facts = reset_keys,
            start = compile_condition(item.when, facts, 1),
            ready = compile_condition(item.await, facts, 1), after = {}}
        local after = item.after or {}
        assert(type(after) == "table" and #after <= LIMIT, "flow dependencies must be bounded")
        local seen = {}
        for dependency = 1, #after do
            local target = name(after[dependency])
            assert(target ~= id and not seen[target], "self or duplicate flow dependency")
            seen[target] = true
            step.after[dependency] = target
        end
        by_id[id], pending[index] = step, step
    end
    local placed = {}
    while #ordered < #pending do
        local added = false
        for _, step in ipairs(pending) do
            if not placed[step.id] then
                local ready = true
                for _, dependency in ipairs(step.after) do
                    assert(by_id[dependency], "unknown flow dependency: " .. dependency)
                    ready = ready and placed[dependency] == true
                end
                if ready then
                    placed[step.id], added = true, true
                    ordered[#ordered + 1] = step
                end
            end
        end
        assert(added, "flow dependency cycle")
    end
    for _, step in ipairs(ordered) do
        for index, dependency in ipairs(step.after) do
            step.after[index] = by_id[dependency].key
        end
    end
    return ordered
end

function flow.new(definition)
    assert(type(definition) == "table", "flow needs a definition")
    local prefix = "flow." .. name(definition.key)
    local owner_key = state_key(prefix, "state", "owner")
    local canceled_key = state_key(prefix, "state", "canceled")
    local checkpoint_key = state_key(prefix, "state", "checkpoint")
    local facts, by_id = {}, {}
    local source = definition.facts or {}
    assert(type(source) == "table" and #source <= LIMIT, "flow fact list must be bounded")
    for index = 1, #source do
        local item = source[index]
        assert(type(item) == "table", "flow fact list has a hole")
        local id = name(item.id)
        assert(not by_id[id], "duplicate flow fact: " .. id)
        assert(type(item.observe) == "function", "flow fact needs an observer")
        local fact = {id = id, key = state_key(prefix, "fact", id), observe = item.observe}
        by_id[id], facts[index] = fact, fact
    end
    local steps = ordered_steps(definition.steps, prefix, by_id)
    local step_keys = {}
    for _, step in ipairs(steps) do step_keys[step.id] = step.key end
    -- Each checkpoint replays itself and every step that depends on it. Steps are ordered.
    local replays = {}
    for _, checkpoint in ipairs(steps) do
        if checkpoint.checkpoint then
            local replay = {[checkpoint.key] = true, facts = checkpoint.reset_facts}
            for _, step in ipairs(steps) do
                for _, dependency in ipairs(step.after) do
                    if dependency == checkpoint.key or replay[dependency] then
                        replay[step.key] = true
                    end
                end
            end
            replays[checkpoint.id] = replay
        end
    end
    local result = {}

    -- All progress lives in the callback candidate, so a failed callback rolls it back.
    local function prepare(context, state)
        local owner = context.attempt_generation
        assert(owner ~= nil, "flow needs native attempt ownership")
        local previous = state:variable(owner_key)
        if previous ~= owner then
            -- A restart after a checkpoint keeps what came before it and replays the rest.
            local replay = previous ~= nil and replays[state:variable(checkpoint_key)]
            if replay then
                for _, step in ipairs(steps) do
                    if replay[step.key] then context:clear_variable(step.key) end
                end
                for _, key in ipairs(replay.facts) do context:clear_variable(key) end
            else
                for _, fact in ipairs(facts) do context:clear_variable(fact.key) end
                for _, step in ipairs(steps) do context:clear_variable(step.key) end
                context:clear_variable(checkpoint_key)
            end
            context:clear_variable(canceled_key)
            context:set_variable(owner_key, owner)
        end
        return state:variable(canceled_key) ~= true
    end

    function result:advance(context, state)
        if not prepare(context, state) then return false end
        local complete = true
        for _, step in ipairs(steps) do
            local progress = state:variable(step.key)
            if progress ~= FINISHED then
                local ready = true
                for _, dependency in ipairs(step.after) do
                    ready = ready and state:variable(dependency) == FINISHED
                end
                -- The start condition only holds a step back; an entered step never rechecks it.
                if ready and progress ~= ENTERED then
                    ready = step.start(context, state) == true
                end
                if ready then
                    local entering = progress ~= ENTERED
                    if entering then
                        if step.run then step.run(context, state) end
                        context:set_variable(step.key, ENTERED)
                    end
                    if step.ready(context, state) == true then
                        context:set_variable(step.key, FINISHED)
                        if step.checkpoint then context:set_variable(checkpoint_key, step.id) end
                        trace(context, definition.key, "step " .. step.id .. (entering and " ran" or " done"))
                    else
                        complete = false
                        if entering then trace(context, definition.key, "step " .. step.id .. " waiting") end
                    end
                else
                    complete = false
                end
            end
        end
        return complete
    end

    function result:handle(context, state, event)
        if event == nil or event.attempt_generation ~= context.attempt_generation then
            return false
        end
        if not prepare(context, state) then return false end
        for _, fact in ipairs(facts) do
            if state:variable(fact.key) ~= true and fact.observe(context, state, event) == true then
                context:set_variable(fact.key, true)
                trace(context, definition.key, "fact " .. fact.id)
            end
        end
        return self:advance(context, state)
    end

    function result:cancel(context, state)
        if prepare(context, state) then context:set_variable(canceled_key, true) end
    end

    function result:finished(context, state)
        if state:variable(owner_key) ~= context.attempt_generation
            or state:variable(canceled_key) then return false end
        for _, step in ipairs(steps) do
            if state:variable(step.key) ~= FINISHED then return false end
        end
        return true
    end

    function result:fact(context, state, id)
        local retained = assert(by_id[id], "unknown flow fact: " .. tostring(id))
        if state:variable(owner_key) ~= context.attempt_generation
            or state:variable(canceled_key) then return false end
        return state:variable(retained.key) == true
    end

    function result:started(context, state, id)
        local key = assert(step_keys[id], "unknown flow step: " .. tostring(id))
        if state:variable(owner_key) ~= context.attempt_generation
            or state:variable(canceled_key) then return false end
        local progress = state:variable(key)
        return progress == ENTERED or progress == FINISHED
    end

    return result
end

return flow
