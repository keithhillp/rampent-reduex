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
    Evolving attack doctrines.

    Each surface keeps a small population of doctrines. A doctrine is a set of
    genes that shape an attack (wave size, squad size, staggering, flanking,
    supply strikes, marching, kamikaze). Every attack a base launches is tagged
    with a doctrine, scored when it ends, and the score feeds the doctrine's
    fitness. Periodically the weakest doctrine is replaced by a mutated
    crossover of two strong ones, so attack shapes adapt to the defenses each
    surface actually has.

    Scouts survey the defenses they run into and give the base a defense
    profile such as "laser+wall" or "gun". Doctrines keep a separate fitness
    per profile, so a base picks the doctrine that has worked best against the
    kind of defense its scouts found.
--]]

if DoctrineG then
    return DoctrineG
end
local Doctrine = {}

--

local Universe

-- imports

local Constants = require("Constants")
local MathUtils = require("MathUtils")
local Telemetry = require("Telemetry")
local Strategy = require("Strategy")

-- Constants

local BUILDING_PHEROMONES = Constants.BUILDING_PHEROMONES
local DEFENSE_TURRET_TYPES = Constants.DEFENSE_TURRET_TYPES

local DOCTRINE_POPULATION_SIZE = Constants.DOCTRINE_POPULATION_SIZE
local DOCTRINE_EXPLORE_CHANCE = Constants.DOCTRINE_EXPLORE_CHANCE
local DOCTRINE_TOURNAMENT_SIZE = Constants.DOCTRINE_TOURNAMENT_SIZE
local DOCTRINE_EVOLVE_EVERY = Constants.DOCTRINE_EVOLVE_EVERY
local DOCTRINE_MIN_TRIALS_TO_REPLACE = Constants.DOCTRINE_MIN_TRIALS_TO_REPLACE
local DOCTRINE_FITNESS_MIN_ALPHA = Constants.DOCTRINE_FITNESS_MIN_ALPHA
local DOCTRINE_MUTATION_CHANCE = Constants.DOCTRINE_MUTATION_CHANCE
local DOCTRINE_MUTATION_SPREAD = Constants.DOCTRINE_MUTATION_SPREAD
local DOCTRINE_WILDCARD_EVERY = Constants.DOCTRINE_WILDCARD_EVERY
local DOCTRINE_ATTACK_TIMEOUT = Constants.DOCTRINE_ATTACK_TIMEOUT
local DOCTRINE_TURRET_KILL_BONUS = Constants.DOCTRINE_TURRET_KILL_BONUS
local DOCTRINE_CHARACTER_KILL_VALUE = Constants.DOCTRINE_CHARACTER_KILL_VALUE
local DOCTRINE_DEFAULT_KILL_VALUE = Constants.DOCTRINE_DEFAULT_KILL_VALUE
local DOCTRINE_DAMAGE_VALUE = Constants.DOCTRINE_DAMAGE_VALUE
local DOCTRINE_LOSS_PENALTY = Constants.DOCTRINE_LOSS_PENALTY
local DOCTRINE_CONTEXT_PRIOR = Constants.DOCTRINE_CONTEXT_PRIOR
local DOCTRINE_CONTEXT_CHAMPION_TRIALS = Constants.DOCTRINE_CONTEXT_CHAMPION_TRIALS
local DOCTRINE_CONTEXT_UNKNOWN = Constants.DOCTRINE_CONTEXT_UNKNOWN
local DEFENSE_PROFILE_TTL = Constants.DEFENSE_PROFILE_TTL
local SCOUT_SURVEY_RADIUS = Constants.SCOUT_SURVEY_RADIUS
local SCOUT_WALL_THRESHOLD = Constants.SCOUT_WALL_THRESHOLD
local DOCTRINE_MAX_WAIT = Constants.DOCTRINE_MAX_WAIT
local NIGHT_DARKNESS = Constants.NIGHT_DARKNESS
local PLAYER_ABSENT_RADIUS = Constants.PLAYER_ABSENT_RADIUS
local BROWNOUT_FRACTION = Constants.BROWNOUT_FRACTION
local SECTOR_FAIL_FITNESS = Constants.SECTOR_FAIL_FITNESS
local SECTOR_FAILS_TO_DETOUR = Constants.SECTOR_FAILS_TO_DETOUR
local SECTOR_MEMORY = Constants.SECTOR_MEMORY
local SECTOR_DETOURS = Constants.SECTOR_DETOURS
local DETACHED_UNIT_TIMEOUT = Constants.DETACHED_UNIT_TIMEOUT
local DOCTRINE_CREDIT_RADIUS = Constants.DOCTRINE_CREDIT_RADIUS
local DOCTRINE_REACH_VALUE = Constants.DOCTRINE_REACH_VALUE
local DOCTRINE_SECTOR_SIZE = Constants.DOCTRINE_SECTOR_SIZE
local DOCTRINE_BASELINE_ALPHA = Constants.DOCTRINE_BASELINE_ALPHA
local DOCTRINE_BASELINE_MIN = Constants.DOCTRINE_BASELINE_MIN
local DOCTRINE_GENE_STATS_DECAY = Constants.DOCTRINE_GENE_STATS_DECAY
local DOCTRINE_GENE_STATS_MIN = Constants.DOCTRINE_GENE_STATS_MIN
local DOCTRINE_GENE_STEER = Constants.DOCTRINE_GENE_STEER

-- imported functions

local gaussianRandomRangeRG = MathUtils.gaussianRandomRangeRG

local mFloor = math.floor
local mMin = math.min
local mMax = math.max
local mSqrt = math.sqrt
local sFormat = string.format
local sMatch = string.match

-- module code

