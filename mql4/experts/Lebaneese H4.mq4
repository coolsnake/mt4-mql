/**
 * Lebaneese H4 Trend System
 *
 * @see  https://www.forexfactory.com/showthread.php?p=9307192#post9307192
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int TakeProfit.Pips = 150;
extern int StopLoss.Pips   =  50;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/EventListener.BarOpen.mqh>
#include <iCustom/icNonLagMA.mqh>


// position management
bool isOpenPosition;

// OrderSend() defaults
string os.name        = "LH4";
int    os.magicNumber = 43210;


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (EventListener.BarOpen(PERIOD_H4)) {
      if (!isOpenPosition) {
         CheckOpenSignal();
      }
   }
   return(last_error);
}


/**
 * Check for and handle entry conditions.
 */
void CheckOpenSignal() {
   int trend = GetNonLagMATrend(1);

   // wait for trend change of last bar
   if (Abs(trend) == 1) {
      debug("CheckOpenSignal(1)  "+ TimeToStr(TimeCurrent(), TIME_FULL) +"  NonLagMA turned "+ ifString(trend==1, "up", "down"));
   }
}


/**
 * Return the trend of the NonLagMA indicator at the specified bar.
 *
 * @param  int bar - bar index
 *
 * @return int - trend value or NULL in case of errors
 */
int GetNonLagMATrend(int bar) {
   return(icNonLagMA(PERIOD_H4, 20, "4", 50, MovingAverage.MODE_TREND, bar));
}


/**
 * Return a string representation of the input parameters for logging.
 *
 * @return string
 */
string InputsToStr() {
   return(EMPTY_STR);
}
