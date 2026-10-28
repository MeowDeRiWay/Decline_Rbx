return {
 -- false chooses a fresh random seed for each server/Play session.
 -- Set a number to reproduce a particular layout for testing.
 Seed = false,
 StoreChance = 0.05,
 PlotSize = 20,
 FitTolerance = 0.05,
 -- Distance from the plot footprint, in horizontal studs.
 GenerationRadius = 240,
 -- Spread each newly discovered nearby batch from first to last job.
 ZoneLoadSeconds = 30,
 CheckInterval = 0.25,
 PlotsPerStep = 4,
 -- Failed/missing-template plots and standalone markers retry at this interval.
 RetryInterval = 5,
}
