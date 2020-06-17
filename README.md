# SanitationSystemMassFlow


Extension of the
[SanitationSystemBuilder](https://github.com/Eawag-SWW/SanitationSystemBuilder.jl)
package. It enables to
- find all possible systems given a set of sanitation technologies
- calculate (optionally stochastic) the mass flows for each system for
  total `phosphor`, total `nitrogen`, `totalsolids`, and `water`.
- select a desired number of diverse but appropriate systems.


# Installation

1. Install [Julia](https://julialang.org/) version >= 1.4.

2. Then the `SanitationSystemMassFlow` package is installed from within the Julia:
```Julia
] add https://gitlab.com/scheidan/SanitationSystemMassFlow.git#santiago

```

# Usage

Some functions of `SanitationSystemMassFlow` are parallelized. To use
this feature start Julia with multiple threads.


## Minimal Example

```Julia
using SanitationSystemMassFlow
using Logging

# -----------
# 0) define log level

global_logger(ConsoleLogger(stderr, Logging.Warn))


# -----------
# 1) Import tech file

# we use the test data that come with the package
input_tech_file = joinpath(pkgdir(SanitationSystemMassFlow), "test/example_techs.json")

sources, additional_sources, techs = import_technologies(input_tech_file)

# number of available technologies (more than in "example_techs.csv", some are auto generated)
length(techs)


# -----------
# 2) Build all systems

allSys = build_systems(sources, techs);

# number of found systems
length(allSys)


# -----------
# 3) Calculate (or update) system properties

sysappscore!.(allSys)
connectivity!.(allSys)
ntechs!.(allSys)
template!.(allSys)

# see all properties of the first system
allSys[1].properties


# -----------
# 3) Mass flows

input_masses = Dict("Dry.toilet" => Dict("phosphor" => 548.0,
                                         "nitrogen" => 4550.0,
                                         "water" => 22447113.5,
                                         "totalsolids" => 32120.0),
                    "Pour.flush" => Dict("phosphor" => 548.0,
                                         "nitrogen" => 4550.0,
                                         "water" => 1277113.465,
                                         "totalsolids" => 32120.0)
                    )

# calculate mass flows for all systems and save to system properties
massflow_summary!.(allSys, Ref(input_masses), n=20)

# Examples how to extract results
allSys[2].properties["massflow_stats"]["entered"]
allSys[2].properties["massflow_stats"]["recovery_ratio"]
allSys[2].properties["massflow_stats"]["recovered"]

allSys[2].properties["massflow_stats"]["lost"][:,"air loss",:]
allSys[2].properties["massflow_stats"]["lost"][:,:,"mean"]
allSys[2].properties["massflow_stats"]["lost"][:,:,"q_0.5"]

# -----------
# 4) select a subset of systems

# select 8 systems
selectedSys = select_systems(allSys, 8)
```

## Logging

By default, `SanitationSystemMassFlow` is rather talkative. This can be
adapted by the logging level. With the package `LoggingExtras.jl` (must
be installed extra)
different logging levels can be used for the console output and the log file:

```Julia
using Logging
using LoggingExtras

# - on console show only warings and errors, write everything in the logfile 'info.log'
mylogger = TeeLogger(
    MinLevelLogger(FileLogger("info.log"), Logging.Debug),  # logs to file
    MinLevelLogger(ConsoleLogger(), Logging.Warn)           # logs to console
)
global_logger(mylogger)

... use SanitationSystemMassFlow functions ...
```
