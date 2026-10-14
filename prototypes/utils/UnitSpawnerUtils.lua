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

local imageUtils = require("ImageUtils")

local scaleAnimation = imageUtils.scaleAnimation
local tintBodyLayer = imageUtils.tintBodyLayer

local unitSpawnerUtils = {}

-- Factorio 2.0 ships the vanilla spawner graphics through global builder functions
-- defined by __base__ (spawner-animation.lua). Those tint only the mask and have no
-- scale parameter, so the body tint and scale are applied here.

function unitSpawnerUtils.spawner_idle_animation(variation, tint, scale, tint2)
    local animation = spawner_idle_animation(variation, tint2 or tint)
    return scaleAnimation(tintBodyLayer(animation, tint), scale)
end

function unitSpawnerUtils.spawner_die_animation(variation, tint, scale, tint2)
    local animation = spawner_die_animation(variation, tint2 or tint)
    return scaleAnimation(tintBodyLayer(animation, tint), scale)
end

function unitSpawnerUtils.spawner_decay_animation(variation, tint, scale, tint2)
    local animation = spawner_decay_animation(variation, tint2 or tint)
    return scaleAnimation(tintBodyLayer(animation, tint), scale)
end

return unitSpawnerUtils
