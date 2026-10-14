-- Copyright (C) 2022  veden

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


if SquadG then
    return SquadG
end
local Squad = {}

--

local Universe
local TargetPosition
local SearchPath
local Queries
local ScoringTick = 0
local ScoringAversion = 0

-- imports

local Constants = require("Constants")
local MapUtils = require("MapUtils")
local BaseUtils = require("BaseUtils")
local Doctrine = require("Doctrine")
local Telemetry = require("Telemetry")
local MathUtils = require("MathUtils")
local ChunkPropertyUtils = require("ChunkPropertyUtils")
local Utils = require("Utils")

local sFind = string.find

-- Constants

local BASE_AI_STATE_ONSLAUGHT = Constants.BASE_AI_STATE_ONSLAUGHT
local BASE_AI_STATE_RAIDING = Constants.BASE_AI_STATE_RAIDING
local MAGIC_MAXIMUM_NUMBER = Constants.MAGIC_MAXIMUM_NUMBER
local MINIMUM_EXPANSION_DISTANCE = Constants.MINIMUM_EXPANSION_DISTANCE
local COMMAND_TIMEOUT = Constants.COMMAND_TIMEOUT
local BUILD_COMMAND_TIMEOUT = Constants.BUILD_COMMAND_TIMEOUT
local PLAYER_PHEROMONE = Constants.PLAYER_PHEROMONE
local BASE_PHEROMONE = Constants.BASE_PHEROMONE
local ENEMY_PHEROMONE = Constants.ENEMY_PHEROMONE
local KAMIKAZE_PHEROMONE = Constants.KAMIKAZE_PHEROMONE
local RESOURCE_PHEROMONE = Constants.RESOURCE_PHEROMONE

local COMPRESSION_COOLDOWN = Constants.COMPRESSION_COOLDOWN

local HALF_CHUNK_SIZE = Constants.HALF_CHUNK_SIZE

local FIVE_DEATH_PHEROMONE_GENERATOR_AMOUNT = Constants.FIVE_DEATH_PHEROMONE_GENERATOR_AMOUNT

local SQUAD_BUILDING = Constants.SQUAD_BUILDING

local SQUAD_RAIDING = Constants.SQUAD_RAIDING
local SQUAD_SETTLING = Constants.SQUAD_SETTLING
local SQUAD_GUARDING = Constants.SQUAD_GUARDING
local SQUAD_RETREATING = Constants.SQUAD_RETREATING

local BASE_AI_STATE_SIEGE = Constants.BASE_AI_STATE_SIEGE
local BASE_AI_STATE_AGGRESSIVE = Constants.BASE_AI_STATE_AGGRESSIVE

local PLAYER_PHEROMONE_MULTIPLER = Constants.PLAYER_PHEROMONE_MULTIPLER

local DEFINES_DISTRACTION_NONE = defines.distraction.none
local DEFINES_DISTRACTION_BY_ENEMY = defines.distraction.by_enemy
local DEFINES_DISTRACTION_BY_ANYTHING = defines.distraction.by_anything
local COOLDOWN_RETREAT = Constants.COOLDOWN_RETREAT

local CHUNK_SIZE = Constants.CHUNK_SIZE
local COOLDOWN_RALLY = Constants.COOLDOWN_RALLY
local RALLY_CRY_DISTANCE = Constants.RALLY_CRY_DISTANCE

local AI_SQUAD_COST = Constants.AI_SQUAD_COST
local AI_SETTLER_COST = Constants.AI_SETTLER_COST
local AI_VENGENCE_SQUAD_COST = Constants.AI_VENGENCE_SQUAD_COST
local AI_VENGENCE_SETTLER_COST = Constants.AI_VENGENCE_SETTLER_COST

local ATTACKING_DISTRACTION = defines.group_state.attacking_distraction
local ATTACKING_TARGET = defines.group_state.attacking_target
local GATHERING = defines.group_state.gathering

local DEFINES_COMMAND_ATTACK = defines.command.attack
local DEFINES_COMMAND_ATTACK_AREA = defines.command.attack_area
local DEFINES_COMMAND_GO_TO_LOCATION = defines.command.go_to_location
local DEFINES_COMMAND_COMPOUND = defines.command.compound
local DEFINES_COMPOUND_COMMAND_RETURN_LAST = defines.compound_command.return_last

local AI_SCOUT_COST = Constants.AI_SCOUT_COST
local ENTITY_SKIP_COUNT_LOOKUP = Constants.ENTITY_SKIP_COUNT_LOOKUP
local SCOUT_SQUAD_SIZE = Constants.SCOUT_SQUAD_SIZE
local SCOUT_MAX_DURATION = Constants.SCOUT_MAX_DURATION

local DEFENSE_THREAT_WEIGHT = Constants.DEFENSE_THREAT_WEIGHT

local SUPPLY_SEARCH_RADIUS = Constants.SUPPLY_SEARCH_RADIUS
local SUPPLY_TURRET_TYPES = Constants.SUPPLY_TURRET_TYPES

local WAVE_STAGING_TIMEOUT = Constants.WAVE_STAGING_TIMEOUT
local WAVE_STAGING_PULLBACK = Constants.WAVE_STAGING_PULLBACK

local PRIORITY_BRAWL_WEIGHT = Constants.PRIORITY_BRAWL_WEIGHT
local PRIORITY_HUNT_RADIUS = Constants.PRIORITY_HUNT_RADIUS
local PRIORITY_LOGISTICS_TYPES = Constants.PRIORITY_LOGISTICS_TYPES
local PRIORITY_DEFAULTS = Constants.PRIORITY_DEFAULTS
local SUPPORT_TURRET_TYPES = Constants.SUPPORT_TURRET_TYPES
local SUPPORT_DETACH_DISTANCE = Constants.SUPPORT_DETACH_DISTANCE
local SUPPORT_PENDING_TIMEOUT = Constants.SUPPORT_PENDING_TIMEOUT
local SUPPORT_DEFAULT_RANGE = Constants.SUPPORT_DEFAULT_RANGE
local SUPPORT_RANGE_MARGIN = Constants.SUPPORT_RANGE_MARGIN
local SUPPORT_SPACING = Constants.SUPPORT_SPACING
local SUPPORT_ROW_GAP = Constants.SUPPORT_ROW_GAP
local SUPPORT_FAN_ANGLE = Constants.SUPPORT_FAN_ANGLE
local SUPPORT_FIRE_CLEARANCE = Constants.SUPPORT_FIRE_CLEARANCE
local SUPPORT_SLOT_TRIES = Constants.SUPPORT_SLOT_TRIES

local FLANK_OFFSET = Constants.FLANK_OFFSET
local FLANK_ADVANCE = Constants.FLANK_ADVANCE
local FEINT_OFFSET = Constants.FEINT_OFFSET
local FEINT_DELAY = Constants.FEINT_DELAY

local STAGING_COMMAND = {
    type = defines.command.wander,
    wander_in_group = true,
    radius = Constants.WAVE_HOLD_RADIUS,
    ticks_to_wait = Constants.WAVE_HOLD_TICKS,
    distraction = defines.distraction.by_enemy
}

-- imported functions

local setPositionInQuery = Utils.setPositionInQuery

local getRallyTick = ChunkPropertyUtils.getRallyTick
local setRallyTick = ChunkPropertyUtils.setRallyTick
local modifyBaseUnitPoints = BaseUtils.modifyBaseUnitPoints

local tableRemove = table.remove
local tableInsert = table.insert
local mCeil = math.ceil
local mFloor = math.floor
local mMin = math.min
local mMax = math.max
local mSqrt = math.sqrt
local mCos = math.cos
local mSin = math.sin
local mAtan2 = math.atan2

local TICKS_A_SECOND = Constants.TICKS_A_SECOND

local getDefenseThreat = ChunkPropertyUtils.getDefenseThreat

local isActiveNest = ChunkPropertyUtils.isActiveNest
local isActiveRaidNest = ChunkPropertyUtils.isActiveRaidNest

local gaussianRandomRangeRG = MathUtils.gaussianRandomRangeRG
local getEnemyStructureCount = ChunkPropertyUtils.getEnemyStructureCount
local getRetreatTick = ChunkPropertyUtils.getRetreatTick

local findNearbyBase = ChunkPropertyUtils.findNearbyBase
local tableSize = table_size
local setPositionInCommand = Utils.setPositionInCommand

local euclideanDistancePoints = MathUtils.euclideanDistancePoints
local canMoveChunkDirection = MapUtils.canMoveChunkDirection

local setRetreatTick = ChunkPropertyUtils.setRetreatTick

local removeSquadFromChunk = ChunkPropertyUtils.removeSquadFromChunk
local addDeathGenerator = ChunkPropertyUtils.addDeathGenerator

local getNeighborChunks = MapUtils.getNeighborChunks
local addSquadToChunk = ChunkPropertyUtils.addSquadToChunk
local getChunkByXY = MapUtils.getChunkByXY
local positionToChunkXY = MapUtils.positionToChunkXY
local positionFromScaledDirections = MapUtils.positionFromScaledDirections
local positionFromScaledSearchPath = MapUtils.positionFromScaledSearchPath

