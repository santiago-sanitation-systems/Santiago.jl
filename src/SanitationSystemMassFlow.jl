module SanitationSystemMassFlow

using AutoHashEquals

# number of substance in the massflow analysis
const NSUBSTANCE = 4
const SUBSTANCE_NAMES = ["phosphor", "nitrogen", "water", "solids"]

include("buildSystems.jl")
include("massflow.jl")
include("importExport.jl")


end
