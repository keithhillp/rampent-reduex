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


local beamUtils = {}

local DISALLOW_FRIENDLY_FIRE = settings.startup["rampant--disallowFriendlyFire"].value

function beamUtils.makeBubble(attributes)
    local name = attributes.name .. "-bubble-rampant"
    data:extend({{
                type = "explosion",
                name = name,
                flags = {"not-on-map"},
                animation_speed = 1,
                animations =
                    {
                        {
                            filename = "__base__/graphics/entity/laser-bubble/laser-bubble.png",
                            priority = "extra-high",
                            width = 8,
                            height = 8,
                            tint = attributes.tint2,
                            frame_count = 5
                        }
                    },
                light = {intensity = 1, size = 10, color = attributes.tint2 or {r = 1.0, g = 1.0, b = 1.0}},
                smoke = "smoke-fast",
                smoke_count = 2,
                smoke_slow_down_factor = 1
    }})
    return name
end

function beamUtils.makeLaser(attributes)
    local name = attributes.name .. "-laser-rampant"
    data:extend({{
                type = "projectile",
                name = name ,
                flags = {"not-on-map"},
                collision_box = attributes.collisionBox or {{-0.3, -1.1}, {0.3, 1.1}},
                acceleration = attributes.acceleration or 0.03,
                force_condition = (settings.startup["rampant--disableCollidingProjectiles"].value and "not-same") or nil,
                action =
                    {
                        type = "direct",
                        force = (DISALLOW_FRIENDLY_FIRE and "not-same") or nil,
                        action_delivery =
                            {
                                type = "instant",
                                target_effects =
                                    {
                                        {
                                            type = "create-entity",
                                            entity_name = attributes.attackBubble or "laser-bubble"
                                        },
                                        {
                                            type = "damage",
                                            damage = { amount = attributes.damage or 5, type = attributes.damageType or "laser"}
                                        }
                                    }
                            }
                    },
                light = {intensity = 0.5, size = 10},
                animation =
                    {
                        filename = "__base__/graphics/entity/laser/laser-to-tint-medium.png",
                        tint = attributes.tint2 or {r=1.0, g=0.0, b=0.0},
                        frame_count = 1,
                        width = 12,
                        height = 33,
                        priority = "high",
                        blend_mode = "additive"
                    },
                speed = 0.15
    }})
    return name
end

function beamUtils.makeBeam(attributes)
    local result =
        {
            type = "beam",
            flags = {"not-on-map"},
            width = attributes.width or 0.5,
            collision_box = attributes.collisionBox or {{-0.3, -1.1}, {0.3, 1.1}},
            damage_interval = attributes.damageInterval or 20,
            action =
                {
                    type = "direct",
                    force = (DISALLOW_FRIENDLY_FIRE and "not-same") or nil,
                    action_delivery =
                        {
                            type = "instant",
                            target_effects =
                                {
                                    {
                                        type = "damage",
                                        damage = { amount = attributes.damage or 10, type = attributes.damageType or "electric"}
                                    }
                                }
                        }
                }
        }

    -- Factorio 2.0 moved beam sprites into graphics_set; reuse the vanilla electric beam
    append_base_electric_beam_graphics(result)

    result.working_sound =
        {
            {
                filename = "__base__/sound/fight/electric-beam.ogg",
                volume = 0.7
            }
        }

    local name = attributes.name .. "-beam-rampant"
    result.name = name

    data:extend({result})
    return name
end

return beamUtils
