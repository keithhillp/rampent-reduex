-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

--[[
    Planet-wide strategy.

    The perimeter map collects what the hive knows about each stretch of the
    player's defenses: scout surveys, how attacks there went, and recent
    breaches. Joint offensives use it to pick the weakest known sector in
    reach, and bring several bases' attacks together: their squads gather at
    rally points around the objective and charge it at the same time.
--]]

if StrategyG then
    return StrategyG
end
local Strategy = {}

--

local Universe

-- imports

local Constants = require("Constants")
local Telemetry = require("Telemetry")

-- Constants

local PERIMETER_CELL_SIZE = Constants.PERIMETER_CELL_SIZE
local PERIMETER_TTL = Constants.PERIMETER_TTL
local PERIMETER_UNKNOWN_STRENGTH = Constants.PERIMETER_UNKNOWN_STRENGTH
local PERIMETER_STRENGTH_WEIGHT = Constants.PERIMETER_STRENGTH_WEIGHT
local PERIMETER_DISTANCE_SCALE = Constants.PERIMETER_DISTANCE_SCALE
local BREACH_TTL = Constants.BREACH_TTL
local BREACH_SCORE_BONUS = Constants.BREACH_SCORE_BONUS
local BREACH_OBJECTIVE_BONUS = Constants.BREACH_OBJECTIVE_BONUS
local OBJECTIVE_RANGE = Constants.OBJECTIVE_RANGE
local OBJECTIVE_EXPLORE_CHANCE = Constants.OBJECTIVE_EXPLORE_CHANCE
local OFFENSIVE_JOIN_RANGE = Constants.OFFENSIVE_JOIN_RANGE
local OFFENSIVE_FORMING_TIME = Constants.OFFENSIVE_FORMING_TIME
local OFFENSIVE_MAX_WAIT = Constants.OFFENSIVE_MAX_WAIT
local OFFENSIVE_TTL = Constants.OFFENSIVE_TTL
local OFFENSIVE_RALLY_DISTANCE = Constants.OFFENSIVE_RALLY_DISTANCE
local CAPS_UPDATE_INTERVAL = Constants.CAPS_UPDATE_INTERVAL
local SURGE_HALF_LIFE = Constants.SURGE_HALF_LIFE
local SURGE_THRESHOLD = Constants.SURGE_THRESHOLD
local SURGE_TURRET_WEIGHT = Constants.SURGE_TURRET_WEIGHT
local SURGE_DURATION = Constants.SURGE_DURATION
local CAPS_MIN_SQUADS = Constants.CAPS_MIN_SQUADS
local CAPS_MIN_BUILDERS = Constants.CAPS_MIN_BUILDERS
local CAPS_MIN_SQUADS_LATE = Constants.CAPS_MIN_SQUADS_LATE
local CAPS_MIN_BUILDERS_LATE = Constants.CAPS_MIN_BUILDERS_LATE
local SQUADS_NESTS_PER_SQUAD = Constants.SQUADS_NESTS_PER_SQUAD
local BUILDERS_NEST_CHUNKS_PER_BUILDER = Constants.BUILDERS_NEST_CHUNKS_PER_BUILDER
local HIVE_TELEMETRY_INTERVAL = Constants.HIVE_TELEMETRY_INTERVAL

-- imported functions

local mFloor = math.floor
local mSqrt = math.sqrt
local mMin = math.min
local mMax = math.max
local mCeil = math.ceil
local sFormat = string.format

-- module code

local function cellKey(position)
    return mFloor(position.x / PERIMETER_CELL_SIZE) .. ":" .. mFloor(position.y / PERIMETER_CELL_SIZE)
end

local function getCell(map, position, tick)
    local perimeter = map.perimeter
    if not perimeter then
        perimeter = {}
        map.perimeter = perimeter
    end
    local key = cellKey(position)
    local cell = perimeter[key]
    if not cell then
        cell = {
            key = key,
            x = position.x,
            y = position.y,
            attacks = 0,
            successes = 0,
            tick = tick
        }
        perimeter[key] = cell
    end
    return cell
end