--[[
    Gene ranges. The defaults reproduce the behaviour of the fixed tactics so
    the "Balanced" seed is the baseline every other doctrine competes with.
--]]
--[[
    unlock is the evolution factor a gene needs before it takes effect, below
    that attacks use its locked value, so early game attacks stay simple and
    tactics arrive as the biters evolve.
--]]
local GENES = {
    -- wave shape
    {name = "squads", short = "sq", min = 1, max = 4, integer = true, default = 3, unlock = 0.3, locked = 1},  -- squads per wave
    {name = "sizeScale", short = "size", min = 0.5, max = 1.75, default = 1, unlock = 0, locked = 1},        -- units and cost per squad
    {name = "stagger", short = "stg", min = 0, max = 20, default = 0, unlock = 0.5, locked = 0},             -- seconds between squad launches
    {name = "spread", short = "pin", min = 0, max = 1, default = 0, unlock = 0.55, locked = 0},              -- chance a wave splits into a pincer
    {name = "feint", short = "fnt", min = 0, max = 1, default = 0, unlock = 0.65, locked = 0},               -- chance a wave opens with a decoy
    {name = "spitters", short = "spit", min = 0, max = 1, default = 0.3, unlock = 0, locked = 0.3},          -- share of spitters recruited
    {name = "support", short = "sup", min = 0, max = 1, default = 1, unlock = 0.4, locked = 0},              -- chance spitters break off to shoot over walls
    {name = "joint", short = "jnt", min = 0, max = 1, default = 0.5, unlock = 0.6, locked = 0},              -- chance to found or join a joint offensive
    -- movement and nerve
    {name = "aversion", short = "avr", min = 0, max = 0.75, default = 0.25, unlock = 0.2, locked = 0},       -- how hard to avoid known defenses
    {name = "march", short = "mar", min = 0, max = 1, default = 0, unlock = 0.5, locked = 0},                -- chance a squad ignores fire en route
    {name = "kamikaze", short = "kam", min = -0.2, max = 0.4, default = 0, unlock = 0, locked = 0},          -- added to the no-retreat chance
    {name = "resolve", short = "res", min = 0, max = 1, default = 0.5, unlock = 0, locked = 0.5},            -- higher holds longer before retreating
    -- target priorities, weighed against a plain brawl at the attack point
    {name = "power", short = "pow", min = 0, max = 1, default = 1, unlock = 0.45, locked = 0},               -- poles powering lasers and teslas
    {name = "ammo", short = "amm", min = 0, max = 1, default = 1, unlock = 0.45, locked = 0},                -- inserters loading gun turrets
    {name = "science", short = "sci", min = 0, max = 1, default = 0, unlock = 0.6, locked = 0},              -- labs
    {name = "logistics", short = "log", min = 0, max = 1, default = 0, unlock = 0.6, locked = 0},            -- rails, train stops, roboports
    {name = "hunt", short = "hnt", min = 0, max = 1, default = 0, unlock = 0.7, locked = 0},                 -- player characters
    -- timing, each attack waits for its window up to a limit
    {name = "night", short = "ngt", min = 0, max = 1, default = 0, unlock = 0.35, locked = 0},               -- chance to wait for darkness
    {name = "opportune", short = "opp", min = 0, max = 1, default = 0, unlock = 0.5, locked = 0}             -- chance to wait for a brownout or absent player
}

-- tactics outside the genes unlock with evolution too
local TACTIC_UNLOCKS = {
    scouting = 0.15,
    detours = 0.3,
    breaches = 0.4,
    regroup = 0.5,
    surges = 0.5,
    -- squads without a doctrine, like vengeance squads, use these
    support = 0.4,
    priorities = 0.45
}

local SEEDS = {
    {label = "Balanced"},
    {label = "Swarm", squads = 4, sizeScale = 0.6, spitters = 0.1},
    {label = "Hammer", squads = 1, sizeScale = 1.75, march = 0.7, resolve = 0.9},
    {label = "Pincer", squads = 3, spread = 1, aversion = 0.6},
    {label = "Feint", squads = 3, feint = 1, stagger = 5},
    {label = "Sapper", march = 0.5, power = 1, ammo = 1, spitters = 0.6},
    {label = "Raider", sizeScale = 0.7, power = 0.3, ammo = 0.3, science = 1, logistics = 1, aversion = 0.6},
    {label = "Stalker", night = 1, opportune = 1, hunt = 0.6, march = 0.4},
    -- extremes the other seeds do not cover, so the starting population spans each gene
    {label = "Blitz", march = 1, aversion = 0, kamikaze = 0.3, resolve = 1},
    {label = "Stream", stagger = 15, power = 0, ammo = 0}
}

-- bump when genes change so populations in existing saves gain the new genes
local GENE_VERSION = 4
-- bump when the meaning of fitness changes so stored fitness is reset
local SCORE_VERSION = 2

local function defaultGenes()
    local genes = {}
    for i=1,#GENES do
        local gene = GENES[i]
        genes[gene.name] = gene.default
    end
    return genes
end

-- used when evolution is disabled, never stored in a population
local DEFAULT_GENOME = {
    id = 0,
    label = "Fixed",
    genes = defaultGenes(),
    trials = 0,
    fitness = 0
}

local function clampGene(gene, value)
    value = mMin(gene.max, mMax(gene.min, value))
    if gene.integer then
        value = mFloor(value + 0.5)
    end
    return value
end

local function copyGenes(genes)
    local copy = {}
    for name, value in pairs(genes) do
        copy[name] = value
    end
    return copy
end

local function createGenome(doctrine, label, genes, parents)
    local genome = {
        id = doctrine.nextId,
        label = label,
        genes = genes,
        trials = 0,
        fitness = 0,
        generation = doctrine.generation,
        parents = parents
    }
    doctrine.nextId = doctrine.nextId + 1
    return genome
end

--[[
    Doctrines from older saves lack newer genes. They get the defaults, except the
    old supply strike chance becomes the power and ammo priorities it replaced.
--]]
local function fillGenes(genes)
    if (genes.supply ~= nil) then
        genes.power = genes.power or genes.supply
        genes.ammo = genes.ammo or genes.supply
        genes.supply = nil
    end
    genes.scout = nil
    for g=1,#GENES do
        local gene = GENES[g]
        if (genes[gene.name] == nil) then
            genes[gene.name] = gene.default
        end
    end
end

