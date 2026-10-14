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


local unitUtils = {}
-- Factorio 2.0 ships the vanilla biter/spitter graphics through global builder
-- functions defined by __base__ (biter-animations.lua, spitter-animations.lua),
-- so vanilla units reuse those instead of hand-written sprite sheets.

function unitUtils.spitter_water_reflection(scale)
    return spitter_water_reflection(scale)
end

function unitUtils.biter_water_reflection(scale)
    return biter_water_reflection(scale)
end

function unitUtils.spitter_alternative_attacking_animation_sequence()
    return spitter_alternative_attacking_animation_sequence
end

local function armoredDieBiter(scale, tint1, tint2)
    return {
        layers=
            {
                {
                    filenames =
                        {
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-01.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-02.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-03.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-04.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-05.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-06.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-07.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-08.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-09.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-10.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-11.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-12.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-13.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-14.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-15.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-16.png"
                        },
                    slice = 4,
                    lines_per_file = 4,
                    line_length = 4,
                    width = 476,
                    height = 340,
                    frame_count = 16,
                    shift = {0,0},
                    direction_count = 16,
                    scale = 0.5 * scale,
                },
                {
                    filenames =
                        {
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask1-01.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask1-02.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask1-03.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask1-04.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask1-05.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask1-06.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask1-07.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask1-08.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask1-09.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask1-10.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask1-11.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask1-12.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask1-13.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask1-14.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask1-15.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask1-16.png"
                        },
                    slice = 4,
                    lines_per_file = 4,
                    line_length = 4,
                    width = 476,
                    height = 340,
                    frame_count = 16,
                    shift = {0,0},
                    direction_count = 16,
                    scale = 0.5 * scale,
                    tint = tint1,
                },
                {
                    filenames =
                        {
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask2-01.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask2-02.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask2-03.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask2-04.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask2-05.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask2-06.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask2-07.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask2-08.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask2-09.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask2-10.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask2-11.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask2-12.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask2-13.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask2-14.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask2-15.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-mask2-16.png"
                        },
                    slice = 4,
                    lines_per_file = 4,
                    line_length = 4,
                    width = 476,
                    height = 340,
                    frame_count = 16,
                    shift = {0,0},
                    direction_count = 16,
                    scale = 0.5 * scale,
                    tint = tint2,
                },
                {
                    filenames =
                        {
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-shadow-01.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-shadow-02.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-shadow-03.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-shadow-04.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-shadow-05.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-shadow-06.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-shadow-07.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-shadow-08.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-shadow-09.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-shadow-10.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-shadow-11.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-shadow-12.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-shadow-13.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-shadow-14.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-shadow-15.png",
                            "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-die-shadow-16.png"
                        },
                    slice = 4,
                    lines_per_file = 4,
                    line_length = 4,
                    width = 476,
                    height = 340,
                    frame_count = 16,
                    shift = {0,0},
                    direction_count = 16,
                    scale = 0.5 * scale,
                    draw_as_shadow = true,
                }
            }
    }
end