local function distance(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return mSqrt((dx * dx) + (dy * dy))
end

local function printStrategy(message)
    if Universe.printTactics then
        game.print("Rampant: " .. message)
    end
end

--[[
    Scout surveys give a sector its strength. Lasers and teslas weigh most, a
    few walls barely matter, a thick wall adds up.
--]]
function Strategy.defenseStrength(report)
    return ((report.electric - report.tesla) * 1.0)
        + (report.tesla * 1.5)
        + (report.gun * 0.7)
        + (report.flame * 1.5)
        + (report.wall * 0.01)
end

function Strategy.recordScout(map, position, report, tick)
    if not position then
        return
    end
    local cell = getCell(map, position, tick)
    -- the surveyed spot is where the defense is, use it as the sector's objective
    cell.x = position.x
    cell.y = position.y
    cell.strength = Strategy.defenseStrength(report)
    cell.scoutTick = tick
    cell.tick = tick
end

function Strategy.recordOutcome(map, impact, success, tick)
    if not impact then
        return
    end
    local cell = getCell(map, impact, tick)
    cell.attacks = cell.attacks + 1
    if success then
        cell.successes = cell.successes + 1
    end
    cell.tick = tick
end

--[[
    A destroyed wall or turret opens a breach. The chunk draws attacking squads
    for a while and the sector becomes a preferred objective.
--]]
--[[
    Surges. Breaches and turret kills in one sector add up, fading by half each
    SURGE_HALF_LIFE. Past SURGE_THRESHOLD the hive declares a breakthrough there:
    nearby bases send their next attacks straight to it and squads already in
    the field divert to it, while every new breach keeps it going.
--]]
local function declareSurge(map, cell, position, tick)
    local surge = map.surge
    if surge and (tick < surge.untilTick) then
        if (surge.key == cell.key) then
            surge.untilTick = tick + SURGE_DURATION
            surge.breaches = surge.breaches + 1
            return
        end
        if (surge.score >= cell.surgeScore) then
            -- a stronger breakthrough elsewhere stays the focus
            return
        end
    end
    surge = {
        key = cell.key,
        x = position.x,
        y = position.y,
        score = cell.surgeScore,
        started = tick,
        untilTick = tick + SURGE_DURATION,
        breaches = 1,
        attacks = 0,
        redirects = 0
    }
    map.surge = surge
    printStrategy(sFormat("%s breakthrough at [gps=%d,%d,%s], the hive surges",
                          map.surface.name, mFloor(position.x), mFloor(position.y), map.surface.name))
    if Telemetry.enabled() then
        Telemetry.record("surge_declared", {
                surface = map.surface.name,
                sector = cell.key,
                score = cell.surgeScore,
                position = Telemetry.position(position)
        })
    end
end

function Strategy.activeSurge(map, position, range, tick)
    local surge = map.surge
    if (not surge) or (tick >= surge.untilTick) then
        return nil
    end
    -- written so a base without chunks, whose position is not a number, is never in range
    if not (distance(surge, position) <= range) then
        return nil
    end
    return surge
end

function Strategy.recordBreach(map, chunk, position, entityName, tick, entityType)
    chunk.breachTick = tick
    local cell = getCell(map, position, tick)
    if Universe.enableOffensives then
        local score = cell.surgeScore or 0
        if cell.surgeTick then
            score = score * (0.5 ^ ((tick - cell.surgeTick) / SURGE_HALF_LIFE))
        end
        local weight = 1
        if (entityType ~= "wall") and (entityType ~= "gate") then
            weight = SURGE_TURRET_WEIGHT
        end
        cell.surgeScore = score + weight
        cell.surgeTick = tick
        if (cell.surgeScore >= SURGE_THRESHOLD) then
            declareSurge(map, cell, position, tick)
        end
    end
    if (not cell.breachTick) or ((tick - cell.breachTick) > BREACH_TTL) then
        printStrategy(sFormat("%s breach opened at [gps=%d,%d,%s] (%s destroyed)",
                              map.surface.name, mFloor(position.x), mFloor(position.y),
                              map.surface.name, entityName))
        if Telemetry.enabled() then
            Telemetry.record("breach", {
                    surface = map.surface.name,
                    sector = cell.key,
                    entity = entityName,
                    position = Telemetry.position(position)
            })
        end
    end
    cell.breachTick = tick
    cell.tick = tick
end

function Strategy.breachBonus(chunk, tick)
    local breachTick = chunk.breachTick
    if breachTick and ((tick - breachTick) < BREACH_TTL) then
        return BREACH_SCORE_BONUS
    end
    return 1
end

local function targetedCells()
    local targeted = {}
    for _, offensive in pairs(Universe.offensives) do
        if not offensive.finished then
            targeted[offensive.cellKey] = true
        end
    end
    return targeted
end

--[[
    The weakest known sector in reach: few turrets, attacks there have worked
    before, a recent breach, and not too far. Sectors another offensive is
    already hitting are skipped so the hive spreads its pressure.
--]]
local function chooseObjective(map, origin, tick)
    local perimeter = map.perimeter
    if not perimeter then
        return nil
    end
    local targeted = targetedCells()
    local candidates = {}
    for key, cell in pairs(perimeter) do
        if ((tick - cell.tick) <= PERIMETER_TTL) and (not targeted[key]) then
            local range = distance(cell, origin)
            if (range <= OBJECTIVE_RANGE) then
                local strength = cell.strength or PERIMETER_UNKNOWN_STRENGTH
                local success = (cell.successes + 1) / (cell.attacks + 2)
                local breach = 1
                if cell.breachTick and ((tick - cell.breachTick) < BREACH_TTL) then
                    breach = BREACH_OBJECTIVE_BONUS
                end
                local score = (success * breach)
                    / (1 + (strength * PERIMETER_STRENGTH_WEIGHT))
                    / (1 + (range / PERIMETER_DISTANCE_SCALE))
                candidates[#candidates+1] = {cell = cell, score = score}
            end
        end
    end
    if (#candidates == 0) then
        return nil
    end
    table.sort(candidates, function(a, b)
        if a.score == b.score then
            return a.cell.key < b.cell.key
        end
        return a.score > b.score
    end)
    if (#candidates > 1) and (Universe.random() < OBJECTIVE_EXPLORE_CHANCE) then
        return candidates[Universe.random(mMin(3, #candidates))].cell
    end
    return candidates[1].cell
end

Strategy.chooseObjective = chooseObjective

--[[
    Called when a base plans an attack. Its joint gene decides whether the
    attack takes part in an offensive: it joins one still forming nearby, or
    founds a new one against the weakest sector in reach.
--]]
function Strategy.assignOffensive(base, attack, tick)
    if (not Universe.enableOffensives) or (Universe.random() >= attack.genes.joint) then
        return nil
    end
    local origin = {x = base.x, y = base.y}
    local map = base.map
    for _, offensive in pairs(Universe.offensives) do
        if (not offensive.finished)
            and (not offensive.launched)
            and (offensive.map == map)
            and (tick < offensive.formingUntil)
            and (distance(offensive.objective, origin) <= OFFENSIVE_JOIN_RANGE)
        then
            offensive.attacks[#offensive.attacks+1] = attack
            offensive.bases[base.id] = true
            if Telemetry.enabled() then
                Telemetry.record("offensive_joined", {
                        offensive = offensive.id,
                        base = base.id,
                        attacks = #offensive.attacks
                })
            end
            return offensive
        end
    end

    local cell = chooseObjective(map, origin, tick)
    if not cell then
        return nil
    end
    Universe.offensiveId = Universe.offensiveId + 1
    local offensive = {
        id = Universe.offensiveId,
        map = map,
        surface = map.surface,
        cellKey = cell.key,
        objective = {x = cell.x, y = cell.y},
        attacks = {attack},
        bases = {[base.id] = true},
        strength = cell.strength or PERIMETER_UNKNOWN_STRENGTH,
        squads = {},
        founded = tick,
        formingUntil = tick + OFFENSIVE_FORMING_TIME,
        deadline = tick + OFFENSIVE_MAX_WAIT,
        launched = false
    }
    Universe.offensives[offensive.id] = offensive
    printStrategy(sFormat("%s base %d calls an offensive on [gps=%d,%d,%s] (strength %.1f, %d of %d attacks there worked)",
                          map.surface.name, base.id, mFloor(cell.x), mFloor(cell.y), map.surface.name,
                          cell.strength or PERIMETER_UNKNOWN_STRENGTH, cell.successes, cell.attacks))
    if Telemetry.enabled() then
        Telemetry.record("offensive_founded", {
                offensive = offensive.id,
                surface = map.surface.name,
                base = base.id,
                sector = cell.key,
                strength = cell.strength,
                attacksThere = cell.attacks,
                successesThere = cell.successes,
                breach = (cell.breachTick ~= nil) and ((tick - cell.breachTick) < BREACH_TTL),
                objective = Telemetry.position(offensive.objective),
                distance = distance(cell, origin)
        })
    end
    return offensive
end

--[[
    Each squad gathers on its own side of the objective, on the line back
    toward where it came from, so every squad has the same distance to charge.
--]]
function Strategy.rallyPoint(offensive, position)
    local objective = offensive.objective
    local dx = position.x - objective.x
    local dy = position.y - objective.y
    local length = mSqrt((dx * dx) + (dy * dy))
    if (length < 1) then
        return {x = objective.x, y = objective.y}
    end
    local reach = mMin(OFFENSIVE_RALLY_DISTANCE, length)
    return {
        x = objective.x + ((dx / length) * reach),
        y = objective.y + ((dy / length) * reach)
    }
end

local function pendingAttacks(offensive, tick)
    local pending = 0
    for i=1,#offensive.attacks do
        local attack = offensive.attacks[i]
        if (not attack.launched)
            and (not attack.finished)
            and (not attack.abandoned)
            and ((not attack.deadline) or (tick < attack.deadline))
        then
            pending = pending + 1
        end
    end
    return pending
end

--[[
    An offensive charges once every joined attack has launched and every squad
    has reached its rally point, or at the deadline with whoever has arrived.
--]]
function Strategy.offensiveReady(offensive, tick)
    if offensive.launched then
        return true
    end
    local moving = 0
    local rallied = 0
    for _, squad in pairs(offensive.squads) do
        if squad.group.valid then
            if (squad.offensivePhase == "rallied") then
                rallied = rallied + 1
            elseif (squad.offensivePhase == "moving") then
                moving = moving + 1
            end
        end
    end
    if (rallied == 0) then
        return false
    end
    local pending = pendingAttacks(offensive, tick)
    local everyoneIn = (tick >= offensive.formingUntil) and (pending == 0) and (moving == 0)
    if not (everyoneIn or (tick >= offensive.deadline)) then
        return false
    end
    offensive.launched = true
    offensive.launchTick = tick
    local bases = 0
    for _ in pairs(offensive.bases) do
        bases = bases + 1
    end
    printStrategy(sFormat("%s offensive %d charges with %d squads from %d bases on [gps=%d,%d,%s]",
                          offensive.surface.name, offensive.id, rallied, bases,
                          mFloor(offensive.objective.x), mFloor(offensive.objective.y), offensive.surface.name))
    if Telemetry.enabled() then
        Telemetry.record("offensive_launched", {
                offensive = offensive.id,
                rallied = rallied,
                stillMoving = moving,
                pendingAttacks = pending,
                attacks = #offensive.attacks,
                bases = bases,
                waitedTicks = tick - offensive.founded,
                deadlineHit = not everyoneIn
        })
    end
    return true
end

local function endOffensive(offensive, tick, reason)
    offensive.finished = true
    Universe.offensives[offensive.id] = nil
    if Telemetry.enabled() then
        local squads = 0
        for _ in pairs(offensive.squads) do
            squads = squads + 1
        end
        Telemetry.record("offensive_ended", {
                offensive = offensive.id,
                reason = reason,
                launched = offensive.launched,
                squads = squads,
                durationTicks = tick - offensive.founded
        })
    end
    -- drop references to squads and attacks so they can be collected
    offensive.squads = {}
    offensive.attacks = {}
end

--[[
    Offensives end when their squads are all gone after the charge, when they
    run too long, or when they never gathered anyone by their deadline.
--]]
function Strategy.process(tick)
    local offensives = Universe.offensives
    local offensiveId = Universe.offensiveIterator
    local offensive
    if not offensiveId then
        offensiveId, offensive = next(offensives, nil)
    else
        offensive = offensives[offensiveId]
    end
    if not offensiveId then
        Universe.offensiveIterator = nil
        return
    end
    Universe.offensiveIterator = next(offensives, offensiveId)
    if not offensive then
        return
    end
    if not offensive.surface.valid then
        endOffensive(offensive, tick, "surface gone")
        return
    end
    local alive = 0
    for groupNumber, squad in pairs(offensive.squads) do
        if squad.group.valid then
            alive = alive + 1
        else
            offensive.squads[groupNumber] = nil
        end
    end
    if offensive.launched then
        if (alive == 0) or ((tick - offensive.launchTick) > OFFENSIVE_TTL) then
            endOffensive(offensive, tick, ((alive == 0) and "squads gone") or "timed out")
        end
    elseif (tick > offensive.deadline) and (alive == 0) and (pendingAttacks(offensive, tick) == 0) then
        endOffensive(offensive, tick, "nobody arrived")
    elseif (tick > (offensive.deadline + OFFENSIVE_TTL)) then
        endOffensive(offensive, tick, "timed out")
    end
end

--[[
    Caps scale with the hive: about one squad per SQUADS_NESTS_PER_SQUAD active
    nests and one builder per BUILDERS_NEST_CHUNKS_PER_BUILDER nest chunks,
    growing with evolution, between a small floor and the ceiling settings.
--]]
function Strategy.updateCaps(tick)
    if Universe.capsTick and ((tick - Universe.capsTick) < CAPS_UPDATE_INTERVAL) then
        return
    end
    Universe.capsTick = tick
    local activeNests = 0
    for _, base in pairs(Universe.bases) do
        activeNests = activeNests + (base.activeNests or 0) + (base.activeRaidNests or 0)
    end
    local nestChunks = table_size(Universe.chunkToNests)
    local evolution = Universe.evolutionLevel or 0
    local growth = 0.25 + (0.75 * evolution)
    local squadFloor = CAPS_MIN_SQUADS + ((CAPS_MIN_SQUADS_LATE - CAPS_MIN_SQUADS) * evolution)
    local builderFloor = CAPS_MIN_BUILDERS + ((CAPS_MIN_BUILDERS_LATE - CAPS_MIN_BUILDERS) * evolution)
    local squads = mMin(Universe.squadCeiling,
                        mMax(mCeil(squadFloor), mCeil((activeNests / SQUADS_NESTS_PER_SQUAD) * growth)))
    local builders = mMin(Universe.builderCeiling,
                          mMax(mCeil(builderFloor), mCeil((nestChunks / BUILDERS_NEST_CHUNKS_PER_BUILDER) * growth)))
    Universe.AI_MAX_SQUAD_COUNT = squads
    Universe.AI_MAX_BUILDER_COUNT = builders
    Universe.AI_MAX_VANILLA_SQUAD_COUNT = squads * 0.65
    Universe.AI_MAX_VANILLA_BUILDER_COUNT = builders * 0.65
    if Telemetry.enabled() and ((not Universe.hiveTick) or ((tick - Universe.hiveTick) >= HIVE_TELEMETRY_INTERVAL)) then
        Universe.hiveTick = tick
        local units = 0
        local groups = 0
        for _, squad in pairs(Universe.groupNumberToSquad) do
            local group = squad.group
            if group.valid then
                groups = groups + 1
                units = units + #group.members
            end
        end
        local detached = table_size(Universe.detachedUnits)
        Telemetry.record("hive", {
                activeNests = activeNests,
                nestChunks = nestChunks,
                bases = table_size(Universe.bases),
                evolution = Universe.evolutionLevel,
                squadCap = squads,
                builderCap = builders,
                squads = Universe.squadCount,
                builders = Universe.builderCount,
                groups = groups,
                unitsInGroups = units,
                detachedUnits = detached,
                offensives = table_size(Universe.offensives)
        })
    end
end

function Strategy.describe(map, tick)
    local lines = {}
    local perimeter = map.perimeter
    if perimeter then
        local cells = {}
        for _, cell in pairs(perimeter) do
            if ((tick - cell.tick) <= PERIMETER_TTL) then
                cells[#cells+1] = cell
            end
        end
        table.sort(cells, function(a, b)
            return (a.strength or PERIMETER_UNKNOWN_STRENGTH) < (b.strength or PERIMETER_UNKNOWN_STRENGTH)
        end)
        lines[#lines+1] = sFormat("%s: %d known sectors, weakest first", map.surface.name, #cells)
        for i=1,mMin(10, #cells) do
            local cell = cells[i]
            local breach = ""
            if cell.breachTick and ((tick - cell.breachTick) < BREACH_TTL) then
                breach = " BREACHED"
            end
            lines[#lines+1] = sFormat("  [gps=%d,%d,%s] strength %s, %d of %d attacks worked%s",
                                      mFloor(cell.x), mFloor(cell.y), map.surface.name,
                                      (cell.strength and sFormat("%.1f", cell.strength)) or "unknown",
                                      cell.successes, cell.attacks, breach)
        end
    else
        lines[#lines+1] = map.surface.name .. ": no sectors known yet"
    end
    for _, offensive in pairs(Universe.offensives) do
        if offensive.map == map then
            local squads = 0
            for _ in pairs(offensive.squads) do
                squads = squads + 1
            end
            lines[#lines+1] = sFormat("  offensive %d on [gps=%d,%d,%s]: %s, %d attacks, %d squads",
                                      offensive.id, mFloor(offensive.objective.x), mFloor(offensive.objective.y),
                                      map.surface.name, (offensive.launched and "charging") or "gathering",
                                      #offensive.attacks, squads)
        end
    end
    return lines
end

function Strategy.init(universe)
    Universe = universe
end

StrategyG = Strategy
return Strategy