local function upgradeGenes(doctrine)
    local population = doctrine.population
    local resetScores = (doctrine.scoreVersion ~= SCORE_VERSION)
    for i=1,#population do
        local genome = population[i]
        fillGenes(genome.genes)
        if resetScores then
            -- old fitness was on another scale, keep lineages but restart their scores
            genome.fitness = 0
            genome.contexts = nil
            genome.trials = mMin(genome.trials, 1)
        end
    end
    if resetScores then
        doctrine.baselines = nil
        doctrine.geneStats = nil
        doctrine.scoreVersion = SCORE_VERSION
    end
    doctrine.geneVersion = GENE_VERSION
end

--[[
    Brings every stored doctrine up to the current genes after a mod update,
    including doctrines only referenced by attacks already underway, which may
    have been retired from their population.
--]]
function Doctrine.upgradeSaved()
    for _, map in pairs(Universe.maps) do
        if map.doctrine then
            upgradeGenes(map.doctrine)
        end
    end
    for _, attack in pairs(Universe.activeAttacks or {}) do
        fillGenes(attack.genome.genes)
        attack.genes = attack.genes or copyGenes(attack.genome.genes)
        fillGenes(attack.genes)
    end
    for _, base in pairs(Universe.bases) do
        local attack = base.attack
        if attack and attack.genome then
            fillGenes(attack.genome.genes)
            attack.genes = attack.genes or copyGenes(attack.genome.genes)
            fillGenes(attack.genes)
        end
    end
end