local euclideanDistanceNamed = MathUtils.euclideanDistanceNamed

-- module code
local function scoreRetreatLocation(neighborChunk)
    return (-neighborChunk[KAMIKAZE_PHEROMONE] +
            -((neighborChunk.playerBaseGenerator or 0) * 1000))
end

local function scoreResourceLocation(neighborChunk)
    local preferred = false
    if (
        not neighborChunk.playerBaseGenerator
        and not neighborChunk.playerGenerator
        and neighborChunk.resourceGenerator
        and getEnemyStructureCount(neighborChunk) == 0
    )
    then
        preferred = true
    end
    local score = neighborChunk[RESOURCE_PHEROMONE]
        - (neighborChunk[PLAYER_PHEROMONE] * PLAYER_PHEROMONE_MULTIPLER)
        - neighborChunk[ENEMY_PHEROMONE]
    return score, preferred
end

local function scoreSiegeLocation(neighborChunk)
    local preferred = false
    if (
        not neighborChunk.playerBaseGenerator
        and not neighborChunk.playerGenerator
    )
    then
        preferred = true
    end
    local settle = neighborChunk[BASE_PHEROMONE]
        + neighborChunk[RESOURCE_PHEROMONE] * 0.5
        + (neighborChunk[PLAYER_PHEROMONE] * PLAYER_PHEROMONE_MULTIPLER)

    local score = settle - neighborChunk[ENEMY_PHEROMONE]

    return score, preferred
end

local function scoreSiegeKamikazeLocation(neighborChunk)
    local preferred = false
    if (
        not neighborChunk.playerBaseGenerator
        and not neighborChunk.playerGenerator
    )
    then
        preferred = true
    end
    local settle = neighborChunk[KAMIKAZE_PHEROMONE]
        + neighborChunk[RESOURCE_PHEROMONE] * 0.5

    local score = settle - neighborChunk[ENEMY_PHEROMONE]

    return score, preferred
end

local function scoreAttackLocation(neighborChunk)
    local preferred = false
    if (
        neighborChunk.playerBaseGenerator
        or neighborChunk.playerGenerator
    )
    then
        preferred = true
    end
    local damage = neighborChunk[BASE_PHEROMONE] +
        (neighborChunk[PLAYER_PHEROMONE] * PLAYER_PHEROMONE_MULTIPLER)
    if preferred then
        damage = damage * 2
    end
    if Universe.enableScouting then
        -- steer toward the least defended part of the perimeter
        damage = damage / (1 + (getDefenseThreat(neighborChunk, ScoringTick) * ScoringAversion))
    end
    return damage, preferred
end

local function scoreAttackKamikazeLocation(neighborChunk)
    local preferred = false
    if (
        neighborChunk.playerBaseGenerator
        or neighborChunk.playerGenerator
    )
    then
        preferred = true
    end
    local damage = neighborChunk[KAMIKAZE_PHEROMONE]
    if preferred then
        damage = damage * 2
    end
    return damage, preferred
end

local function findMovementPosition(surface, position)
    return surface.find_non_colliding_position(
        "behemoth-biter",
        position,
        10,
        2,
        false
    )
end

local function findDeploymentPosition(surface, position)
    return surface.find_non_colliding_position(
        "biter-spawner",
        position,
        CHUNK_SIZE,
        4,
        true
    )
end

local function calculateSettlerMaxDistance()
    local targetDistance
    local distanceRoll = Universe.random()
    if distanceRoll < 0.05 then
        return 0
    elseif distanceRoll < 0.30 then
        targetDistance = Universe.expansionLowTargetDistance
    elseif distanceRoll < 0.70 then
        targetDistance = Universe.expansionMediumTargetDistance
    elseif distanceRoll < 0.95 then
        targetDistance = Universe.expansionHighTargetDistance
    else
        return Universe.expansionMaxDistance
    end
    return gaussianRandomRangeRG(targetDistance,
                                 Universe.expansionDistanceDeviation,
                                 MINIMUM_EXPANSION_DISTANCE,
                                 Universe.expansionMaxDistance,
                                 Universe.random)
end

local function addMovementPenalty(squad, chunk)
    if (chunk == -1) then
        return
    end
    local penalties = squad.penalties
    local penaltyCount = #penalties
    for i=1,penaltyCount do
        local penalty = penalties[i]
        if (penalty.c.id == chunk.id) then
            penalty.v = penalty.v + 1
            if penalty.v >= 7 then
                if Universe.enabledMigration
                    and (Universe.random() < 0.05)
                    and (Universe.builderCount < Universe.AI_MAX_BUILDER_COUNT)
                then
                    squad.settler = true
                    squad.originPosition.x = squad.group.position.x
                    squad.originPosition.y = squad.group.position.y
                    squad.maxDistance = calculateSettlerMaxDistance()

                    squad.status = SQUAD_SETTLING
                elseif not squad.kamikaze then
                    squad.kamikaze = true
                    squad.penalties = {}
                else
                    for _, entity in pairs(squad.group.members) do
                        if entity.valid then
                            entity.destroy()
                        end
                    end
                    squad.group.destroy()
                end
            end
            return
        end
    end
    if (penaltyCount == 10) then
        tableRemove(penalties, 10)
    end
    tableInsert(penalties,
                1,
                { v = 1,
                  c = chunk })
end

