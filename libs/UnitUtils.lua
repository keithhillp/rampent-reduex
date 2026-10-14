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


if (unitUtilsG) then
    return unitUtilsG
end
local unitUtils = {}

-- imports

local constants = require("Constants")
local chunkPropertyUtils = require("ChunkPropertyUtils")
local utils = require("Utils")

-- constants


local ENERGY_THIEF_CONVERSION_TABLE = constants.ENERGY_THIEF_CONVERSION_TABLE
local ENERGY_THIEF_LOOKUP = constants.ENERGY_THIEF_LOOKUP

local ENERGY_THIEF_DRAIN_CRYSTALS = constants.ENERGY_THIEF_DRAIN_CRYSTALS

-- imported functions

local setDrainPylons = chunkPropertyUtils.setDrainPylons
local getWireConnections = utils.getWireConnections
local restoreWireConnections = utils.restoreWireConnections

-- module code

local function convertTypeToDrainCrystal(evolutionFactor, entity)
    if (entity == "pole") then
        return "crystal-drain-pole-rampant"
    else
        if (entity == "smallUnit") then
            if (evolutionFactor < 0.25) then
                return ENERGY_THIEF_DRAIN_CRYSTALS[1]
            elseif (evolutionFactor < 0.50) then
                return ENERGY_THIEF_DRAIN_CRYSTALS[2]
            elseif (evolutionFactor < 0.75) then
                return ENERGY_THIEF_DRAIN_CRYSTALS[3]
            else
                return ENERGY_THIEF_DRAIN_CRYSTALS[4]
            end
        elseif (entity == "unit") then
            if (evolutionFactor < 0.25) then
                return ENERGY_THIEF_DRAIN_CRYSTALS[4]
            elseif (evolutionFactor < 0.50) then
                return ENERGY_THIEF_DRAIN_CRYSTALS[5]
            elseif (evolutionFactor < 0.75) then
                return ENERGY_THIEF_DRAIN_CRYSTALS[6]
            else
                return ENERGY_THIEF_DRAIN_CRYSTALS[7]
            end
        else
            if (evolutionFactor < 0.25) then
                return ENERGY_THIEF_DRAIN_CRYSTALS[7]
            elseif (evolutionFactor < 0.50) then
                return ENERGY_THIEF_DRAIN_CRYSTALS[8]
            elseif (evolutionFactor < 0.75) then
                return ENERGY_THIEF_DRAIN_CRYSTALS[9]
            else
                return ENERGY_THIEF_DRAIN_CRYSTALS[10]
            end
        end
    end
end

function unitUtils.createDrainPylon(map, cause, entity, entityType)
    if ((cause and ENERGY_THIEF_LOOKUP[cause.name]) or (not cause)) then
        local conversion = ENERGY_THIEF_CONVERSION_TABLE[entityType]
        if conversion then
            local newEntity = map.surface.create_entity({
                    position=entity.position,
                    name=convertTypeToDrainCrystal(entity.force.get_evolution_factor(entity.surface), conversion),
                    direction=entity.direction
            })
            if (conversion == "pole") then
                local targetEntity = map.surface.create_entity({
                        position=entity.position,
                        name="pylon-target-rampant",
                        direction=entity.direction
                })
                targetEntity.backer_name = ""
                restoreWireConnections(newEntity, getWireConnections(entity))
                setDrainPylons(map, targetEntity, newEntity)
            elseif newEntity.backer_name then
                newEntity.backer_name = ""
            end
        end
    end
end

unitUtilsG = unitUtils
return unitUtils
