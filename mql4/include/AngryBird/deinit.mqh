
/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   int uninitReason = UninitializeReason();

   // clean-up created chart objects
   if (uninitReason!=UR_CHARTCHANGE && uninitReason!=UR_PARAMETERS) {
      if (!IsTesting()) DeleteRegisteredObjects(NULL);
   }

   // store runtime status
   if (uninitReason==UR_CLOSE || uninitReason==UR_CHARTCLOSE || uninitReason==UR_RECOMPILE) {
      if (!IsTesting()) StoreRuntimeStatus();
   }
   return(last_error);
}


/**
 * Save input parameters and runtime status in the chart to be able to continue a sequence after terminal re-start, profile
 * change or recompilation.
 *
 * @return bool - success status
 */
bool StoreRuntimeStatus() {
   int sequenceId = 0;
   if (ArraySize(position.tickets) > 0)
      sequenceId = position.tickets[0];

   // sequence id
   Chart.StoreInt   (__NAME__ +".id", sequenceId);

   // input parameters
   Chart.StoreString(__NAME__ +".input.Trade.StartMode",        Trade.StartMode       );
   Chart.StoreBool  (__NAME__ +".input.Trade.Reverse",          Trade.Reverse         );
   Chart.StoreBool  (__NAME__ +".input.Trade.StopAtTarget",     Trade.StopAtTarget    );
   Chart.StoreDouble(__NAME__ +".input.Lots.StartSize",         Lots.StartSize        );
   Chart.StoreInt   (__NAME__ +".input.Lots.StartVola.Percent", Lots.StartVola.Percent);
   Chart.StoreDouble(__NAME__ +".input.Lots.Multiplier",        Lots.Multiplier       );
   Chart.StoreDouble(__NAME__ +".input.TakeProfit.Pips",        TakeProfit.Pips       );
   Chart.StoreInt   (__NAME__ +".input.StopLoss.Percent",       StopLoss.Percent      );
   Chart.StoreBool  (__NAME__ +".input.StopLoss.ShowLevels",    StopLoss.ShowLevels   );
   Chart.StoreInt   (__NAME__ +".input.Grid.MaxLevels",         Grid.MaxLevels        );
   Chart.StoreDouble(__NAME__ +".input.Grid.Min.Pips",          Grid.Min.Pips         );
   Chart.StoreDouble(__NAME__ +".input.Grid.Max.Pips",          Grid.Max.Pips         );
   Chart.StoreInt   (__NAME__ +".input.Grid.Lookback.Periods",  Grid.Lookback.Periods );
   Chart.StoreInt   (__NAME__ +".input.Grid.Lookback.Divider",  Grid.Lookback.Divider );
   Chart.StoreDouble(__NAME__ +".input.Exit.Trail.Pips",        Exit.Trail.Pips       );
   Chart.StoreDouble(__NAME__ +".input.Exit.Trail.Start.Pips",  Exit.Trail.Start.Pips );

   // runtime status
   Chart.StoreBool  (__NAME__ +".runtime.__STATUS_INVALID_INPUT",  __STATUS_INVALID_INPUT );
   Chart.StoreBool  (__NAME__ +".runtime.__STATUS_OFF",            __STATUS_OFF           );
   Chart.StoreInt   (__NAME__ +".runtime.__STATUS_OFF.reason",     __STATUS_OFF.reason    );
   Chart.StoreDouble(__NAME__ +".runtime.lots.calculatedSize",     lots.calculatedSize    );
   Chart.StoreDouble(__NAME__ +".runtime.lots.startSize",          lots.startSize         );
   Chart.StoreInt   (__NAME__ +".runtime.lots.startVola",          lots.startVola         );
   Chart.StoreInt   (__NAME__ +".runtime.grid.level",              grid.level             );
   Chart.StoreDouble(__NAME__ +".runtime.grid.minSize",            grid.minSize           );
   Chart.StoreDouble(__NAME__ +".runtime.grid.marketSize",         grid.marketSize        );
   Chart.StoreDouble(__NAME__ +".runtime.position.startEquity",    position.startEquity   );
   Chart.StoreDouble(__NAME__ +".runtime.position.slPrice",        position.slPrice       );
   Chart.StoreDouble(__NAME__ +".runtime.position.plPip",          position.plPip         );
   Chart.StoreDouble(__NAME__ +".runtime.position.plPipMin",       position.plPipMin      );
   Chart.StoreDouble(__NAME__ +".runtime.position.plPipMax",       position.plPipMax      );
   Chart.StoreDouble(__NAME__ +".runtime.position.plUPip",         position.plUPip        );
   Chart.StoreDouble(__NAME__ +".runtime.position.plUPipMin",      position.plUPipMin     );
   Chart.StoreDouble(__NAME__ +".runtime.position.plUPipMax",      position.plUPipMax     );
   Chart.StoreDouble(__NAME__ +".runtime.position.plPct",          position.plPct         );
   Chart.StoreDouble(__NAME__ +".runtime.position.plPctMin",       position.plPctMin      );
   Chart.StoreDouble(__NAME__ +".runtime.position.plPctMax",       position.plPctMax      );
   Chart.StoreDouble(__NAME__ +".runtime.position.cumStartEquity", position.cumStartEquity);
   Chart.StoreDouble(__NAME__ +".runtime.position.cumPl",          position.cumPl         );
   Chart.StoreDouble(__NAME__ +".runtime.position.cumPlPct",       position.cumPlPct      );
   Chart.StoreDouble(__NAME__ +".runtime.position.cumPlPctMin",    position.cumPlPctMin   );
   Chart.StoreDouble(__NAME__ +".runtime.position.cumPlPctMax",    position.cumPlPctMax   );

   return(!catch("StoreRuntimeStatus(1)"));
}
