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
    Tactics telemetry. When enabled, every tactical decision is appended as one
    JSON object per line to script-output/rampant/telemetry.jsonl, so attack
    behaviour and doctrine evolution can be analysed outside the game.

    Records must only hold plain values (numbers, strings, booleans, tables of
    those), never LuaObjects, so they serialise to JSON.
--]]

if TelemetryG then
    return TelemetryG
end
local Telemetry = {}

--

local Universe

-- Constants

local TELEMETRY_FILE = "rampant/telemetry.jsonl"

-- module code

function Telemetry.enabled()
    return Universe and Universe.writeTelemetry
end

function Telemetry.record(event, data)
    if not (Universe and Universe.writeTelemetry) then
        return
    end
    data = data or {}
    data.event = event
    data.tick = game.tick
    helpers.write_file(TELEMETRY_FILE, helpers.table_to_json(data) .. "\n", true)
end

function Telemetry.position(position)
    if not position then
        return nil
    end
    return {
        x = math.floor(position.x),
        y = math.floor(position.y)
    }
end

function Telemetry.init(universe)
    Universe = universe
end

TelemetryG = Telemetry
return Telemetry
