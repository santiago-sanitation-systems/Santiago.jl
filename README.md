# Santiago.jl

[![version](https://juliahub.com/docs/Santiago/version.svg)](https://juliahub.com/ui/Packages/Santiago/JPJQH)
[![Build
Status](https://github.com/santiago-sanitation-systems/Santiago.jl/workflows/CI/badge.svg)](https://github.com/santiago-sanitation-systems/Santiago.jl/actions)
[![codecov](https://codecov.io/gh/santiago-sanitation-systems/Santiago.jl/branch/master/graph/badge.svg?token=GWBV5M4Z13)](https://codecov.io/gh/santiago-sanitation-systems/Santiago.jl)

`Santiago` (SANitation sysTem Alternative GeneratOr) is a Julia package to generate appropriate sanitation system options. It is able to
- find all possible systems given a set of sanitation technologies;
- assess the appropriateness of a technology in a given case (context);
- assess the overall appropriateness of a sanitation system in a given context;
- calculate (optionally with uncertainly quantification) the massflows for each system for
  total `phosphor`, total `nitrogen`, `totalsolids`, and `water`;
- select a meaningful subset of systems for the given case.


# Installation

1. Install [Julia](https://julialang.org/) version >= 1.4.

2. Install the `Santiago` package from the Julia prompt:
```Julia
] add Santiago
```

3. To edit Julia files you may also want to install [Visual Studio
Code](https://code.visualstudio.com/) and its [Julia
Extension](https://www.julia-vscode.org/docs/stable/). Alternatively, see the [Julia
home page](https://julialang.org/) for support for other editors.

# Usage

The example below demonstrates the typical steps needed to identify
sanitation systems appropriate for a given case. See the references below for a
clarification of the terminology and the recommended embedding in the
strategic planning process.

Most functions have a documentation string attached that can be accessed with
`?functionname` on the Julia prompt.

For reproducibility it is a good idea to create a separate _Julia project_
(similar like `virtualenv` in Python) for
every analysis, see [here](https://julialang.github.io/Pkg.jl/v1/environments/).

## Minimal Example

```Julia
using Santiago

# -----------
# 1) Import technologies

# we use the test data that come with the package
input_tech_file = joinpath(pkgdir(Santiago), "test/example_techs.json")
input_case_file = joinpath(pkgdir(Santiago), "test/example_case.json")

sources, additional_sources, techs = import_technologies(input_tech_file, input_case_file)

# -----------
# 2) Build all systems

allSys = build_systems(sources, techs);

# number of found systems
length(allSys)


# The computations can be accelerated by setting max_candidates to a low number.
# However, this will result only in a *stochastic* subset of all possible systems!
allSys = build_systems(sources, techs, max_candidates=100);


# -----------
# 3) Calculate system properties

tas, tas_components = appropriateness(tech_file, case_file)

sysappscore!.(allSys)
ntechs!.(allSys)
nconnections!.(allSys)
connectivity!.(allSys)
template!.(allSys)

# see all properties of the first system
allSys[1].properties

# -----------
# 4) Mass flows

# Inputs for different sources in kg/year/person equivalent.
# See references below.
input_masses = Dict("Dry.toilet" => Dict("phosphor" => 0.548,
                                         "nitrogen" => 4.550,
                                         "totalsolids" => 32.12,
                                         "water" => 547.1),
                    "Pour.flush" => Dict("phosphor" => 0.548,
                                         "nitrogen" => 4.55,
                                         "totalsolids" => 32.12,
                                         "water" => 1277.1),
                    "Cistern.flush" => Dict("phosphor" => 0.548,
                                            "nitrogen" => 4.55,
                                            "totalsolids" => 32.12,
                                            "water" => 22447.1),
                    # Urine diversion dry toilet
                    "Uddt" => Dict("phosphor" => 0.548,
                                   "nitrogen" => 4.55,
                                   "totalsolids" => 32.12,
                                   "water" => 547.1)
                    )


# Calculate massflows with 20 Mont Carlo iterations (probably not enough)
# for all systems and save to system properties
massflow_summary_parallel!(allSys, input_masses, n=20);

# Alternatively, the non-parallelized version can be used:
# massflow_summary!.(allSys, Ref(input_masses), n=20);

# If the flows of every technology is of interest, set 'techflows=true'.
# The default is 'false' as this produces as very large amount of additional data!
massflow_summary_parallel!(allSys, input_masses, n=20, techflows=true);

# Examples how to extract results
allSys[2].properties["massflow_stats"]["entered"]
allSys[2].properties["massflow_stats"]["recovery_ratio"]
allSys[2].properties["massflow_stats"]["recovered"]

allSys[2].properties["massflow_stats"]["lost"][:,"air loss",:]
allSys[2].properties["massflow_stats"]["lost"][:,:,"mean"]
allSys[2].properties["massflow_stats"]["lost"][:,:,"q_0.5"]

# -----------
# 5) select a subset of systems

# For example, select eight systems for further investigation
selectedSys = select_systems(allSys, 8)

# We can also include or exclude technologies
select_systems(allSys, 8, techs_exclude=["Pour.flush", "wsp_3_trans"])
select_systems(allSys, 8, techs_include=["Pour.flush"])

# Similar for templates
select_systems(allSys, 8, templates_exclude=["ST.3", "ST.15"])
select_systems(allSys, 8, templates_include=["ST.17"])

# By default the systems are selected by the `"sysappscore"` but other
# properties can be used too. For example, here we prefer short systems:
select_systems(allSys, 8, target="ntechs", maximize=false)

# Or systems with a high phosphor recovery (run massflow calculation first):
select_systems(allSys, 8, target="phosphor" => "recovery_ratio")

# By default the returned systems are diverse while having a good
# target score. You can ignore the diversity requirement to get the
# systems with the best target scores by setting
# the `selection_type` to "ranking".
select_systems(allSys, 10, selection_type="ranking")

# This helper function returns the systems with matching IDs:
pick_systems(allSys, ["003s-QbnU-FvGB", "0JLD-YQbJ-SGAu"])

# Investigate how techs and templates are used
templates_per_tech(allSys)
techs_per_template(allSys)

# -----------
# 6) write some properties in a DataFrame for further analysis

df = properties_dataframe(selectedSys,
                          massflow_selection = ["recovered | water | mean",
                                                "recovered | water | sd",
                                                "lost | water | air loss| q_0.5",
                                                "entered | water"])

size(df)
names(df)

# or you could simply export all properties (> 400!)
df = properties_dataframe(allSys, massflow_selection = "all")

# export as csv
import CSV  # the package 'CSV' needs to be installed separately
CSV.write("mysystems.csv", df)


# -----------
# 7) create a visualization of a system as pdf

# First write a dot file
dot_file(selectedSys[1], "system.dot")

# Then, convert it to pdf (The program `graphviz` must be installed on the system)
run(`dot -Tpdf system.dot -o system.pdf`)


# -----------
# 8) export to JSON

# Note, the JSON export is designed to interface other applications,
# but not for serialization.

open("system_export.json", "w") do f
    JSON3.write(f, selectedSys)
end
```


## Input format

Typically the information on the case specification and the available
technologies are provided via files. `Santiago` can only import JSON
files. The structure must match these examples:

- Technologies: [`example_techs.json`](test/example_techs.json)
- Case: [`example_case.json`](test/example_case.json)

Many tools are available to browse and edit JSON files. For example,
Firefox renders JSON files nicely, or Visual Studio allows for editing.


## Logging

By default, `Santiago` prints only few information. This can be
adapted by the logging level. With the package `LoggingExtras.jl` (needs to
be installed extra)
different logging levels can be used for the console output and the log file:

```Julia
using Logging
using LoggingExtras

# - on console show only infos and errors, write everything in the logfile 'mylogfile.log'
mylogger = TeeLogger(
    MinLevelLogger(FileLogger("mylogfile.log"), Logging.Debug),  # logs to file
    MinLevelLogger(ConsoleLogger(), Logging.Info)                # logs to console
)
global_logger(mylogger)

... use Santiago functions ...
```

## Update systems for a new case profile

The generation of all systems is computationally intense. The code
below demonstrates how to first generate all systems without case
information and later update the system scores with case data.

```Julia
using Serialization

## 1) build systems without case information and cache result

sources, additional_sources, techs = import_technologies(tech_file)

if isfile("mycachfile.jls")
    allSys = deserialize("mycachfile.jls")
else
    allSys = build_systems(sources, techs)
    ...
    massflow_summary!.(allSys, Ref(input_masses), n=100);
    ...
    serialize("mycachfile.jls", allSys)
end

sysappscore!.(allSys) # all are '-1.0' because no case profile was defined yet

## 2) read case file and update sysappscore

tas, tas_components = appropriateness(tech_file, case_file);
update_appropriateness!(sources, tas)
update_appropriateness!(additional_sources, tas)
update_appropriateness!(techs, tas)

sysappscore!.(allSys)  # now we have the updated SAS

## 3) select systems

fewSys = select_systems(allSys, 6)

## 4) scale massflows for 100 people

fewSys = scale_massflows.(fewSys, 100)

```
The slowest parts are `build_systems` and
`massflow_summary!`. Therefore we could cache the output as shown in this
example. Steps 2 and 4 are fast and can be quickly adapted to new cases.


## Multi-threading

The functions `build_systems` and especially
`massflow_summary_parallel!` benefit from multi-threading. As this may
involves some overhead, benchmarking is recommended. See the official
[documentation](https://docs.julialang.org/en/v1/manual/parallel-computing/#man-multithreading-1)
how to control the number of threads.



# References

Spuhler, D., Scheidegger, A., Maurer, M., 2018. Generation of
sanitation system options for urban planning considering novel
technologies. Water Research 145,
259–278. https://doi.org/10.1016/j.watres.2018.08.021

Spuhler, D., Scheidegger, A., Maurer, M., 2020. Comparative analysis
of sanitation systems for resource recovery: influence of
configurations and single technology components. Water
Research 116281. https://doi.org/10.1016/j.watres.2020.116281

Spuhler, D., Scheidegger, A., Maurer, M., 2021. Ex-ante quantification
of nutrient, total solids, and water flows in sanitation
systems. Journal of Environmental Management 280, 111785.
https://doi.org/10.1016/j.jenvman.2020.111785


# License

The `Santiago.jl` package is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

Copyright 2020, Eawag. Contact: Dorothee Spuhler, <Dorothee.Spuhler@eawag.ch>
