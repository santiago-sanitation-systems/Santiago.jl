module SanitationSystemBuilder

using AutoHashEquals

# number of substance in the massflow analysis
const NSUBSTANCE = 4

include("buildSystems.jl")
include("massflow.jl")
include("importExport.jl")


end
