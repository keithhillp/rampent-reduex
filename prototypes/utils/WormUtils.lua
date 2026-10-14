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

local tintBodyLayer = imageUtils.tintBodyLayer

local wormUtils = {}

-- Factorio 2.0 ships the vanilla worm graphics through global builder functions
-- defined by __base__ (worm-animations.lua). Those tint only the mask, so the mask
-- gets tint2 and the body tint is applied here.

function wormUtils.wormFoldedAnimation(scale, tint, tint2)
    return tintBodyLayer(worm_folded_animation(scale, tint2 or tint), tint)
end

function wormUtils.wormPreparingAnimation(scale, tint, run_mode, tint2)
    return tintBodyLayer(worm_preparing_animation(scale, tint2 or tint, run_mode), tint)
end

function wormUtils.wormPreparedAnimation(scale, tint, tint2)
    return tintBodyLayer(worm_prepared_animation(scale, tint2 or tint), tint)
end

function wormUtils.wormPreparedAlternativeAnimation(scale, tint, tint2)
    return tintBodyLayer(worm_prepared_alternative_animation(scale, tint2 or tint), tint)
end

function wormUtils.wormStartAttackAnimation(scale, tint, tint2)
    return tintBodyLayer(worm_start_attack_animation(scale, tint2 or tint), tint)
end

function wormUtils.wormEndAttackAnimation(scale, tint, tint2)
    return tintBodyLayer(worm_end_attack_animation(scale, tint2 or tint), tint)
end

function wormUtils.wormDieAnimation(scale, tint, tint2)
    return tintBodyLayer(worm_die_animation(scale, tint2 or tint), tint)
end

function wormUtils.wormDecayAnimation(scale, tint, tint2)
    return tintBodyLayer(worm_decay_animation(scale, tint2 or tint), tint)
end

return wormUtils
