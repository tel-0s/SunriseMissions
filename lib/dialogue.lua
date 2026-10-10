-- A dialogue queue: lines play one at a time, in request order, each holding the line after it
-- for its authored window plus a short gap. A mission sends dialogue rows from many places (steps,
-- triggers, encounter clears). Sent straight to the sensor they overlap and cut each other off.
--
--   local dialogue = require("lib.dialogue")
--   local talk = dialogue.new{
--       key = "hc",                                  -- prefix for this queue's variables/timer
--       sensor = mission.Slot.M_DIALOG_SENSOR_X,     -- the type-53 dialogue sensor
--       windows = {15350, 3933, 0, ...},             -- [row + 1] = window in ms; 0 = never play
--   }
--   talk:say(context, state, 40)                     -- queue row 40 (once per attempt)
--   talk:say_now(context, 34, filter_slot)           -- bypass the queue (filtered lines)
--   talk:hold(context, state, true / false)          -- pause/resume, e.g. while a scene speaks
--   on_event_timer_elapsed: if talk:handle_timer(context, state, event) then return end
--   on_load:                talk:resume(context, state)
--
-- The queue keeps everything in mission variables, so it survives reattach. Rows already played
-- this attempt are skipped. Rows with a zero window have no decoded speech and are never sent.
-- A refused cue is not retried: its window still runs, so the queue cannot stall on it.

local dialogue = {}
dialogue.__index = dialogue

local GAP_MS = 250
local COMMA = 44

local function log(context, text)
    local write = context.log
    if write ~= nil then write(context, text) end
end

function dialogue.new(definition)
    assert(type(definition) == "table", "dialogue needs a definition")
    assert(type(definition.key) == "string" and #definition.key > 0, "dialogue needs a key")
    assert(definition.sensor ~= nil, "dialogue needs a sensor slot")
    assert(type(definition.windows) == "table", "dialogue needs a window table")
    local p = "dlg." .. definition.key .. "."
    local self = setmetatable({
        sensor = definition.sensor,
        windows = definition.windows,
        gap = definition.gap_ms or GAP_MS,
        tag = definition.key,
        k_queue = p .. "queue",
        k_busy = p .. "busy",
        k_hold = p .. "hold",
        k_played0 = p .. "played0",
        k_played1 = p .. "played1",
        timer = p .. "window",
    }, dialogue)
    return self
end

-- Played rows live in two 64-bit masks: rows 0-63 and 64-127.
function dialogue:_played_key(row)
    if row < 64 then return self.k_played0, row end
    return self.k_played1, row - 64
end

function dialogue:played(state, row)
    local key, bit = self:_played_key(row)
    return ((state:variable(key) or 0) >> bit) & 1 == 1
end

function dialogue:_mark(context, state, row)
    local key, bit = self:_played_key(row)
    context:set_variable(key, (state:variable(key) or 0) | (1 << bit))
end

function dialogue:window(row)
    return self.windows[row + 1] or 0
end

-- The queue is "r1,r2,...," in one variable.
local function first(queue)
    for index = 1, #queue do
        if string.byte(queue, index) == COMMA then
            return tonumber(string.sub(queue, 1, index - 1)), string.sub(queue, index + 1)
        end
    end
    return nil, ""
end

local function contains(queue, row)
    local rest = queue
    while #rest > 0 do
        local value
        value, rest = first(rest)
        if value == row then return true end
        if value == nil then return false end
    end
    return false
end

function dialogue:_play(context, state, row)
    self:_mark(context, state, row)
    context:slot(self.sensor):play_dialogue_cue{cue = row}
    context:set_variable(self.k_busy, true)
    context:start_timer(self.timer, self:window(row) + self.gap)
    log(context, self.tag .. ": line " .. row)
end

function dialogue:_pump(context, state)
    if state:variable(self.k_busy) == true or state:variable(self.k_hold) == true then return end
    local queue = state:variable(self.k_queue) or ""
    local row, rest = first(queue)
    if row == nil then return end
    if rest == "" then context:clear_variable(self.k_queue) else context:set_variable(self.k_queue, rest) end
    self:_play(context, state, row)
end

-- Queues one row. Rows already played or queued this attempt, and silent rows, are ignored.
function dialogue:say(context, state, row)
    assert(type(row) == "number", "dialogue row must be a number")
    if self:window(row) <= 0 or self:played(state, row) then return end
    local queue = state:variable(self.k_queue) or ""
    if contains(queue, row) then return end
    local grown = queue .. row .. ","
    if #grown > 127 then
        log(context, self.tag .. ": queue full, dropped line " .. row)
        return
    end
    context:set_variable(self.k_queue, grown)
    self:_pump(context, state)
end

-- Sends one row immediately, outside the queue. Use for filtered lines: the client holds a filtered
-- line until the player enters the filter volume, which would block a queue.
function dialogue:say_now(context, row, filter)
    context:slot(self.sensor):play_dialogue_cue{
        cue = row, filter = filter ~= nil and context:slot(filter) or nil,
    }
    log(context, self.tag .. ": line " .. row .. (filter ~= nil and " (filtered)" or ""))
end

function dialogue:hold(context, state, held)
    if held then
        context:set_variable(self.k_hold, true)
    else
        context:clear_variable(self.k_hold)
        self:_pump(context, state)
    end
end

-- @return true when the event was this queue's timer.
function dialogue:handle_timer(context, state, event)
    if event.timer_name ~= self.timer then return false end
    context:clear_variable(self.k_busy)
    self:_pump(context, state)
    return true
end

-- After a reattach the window timer may be gone while the busy flag survived.
function dialogue:resume(context, state)
    if state:variable(self.k_busy) == true and state:timer(self.timer) == nil then
        context:clear_variable(self.k_busy)
    end
    self:_pump(context, state)
end

return dialogue
