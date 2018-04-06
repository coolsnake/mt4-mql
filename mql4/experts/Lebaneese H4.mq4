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
      if (!isOpenPosition) CheckOpenSignal();
      else                 CheckCloseSignal();        // don't check for close on an open signal
   }
   return(last_error);
}


/**
 * Check for and handle entry conditions.
 */
void CheckOpenSignal() {
}


/**
 * Check for and handle exit conditions.
 */
void CheckCloseSignal() {
}


/**
 * Return a string representation of the input parameters for logging.
 *
 * @return string
 */
string InputsToStr() {
   return(EMPTY_STR);
}