local function compressSquad(squad, tick)
    if squad.compressionSet
        or (Universe.squadCompressionThreshold == -1)
        or (squad.canBeCompressed >= tick)
    then
        return
    end

    local group = squad.group
    local groupState = group.state
    if (groupState == ATTACKING_DISTRACTION)
        or (groupState == ATTACKING_TARGET)
        or (groupState == GATHERING)
        or (squad.status == SQUAD_BUILDING)
    then
        return
    end
    local members = group.members
    if (#members <= Universe.squadCompressionThreshold) then
        return
    end
    local compressionSet = {}
    local compressedTotal = 0
    local totalTypes = 0
    local entityToTag
    for _, entity in pairs(members) do
        local entityName = entity.name
        local count = compressionSet[entityName]
        if not count then
            totalTypes = totalTypes + 1
            if totalTypes > 6 then
                entity.destroy()
                compressedTotal = compressedTotal + 1
                compressionSet[entityName] = 1
            else
                entityToTag = entity
                compressionSet[entityName] = 0
            end
        else
            compressionSet[entityName] = count + 1
            compressedTotal = compressedTotal + 1
            entity.destroy()
        end
    end
    local query = Queries.renderText
    query.surface = group.surface
    query.text = compressedTotal
    query.target = entityToTag
    squad.compressionText = rendering.draw_text(query)
    squad.compressionSet = compressionSet
    squad.compressedTotal = compressedTotal
    squad.canBeCompressed = false
end

function Squad.decompressSquad(squad, tick)
    if not squad.compressionSet then
        return
    end

    local group = squad.group
    local query = Queries.createEntityQuery
    local add_member = group.add_member
    local create_entity = squad.map.surface.create_entity
    setPositionInQuery(
        query,
        group.position
    )
    for name,count in pairs(squad.compressionSet) do
        query.name = name
        for _ = 1, count do
            add_member(create_entity(query))
        end
    end
    local compressionText = squad.compressionText
    if type(compressionText) == "number" then
        -- saves from Factorio 1.1 stored the render id instead of a LuaRenderObject
        compressionText = rendering.get_object_by_id(compressionText)
    end
    if compressionText then
        compressionText.destroy()
    end
    squad.compressionSet = nil
    squad.canBeCompressed = tick + COMPRESSION_COOLDOWN
end

--[[
    Expects all neighbors adjacent to a chunk
--]]
local function scoreNeighbors(map, chunk, neighborDirectionChunks, scoreFunction)
    local highest = SearchPath[1]
    local highestScore = -MAGIC_MAXIMUM_NUMBER
    local highestPreferred = false

    highest.chunk = -1

    for x=1,8 do
        local neighborChunk = neighborDirectionChunks[x]
        if (neighborChunk ~= -1) then
            if (chunk == -1) or canMoveChunkDirection(x, chunk, neighborChunk) then
                local score, preferred = scoreFunction(neighborChunk)
                if (highestPreferred and preferred and (score > highestScore))
                    or (not highestPreferred and (score > highestScore))
                    or (not highestPreferred and preferred)
                then
                    highest.chunk = neighborChunk
                    highest.direction = x
                    highestScore = score
                    highestPreferred = preferred
                end
            end
        end
    end

    if (highest.chunk == -1) then
        return SearchPath
    end

    if highestPreferred then
        SearchPath[2].chunk = -1
        return SearchPath
    end

    for i = 2, 4 do
        local lastChunk = SearchPath[i-1].chunk
        highest = SearchPath[i]
        highest.chunk = -1
        highestPreferred = false

        neighborDirectionChunks = getNeighborChunks(map, lastChunk.x, lastChunk.y)
        for x=1,8 do
            local neighborChunk = neighborDirectionChunks[x]
            if ((neighborChunk ~= -1) and (neighborChunk.id ~= lastChunk.id) and
                canMoveChunkDirection(x, lastChunk, neighborChunk))
            then
                local score, preferred = scoreFunction(neighborChunk)
                if (highestPreferred and preferred and (score > highestScore))
                    or (not highestPreferred and (score > highestScore))
                    or (not highestPreferred and preferred)
                then
                    highestScore = score
                    highest.chunk = neighborChunk
                    highest.direction = x
                    highestPreferred = preferred
                end
            end
        end
        if highest.chunk == -1 then
            return SearchPath
        end
        if highestPreferred and (i ~= 4) then
            SearchPath[i+1].chunk = -1
            return SearchPath
        end
    end

    return SearchPath
end

local function settleMove(squad, tick)
    local group = squad.group
    local map = squad.map

    local groupPosition = group.position
    local x, y = positionToChunkXY(groupPosition)
    local chunk = getChunkByXY(map, x, y)
    local scoreFunction = scoreResourceLocation
    if (squad.type == BASE_AI_STATE_SIEGE) then
        scoreFunction = scoreSiegeLocation
        if squad.kamikaze then
            scoreFunction = scoreSiegeKamikazeLocation
        end
    end
    local squadChunk = squad.chunk
    if squadChunk ~= -1 then
        addDeathGenerator(squadChunk, -FIVE_DEATH_PHEROMONE_GENERATOR_AMOUNT)
    end
    if chunk ~= -1 then
        addSquadToChunk(chunk, squad)
        addMovementPenalty(squad, chunk)
        if not squad.group.valid then
            return
        end
    end
    local originPosition = squad.originPosition
    local distance = euclideanDistancePoints(groupPosition.x,
                                             groupPosition.y,
                                             originPosition.x,
                                             originPosition.y)
    local cmd
    local position
    local surface = map.surface

    if (chunk ~= -1) and
        (
            (distance >= squad.maxDistance) or
            (
                chunk.resourceGenerator and (not chunk.nestCount) and (not chunk.hiveCount)
            )
        )
    then
        Squad.decompressSquad(squad, tick)

        position = findMovementPosition(surface, groupPosition) or groupPosition

        cmd = Queries.settleCommand
        if squad.kamikaze then
            cmd.distraction = DEFINES_DISTRACTION_NONE
        else
            cmd.distraction = DEFINES_DISTRACTION_BY_ENEMY
        end

        setPositionInCommand(cmd, position)

        squad.status = SQUAD_BUILDING
        squad.commandTick = tick + BUILD_COMMAND_TIMEOUT

        group.set_command(cmd)
        return
    end

    local searchPath = scoreNeighbors(
        map,
        chunk,
        getNeighborChunks(map, x, y),
        scoreFunction
    )

    if (searchPath[1].chunk == -1) then
        cmd = Queries.wanderCommand
        group.set_command(cmd)
        return
    end

    local lastChunk = 0
    for i = 1, 4 do
        local moveChunk = searchPath[i].chunk
        if (moveChunk ~= -1) then
            distance = euclideanDistancePoints(
                moveChunk.x + HALF_CHUNK_SIZE,
                moveChunk.y + HALF_CHUNK_SIZE,
                originPosition.x,
                originPosition.y
            )
            if distance >= squad.maxDistance then
                searchPath[i].chunk = -1
                if i < 4 then
                    searchPath[i+1].chunk = -1
                end
            else
                lastChunk = i
                addDeathGenerator(moveChunk, -FIVE_DEATH_PHEROMONE_GENERATOR_AMOUNT)
            end
        end
    end

    position = findMovementPosition(
        surface,
        positionFromScaledSearchPath(
            groupPosition,
            1,
            searchPath
        )
    )

    if not position then
        cmd = Queries.wanderCommand
        group.set_command(cmd)
        return
    end

    TargetPosition.x = position.x
    TargetPosition.y = position.y

    if lastChunk ~= 4 then
        cmd = Queries.settleCommand
        squad.status = SQUAD_BUILDING
        squad.commandTick = tick + BUILD_COMMAND_TIMEOUT
        Squad.decompressSquad(squad, tick)
        if squad.kamikaze then
            cmd.distraction = DEFINES_DISTRACTION_NONE
        else
            cmd.distraction = DEFINES_DISTRACTION_BY_ENEMY
        end
    else
        cmd = Queries.moveCommand
        if squad.rabid or squad.kamikaze then
            cmd.distraction = DEFINES_DISTRACTION_NONE
        else
            cmd.distraction = DEFINES_DISTRACTION_BY_ENEMY
        end
    end

    setPositionInCommand(cmd, TargetPosition)

    group.set_command(cmd)
end

local function printTactic(message, surface, position)
    if Universe.printTactics then
        game.print("Rampant: " .. message .. " [gps=" .. mFloor(position.x) .. "," .. mFloor(position.y)
                   .. "," .. surface.name .. "]")
    end
end

--[[
    1 2 3
    4   5
    6 7 8
--]]
local DIRECTION_VECTORS = {
    {x = -1, y = -1}, {x = 0, y = -1}, {x = 1, y = -1},
    {x = -1, y = 0}, {x = 1, y = 0},
    {x = -1, y = 1}, {x = 0, y = 1}, {x = 1, y = 1}
}

--[[
    The attack axis points from a squad toward the strongest player scent next
    to it, so flank squads can swing out perpendicular to the approach.
--]]
local function findAttackAxis(squad)
    local map = squad.map
    local x, y = positionToChunkXY(squad.group.position)
    local chunk = getChunkByXY(map, x, y)
    if (chunk == -1) then
        return nil
    end
    local neighbors = getNeighborChunks(map, x, y)
    local bestDirection
    local bestScore = -MAGIC_MAXIMUM_NUMBER
    for direction=1,8 do
        local neighbor = neighbors[direction]
        if (neighbor ~= -1) and canMoveChunkDirection(direction, chunk, neighbor) then
            local score = neighbor[PLAYER_PHEROMONE] + neighbor[BASE_PHEROMONE]
            if (score > bestScore) then
                bestScore = score
                bestDirection = direction
            end
        end
    end
    if not bestDirection then
        return nil
    end
    local vector = DIRECTION_VECTORS[bestDirection]
    local length = mSqrt((vector.x * vector.x) + (vector.y * vector.y))
    return vector.x / length, vector.y / length
end

local function findFlankWaypoint(squad, axisX, axisY, side, offset)
    local position = squad.group.position
    return findMovementPosition(squad.map.surface, {
            x = position.x - (axisY * side * offset) + (axisX * FLANK_ADVANCE),
            y = position.y + (axisX * side * offset) + (axisY * FLANK_ADVANCE)
    })
end

local function closestTo(entities, origin, accept)
    local bestTarget
    local bestDistance = MAGIC_MAXIMUM_NUMBER
    for i=1,#entities do
        local entity = entities[i]
        if (not accept) or accept(entity) then
            local entityPosition = entity.position
            local dx = entityPosition.x - origin.x
            local dy = entityPosition.y - origin.y
            local distance = (dx * dx) + (dy * dy)
            if (distance < bestDistance) then
                bestDistance = distance
                bestTarget = entity
            end
        end
    end
    return bestTarget
end

--[[
    Turrets near the attack point, split into the electric networks feeding
    lasers and teslas and whether any gun turrets are present. Shared by the
    power and ammo priorities so the turret search runs once per decision.
--]]
local function surveyTurrets(surface, position, cache)
    if cache.turretsScanned then
        return
    end
    cache.turretsScanned = true
    local turrets = surface.find_entities_filtered({
            position = position,
            radius = SUPPLY_SEARCH_RADIUS,
            type = SUPPLY_TURRET_TYPES,
            force = Universe.playerForces
    })
    local networks = {}
    for i=1,#turrets do
        local turret = turrets[i]
        if (turret.type == "electric-turret") then
            local networkId = turret.electric_network_id
            if networkId then
                networks[networkId] = true
                cache.hasElectric = true
            end
        else
            cache.hasGuns = true
        end
    end
    cache.networks = networks
end

local PRIORITY_FINDERS = {
    {
        name = "power",
        find = function(surface, position, origin, cache)
            surveyTurrets(surface, position, cache)
            if not cache.hasElectric then
                return nil
            end
            local networks = cache.networks
            return closestTo(surface.find_entities_filtered({
                                 position = position,
                                 radius = SUPPLY_SEARCH_RADIUS,
                                 type = "electric-pole",
                                 force = Universe.playerForces
                             }),
                             origin,
                             function(pole)
                                 local networkId = pole.electric_network_id
                                 return networkId and networks[networkId]
                             end)
        end
    },
    {
        name = "ammo",
        find = function(surface, position, origin, cache)
            surveyTurrets(surface, position, cache)
            if not cache.hasGuns then
                return nil
            end
            return closestTo(surface.find_entities_filtered({
                                 position = position,
                                 radius = SUPPLY_SEARCH_RADIUS,
                                 type = "inserter",
                                 force = Universe.playerForces
                             }),
                             origin,
                             function(inserter)
                                 local dropTarget = inserter.drop_target
                                 return dropTarget and (dropTarget.type == "ammo-turret")
                             end)
        end
    },
    {
        name = "science",
        find = function(surface, position, origin)
            return closestTo(surface.find_entities_filtered({
                                 position = position,
                                 radius = SUPPLY_SEARCH_RADIUS,
                                 type = "lab",
                                 force = Universe.playerForces
                             }),
                             origin)
        end
    },
    {
        name = "logistics",
        find = function(surface, position, origin)
            return closestTo(surface.find_entities_filtered({
                                 position = position,
                                 radius = SUPPLY_SEARCH_RADIUS,
                                 type = PRIORITY_LOGISTICS_TYPES,
                                 force = Universe.playerForces
                             }),
                             origin)
        end
    },
    {
        name = "hunt",
        find = function(surface, position, origin)
            return closestTo(surface.find_entities_filtered({
                                 position = position,
                                 radius = PRIORITY_HUNT_RADIUS,
                                 type = "character",
                                 force = Universe.playerForces
                             }),
                             origin)
        end
    }
}

--[[
    Weighs every priority that has a target near the attack point against a
    plain brawl, and returns the chosen target and its priority, or nil to brawl.
--]]
local function findPriorityTarget(surface, position, origin, priorities)
    local cache = {}
    local candidates = {}
    local total = PRIORITY_BRAWL_WEIGHT
    for i=1,#PRIORITY_FINDERS do
        local finder = PRIORITY_FINDERS[i]
        local weight = priorities[finder.name] or 0
        if (weight > 0.05) then
            local target = finder.find(surface, position, origin, cache)
            if target then
                candidates[#candidates+1] = {name = finder.name, target = target, weight = weight}
                total = total + weight
            end
        end
    end
    if (#candidates == 0) then
        return nil
    end
    local roll = Universe.random() * total
    for i=1,#candidates do
        local candidate = candidates[i]
        roll = roll - candidate.weight
        if (roll <= 0) then
            return candidate.target, candidate.name
        end
    end
    return nil
end

local function priorityStrike(squad, target, priority, position)
    local group = squad.group
    local surface = squad.map.surface
    local targetName = target.name
    local targetPosition = target.position
    local members = #group.members
    -- push for the priority target, then clear the area. Turrets shooting the squad
    -- still distract it, otherwise spitters walk into the walls instead of shooting over them
    group.set_command({
            type = DEFINES_COMMAND_COMPOUND,
            structure_type = DEFINES_COMPOUND_COMMAND_RETURN_LAST,
            commands = {
                {
                    type = DEFINES_COMMAND_ATTACK,
                    target = target,
                    distraction = DEFINES_DISTRACTION_BY_ENEMY
                },
                {
                    type = DEFINES_COMMAND_ATTACK_AREA,
                    destination = {x = position.x, y = position.y},
                    radius = CHUNK_SIZE * 1.5,
                    distraction = DEFINES_DISTRACTION_BY_ENEMY
                }
            }
    })
    -- the group or target can be gone once the command is set, so only use what was read before
    printTactic("Priority strike (" .. priority .. ") on " .. targetName, surface, targetPosition)
    if Telemetry.enabled() then
        Telemetry.record("priority_strike", {
                attack = squad.attack and squad.attack.id,
                group = squad.groupNumber,
                priority = priority,
                target = targetName,
                members = members,
                position = Telemetry.position(targetPosition)
        })
    end
end

--[[
    Fire support. Unit groups move as one blob, so at a wall the whole group,
    spitters included, chews on the wall. Spitters given their own commands stop
    once their target is in range and shoot over the wall like vanilla attackers.

    The target is picked at the attack point, but spitters stay with the group
    until it is close, then fan out into a firing line: each spitter gets its
    own spot on an arc just inside its range, facing the side the squad came
    from, with spots near burning ground shifted or skipped.
--]]
local function findSupportTarget(squad, position, origin)
    return closestTo(squad.map.surface.find_entities_filtered({
                         position = position,
                         radius = SUPPLY_SEARCH_RADIUS,
                         type = SUPPORT_TURRET_TYPES,
                         force = Universe.playerForces
                     }),
                     origin)
end

local function planFireSupport(squad, position, priorityTarget, tick)
    local target = priorityTarget
    if not (target and target.valid) then
        target = findSupportTarget(squad, position, squad.group.position)
    end
    if not target then
        return
    end
    squad.supportTarget = target
    squad.supportUntil = tick + SUPPORT_PENDING_TIMEOUT
end

local function spitterRange(unit)
    local attack = unit.prototype.attack_parameters
    return (attack and attack.range) or SUPPORT_DEFAULT_RANGE
end

local function burning(surface, position)
    return surface.count_entities_filtered({
            position = position,
            radius = SUPPORT_FIRE_CLEARANCE,
            type = "fire",
            limit = 1
    }) > 0
end

--[[
    Slot i of a firing line: rows of spots along an arc around the target,
    centred on the bearing the squad approaches from.
--]]
local function firingSlot(bearing, index, perRow, rowRadius)
    local row = mFloor((index - 1) / perRow)
    local column = ((index - 1) % perRow) - ((perRow - 1) / 2)
    local radius = rowRadius - (row * SUPPORT_ROW_GAP)
    local angle = bearing + ((column * SUPPORT_SPACING) / radius)
    return radius, angle
end

local function detachFireSupport(squad, tick)
    local group = squad.group
    local target = squad.supportTarget
    squad.supportTarget = nil
    squad.supportUntil = nil
    local members = group.members
    local spitters = {}
    for i=1,#members do
        local unit = members[i]
        if unit.valid and sFind(unit.name, "spitter", 1, true) then
            spitters[#spitters+1] = unit
        end
    end
    if (#spitters == 0) then
        return
    end

    local surface = squad.map.surface
    local groupPosition = group.position
    local targetName = target.name
    local targetPosition = target.position
    local bearing = mAtan2(groupPosition.y - targetPosition.y, groupPosition.x - targetPosition.x)
    -- as many spots per row as fit across the fan at the shortest spitter range
    local shortest = MAGIC_MAXIMUM_NUMBER
    for i=1,#spitters do
        shortest = mMin(shortest, spitterRange(spitters[i]))
    end
    -- every row is measured from the shortest range so rows never overlap
    local rowRadius = shortest - SUPPORT_RANGE_MARGIN
    local perRow = mMax(1, mFloor(((2 * SUPPORT_FAN_ANGLE) * rowRadius) / SUPPORT_SPACING) + 1)

    local leftGroup = 0
    local avoidedFire = 0
    local slot = 1
    for i=1,#spitters do
        local unit = spitters[i]
        local spot
        -- try this slot and a few more along the line if it is on fire
        for _=1,SUPPORT_SLOT_TRIES do
            local radius, angle = firingSlot(bearing, slot, perRow, rowRadius)
            slot = slot + 1
            local candidate = {
                x = targetPosition.x + (radius * mCos(angle)),
                y = targetPosition.y + (radius * mSin(angle))
            }
            if burning(surface, candidate) then
                avoidedFire = avoidedFire + 1
            else
                spot = surface.find_non_colliding_position(unit.name, candidate, 4, 0.5)
                if spot then
                    break
                end
            end
        end
        local commandable = unit.commandable
        if spot and commandable then
            commandable.set_command({
                    type = DEFINES_COMMAND_COMPOUND,
                    structure_type = DEFINES_COMPOUND_COMMAND_RETURN_LAST,
                    commands = {
                        {
                            -- take the firing spot without stopping to fight on the way
                            type = DEFINES_COMMAND_GO_TO_LOCATION,
                            destination = spot,
                            radius = 1,
                            distraction = DEFINES_DISTRACTION_NONE
                        },
                        {
                            type = DEFINES_COMMAND_ATTACK,
                            target = target,
                            distraction = DEFINES_DISTRACTION_BY_ENEMY
                        },
                        {
                            type = DEFINES_COMMAND_ATTACK_AREA,
                            destination = {x = targetPosition.x, y = targetPosition.y},
                            radius = CHUNK_SIZE,
                            distraction = DEFINES_DISTRACTION_BY_ENEMY
                        }
                    }
            })
            Doctrine.detachUnit(unit, squad, tick)
            if not commandable.parent_group then
                leftGroup = leftGroup + 1
            end
        end
    end

    printTactic("Fire support: " .. leftGroup .. " spitters fan out on " .. targetName, surface, targetPosition)
    if Telemetry.enabled() then
        local dx = targetPosition.x - groupPosition.x
        local dy = targetPosition.y - groupPosition.y
        Telemetry.record("fire_support", {
                attack = squad.attack and squad.attack.id,
                group = squad.groupNumber,
                spitters = #spitters,
                leftGroup = leftGroup,
                members = #members,
                target = targetName,
                distance = mSqrt((dx * dx) + (dy * dy)),
                perRow = perRow,
                rows = mCeil(#spitters / perRow),
                avoidedFire = avoidedFire,
                position = Telemetry.position(targetPosition)
        })
    end
end

--[[
    Checked as squads are cycled: once the group is close to its fire support
    target, the spitters break off. A target destroyed in the meantime is
    replaced by the nearest turret.
--]]
local function checkFireSupport(squad, tick)
    if (tick > squad.supportUntil) then
        squad.supportTarget = nil
        squad.supportUntil = nil
        return
    end
    local groupPosition = squad.group.position
    local target = squad.supportTarget
    if not target.valid then
        target = findSupportTarget(squad, groupPosition, groupPosition)
        if not target then
            return
        end
        squad.supportTarget = target
    end
    local targetPosition = target.position
    local dx = targetPosition.x - groupPosition.x
    local dy = targetPosition.y - groupPosition.y
    if (((dx * dx) + (dy * dy)) <= (SUPPORT_DETACH_DISTANCE * SUPPORT_DETACH_DISTANCE)) then
        detachFireSupport(squad, tick)
    end
end

local function attackMove(squad, tick)
    ScoringTick = tick
    ScoringAversion = squad.aversion or DEFENSE_THREAT_WEIGHT
    local group = squad.group

    local groupPosition = group.position
    local x, y = positionToChunkXY(groupPosition)
    local map = squad.map
    local chunk = getChunkByXY(map, x, y)
    local squadChunk = squad.chunk
    if squadChunk ~= -1 then
        addDeathGenerator(squadChunk, -FIVE_DEATH_PHEROMONE_GENERATOR_AMOUNT)
    end
    if chunk ~= -1 then
        addSquadToChunk(chunk, squad)
        addMovementPenalty(squad, chunk)
        if not squad.group.valid then
            return
        end
    end

    local plan = squad.attack
    if plan and plan.detour and (not squad.detourAssigned) then
        -- lone squads take their attack's detour here, wave squads get it at launch
        squad.detourAssigned = true
        local axisX, axisY = findAttackAxis(squad)
        if axisX then
            squad.flankWaypoint = findFlankWaypoint(squad, axisX, axisY, plan.detour.side, plan.detour.distance)
        end
    end

    local flankWaypoint = squad.flankWaypoint
    if flankWaypoint then
        -- pincer and feint squads swing out to their side before attacking
        squad.flankWaypoint = nil
        local flankCommand = Queries.moveCommand
        if squad.rabid then
            flankCommand.distraction = DEFINES_DISTRACTION_BY_ANYTHING
        else
            flankCommand.distraction = DEFINES_DISTRACTION_BY_ENEMY
        end
        setPositionInCommand(flankCommand, flankWaypoint)
        group.set_command(flankCommand)
        return
    end

    local attackScorer = scoreAttackLocation
    if squad.kamikaze then
        attackScorer = scoreAttackKamikazeLocation
    end

    squad.frenzy = (squad.frenzy and (euclideanDistanceNamed(groupPosition, squad.frenzyPosition) < 100))
    local searchPath = scoreNeighbors(
        map,
        chunk,
        getNeighborChunks(map, x, y),
        attackScorer
    )
    local cmd
    if (searchPath[1].chunk == -1) then
        cmd = Queries.wanderCommand
        group.set_command(cmd)
        return
    end

    local position = findMovementPosition(
        map.surface,
        positionFromScaledSearchPath(
            groupPosition,
            1,
            searchPath
        )
    )

    if not position then
        cmd = Queries.wanderCommand
        group.set_command(cmd)
        return
    end

    local attack = false
    for i = 1, 4 do
        local attackChunk = searchPath[i].chunk
        if (attackChunk ~= -1) then
            addDeathGenerator(attackChunk, -FIVE_DEATH_PHEROMONE_GENERATOR_AMOUNT)
            if attackChunk.playerBaseGenerator or
                (attackChunk[PLAYER_PHEROMONE] >= Universe.attackPlayerThreshold)
            then
                attack = true
            end
        end
    end

    if attack then
        Squad.decompressSquad(squad, tick)
        cmd = Queries.attackCommand
        -- engage turrets and other military targets first, walls only when they block the
        -- path, which lets spitters shoot turrets over walls like vanilla attacks
        cmd.distraction = DEFINES_DISTRACTION_BY_ENEMY

        if not squad.rabid then
            squad.frenzy = true
            squad.frenzyPosition.x = groupPosition.x
            squad.frenzyPosition.y = groupPosition.y
        end

        if squad.scout and not squad.surveyed then
            squad.surveyed = true
            Doctrine.survey(squad.base, map.surface, position)
        end

        if plan then
            Doctrine.setImpact(plan, position)
        end

        local target, priority
        if Universe.enableSupplyTargeting and not squad.scout then
            target, priority = findPriorityTarget(map.surface,
                                                  position,
                                                  groupPosition,
                                                  squad.priorities or PRIORITY_DEFAULTS)
        end

        if (squad.support ~= false) and (not squad.scout) and (not squad.supportSent) then
            squad.supportSent = true
            -- spitters shoot the priority target over the walls, never chase players
            local supportTarget = target
            if (priority == "hunt") then
                supportTarget = nil
            end
            planFireSupport(squad, position, supportTarget, tick)
        end

        if target and target.valid then
            priorityStrike(squad, target, priority, position)
            return
        end
    else
        cmd = Queries.moveCommand
        if squad.rabid or squad.frenzy then
            cmd.distraction = DEFINES_DISTRACTION_BY_ANYTHING
        elseif squad.march then
            -- marching squads push past outer defenses toward the target
            cmd.distraction = DEFINES_DISTRACTION_NONE
        else
            cmd.distraction = DEFINES_DISTRACTION_BY_ENEMY
        end
    end

    TargetPosition.x = position.x
    TargetPosition.y = position.y
    setPositionInCommand(cmd, TargetPosition)

    group.set_command(cmd)
end

local function buildMove(squad, tick)
    local group = squad.group
    local groupPosition = group.position
    local position = findMovementPosition(squad.map.surface, groupPosition) or groupPosition

    setPositionInCommand(Queries.settleCommand, position)

    Squad.decompressSquad(squad, tick)

    group.set_command(Queries.settleCommand)
end

function Squad.cleanSquads(tick)
    local squads = Universe.groupNumberToSquad
    local groupId = Universe.squadIterator
    local squad
    if not groupId then
        groupId, squad = next(squads, groupId)
    else
        squad = squads[groupId]
    end
    if not groupId then
        Universe.squadIterator = nil
        if (tableSize(squads) == 0) then
            -- this is needed as the next command remembers the max length a table has been
            Universe.groupNumberToSquad = {}
        end
    else
        Universe.squadIterator = next(squads, groupId)
        local group = squad.group
        if squad.supportTarget and group.valid then
            checkFireSupport(squad, tick)
        end
        if not group.valid then
            if squad.chunk ~= -1 then
                addDeathGenerator(squad.chunk, -FIVE_DEATH_PHEROMONE_GENERATOR_AMOUNT)
            end
            removeSquadFromChunk(squad)
            Doctrine.squadGone(squad)
            if squad.settlers then
                Universe.builderCount = Universe.builderCount - 1
                if Universe.builderCount < 0 then
                    Universe.builderCount = 0
                end
            else
                Universe.squadCount = Universe.squadCount - 1
                if Universe.squadCount < 0 then
                    Universe.squadCount = 0
                end
                if (squad.type == BASE_AI_STATE_AGGRESSIVE) and not squad.scout then
                    local base = squad.base
                    base.sentAggressiveGroups = base.sentAggressiveGroups - 1
                    if base.sentAggressiveGroups < 0 then
                        base.sentAggressiveGroups = 0
                    end
                end
            end
            squads[groupId] = nil
        elseif (group.state == 4) then
            squad.wanders = 0
            Squad.squadDispatch(squad, tick)
            if group.valid then
                compressSquad(squad, tick)
            end
        elseif (squad.commandTick and (squad.commandTick < tick)) then
            if squad.wanders > 5 then
                for _, entity in pairs(squad.group.members) do
                    if entity.valid then
                        entity.destroy()
                    end
                end
                squad.group.destroy()
            else
                squad.wanders = squad.wanders + 1
                if squad.status == SQUAD_BUILDING then
                    squad.commandTick = tick + BUILD_COMMAND_TIMEOUT
                else
                    squad.commandTick = tick + COMMAND_TIMEOUT
                end
                squad.group.set_command(Queries.wander2Command)
            end
        end
    end
end

local function holdSquad(squad, tick)
    squad.commandTick = tick + COMMAND_TIMEOUT
    squad.group.set_command(STAGING_COMMAND)
end

--[[
    Releases a staged wave. A feint sends one decoy wide to one side and holds
    the rest back, a pincer alternates the remaining squads out to both flanks
    around a center squad, and stagger spaces out the release of each squad.
--]]
local function launchWave(wave, tick)
    wave.launched = true
    local squads = wave.squads
    wave.squads = {}
    local members = {}
    for _, member in pairs(squads) do
        member.wave = nil
        if member.group.valid then
            members[#members+1] = member
        end
    end
    if (#members == 0) then
        return
    end

    local genes = wave.genome.genes
    local staggerTicks = mFloor(genes.stagger * TICKS_A_SECOND)
    local detour = wave.detour
    local axisX, axisY
    if wave.pincer or wave.feint or detour then
        axisX, axisY = findAttackAxis(members[1])
    end

    local shape = {}
    local releaseTick = tick
    local first = 1
    local pincerSide = 1
    if wave.feint and axisX and (#members >= 2) then
        local decoy = members[1]
        local side = ((Universe.random() < 0.5) and 1) or -1
        decoy.decoy = true
        decoy.rabid = true
        decoy.detourAssigned = true
        if detour then
            -- the decoy hits the usual sector while the main force detours
            decoy.flankWaypoint = nil
        else
            decoy.flankWaypoint = findFlankWaypoint(decoy, axisX, axisY, side, FEINT_OFFSET)
        end
        -- the first flank of the main force goes away from the decoy
        pincerSide = -side
        releaseTick = tick + FEINT_DELAY
        first = 2
        shape[#shape+1] = "feint first"
    end
    if wave.pincer and axisX and ((#members - first) >= 1) then
        shape[#shape+1] = "pincer"
    end
    if (staggerTicks > 0) then
        shape[#shape+1] = "staggered " .. genes.stagger .. "s"
    end

    if detour and axisX then
        shape[#shape+1] = "detour " .. detour.distance .. " tiles " .. (((detour.side > 0) and "right") or "left")
    end

    for i=first,#members do
        local member = members[i]
        local flank = i - first
        -- sideways offset from the attack axis: the detour plus this squad's pincer flank
        local lateral = 0
        if detour then
            lateral = detour.side * detour.distance
        end
        if wave.pincer and (flank > 0) then
            local side = (((flank % 2) == 1) and pincerSide) or -pincerSide
            lateral = lateral + (side * FLANK_OFFSET)
        end
        member.detourAssigned = true
        if axisX and (lateral ~= 0) then
            member.flankWaypoint = findFlankWaypoint(member, axisX, axisY, 1, lateral)
        end
        if (releaseTick > tick) then
            member.releaseTick = releaseTick
        end
        releaseTick = releaseTick + staggerTicks
    end

    local launched = 0
    local position
    for i=1,#members do
        local member = members[i]
        local group = member.group
        -- members still gathering are dispatched by their own gathering event
        if group.valid and (group.state ~= GATHERING) then
            launched = launched + 1
            position = group.position
            Squad.squadDispatch(member, tick)
        end
    end
    if position then
        local description = "together"
        if (#shape > 0) then
            description = table.concat(shape, ", ")
        end
        printTactic("Wave launched with " .. launched .. " squads, " .. description, wave.surface, position)
        if Telemetry.enabled() then
            Telemetry.record("wave_launched", {
                    attack = wave.id,
                    surface = wave.surface.name,
                    planned = wave.size,
                    staged = #members,
                    launchedNow = launched,
                    feint = (first == 2),
                    pincer = wave.pincer and (axisX ~= nil) or false,
                    detour = detour and detour.index,
                    axisFound = axisX ~= nil,
                    staggerSeconds = genes.stagger,
                    position = Telemetry.position(position)
            })
        end
    end
end

--[[
    Returns true when the wave handled the dispatch, either by holding the squad
    for the rest of its wave or by launching the whole wave including this squad.
--]]
local function holdForWave(squad, tick)
    local wave = squad.wave
    if not wave then
        return false
    end
    if wave.launched then
        squad.wave = nil
        return false
    end

    local ready = (wave.count >= wave.size)
    if ready then
        for _, member in pairs(wave.squads) do
            local group = member.group
            if group.valid and (group.state == GATHERING) then
                ready = false
                break
            end
        end
    end

    if ready or (tick >= wave.deadline) then
        launchWave(wave, tick)
        return true
    end

    if not squad.stagingMoved then
        -- fall back away from the defenses once, then wait there for the rest of the wave
        squad.stagingMoved = true
        local axisX, axisY = findAttackAxis(squad)
        if axisX then
            local position = squad.group.position
            local stagingPoint = findMovementPosition(squad.map.surface, {
                    x = position.x - (axisX * WAVE_STAGING_PULLBACK),
                    y = position.y - (axisY * WAVE_STAGING_PULLBACK)
            })
            if stagingPoint then
                local cmd = Queries.moveCommand
                cmd.distraction = DEFINES_DISTRACTION_BY_ENEMY
                setPositionInCommand(cmd, stagingPoint)
                squad.commandTick = tick + COMMAND_TIMEOUT
                if Telemetry.enabled() then
                    Telemetry.record("squad_staging", {
                            attack = wave.id,
                            group = squad.groupNumber,
                            from = Telemetry.position(position),
                            to = Telemetry.position(stagingPoint)
                    })
                end
                squad.group.set_command(cmd)
                return true
            end
        end
    end

    holdSquad(squad, tick)
    return true
end

--[[
    The attack record doubles as the wave. Its doctrine decides how many squads
    to stage, and a single squad attack launches as soon as it forms.
--]]
local function joinWave(base, attack, squad, cost, tick)
    if (attack.count == 0) then
        local size = 1
        if Universe.enableCoordinatedWaves then
            size = mMin(attack.genome.genes.squads, mFloor(base.unitPoints / cost))
        end
        attack.size = mMax(size, 1)
        attack.deadline = tick + WAVE_STAGING_TIMEOUT
        local genes = attack.genome.genes
        attack.pincer = Universe.random() < genes.spread
        attack.feint = Universe.random() < genes.feint
        if (attack.size > 1) then
            printTactic("Staging a wave of " .. attack.size .. " squads", attack.surface, squad.originPosition)
        end
    end
    attack.count = attack.count + 1
    if (attack.size <= 1) then
        attack.launched = true
        return
    end
    attack.squads[squad.groupNumber] = squad
    squad.wave = attack
end

function Squad.squadDispatch(squad, tick)
    local group = squad.group
    if not (group and group.valid) then
        return
    end

    if squad.attack and (not squad.movingLogged) and Telemetry.enabled() then
        -- the first dispatch shows the group finished gathering
        squad.movingLogged = true
        Telemetry.record("squad_moving", {
                attack = squad.attack.id,
                group = squad.groupNumber,
                members = #group.members,
                gatherTicks = tick - (squad.formedTick or tick)
        })
    end

    if (squad.status == SQUAD_GUARDING) then
        if holdForWave(squad, tick) then
            return
        end
        if squad.releaseTick then
            if (tick < squad.releaseTick) then
                holdSquad(squad, tick)
                return
            end
            squad.releaseTick = nil
        end
    end

    local status = squad.status
    if (status == SQUAD_RAIDING) then
        squad.commandTick = tick + COMMAND_TIMEOUT
        attackMove(squad, tick)
    elseif (status == SQUAD_SETTLING) then
        squad.commandTick = tick + COMMAND_TIMEOUT
        settleMove(squad, tick)
    elseif (status == SQUAD_RETREATING) then
        squad.commandTick = tick + COMMAND_TIMEOUT
        if squad.settlers then
            squad.status = SQUAD_SETTLING
            settleMove(squad, tick)
        else
            squad.status = SQUAD_RAIDING
            attackMove(squad, tick)
        end
    elseif (status == SQUAD_BUILDING) then
        squad.commandTick = tick + BUILD_COMMAND_TIMEOUT
        removeSquadFromChunk(squad)
        buildMove(squad, tick)
    elseif (status == SQUAD_GUARDING) then
        squad.commandTick = tick + COMMAND_TIMEOUT
        if squad.settlers then
            squad.status = SQUAD_SETTLING
            settleMove(squad, tick)
        else
            squad.status = SQUAD_RAIDING
            attackMove(squad, tick)
        end
    end
end

--[[
    Expects all neighbors adjacent to a chunk
--]]
local function scoreNeighborsForRetreat(chunk, neighborDirectionChunks, scoreFunction, map)
    local highestChunk = -1
    local highestScore = -MAGIC_MAXIMUM_NUMBER
    local highestDirection

    for x=1,8 do
        local neighborChunk = neighborDirectionChunks[x]
        if (neighborChunk ~= -1) then
            if (chunk == -1) or canMoveChunkDirection(x, chunk, neighborChunk) then
                local score = scoreFunction(neighborChunk)
                if (score > highestScore) then
                    highestScore = score
                    highestChunk = neighborChunk
                    highestDirection = x
                end
            end
        end
    end

    local nextHighestChunk = -1
    local nextHighestScore = highestScore
    local nextHighestDirection

    if (highestChunk ~= -1) then
        neighborDirectionChunks = getNeighborChunks(map, highestChunk.x, highestChunk.y)
        for x=1,8 do
            local neighborChunk = neighborDirectionChunks[x]

            if ((neighborChunk ~= -1) and ((chunk == -1) or (neighborChunk.id ~= chunk.id)) and
                canMoveChunkDirection(x, highestChunk, neighborChunk)) then
                local score = scoreFunction(neighborChunk)
                if (score > nextHighestScore) then
                    nextHighestScore = score
                    nextHighestChunk = neighborChunk
                    nextHighestDirection = x
                end
            end
        end
    end

    if (nextHighestChunk == nil) then
        nextHighestChunk = -1
    end

    return highestChunk, highestDirection, nextHighestChunk, nextHighestDirection
end

function Squad.retreatUnits(chunk, cause, tick, existingSquad, radius)
    if (tick - getRetreatTick(chunk) > COOLDOWN_RETREAT)
        and (getEnemyStructureCount(chunk) == 0)
    then

        if existingSquad and
            (
                (not existingSquad.group.valid)
                or existingSquad.kamikaze
                or existingSquad.scout
            )
        then
            return
        end

        local map = chunk.map

        setRetreatTick(chunk, tick)
        local exitPath,exitDirection,
            nextExitPath,nextExitDirection  = scoreNeighborsForRetreat(chunk,
                                                                       getNeighborChunks(map,
                                                                                         chunk.x,
                                                                                         chunk.y),
                                                                       scoreRetreatLocation,
                                                                       map)
        local position = {
            x = chunk.x + 16,
            y = chunk.y + 16
        }
        local retreatPosition
        local surface = map.surface
        if (exitPath == -1) then
            return
        elseif (nextExitPath ~= -1) then
            retreatPosition = findMovementPosition(
                surface,
                positionFromScaledDirections(
                    position,
                    1,
                    exitDirection,
                    nextExitDirection
                )
            )
        else
            retreatPosition = findMovementPosition(
                surface,
                positionFromScaledDirections(
                    position,
                    1,
                    exitDirection
                )
            )
        end

        if retreatPosition then
            position.x = retreatPosition.x
            position.y = retreatPosition.y
        else
            return
        end

        if not existingSquad then
            if (Universe.squadCount >= Universe.AI_MAX_SQUAD_COUNT) then
                return
            end

            local base = findNearbyBase(chunk)
            if not base then
                return
            end
            existingSquad = Squad.createSquad(position, map, nil, false, base)

            Queries.fleeCommand.from = cause
            Queries.retreatCommand.group = existingSquad.group

            Queries.formRetreatCommand.unit_search_distance = radius

            local foundUnits = surface.set_multi_command(Queries.formRetreatCommand)

            if (foundUnits == 0) then
                existingSquad.group.destroy()
                return
            end

            Universe.groupNumberToSquad[existingSquad.groupNumber] = existingSquad
            Universe.squadCount = Universe.squadCount + 1
        else
            Queries.moveCommand.distraction = DEFINES_DISTRACTION_NONE
            setPositionInCommand(Queries.moveCommand, position)
            existingSquad.group.set_command(Queries.moveCommand)
        end

        existingSquad.retreats = existingSquad.retreats + 1
        if (existingSquad.retreats >= 3) then
            existingSquad.kamikaze = true
        end

        existingSquad.status = SQUAD_RETREATING

        addSquadToChunk(chunk, existingSquad)

        existingSquad.frenzy = true
        existingSquad.frenzyPosition.x = position.x
        existingSquad.frenzyPosition.y = position.y
    end
end

function Squad.createSquad(position, map, group, settlers, base)
    local unitGroup = group
    if not unitGroup then
        local query = Queries.createUnitGroup
        setPositionInQuery(query, position)
        unitGroup = map.surface.create_unit_group(query)
    end

    local squad = {
        group = unitGroup,
        canBeCompressed = 0,
        compressionSet = nil,
        compressionText = nil,
        status = SQUAD_GUARDING,
        rabid = false,
        penalties = {},
        base = base,
        type = base.stateAI,
        retreats = 0,
        frenzy = false,
        map = map,
        wanders = 0,
        settlers = settlers or false,
        kamikaze = false,
        frenzyPosition = {x = 0,
                          y = 0},
        maxDistance = 0,
        groupNumber = unitGroup.unique_id,
        originPosition = {x = 0,
                          y = 0},
        commandTick = nil,
        chunk = -1
    }

    if settlers then
        squad.maxDistance = calculateSettlerMaxDistance()
    end

    if position then
        squad.originPosition.x = position.x
        squad.originPosition.y = position.y
    elseif group then
        squad.originPosition.x = group.position.x
        squad.originPosition.y = group.position.y
    end

    return squad
end

function Squad.calculateKamikazeSquadThreshold(memberCount)
    local threshold = (memberCount / Universe.attackWaveMaxSize) * 0.2 + (Universe.evolutionLevel * 0.2)
    return threshold
end

function Squad.calculateKamikazeSettlerThreshold(memberCount)
    local threshold = (memberCount / Universe.expansionMaxSize) * 0.2 + (Universe.evolutionLevel * 0.2)
    return threshold
end


local function settlerWaveScaling()
    return mCeil(gaussianRandomRangeRG(Universe.settlerWaveSize,
                                       Universe.settlerWaveDeviation,
                                       Universe.expansionMinSize,
                                       Universe.expansionMaxSize,
                                       Universe.random))
end

local function attackWaveScaling()
    return mCeil(gaussianRandomRangeRG(Universe.attackWaveSize,
                                       Universe.attackWaveDeviation,
                                       1,
                                       Universe.attackWaveUpperBound,
                                       Universe.random))
end

local function attackWaveValidCandidate(chunk)
    if isActiveNest(chunk) then
        return true
    end
    local base = chunk.base
    if (base.stateAI == BASE_AI_STATE_RAIDING) or
        (base.stateAI == BASE_AI_STATE_SIEGE) or
        (base.stateAI == BASE_AI_STATE_ONSLAUGHT)
    then
        return isActiveRaidNest(chunk)
    end
    return false
end

local function scoreSettlerLocation(neighborChunk)
    return neighborChunk[RESOURCE_PHEROMONE] + -neighborChunk[PLAYER_PHEROMONE]
end

local function scoreSiegeSettlerLocation(neighborChunk)
    return (neighborChunk[RESOURCE_PHEROMONE] + neighborChunk[BASE_PHEROMONE]) + -neighborChunk[PLAYER_PHEROMONE]
end

local function scoreUnitGroupLocation(neighborChunk)
    return neighborChunk[PLAYER_PHEROMONE] + neighborChunk[BASE_PHEROMONE]
end

local function validUnitGroupLocation(neighborChunk)
    return (not neighborChunk.nestCount)
end

local function visitPattern(o, cX, cY, distance)
    local startX
    local endX
    local stepX
    local startY
    local endY
    local stepY
    if (o == 0) then
        startX = cX - distance
        endX = cX + distance
        stepX = 32
        startY = cY - distance
        endY = cY + distance
        stepY = 32
    elseif (o == 1) then
        startX = cX + distance
        endX = cX - distance
        stepX = -32
        startY = cY + distance
        endY = cY - distance
        stepY = -32
    elseif (o == 2) then
        startX = cX - distance
        endX = cX + distance
        stepX = 32
        startY = cY + distance
        endY = cY - distance
        stepY = -32
    elseif (o == 3) then
        startX = cX + distance
        endX = cX - distance
        stepX = -32
        startY = cY - distance
        endY = cY + distance
        stepY = 32
    end
    return startX, endX, stepX, startY, endY, stepY
end

--[[
    Expects all neighbors adjacent to a chunk
--]]
local function scoreNeighborsForFormation(chunk, validFunction, scoreFunction)
    local highestChunk = -1
    local highestScore = -MAGIC_MAXIMUM_NUMBER
    local highestDirection
    local neighborChunks = getNeighborChunks(chunk.map, chunk.x, chunk.y)
    for x=1,8 do
        local neighborChunk = neighborChunks[x]
        if (neighborChunk ~= -1)
            and canMoveChunkDirection(x, chunk, neighborChunk)
            and validFunction(neighborChunk)
        then
            local score = scoreFunction(neighborChunk)
            if (score > highestScore) then
                highestScore = score
                highestChunk = neighborChunk
                highestDirection = x
            end
        end
    end

    return highestChunk, highestDirection
end

function Squad.rallyUnits(chunk, tick)
    if (tick - getRallyTick(chunk)) < COOLDOWN_RALLY then
        return
    end
    setRallyTick(chunk, tick)
    local cX = chunk.x
    local cY = chunk.y
    local startX, endX, stepX, startY, endY, stepY = visitPattern(tick % 4, cX, cY, RALLY_CRY_DISTANCE)
    local vengenceQueue = Universe.vengenceQueue
    local map = chunk.map
    for x=startX, endX, stepX do
        for y=startY, endY, stepY do
            if (x ~= cX) and (y ~= cY) then
                local rallyChunk = getChunkByXY(map, x, y)
                if rallyChunk ~= -1 then
                    local base = rallyChunk.base
                    if rallyChunk.nestCount
                        and (base.unitPoints >= AI_VENGENCE_SQUAD_COST)
                    then
                        vengenceQueue[rallyChunk.id] = rallyChunk
                    end
                end
            end
        end
    end
end

--[[
    Recruits idle spitters and biters near the formation point in the doctrine's
    ratio, topping up from the other kind when one runs short. Returns how many
    joined, the normal recruiting command fills whatever is still missing.
--]]
local function recruitMix(surface, group, position, count, spitterShare)
    local units = surface.find_entities_filtered({
            position = position,
            radius = Queries.formCommand.unit_search_distance,
            type = "unit",
            force = Universe.enemyForces
    })
    local spitters = {}
    local biters = {}
    for i=1,#units do
        local unit = units[i]
        local commandable = unit.commandable
        if commandable and (not commandable.parent_group) and (not ENTITY_SKIP_COUNT_LOOKUP[unit.name]) then
            if sFind(unit.name, "spitter", 1, true) then
                spitters[#spitters+1] = unit
            else
                biters[#biters+1] = unit
            end
        end
    end

    local wantSpitters = mFloor((count * spitterShare) + 0.5)
    local added = 0
    local addedSpitters = 0
    local spitterIndex = 1
    local biterIndex = 1
    while (added < count) do
        local preferSpitter = (spitterIndex - 1) < wantSpitters
        local unit
        if (preferSpitter and spitters[spitterIndex]) or ((not biters[biterIndex]) and spitters[spitterIndex]) then
            unit = spitters[spitterIndex]
            spitterIndex = spitterIndex + 1
            addedSpitters = addedSpitters + 1
        elseif biters[biterIndex] then
            unit = biters[biterIndex]
            biterIndex = biterIndex + 1
        else
            break
        end
        group.add_member(unit)
        added = added + 1
    end
    return added, addedSpitters
end

local function deploySquad(name, chunk, cost, vengence, attacker, scoutSize, attack)
    local base = chunk.base

    local lackingPoints = ((base.unitPoints - cost) < 0)
    if attacker then
        if lackingPoints
            or ((chunk[BASE_PHEROMONE] < 0.0001) and (chunk[PLAYER_PHEROMONE] < 0.0001))
            or (Universe.squadCount >= Universe.AI_MAX_SQUAD_COUNT)
            or (not vengence and not attackWaveValidCandidate(chunk))
            or (Universe.random() > Universe.formSquadThreshold)
        then
            return
        end
    else
        if lackingPoints
            or (Universe.builderCount > Universe.AI_MAX_BUILDER_COUNT)
            or (not vengence and (base.sentExpansionGroups >= base.maxExpansionGroups))
            or (Universe.random() > Universe.formSquadThreshold)
        then
            return
        end
    end

    local scoringFunction
    if attacker then
        scoringFunction = scoreUnitGroupLocation
    else
        scoringFunction = scoreSettlerLocation
        if base.stateAI == BASE_AI_STATE_SIEGE then
            scoringFunction = scoreSiegeSettlerLocation
        end
    end

    local squadPath, squadDirection = scoreNeighborsForFormation(
        chunk,
        validUnitGroupLocation,
        scoringFunction
    )
    if (squadPath == -1) then
        return
    end

    local map = chunk.map
    local surface = map.surface
    TargetPosition.x = chunk.x + HALF_CHUNK_SIZE
    TargetPosition.y = chunk.y + HALF_CHUNK_SIZE

    local squadPosition = findDeploymentPosition(
        surface,
        positionFromScaledDirections(
            TargetPosition,
            1.25,
            squadDirection
        )
    )

    if not squadPosition then
        return
    end

    local squad = Squad.createSquad(squadPosition, map, nil, not attacker, base)

    local scaledWaveSize
    if scoutSize then
        scaledWaveSize = scoutSize
    elseif attacker then
        scaledWaveSize = attackWaveScaling()
        if attack then
            scaledWaveSize = mMax(1, mMin(mCeil(scaledWaveSize * attack.genome.genes.sizeScale),
                                          Universe.attackWaveMaxSize))
        end
    else
        scaledWaveSize = settlerWaveScaling()
    end
    local foundUnits = 0
    local recruitedSpitters = 0
    if attack and attack.evaluate then
        foundUnits, recruitedSpitters = recruitMix(surface,
                                                   squad.group,
                                                   squadPosition,
                                                   scaledWaveSize,
                                                   attack.genome.genes.spitters)
    end
    local recruited = foundUnits
    if (foundUnits < scaledWaveSize) then
        Queries.formGroupCommand.group = squad.group
        Queries.formCommand.unit_count = scaledWaveSize - foundUnits
        foundUnits = foundUnits + surface.set_multi_command(Queries.formCommand)
    end
    if Telemetry.enabled() then
        local kind = (scoutSize and "scout") or (vengence and "vengeance") or (attacker and "attack") or "settler"
        Telemetry.record("squad_formed", {
                kind = kind,
                surface = surface.name,
                base = base.id,
                attack = attack and attack.id,
                group = squad.groupNumber,
                requested = scaledWaveSize,
                found = foundUnits,
                recruitedByMix = recruited,
                recruitedSpitters = recruitedSpitters,
                spitterShare = attack and attack.genome.genes.spitters,
                position = Telemetry.position(squadPosition)
        })
    end
    squad.formedTick = game.tick
    if (foundUnits == 0) then
        if squad.group.valid then
            squad.group.destroy()
        end
        return
    end

    local tick = game.tick
    if scoutSize then
        squad.scout = true
        Universe.squadCount = Universe.squadCount + 1
        base.scoutSquad = squad
        base.scoutDeadline = tick + SCOUT_MAX_DURATION
        Doctrine.startScouting(base)
        printTactic("Scouts sent", surface, squadPosition)
        if Telemetry.enabled() then
            Telemetry.record("scouts_sent", {
                    surface = surface.name,
                    base = base.id,
                    units = foundUnits,
                    position = Telemetry.position(squadPosition)
            })
        end
    elseif attacker then
        local kamikazeThreshold = Squad.calculateKamikazeSquadThreshold(foundUnits)
        if attack then
            kamikazeThreshold = kamikazeThreshold + attack.genome.genes.kamikaze
        end
        squad.kamikaze = Universe.random() < kamikazeThreshold
        Universe.squadCount = Universe.squadCount + 1
        if not vengence and (base.stateAI == BASE_AI_STATE_AGGRESSIVE) then
            base.sentAggressiveGroups = base.sentAggressiveGroups + 1
        end
        if attack then
            Doctrine.applyToSquad(squad, attack.genome)
            joinWave(base, attack, squad, cost, tick)
            Doctrine.addSquad(attack, squad, cost, foundUnits, tick)
        end
    else
        local kamikazeThreshold = Squad.calculateKamikazeSettlerThreshold(foundUnits)
        if base.stateAI == BASE_AI_STATE_SIEGE then
            kamikazeThreshold = kamikazeThreshold * 2.5
        end
        squad.kamikaze = Universe.random() < kamikazeThreshold
        base.sentExpansionGroups = base.sentExpansionGroups + 1
        Universe.builderCount = Universe.builderCount + 1
    end

    squad.rabid = Universe.random() < 0.03

    Universe.groupNumberToSquad[squad.groupNumber] = squad
    modifyBaseUnitPoints(base, -cost, name, squadPosition.x, squadPosition.y)
end

function Squad.formSettlers(chunk)
    deploySquad("Settler", chunk, AI_SETTLER_COST, false, false)
end

function Squad.formVengenceSettler(chunk)
    deploySquad("Vengence Settler", chunk, AI_VENGENCE_SETTLER_COST, true, false)
end

--[[
    Bases probe the defenses with a scout before committing a full attack, then
    hold the main attack until the scout has died or run out of time and its
    survey has become the base's defense profile.
--]]
local function scoutingBlocksAttack(base, tick)
    local scout = base.scoutSquad
    if scout then
        if scout.group.valid and (tick < base.scoutDeadline) then
            return true
        end
        base.scoutSquad = nil
        Doctrine.concludeScouting(base, tick)
    end
    return false
end

local function attackInProgress(attack, tick)
    return attack
        and (not attack.launched)
        and attack.deadline
        and (tick < attack.deadline)
end

--[[
    A base works on one attack at a time. A new attack picks its doctrine for
    the base's current defense profile once the previous attack has launched or
    its staging deadline has passed. An attack that has not formed a squad yet
    is re-planned when fresh scouting changes the profile.
--]]
local function getAttackPlan(base, tick)
    local attack = base.attack
    if (not attack)
        or attack.launched
        or (attack.deadline and (tick >= attack.deadline))
        or ((attack.count == 0) and (attack.context ~= Doctrine.currentContext(base, tick)))
    then
        attack = Doctrine.newAttack(base, tick)
        base.attack = attack
    end
    return attack
end

function Squad.formSquads(chunk)
    local base = chunk.base
    local tick = game.tick
    if Universe.enableScouting then
        if scoutingBlocksAttack(base, tick) then
            return
        end
        -- never re-scout in the middle of staging a wave
        if Doctrine.needsScouting(base, tick) and not attackInProgress(base.attack, tick) then
            deploySquad("Scout", chunk, AI_SCOUT_COST, false, true, SCOUT_SQUAD_SIZE)
            return
        end
    end
    local attack = getAttackPlan(base, tick)
    if (attack.count > 0) and (attack.count >= attack.size) then
        -- the wave is complete and waiting to launch
        return
    end
    -- timing genes hold the attack back until its window opens
    if (attack.count == 0) and attack.evaluate and not Doctrine.attackWindowOpen(attack, tick) then
        return
    end
    deploySquad("Squad", chunk, AI_SQUAD_COST * attack.genome.genes.sizeScale, false, true, nil, attack)
end

function Squad.formVengenceSquad(chunk)
    deploySquad("Vengence Squad", chunk, AI_VENGENCE_SQUAD_COST, true, true)
end

function Squad.init(universe)
    Universe = universe
    Queries = universe.squadQueries
    if Queries then
        TargetPosition = Queries.targetPosition
        SearchPath = Queries.searchPath
    end
end

SquadG = Squad
return Squad
