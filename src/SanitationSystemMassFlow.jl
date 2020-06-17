module SanitationSystemMassFlow

# number of substance in the massflow analysis
const NSUBSTANCE = 4
const SUBSTANCE_NAMES = ["phosphor", "nitrogen", "water", "totalsolids"]

include("buildSystems.jl")
include("massflow.jl")
include("importExport.jl")
include("properties.jl")
include("selection.jl")

include("interface.jl")

end
