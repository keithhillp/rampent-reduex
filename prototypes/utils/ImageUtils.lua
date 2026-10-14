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


local imageUtils = {}

local fireutil = require("__base__.prototypes.fire-util")

-- module code

function imageUtils.create_burnt_patch_pictures(attributes)
    local base = {
        filename = "__base__/graphics/entity/fire-flame/burnt-patch.png",
        line_length = 3,
        width = 115,
        height = 56,
        frame_count = 9,
        axially_symmetrical = false,
        tint = attributes.tint2,
        direction_count = 1,
        shift = {-0.09375, 0.125},
    }

    local variations = {}

    for y=1,(base.frame_count / base.line_length) do
        for x=1,base.line_length do
            table.insert(variations,
                         {
                             filename = base.filename,
                             width = base.width,
                             height = base.height,
                             tint = base.tint,
                             shift = base.shift,
                             x = (x-1) * base.width,
                             y = (y-1) * base.height,
            })
        end
    end

    return variations
end


-- Factorio 2.0 consolidated the fire flame sheets, so the flames come from the
-- __base__ fire utilities and Rampant's options are layered on top. A Rampant scale
-- of 1 matches the vanilla flame size, as it did in 1.1.
local function applyFlameOptions(flames, opts)
    local scale = opts.scale or 1
    for _, flame in pairs(flames) do
        flame.scale = flame.scale * scale
        flame.shift = { flame.shift[1] * scale, flame.shift[2] * scale }
        flame.blend_mode = opts.blend_mode or "additive"
        flame.animation_speed = opts.animation_speed or 0.5
        flame.tint = opts.tint2
    end
    return flames
end

function imageUtils.create_small_tree_flame_animations(opts)
    return applyFlameOptions(fireutil.create_small_tree_flame_animations(), opts)
end

function imageUtils.create_fire_pictures(opts)
    return applyFlameOptions(fireutil.create_fire_pictures({}), opts)
end

-- Rescale every layer of an animation built by the __base__ graphics helpers,
-- which take no scale argument for some entities (e.g. spawners).
function imageUtils.scaleAnimation(animation, scale)
    if animation[1] then
        for _, variation in pairs(animation) do
            imageUtils.scaleAnimation(variation, scale)
        end
        return animation
    end
    for _, layer in pairs(animation.layers or {animation}) do
        layer.scale = (layer.scale or 1) * scale
        if layer.shift then
            layer.shift = { layer.shift[1] * scale, layer.shift[2] * scale }
        end
    end
    return animation
end

-- The __base__ graphics helpers only tint the mask layer; Rampant also tints the
-- body (the first layer that is neither a mask nor a shadow).
function imageUtils.tintBodyLayer(animation, tint)
    if animation[1] then
        for _, variation in pairs(animation) do
            imageUtils.tintBodyLayer(variation, tint)
        end
        return animation
    end
    for _, layer in pairs(animation.layers or {animation}) do
        local isMask = false
        for _, flag in pairs(layer.flags or {}) do
            if flag == "mask" then
                isMask = true
            end
        end
        if not isMask and not layer.draw_as_shadow and not layer.tint then
            layer.tint = tint
            break
        end
    end
    return animation
end

return imageUtils
