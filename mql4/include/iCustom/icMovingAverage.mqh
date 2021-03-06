/**
 * Load the "Moving Average" indicator and return a calculated value.
 *
 * @param  int    timeframe      - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int    maPeriods      - indicator parameter
 * @param  string maTimeframe    - indicator parameter
 * @param  string maMethod       - indicator parameter
 * @param  string maAppliedPrice - indicator parameter
 * @param  int    maxValues      - indicator parameter
 * @param  int    iBuffer        - indicator buffer index of the value to return
 * @param  int    iBar           - bar index of the value to return
 *
 * @return double - value or NULL in case of errors
 */
double icMovingAverage(int timeframe/*=NULL*/, int maPeriods, string maTimeframe, string maMethod, string maAppliedPrice, int maxValues, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, "Moving Average",
                          maPeriods,                                       // int    MA.Periods
                          maTimeframe,                                     // string MA.Timeframe
                          maMethod,                                        // string MA.Method
                          maAppliedPrice,                                  // string MA.AppliedPrice

                          Blue,                                            // color  Color.UpTrend
                          Orange,                                          // color  Color.DownTrend
                          "Line",                                          // string Draw.Type
                          1,                                               // int    Draw.LineWidth

                          maxValues,                                       // int    Max.Values
                          0,                                               // int    Shift.Vertical.Pips
                          0,                                               // int    Shift.Horizontal.Bars

                          "",                                              // string _____________________
                          false,                                           // bool   Signal.onTrendChange
                          "off",                                           // string Signal.Sound
                          "off",                                           // string Signal.Mail.Receiver
                          "off",                                           // string Signal.SMS.Receiver

                          "",                                              // string _____________________
                          lpSuperContext,                                  // int    __SuperContext__

                          iBuffer, iBar);

   int error = GetLastError();
   if (IsError(error)) {
      if (error != ERS_HISTORY_UPDATE)
         return(_NULL(catch("icMovingAverage(1)", error)));
      warn("icMovingAverage(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Tick +")", ERS_HISTORY_UPDATE);
   }                                                                       // TODO: check number of loaded bars

   error = ec_MqlError(__ExecutionContext);                                // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(_NULL(SetLastError(error)));
}