local function armoredAttackBiter(scale, tint1, tint2)
    return
        {
            layers=
                {
                    {
                        filenames =
                            {
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-attack-01.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-attack-02.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-attack-03.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-attack-04.png",
                            },
                        slice = 11,
                        lines_per_file = 4,
                        line_length = 16,
                        width = 476,
                        height = 340,
                        frame_count = 11,
                        shift = {0,0},
                        direction_count = 16,
                        animation_speed = 0.4,
                        scale = 0.5 * scale,
                    },
                    {
                        filenames =
                            {
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-attack-mask1-01.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-attack-mask1-02.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-attack-mask1-03.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-attack-mask1-04.png",
                            },
                        slice = 11,
                        lines_per_file = 4,
                        line_length = 16,
                        width = 476,
                        height = 340,
                        frame_count = 11,
                        shift = {0,0},
                        direction_count = 16,
                        animation_speed = 0.4,
                        scale = 0.5 * scale,
                        tint = tint1,
                    },
                    {
                        filenames =
                            {
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-attack-mask2-01.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-attack-mask2-02.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-attack-mask2-03.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-attack-mask2-04.png",
                            },
                        slice = 11,
                        lines_per_file = 4,
                        line_length = 16,
                        width = 476,
                        height = 340,
                        frame_count = 11,
                        shift = {0,0},
                        direction_count = 16,
                        animation_speed = 0.4,
                        scale = 0.5 * scale,
                        tint = tint2,
                    },
                    {
                        filenames =
                            {
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-attack-shadow-01.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-attack-shadow-02.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-attack-shadow-03.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-attack-shadow-04.png",
                            },
                        slice = 11,
                        lines_per_file = 4,
                        line_length = 16,
                        width = 476,
                        height = 340,
                        frame_count = 11,
                        shift = {0,0},
                        direction_count = 16,
                        animation_speed = 0.4,
                        scale = 0.5 * scale,
                        draw_as_shadow = true,
                    },
                }
        }
end

local function armoredRunBiter(scale, tint1, tint2)
    return
        {
            layers=
                {
                    {
                        filenames =
                            {
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-run-01.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-run-02.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-run-03.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-run-04.png",
                            },
                        slice = 8,
                        lines_per_file = 8,
                        line_length = 8,
                        width = 476,
                        height = 340,
                        frame_count = 16,
                        shift = {0,0},
                        direction_count = 16,
                        scale = 0.5 * scale,
                    },
                    {
                        filenames =
                            {
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-run-mask1-01.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-run-mask1-02.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-run-mask1-03.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-run-mask1-04.png",
                            },
                        slice = 8,
                        lines_per_file = 8,
                        line_length = 8,
                        width = 476,
                        height = 340,
                        frame_count = 16,
                        shift = {0,0},
                        direction_count = 16,
                        scale = 0.5 * scale,
                        tint = tint1,
                    },
                    {
                        filenames =
                            {
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-run-mask2-01.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-run-mask2-02.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-run-mask2-03.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-run-mask2-04.png",
                            },
                        slice = 8,
                        lines_per_file = 8,
                        line_length = 8,
                        width = 476,
                        height = 340,
                        frame_count = 16,
                        shift = {0,0},
                        direction_count = 16,
                        scale = 0.5 * scale,
                        tint = tint2,
                    },
                    {
                        filenames =
                            {
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-run-shadow-01.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-run-shadow-02.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-run-shadow-03.png",
                                "__ArmouredBiters__/graphics/armoured-biter/HighRes/hr-armoured-biter-run-shadow-04.png",
                            },
                        slice = 8,
                        lines_per_file = 8,
                        line_length = 8,
                        width = 476,
                        height = 340,
                        frame_count = 16,
                        shift = {0,0},
                        direction_count = 16,
                        scale = 0.5 * scale,
                        draw_as_shadow = true,
                    }
                }
        }
end

function unitUtils.biterdieanimation(scale, tint1, tint2, altBiter)
    if (altBiter == "armored") and mods["ArmouredBiters"] then
        return armoredDieBiter(scale, tint1, tint2)
    else
        return biterdieanimation(scale, tint1, tint2)
    end
end

function unitUtils.biterattackanimation(scale, tint1, tint2, altBiter)
    if (altBiter == "armored") and mods["ArmouredBiters"] then
        return armoredAttackBiter(scale, tint1, tint2)
    else
        return biterattackanimation(scale, tint1, tint2)
    end
end


function unitUtils.biterrunanimation(scale, tint1, tint2, altBiter)
    if (altBiter == "armored") and mods["ArmouredBiters"] then
        return armoredRunBiter(scale, tint1, tint2)
    else
        return biterrunanimation(scale, tint1, tint2)
    end
end


return unitUtils