local function getDoctrine(map)
    local doctrine = map.doctrine
    if doctrine then
        if (doctrine.geneVersion ~= GENE_VERSION) then
            upgradeGenes(doctrine)
        end
        return doctrine
    end
    doctrine = {
        population = {},
        nextId = 1,
        generation = 0,
        completed = 0
    }
    map.doctrine = doctrine
    doctrine.geneVersion = GENE_VERSION
    doctrine.scoreVersion = SCORE_VERSION
    for i=1,mMin(#SEEDS, DOCTRINE_POPULATION_SIZE) do
        local seed = SEEDS[i]
        local genes = defaultGenes()
        for g=1,#GENES do
            local gene = GENES[g]
            if seed[gene.name] ~= nil then
                genes[gene.name] = clampGene(gene, seed[gene.name])
            end
        end
        doctrine.population[i] = createGenome(doctrine, seed.label, genes)
    end
    return doctrine
end

local function getContextStats(genome, context, create)
    local contexts = genome.contexts
    if not contexts then
        if not create then
            return nil
        end
        contexts = {}
        genome.contexts = contexts
    end
    local stats = contexts[context]
    if (not stats) and create then
        stats = {trials = 0, fitness = 0}
        contexts[context] = stats
    end
    return stats
end

--[[
    Fitness against a defense profile, shrunk toward the doctrine's overall
    fitness until it has been tried a few times against that profile.
--]]
local function estimate(genome, context)
    local stats = context and getContextStats(genome, context, false)
    if (not stats) or (stats.trials == 0) then
        return genome.fitness
    end
    return ((stats.fitness * stats.trials) + (genome.fitness * DOCTRINE_CONTEXT_PRIOR))
        / (stats.trials + DOCTRINE_CONTEXT_PRIOR)
end

local function tournament(population, context)
    local best
    local bestScore
    for _=1,DOCTRINE_TOURNAMENT_SIZE do
        local genome = population[Universe.random(#population)]
        local score = estimate(genome, context)
        if (not best) or (score > bestScore) then
            best = genome
            bestScore = score
        end
    end
    return best
end

local function updateFitness(stats, fitness)
    stats.trials = stats.trials + 1
    if (stats.trials == 1) then
        stats.fitness = fitness
    else
        local alpha = mMax(1 / stats.trials, DOCTRINE_FITNESS_MIN_ALPHA)
        stats.fitness = stats.fitness + (alpha * (fitness - stats.fitness))
    end
end

--[[
    Baselines: the usual raw score in a sector, or against a defense profile
    when the sector has too little history. A doctrine's fitness is how far its
    attacks beat the baseline, so doctrines are not judged on where they landed.
--]]
local function sectorKey(position)
    if not position then
        return nil
    end
    return mFloor(position.x / DOCTRINE_SECTOR_SIZE) .. ":" .. mFloor(position.y / DOCTRINE_SECTOR_SIZE)
end

local function baselineFor(doctrine, kind, key, create)
    local baselines = doctrine.baselines
    if not baselines then
        baselines = {sector = {}, context = {}}
        doctrine.baselines = baselines
    end
    local entry = baselines[kind][key]
    if (not entry) and create then
        entry = {n = 0, mean = 0}
        baselines[kind][key] = entry
    end
    return entry
end

local function updateBaseline(entry, raw)
    entry.n = entry.n + 1
    local alpha = mMax(1 / entry.n, DOCTRINE_BASELINE_ALPHA)
    entry.mean = entry.mean + (alpha * (raw - entry.mean))
end

local function advantageOf(doctrine, attack, context, raw)
    local key = sectorKey(attack.impact)
    local sector = key and baselineFor(doctrine, "sector", key, true)
    local profile = baselineFor(doctrine, "context", context, true)
    local baseline
    if sector and (sector.n >= DOCTRINE_BASELINE_MIN) then
        baseline = sector.mean
    elseif (profile.n >= DOCTRINE_BASELINE_MIN) then
        baseline = profile.mean
    else
        -- no history yet, score against zero like before
        baseline = 0
    end
    if sector then
        updateBaseline(sector, raw)
    end
    updateBaseline(profile, raw)
    return raw - baseline, baseline
end

--[[
    Gene statistics: decayed covariance between each gene's value and the
    advantage it produced. Mutation is nudged along genes that correlate with
    beating the baseline, which learns faster than blind mutation.
--]]
local function recordGeneStats(doctrine, context, genes, advantage)
    -- per defense profile, a gene that helps against lasers can hurt against guns
    local allStats = doctrine.geneStats
    if not allStats then
        allStats = {}
        doctrine.geneStats = allStats
    end
    local stats = allStats[context]
    if not stats then
        stats = {}
        allStats[context] = stats
    end
    for i=1,#GENES do
        local gene = GENES[i]
        local x = ((genes[gene.name] or gene.default) - gene.min) / (gene.max - gene.min)
        local s = stats[gene.name]
        if not s then
            s = {w = 0, mx = 0, my = 0, cxy = 0, cxx = 0, cyy = 0}
            stats[gene.name] = s
        end
        -- exponentially weighted moments
        local w = (s.w * DOCTRINE_GENE_STATS_DECAY) + 1
        local a = 1 / w
        local dx = x - s.mx
        local dy = advantage - s.my
        s.mx = s.mx + (a * dx)
        s.my = s.my + (a * dy)
        s.cxy = ((1 - a) * (s.cxy + (a * dx * dy)))
        s.cxx = ((1 - a) * (s.cxx + (a * dx * dx)))
        s.cyy = ((1 - a) * (s.cyy + (a * dy * dy)))
        s.w = w
    end
end

local function geneCorrelation(doctrine, context, name)
    local stats = context and doctrine.geneStats and doctrine.geneStats[context]
    local s = stats and stats[name]
    if not s or (s.w < DOCTRINE_GENE_STATS_MIN) or (s.cxx <= 0) or (s.cyy <= 0) then
        return 0
    end
    return s.cxy / mSqrt(s.cxx * s.cyy)
end

local function breed(doctrine, context)
    local population = doctrine.population
    local mother = tournament(population)
    local father = tournament(population)
    local genes = {}
    for i=1,#GENES do
        local gene = GENES[i]
        local value
        if (Universe.random() < 0.5) then
            value = mother.genes[gene.name]
        else
            value = father.genes[gene.name]
        end
        if (Universe.random() < DOCTRINE_MUTATION_CHANCE) then
            local spread = (gene.max - gene.min) * DOCTRINE_MUTATION_SPREAD
            if gene.integer then
                spread = mMax(spread, 0.75)
            end
            -- lean the mutation toward values that have beaten the baseline
            local steer = geneCorrelation(doctrine, context, gene.name) * DOCTRINE_GENE_STEER * spread
            value = gaussianRandomRangeRG(value + steer, spread, gene.min, gene.max, Universe.random)
        end
        genes[gene.name] = clampGene(gene, value)
    end
    -- name children after the founding seed of each parent line
    local motherLine = sMatch(mother.label, "^[^/]+")
    local fatherLine = sMatch(father.label, "^[^/]+")
    local label = motherLine
    if (motherLine ~= fatherLine) then
        label = motherLine .. "/" .. fatherLine
    end
    return createGenome(doctrine, label, genes, {mother.id, father.id})
end

local function wildcard(doctrine)
    local genes = {}
    for i=1,#GENES do
        local gene = GENES[i]
        genes[gene.name] = clampGene(gene, gene.min + (Universe.random() * (gene.max - gene.min)))
    end
    return createGenome(doctrine, "Wildcard", genes)
end

local function printDoctrine(message)
    if Universe.printTactics then
        game.print("Rampant: " .. message)
    end
end

--[[
    The overall best doctrine and the best doctrine against each defense
    profile are protected, so specialists for rare defenses are not culled for
    having a mediocre overall fitness.
--]]
local function findProtected(population)
    local protected = {}
    local best
    local contextBest = {}
    for i=1,#population do
        local genome = population[i]
        if (not best) or (genome.fitness > best.fitness) then
            best = genome
        end
        local contexts = genome.contexts
        if contexts then
            for context, stats in pairs(contexts) do
                if (stats.trials >= DOCTRINE_CONTEXT_CHAMPION_TRIALS) then
                    local champion = contextBest[context]
                    if (not champion) or (stats.fitness > champion.fitness) then
                        contextBest[context] = {genome = genome, fitness = stats.fitness}
                    end
                end
            end
        end
    end
    if best then
        protected[best.id] = true
    end
    for _, champion in pairs(contextBest) do
        protected[champion.genome.id] = true
    end
    return protected
end

local function evolve(doctrine, surfaceName, context)
    local population = doctrine.population
    local protected = findProtected(population)
    local worstIndex
    for i=1,#population do
        local genome = population[i]
        if (not protected[genome.id]) and (genome.trials >= DOCTRINE_MIN_TRIALS_TO_REPLACE) then
            if (not worstIndex) or (genome.fitness < population[worstIndex].fitness) then
                worstIndex = i
            end
        end
    end
    if not worstIndex then
        return
    end
    doctrine.generation = doctrine.generation + 1
    local retired = population[worstIndex]
    retired.retired = true
    local child
    if (doctrine.generation % DOCTRINE_WILDCARD_EVERY) == 0 then
        child = wildcard(doctrine)
    else
        -- steer the child toward what works against the defense just attacked
        child = breed(doctrine, context)
    end
    population[worstIndex] = child
    printDoctrine(sFormat("%s doctrine #%d %s (%.2f) replaced by #%d %s, generation %d",
                          surfaceName, retired.id, retired.label, retired.fitness,
                          child.id, child.label, doctrine.generation))
    if Telemetry.enabled() then
        Telemetry.record("evolution", {
                surface = surfaceName,
                generation = doctrine.generation,
                retired = {id = retired.id, label = retired.label, fitness = retired.fitness, trials = retired.trials},
                child = {id = child.id, label = child.label, parents = child.parents, genes = copyGenes(child.genes)}
        })
    end
end

--[[
    Attack value per point spent, discounted when most of the attackers died.
--]]
local function scoreAttack(attack)
    -- squads that reached the defenses earn partial credit, so attacks that got
    -- there and failed rank above attacks that never arrived
    local value = attack.destroyedValue
        + (attack.turretKills * DOCTRINE_TURRET_KILL_BONUS)
        + (attack.damageDealt * DOCTRINE_DAMAGE_VALUE)
        + ((attack.reached or 0) * DOCTRINE_REACH_VALUE)
    local lossFraction = 0
    if (attack.units > 0) then
        lossFraction = mMin(1, attack.unitsLost / attack.units)
    end
    return (value / mMax(attack.cost, 1)) * (1 - (DOCTRINE_LOSS_PENALTY * lossFraction))
end

--[[
    Sector memory. A base's undetoured attacks follow the pheromone trail to its
    default sector of the player's base. When those keep failing, later attacks
    detour sideways, trying each side at growing distances, and keep using a
    detour that works. The memory fades so the default sector is retried.
--]]
local updateSector

local function getSector(base, tick)
    local sector = base.sector
    if not sector then
        sector = {fails = 0, tick = tick, detourIndex = 1}
        base.sector = sector
    end
    if ((tick - sector.tick) > SECTOR_MEMORY) then
        sector.fails = 0
        sector.good = nil
        sector.detourIndex = 1
        sector.tick = tick
    end
    return sector
end

updateSector = function(attack, fitness)
    local tick = game.tick
    local base = attack.base
    local sector = getSector(base, tick)
    local failed = fitness < SECTOR_FAIL_FITNESS
    Strategy.recordOutcome(base.map, attack.impact, not failed, tick)
    local detour = attack.detour
    if not detour then
        if failed then
            sector.fails = sector.fails + 1
        else
            sector.fails = 0
            sector.good = nil
        end
    elseif failed then
        if (sector.good == detour.index) then
            sector.good = nil
        end
        sector.detourIndex = detour.index + 1
        if (sector.detourIndex > #SECTOR_DETOURS) then
            -- every detour has failed, try the usual sector again
            sector.detourIndex = 1
            sector.fails = 0
        end
    else
        sector.good = detour.index
    end
    sector.tick = tick
    if Telemetry.enabled() then
        Telemetry.record("sector_update", {
                attack = attack.id,
                base = base.id,
                fitness = fitness,
                failed = failed,
                detour = detour and detour.index,
                defaultFails = sector.fails,
                goodDetour = sector.good,
                nextDetour = sector.detourIndex,
                impact = Telemetry.position(attack.impact)
        })
    end
end

local function chooseDetour(base, tick)
    local sector = getSector(base, tick)
    if (sector.fails < SECTOR_FAILS_TO_DETOUR) then
        return nil
    end
    local index = sector.good or sector.detourIndex
    local option = SECTOR_DETOURS[((index - 1) % #SECTOR_DETOURS) + 1]
    return {
        index = index,
        side = option.side,
        distance = option.distance
    }
end

local function finishAttack(attack)
    if attack.finished then
        return
    end
    attack.finished = true
    Universe.activeAttacks[attack.id] = nil
    if (Universe.attackIterator == attack.id) then
        Universe.attackIterator = nil
    end

    -- drop references so finished records can be collected
    attack.squads = {}
    local base = attack.base
    if base.attack == attack then
        base.attack = nil
    end

    if (attack.count > 0) then
        updateSector(attack, scoreAttack(attack))
    end

    if (not attack.evaluate) or (attack.count == 0) then
        if Telemetry.enabled() then
            Telemetry.record("attack_discarded", {
                    attack = attack.id,
                    reason = ((not attack.evaluate) and "evolution disabled") or "no squads formed",
                    alive = attack.alive
            })
        end
        return
    end

    local genome = attack.genome
    -- attacks started before defense profiles existed have no context
    local context = attack.context or DOCTRINE_CONTEXT_UNKNOWN
    local raw = scoreAttack(attack)
    local doctrine = getDoctrine(attack.map)
    local fitness, baseline = advantageOf(doctrine, attack, context, raw)
    recordGeneStats(doctrine, context, attack.genes or genome.genes, fitness)
    local surfaceName = (attack.surface.valid and attack.surface.name) or "?"
    printDoctrine(sFormat("%s attack #%d with #%d %s vs %s scored %.2f against a usual %.2f (destroyed %.0f, turrets %d, damage %.0f, lost %d/%d)",
                          surfaceName, attack.id, genome.id, genome.label, context, raw, baseline,
                          attack.destroyedValue, attack.turretKills, attack.damageDealt,
                          attack.unitsLost, attack.units))
    if Telemetry.enabled() then
        Telemetry.record("attack_scored", {
                attack = attack.id,
                surface = surfaceName,
                base = attack.base.id,
                doctrine = genome.id,
                label = genome.label,
                context = context,
                fitness = fitness,
                raw = raw,
                baseline = baseline,
                sector = sectorKey(attack.impact),
                reached = attack.reached or 0,
                offensive = attack.offensive and attack.offensive.id,
                destroyed = attack.destroyedValue,
                turretKills = attack.turretKills,
                damage = attack.damageDealt,
                indirectDamage = attack.indirectDamage or 0,
                indirectKills = attack.indirectKills or 0,
                unitsLost = attack.unitsLost,
                units = attack.units,
                cost = attack.cost,
                squads = attack.count,
                timedOut = attack.alive > 0,
                durationTicks = game.tick - attack.startTick,
                retired = genome.retired or false
        })
    end
    if genome.retired then
        return
    end

    updateFitness(genome, fitness)
    updateFitness(getContextStats(genome, context, true), fitness)

    doctrine.completed = doctrine.completed + 1
    if (doctrine.completed % DOCTRINE_EVOLVE_EVERY) == 0 then
        evolve(doctrine, surfaceName, context)
    end
end

local function select(map, context)
    if not Universe.enableEvolvingDoctrine then
        return DEFAULT_GENOME
    end
    local population = getDoctrine(map).population
    local untried
    for i=1,#population do
        local genome = population[i]
        if (genome.trials == 0) then
            untried = untried or {}
            untried[#untried+1] = genome
        end
    end
    if untried then
        return untried[Universe.random(#untried)]
    end
    if (Universe.random() < DOCTRINE_EXPLORE_CHANCE) then
        return population[Universe.random(#population)]
    end
    -- exploit the best known doctrine against this defense profile
    local best
    local bestScore
    for i=1,#population do
        local genome = population[i]
        local score = estimate(genome, context)
        if (not best) or (score > bestScore) then
            best = genome
            bestScore = score
        end
    end
    return best
end

local function evolutionOf(surface)
    return game.forces.enemy.get_evolution_factor(surface)
end

--[[
    The genes an attack actually uses: genes still locked at this evolution
    use their locked value.
--]]
local function effectiveGenes(genes, evolution)
    local effective = {}
    local gated = Universe.evolutionGatedTactics
    for i=1,#GENES do
        local gene = GENES[i]
        local value = genes[gene.name]
        if (value == nil) then
            value = gene.default
        end
        if gated and (evolution < gene.unlock) then
            value = gene.locked
        end
        effective[gene.name] = value
    end
    return effective
end

function Doctrine.tacticUnlocked(tactic, surface)
    if not Universe.evolutionGatedTactics then
        return true
    end
    return evolutionOf(surface) >= TACTIC_UNLOCKS[tactic]
end

function Doctrine.newAttack(base, tick)
    local context = Doctrine.currentContext(base, tick)
    local genome = select(base.map, context)
    local evolution = evolutionOf(base.map.surface)
    local detour
    if Doctrine.tacticUnlocked("detours", base.map.surface) then
        detour = chooseDetour(base, tick)
    end
    return {
        genome = genome,
        genes = effectiveGenes(genome.genes, evolution),
        evolution = evolution,
        context = context,
        detour = detour,
        evaluate = (genome ~= DEFAULT_GENOME),
        base = base,
        map = base.map,
        surface = base.map.surface,
        size = 0,
        count = 0,
        squads = {},
        launched = false,
        alive = 0,
        cost = 0,
        units = 0,
        unitsLost = 0,
        destroyedValue = 0,
        turretKills = 0,
        damageDealt = 0
    }
end

function Doctrine.addSquad(attack, squad, cost, units, tick)
    squad.attack = attack
    attack.alive = attack.alive + 1
    attack.cost = attack.cost + cost
    attack.units = attack.units + units
    if not attack.id then
        Universe.attackId = Universe.attackId + 1
        attack.id = Universe.attackId
        attack.startTick = tick
        Universe.activeAttacks[attack.id] = attack
        if attack.evaluate then
            local genome = attack.genome
            printDoctrine(sFormat("%s attack #%d using doctrine #%d %s against %s",
                                  attack.surface.name, attack.id, genome.id, genome.label, attack.context))
        end
        if attack.detour then
            printDoctrine(sFormat("%s base %d detours %d tiles to the %s after %d failed attacks on its usual sector",
                                  attack.surface.name, attack.base.id, attack.detour.distance,
                                  ((attack.detour.side > 0) and "right") or "left",
                                  attack.base.sector.fails))
        end
        if Telemetry.enabled() then
            local genome = attack.genome
            Telemetry.record("attack_start", {
                    attack = attack.id,
                    surface = attack.surface.name,
                    base = attack.base.id,
                    doctrine = genome.id,
                    label = genome.label,
                    context = attack.context,
                    evaluated = attack.evaluate,
                    plannedSquads = attack.size,
                    pincer = attack.pincer or false,
                    feint = attack.feint or false,
                    detour = attack.detour and attack.detour.index,
                    detourDistance = attack.detour and attack.detour.distance,
                    evolutionFactor = attack.evolution,
                    genes = copyGenes(attack.genes)
            })
        end
    end
end

function Doctrine.applyToSquad(squad, genes)
    squad.aversion = genes.aversion
    squad.march = Universe.random() < genes.march
    squad.retreatScale = 1.5 - genes.resolve
    squad.support = Universe.random() < genes.support
    squad.priorities = {
        power = genes.power,
        ammo = genes.ammo,
        science = genes.science,
        logistics = genes.logistics,
        hunt = genes.hunt
    }
end

function Doctrine.recordLoss(squad)
    local attack = squad.attack
    if attack then
        attack.unitsLost = attack.unitsLost + 1
    end
end

function Doctrine.recordKill(squad, entityType)
    local attack = squad.attack
    if not attack then
        return
    end
    if (entityType == "character") then
        attack.destroyedValue = attack.destroyedValue + DOCTRINE_CHARACTER_KILL_VALUE
    else
        attack.destroyedValue = attack.destroyedValue + (BUILDING_PHEROMONES[entityType] or DOCTRINE_DEFAULT_KILL_VALUE)
    end
    if DEFENSE_TURRET_TYPES[entityType] then
        attack.turretKills = attack.turretKills + 1
    end
end

--[[
    Indirect credit. Spitter acid mostly hurts through the splash fires it
    leaves, and that damage does not name a squad unit as its cause. Enemy
    damage and kills with no squad unit to credit go to the attack whose impact
    point is closest, within a short radius.
--]]
local function findNearbyAttack(entity)
    local surfaceIndex = entity.surface.index
    local position = entity.position
    local best
    local bestDistance = DOCTRINE_CREDIT_RADIUS * DOCTRINE_CREDIT_RADIUS
    for _, attack in pairs(Universe.activeAttacks) do
        local impact = attack.impact
        if impact and attack.surface.valid and (attack.surface.index == surfaceIndex) then
            local dx = impact.x - position.x
            local dy = impact.y - position.y
            local distance = (dx * dx) + (dy * dy)
            if (distance <= bestDistance) then
                best = attack
                bestDistance = distance
            end
        end
    end
    return best
end

function Doctrine.creditNearbyDamage(entity, amount)
    local attack = findNearbyAttack(entity)
    if attack then
        attack.damageDealt = attack.damageDealt + amount
        attack.indirectDamage = (attack.indirectDamage or 0) + amount
    end
end

function Doctrine.creditNearbyKill(entity, entityType)
    local attack = findNearbyAttack(entity)
    if attack then
        Doctrine.recordKill({attack = attack}, entityType)
        attack.indirectKills = (attack.indirectKills or 0) + 1
    end
end

function Doctrine.recordDamage(squad, amount)
    local attack = squad.attack
    if attack then
        attack.damageDealt = attack.damageDealt + amount
    end
end

function Doctrine.squadGone(squad)
    local attack = squad.attack
    if not attack then
        return
    end
    squad.attack = nil
    attack.alive = attack.alive - 1
    if (attack.alive <= 0) and attack.launched then
        finishAttack(attack)
    end
end

function Doctrine.setImpact(attack, position)
    if not attack.impact then
        attack.impact = {x = position.x, y = position.y}
    end
end

--[[
    Units detached from their squad, like spitters giving fire support, keep
    crediting their attack through a lookup by unit number.
--]]
function Doctrine.detachUnit(unit, squad, tick)
    Universe.detachedUnits[unit.unit_number] = {
        attack = squad.attack,
        tick = tick
    }
end

function Doctrine.detachedCredit(unit)
    local unitNumber = unit.unit_number
    return unitNumber and Universe.detachedUnits[unitNumber]
end

function Doctrine.forgetDetached(unit)
    local unitNumber = unit.unit_number
    if unitNumber then
        Universe.detachedUnits[unitNumber] = nil
    end
end

local function sweepDetached(tick)
    local detached = Universe.detachedUnits
    local unitNumber = Universe.detachedIterator
    local entry
    if not unitNumber then
        unitNumber, entry = next(detached, nil)
    else
        entry = detached[unitNumber]
    end
    if not unitNumber then
        Universe.detachedIterator = nil
        return
    end
    Universe.detachedIterator = next(detached, unitNumber)
    if entry and ((tick - entry.tick) > DETACHED_UNIT_TIMEOUT) then
        detached[unitNumber] = nil
    end
end

--[[
    Finishes attacks whose squads are still wandering long after launch.
--]]
function Doctrine.processAttacks(tick)
    sweepDetached(tick)
    local attacks = Universe.activeAttacks
    local attackId = Universe.attackIterator
    local attack
    if not attackId then
        attackId, attack = next(attacks, nil)
    else
        attack = attacks[attackId]
    end
    if not attackId then
        Universe.attackIterator = nil
        return
    end
    Universe.attackIterator = next(attacks, attackId)
    if attack and ((tick - attack.startTick) > DOCTRINE_ATTACK_TIMEOUT) then
        finishAttack(attack)
    end
end

function Doctrine.describe(map)
    local doctrine = map.doctrine
    if not doctrine then
        return {map.surface.name .. ": no attacks yet"}
    end
    local lines = {
        sFormat("%s: generation %d, %d attacks scored", map.surface.name, doctrine.generation, doctrine.completed)
    }
    local population = doctrine.population
    local contextLeaders = {}
    for i=1,#population do
        local genome = population[i]
        local genes = genome.genes
        local parts = {}
        for g=1,#GENES do
            local gene = GENES[g]
            local value = genes[gene.name] or gene.default
            if gene.integer then
                parts[#parts+1] = gene.short .. " " .. sFormat("%d", value)
            else
                parts[#parts+1] = gene.short .. " " .. sFormat("%.2f", value)
            end
        end
        lines[#lines+1] = sFormat("  #%d %s fit %.2f (%d tries) %s",
                                  genome.id, genome.label, genome.fitness, genome.trials,
                                  table.concat(parts, " "))
        if genome.contexts then
            for context, stats in pairs(genome.contexts) do
                local leader = contextLeaders[context]
                if (stats.trials > 0) and ((not leader) or (stats.fitness > leader.fitness)) then
                    contextLeaders[context] = {genome = genome, fitness = stats.fitness, trials = stats.trials}
                end
            end
        end
    end
    local contexts = {}
    for context in pairs(contextLeaders) do
        contexts[#contexts+1] = context
    end
    table.sort(contexts)
    for i=1,#contexts do
        local leader = contextLeaders[contexts[i]]
        lines[#lines+1] = sFormat("  vs %s: best #%d %s fit %.2f (%d tries)",
                                  contexts[i], leader.genome.id, leader.genome.label, leader.fitness, leader.trials)
    end
    return lines
end

--[[
    Defense profiles. Scouts survey around where they die and where they reach
    their target. The densest survey per category becomes the base's profile.
--]]
local SURVEY_QUERIES = {
    {category = "gun", query = {type = "ammo-turret"}},
    {category = "electric", query = {type = "electric-turret"}},
    {category = "tesla", query = {name = "tesla-turret"}},
    {category = "flame", query = {type = "fluid-turret"}},
    {category = "wall", query = {type = {"wall", "gate"}}}
}

-- order breaks ties between equally common turret kinds
local TURRET_CATEGORIES = {"laser", "tesla", "gun", "flame"}

function Doctrine.startScouting(base)
    base.scoutReport = {
        surveys = 0,
        gun = 0,
        electric = 0,
        tesla = 0,
        flame = 0,
        wall = 0
    }
end

function Doctrine.survey(base, surface, position)
    local report = base.scoutReport
    if not report then
        return
    end
    report.surveys = report.surveys + 1
    local playerForces = Universe.playerForces
    local turrets = 0
    for i=1,#SURVEY_QUERIES do
        local survey = SURVEY_QUERIES[i]
        local query = survey.query
        -- name filters error on prototypes that do not exist, e.g. tesla without Space Age
        if (not query.name) or prototypes.entity[query.name] then
            query.position = position
            query.radius = SCOUT_SURVEY_RADIUS
            query.force = playerForces
            local count = surface.count_entities_filtered(query)
            if (count > report[survey.category]) then
                report[survey.category] = count
            end
            if (survey.category ~= "wall") and (survey.category ~= "tesla") then
                turrets = turrets + count
            end
        end
    end
    -- remember where the defense is thickest, and a powered turret there to watch for brownouts
    if (turrets > 0) and (turrets >= (report.densest or 0)) then
        report.densest = turrets
        report.position = {x = position.x, y = position.y}
        if (report.electric > 0) then
            report.sentinel = surface.find_entities_filtered({
                    position = position,
                    radius = SCOUT_SURVEY_RADIUS,
                    type = "electric-turret",
                    force = playerForces,
                    limit = 1
            })[1]
        end
    end
end

local function profileKey(report)
    if (report.surveys == 0) then
        return DOCTRINE_CONTEXT_UNKNOWN
    end
    local counts = {
        laser = mMax(0, report.electric - report.tesla),
        tesla = report.tesla,
        gun = report.gun,
        flame = report.flame
    }
    local dominant
    for i=1,#TURRET_CATEGORIES do
        local category = TURRET_CATEGORIES[i]
        if (counts[category] > 0) and ((not dominant) or (counts[category] > counts[dominant])) then
            dominant = category
        end
    end
    if not dominant then
        return "open"
    end
    if (report.wall >= SCOUT_WALL_THRESHOLD) then
        return dominant .. "+wall"
    end
    return dominant
end

function Doctrine.concludeScouting(base, tick)
    local report = base.scoutReport
    base.scoutReport = nil
    if not report then
        return
    end
    local key = profileKey(report)
    Strategy.recordScout(base.map, report.position, report, tick)
    base.defenseProfile = {
        key = key,
        tick = tick,
        strength = (report.surveys > 0) and Strategy.defenseStrength(report) or nil,
        position = report.position,
        sentinel = report.sentinel
    }
    if Telemetry.enabled() then
        Telemetry.record("scout_report", {
                surface = base.map.surface.name,
                base = base.id,
                profile = key,
                surveys = report.surveys,
                guns = report.gun,
                lasers = mMax(0, report.electric - report.tesla),
                teslas = report.tesla,
                flamers = report.flame,
                walls = report.wall,
                position = Telemetry.position(report.position),
                sentinel = (report.sentinel and report.sentinel.valid and report.sentinel.name) or nil
        })
    end
    if Universe.printTactics then
        game.print(sFormat("Rampant: %s base %d scouts report %s (guns %d, lasers %d, teslas %d, flamers %d, walls %d)",
                           base.map.surface.name, base.id, key, report.gun,
                           mMax(0, report.electric - report.tesla), report.tesla, report.flame, report.wall))
    end
end

function Doctrine.needsScouting(base, tick)
    local profile = base.defenseProfile
    return (not profile) or ((tick - profile.tick) >= DEFENSE_PROFILE_TTL)
end

function Doctrine.currentStrength(base, tick)
    local profile = base.defenseProfile
    if profile and (not Doctrine.needsScouting(base, tick)) then
        return profile.strength
    end
    return nil
end

function Doctrine.currentContext(base, tick)
    if (not Universe.enableScouting)
        or (not Doctrine.tacticUnlocked("scouting", base.map.surface))
        or Doctrine.needsScouting(base, tick)
    then
        return DOCTRINE_CONTEXT_UNKNOWN
    end
    return base.defenseProfile.key
end

local function defenseWeakened(base)
    local profile = base.defenseProfile
    if not (profile and profile.position) then
        -- nothing scouted to wait on
        return true
    end
    local sentinel = profile.sentinel
    if sentinel and sentinel.valid then
        local buffer = sentinel.electric_buffer_size
        if buffer and (buffer > 0) and (sentinel.energy < (buffer * BROWNOUT_FRACTION)) then
            return true
        end
    end
    local surface = base.map.surface
    return surface.count_entities_filtered({
            position = profile.position,
            radius = PLAYER_ABSENT_RADIUS,
            type = "character",
            force = Universe.playerForces,
            limit = 1
    }) == 0
end

--[[
    Timing genes make an attack wait for its window before forming any squad:
    darkness, or the scouted defense browning out or being left unattended.
    Bases never wait longer than the limit, so patient doctrines still attack.
--]]
function Doctrine.attackWindowOpen(attack, tick)
    if not attack.waitUntil then
        local genes = attack.genes
        attack.waitUntil = tick + DOCTRINE_MAX_WAIT
        attack.waitNight = Universe.random() < genes.night
        attack.waitOpportunity = Universe.random() < genes.opportune
        if attack.waitNight or attack.waitOpportunity then
            local waits = {}
            if attack.waitNight then
                waits[#waits+1] = "darkness"
            end
            if attack.waitOpportunity then
                waits[#waits+1] = "a brownout or absent player"
            end
            printDoctrine(sFormat("%s base %d doctrine #%d %s waits for %s",
                                  attack.surface.name, attack.base.id, attack.genome.id,
                                  attack.genome.label, table.concat(waits, " and ")))
            if Telemetry.enabled() then
                Telemetry.record("attack_wait", {
                        surface = attack.surface.name,
                        base = attack.base.id,
                        doctrine = attack.genome.id,
                        night = attack.waitNight,
                        opportunity = attack.waitOpportunity
                })
            end
        end
    end
    if attack.waitUntil and (tick >= attack.waitUntil) and attack.waitLogged == nil then
        attack.waitLogged = true
        if (attack.waitNight or attack.waitOpportunity) and Telemetry.enabled() then
            Telemetry.record("attack_wait_expired", {
                    surface = attack.surface.name,
                    base = attack.base.id,
                    doctrine = attack.genome.id
            })
        end
    end
    if (tick >= attack.waitUntil) then
        return true
    end
    local surface = attack.surface
    if attack.waitNight
        and not (surface.always_day or surface.freeze_daytime)
        and (surface.darkness < NIGHT_DARKNESS)
    then
        return false
    end
    if attack.waitOpportunity and not defenseWeakened(attack.base) then
        return false
    end
    if (attack.waitNight or attack.waitOpportunity) and (not attack.waitLogged) then
        attack.waitLogged = true
        if Telemetry.enabled() then
            Telemetry.record("attack_window_open", {
                    surface = surface.name,
                    base = attack.base.id,
                    doctrine = attack.genome.id,
                    waitedTicks = tick - (attack.waitUntil - DOCTRINE_MAX_WAIT),
                    darkness = surface.darkness
            })
        end
    end
    return true
end

function Doctrine.init(universe)
    Universe = universe
end

DoctrineG = Doctrine
return Doctrine
