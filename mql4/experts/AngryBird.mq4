/**
 * AngryBird (aka Headless Chicken)
 *
 * A Martingale system with nearly random entry (trades like a headless chicken) and very low profit target. The entry
 * condition analyzes the last bar, further positions are added on BarOpen only. The distance between consecutive trades
 * adapts to the past trading range. Risk control via drawdown limit. The lower profit target and drawdown limit the better
 * (and less realistic) the observed results. As market volatility increases so does the probability of major losses.
 *
 * Rewritten and enhanced version of "AngryBird EA" (see https://www.mql5.com/en/code/12872) wich itself is a remake of
 * "Ilan 1.6 Dynamic" (see https://www.mql5.com/en/code/12220). The initial commit matches the original source.
 *
 *
 * Changes:
 * --------
 *  - Removed RSI entry filter as it has no statistical edge but only reduces opportunities.
 *  - Removed CCI stop as the drawdown limit is a better stop condition.
 *  - Added parameter "Lots.StartVola" for lotsize calculation based on account size and instrument volatility. Can also be
 *    used for compounding.
 *  - Added explicit grid limits (parameters "Grid.MaxLevels", "Grid.Min.Pips", "Grid.Max.Pips", "Grid.Contractable").
 *  - Added parameter "Trade.StartMode" to kick-start the chicken in a given direction (doesn't wait for BarOpen).
 *  - Added parameter "Trade.Reverse" to switch the strategy into Reverse-Martingale mode. All trade operations are reversed,
 *    TakeProfit will become StopLoss and StopLoss will become cumulative TakeProfit.
 *  - Added parameter "Trade.StopAtTarget" to stop the chicken after the profit target has been reached.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Trade.StartMode        = "Long | Short | Headless* | Legless | Auto";
extern bool   Trade.Reverse          = false;      // whether or not to enable Reverse-Martingale mode
extern bool   Trade.StopAtTarget     = true;       // whether or not to continue trading once the profit target is reached
extern string _____________________________1_;

extern double Lots.StartSize         = 0;          // fix lotsize or 0 = dynamic lotsize using Lots.StartVola
extern int    Lots.StartVola.Percent = 30;         // expected weekly equity volatility, see CalculateLotSize()
extern double Lots.Multiplier        = 2;
extern string _____________________________2_;

extern double TakeProfit.Pips        = 2;
extern int    StopLoss.Percent       = 20;
extern bool   StopLoss.ShowLevels    = false;      // display extrapolated StopLoss levels
extern string _____________________________3_;

extern int    Grid.MaxLevels         = 0;          // 0 = no limit (was "MaxTrades = 10")
extern double Grid.Min.Pips          = 30;         // was "DefaultPips/DEL = 0.4"
extern double Grid.Max.Pips          = 0;          // was "DefaultPips*DEL = 3.6"
extern int    Grid.Lookback.Periods  = 70;         // was "Glubina = 24"
extern int    Grid.Lookback.Divider  = 3;          // was "DEL = 3"
extern string _____________________________4_;

extern double Exit.Trail.Pips        = 0;          // trailing stop size in pip: 0=Off (was 1)
extern double Exit.Trail.Start.Pips  = 1;          // minimum profit in pip to start trailing

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/@ATR.mqh>
#include <functions/EventListener.BarOpen.mqh>
#include <functions/JoinStrings.mqh>
#include <structs/xtrade/OrderExecution.mqh>


// runtime status
#define STATUS_UNDEFINED      0
#define STATUS_PENDING        1
#define STATUS_STARTING       2
#define STATUS_PROGRESSING    3
#define STATUS_STOPPING       4
#define STATUS_STOPPED        5

string chicken.mode;
int    chicken.status;
string statusDescr[] = {"undefined", "pending", "starting", "progressing", "stopping", "stopped"};

// lotsize management
double lots.calculatedSize;                  // calculated lot size (not used if Lots.StartSize is set)
double lots.startSize;                       // actual starting lot size (can differ from input Lots.StartSize)
int    lots.startVola;                       // resulting starting vola (can differ from input Lots.StartVola)

// grid management
string grid.startDirection;
int    grid.level;                           // current grid level: >= 0
double grid.minSize;                         // enforced minimum grid size in pip (can change over time)
double grid.marketSize;                      // current market grid size in pip
double grid.usedSize;                        // grid size in pip used for calculating entry levels

// position tracking
int    position.tickets   [];                // currently open orders
double position.lots      [];                // order lot sizes
double position.openPrices[];                // order open prices

int    position.level;                       // current position level: positive or negative
double position.size;                        // current total position size
double position.avgPrice;                    // current average position price
double position.slPrice;                     // current total position StopLoss price (invisible to the broker)
double position.startEquity;                 // equity in account currency at the current sequence start

double position.plPip       = EMPTY_VALUE;   // current PL in pip
double position.plPipMin    = EMPTY_VALUE;   // min. PL in pip
double position.plPipMax    = EMPTY_VALUE;   // max. PL in pip
double position.plUPip      = EMPTY_VALUE;   // current PL in unit pip
double position.plUPipMin   = EMPTY_VALUE;   // min. PL in unit pip
double position.plUPipMax   = EMPTY_VALUE;   // max. PL in unit pip
double position.plPct       = EMPTY_VALUE;   // current PL in percent
double position.plPctMin    = EMPTY_VALUE;   // min. PL in percent
double position.plPctMax    = EMPTY_VALUE;   // max. PL in percent

double position.cumStartEquity;              // equity in account currency at start of trading
double position.cumPl;                       // total PL in account currency since start of trading
double position.cumPlPct    = EMPTY_VALUE;   // total PL in percent since start of trading
double position.cumPlPctMin = EMPTY_VALUE;   // total min. PL in percent since start of trading
double position.cumPlPctMax = EMPTY_VALUE;   // total max. PL in percent since start of trading

bool   exit.trailStop;
double exit.trailLimitPrice;                 // price limit to start trailing the current position's stops

// OrderSend() defaults
string os.name        = "AngryBird";
int    os.magicNumber = 2222;
double os.slippage    = 0.1;

// cache variables to speed-up execution of ShowStatus()
string str.lots.startSize       = "-";

string str.grid.minSize         = "-";
string str.grid.marketSize      = "-";

string str.position.slPrice     = "-";
string str.position.tpPip       = "-";
string str.position.plPip       = "-";
string str.position.plPipMin    = "-";
string str.position.plPipMax    = "-";
string str.position.plUPip      = "-";
string str.position.plUPipMin   = "-";
string str.position.plUPipMax   = "-";
string str.position.plPct       = "-";
string str.position.plPctMin    = "-";
string str.position.plPctMax    = "-";

string str.position.cumPlPct    = "-";
string str.position.cumPlPctMin = "-";
string str.position.cumPlPctMax = "-";

#include <AngryBird/functions.mqh>
#include <AngryBird/init.mqh>
#include <AngryBird/deinit.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   UpdateStatus();

   // check exit conditions on every tick
   if (grid.level > 0) {
      if (CheckOpenPositions())
         if (exit.trailStop) TrailProfits();                   // TODO: fails live because done on every tick
      if (__STATUS_OFF) return(last_error);
   }

   if (chicken.status == STATUS_PENDING)
      return(last_error);


   // stop adding more positions once Grid.MaxLevels has been reached
   if (Grid.MaxLevels && grid.level >= Grid.MaxLevels)
      return(last_error);


   // check entry conditions
   if (grid.startDirection == "auto") {
      if (EventListener.BarOpen(PERIOD_M1)) {
         bool openLong, openShort;

         if (!position.level) {
            if      (Close[1] > Close[2]) openLong  = true;
            else if (Close[1] < Close[2]) openShort = true;
         }
         else {
            double entryPrice = UpdateGridSize(); if (!entryPrice) return(last_error);
            if (Trade.Reverse) {
               if (position.level > 0) { if (Bid >= entryPrice) openLong  = true; }
               else                    { if (Ask <= entryPrice) openShort = true; }
            }
            else {
               if (position.level > 0) { if (Ask <= entryPrice) openLong  = true; }
               else                    { if (Bid >= entryPrice) openShort = true; }
            }
         }
         if      (openLong)  OpenPosition(OP_BUY);
         else if (openShort) OpenPosition(OP_SELL);
      }
   }
   else {
      if (!grid.level) OpenPosition(ifInt(grid.startDirection=="long", OP_BUY, OP_SELL));
      grid.startDirection = "auto";
   }
   return(last_error);
}


/**
 * Calculate the current grid size and return the price at which to open the next position.
 *
 * @return double - price or NULL if the sequence was not yet started or if an error occurred
 */
double UpdateGridSize() {
   if (__STATUS_OFF) return(NULL);

   static int    lastTick;                                     // set to -1 to ensure the function is executed in init()
   static double lastResult;
   if (Tick == lastTick)                                       // prevent multiple calculations per tick
      return(lastResult);

   double high = iHigh(NULL, PERIOD_M1, iHighest(NULL, PERIOD_M1, MODE_HIGH, Grid.Lookback.Periods, 1));
   double low  =  iLow(NULL, PERIOD_M1,  iLowest(NULL, PERIOD_M1, MODE_LOW,  Grid.Lookback.Periods, 1));

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("UpdateGridSize(1)", error));
      warn("UpdateGridSize(2)  ERS_HISTORY_UPDATE, reported "+ Grid.Lookback.Periods +"xM1 range: "+ DoubleToStr((high-low)/Pip, 1) +" pip", error);
   }

   double barRange  = (high-low) / Pip;
   double gridSize  = barRange / Grid.Lookback.Divider;
   SetGridMarketSize(NormalizeDouble(gridSize, 1));

   double usedSize = MathMax(grid.marketSize, grid.minSize);
   usedSize = MathMax(usedSize, Grid.Min.Pips);                // enforce lower user defined limit

   if (Grid.Max.Pips > 0)
      usedSize = MathMin(usedSize, Grid.Max.Pips);             // enforce upper user defined limit
   grid.usedSize = NormalizeDouble(usedSize, 1);

   double result = 0;

   if (grid.level > 0) {
      double lastPrice = position.openPrices[grid.level-1];
      double nextPrice = lastPrice - ifInt(Trade.Reverse, -1, 1) * Sign(position.level) * grid.usedSize * Pips;
      result = NormalizeDouble(nextPrice, Digits);
   }
   lastTick   = Tick;
   lastResult = result;

   return(result);
}


/**
 * Calculate the lot size to use for the specified sequence level.
 *
 * @param  int level
 *
 * @return double - lotsize or NULL in case of an error
 */
double CalculateLotsize(int level) {
   if (__STATUS_OFF) return(NULL);
   if (level < 1)    return(!catch("CalculateLotsize(1)  invalid parameter level = "+ level +" (not positive)", ERR_INVALID_PARAMETER));

   // decide whether to use manual or calculated mode
   bool   manualMode = Lots.StartSize > 0;
   double usedSize;


   // (1) manual mode
   if (manualMode) {
      if (!lots.startSize)
         SetLotsStartSize(Lots.StartSize);
      lots.calculatedSize = 0;
      usedSize = lots.startSize;
   }


   // (2) calculated mode
   else {
      if (!lots.calculatedSize) {
         // calculate using Lots.StartVola
         // unleveraged lotsize
         double tickSize        = MarketInfo(Symbol(), MODE_TICKSIZE);  if (!tickSize)  return(!catch("CalculateLotsize(2)  invalid MarketInfo(MODE_TICKSIZE) = 0", ERR_RUNTIME_ERROR));
         double tickValue       = MarketInfo(Symbol(), MODE_TICKVALUE); if (!tickValue) return(!catch("CalculateLotsize(3)  invalid MarketInfo(MODE_TICKVALUE) = 0", ERR_RUNTIME_ERROR));
         double lotValue        = Bid/tickSize * tickValue;                      // value of a full lot in account currency
         double unleveragedLots = AccountBalance() / lotValue;                   // unleveraged lotsize (leverage 1:1)
         if (unleveragedLots < 0) unleveragedLots = 0;

         // expected weekly range: maximum of ATR(100xW1), previous TrueRange(W1) and current TrueRange(W1)
         double a = @ATR(NULL, PERIOD_W1, 100, 1); if (!a) return(_NULL(debug("CalculateLotsize(4)  W1", last_error)));
         double b = @ATR(NULL, PERIOD_W1,   1, 1); if (!b) return(_NULL(debug("CalculateLotsize(5)  W1", last_error)));
         double c = @ATR(NULL, PERIOD_W1,   1, 0); if (!c) return(_NULL(debug("CalculateLotsize(6)  W1", last_error)));
         double expectedRange    = MathMax(a, MathMax(b, c));
         double expectedRangePct = expectedRange/Close[0] * 100;

         // leveraged lotsize = Lots.StartSize
         double leverage     = Lots.StartVola.Percent / expectedRangePct;        // leverage weekly range vola to user-defined vola
         lots.calculatedSize = leverage * unleveragedLots;
         double startSize    = SetLotsStartSize(NormalizeLots(lots.calculatedSize));
         lots.startVola      = Round(startSize / unleveragedLots * expectedRangePct);
      }
      if (!lots.startSize)
         SetLotsStartSize(NormalizeLots(lots.calculatedSize));
      usedSize = lots.calculatedSize;
   }


   // (3) calculate the requested level's lotsize
   double calculated = usedSize * MathPow(Lots.Multiplier, level-1);
   double result     = NormalizeLots(calculated);
   if (!result) return(!catch("CalculateLotsize(7)  The resulting lot size for level "+ level +" is too small for this account (calculated="+ NumberToStr(calculated, ".+") +", MODE_MINLOT="+ NumberToStr(MarketInfo(Symbol(), MODE_MINLOT), ".+") +", normalized=0)", ERR_INVALID_TRADE_VOLUME));

   double ratio = result / calculated;
   if (ratio > 1.15) {                                                           // ask for confirmation if the resulting lotsize > 15% from the calculation
      static bool lotsConfirmed = false;
      if (!position.cumPl && !lotsConfirmed) {                                   // ask only before the very first trade
         PlaySoundEx("Windows Notify.wav");
         string msg = "The lot size for level "+ level +" substantially deviates from the calculation: "+ NumberToStr(result, ".+") +" instead of "+ NumberToStr(calculated, ".+");
         int button = MessageBoxEx(__NAME__ +" - CalculateLotsize()", ifString(IsDemoFix(), "", "- Real Account -\n\n") + msg, MB_ICONQUESTION|MB_OKCANCEL);
         if (button != IDOK) return(!SetLastError(ERR_CANCELLED_BY_USER));
      }
      lotsConfirmed = true;
   }
   return(result);
}


/**
 * Open a position at the next sequence level.
 *
 * @param  int type - order operation type: OP_BUY | OP_SELL
 *
 * @return bool - success status
 */
bool OpenPosition(int type) {
   if (__STATUS_OFF) return(false);

   if (InitReason()!=IR_USER) /*&&*/ if (!ConfirmFirstTickTrade("OpenPosition()", "Do you really want to submit a Market "+ OrderTypeDescription(type) +" order now?"))
      return(!SetLastError(ERR_CANCELLED_BY_USER));

   // reset the start lotsize of a new sequence to trigger re-calculation and thus provide compounding if configured
   if (!grid.level) {
      position.startEquity = NormalizeDouble(AccountEquity() - AccountCredit(), 2);
      if (!position.cumStartEquity)
         position.cumStartEquity = position.startEquity;
      SetLotsStartSize(NULL);
   }

   string   symbol      = Symbol();
   double   price       = NULL;
   double   lots        = CalculateLotsize(grid.level+1); if (!lots) return(false);
   double   stopLoss    = NULL;
   double   takeProfit  = NULL;
   string   comment     = os.name +"-"+ (grid.level+1) +"-"+ DoubleToStr(grid.usedSize, 1);
   datetime expires     = NULL;
   color    markerColor = ifInt(type==OP_BUY, Blue, Red);
   int      oeFlags     = NULL;
   int      oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);

   int ticket = OrderSendEx(symbol, type, lots, price, os.slippage, stopLoss, takeProfit, comment, os.magicNumber, expires, markerColor, oeFlags, oe);
   if (!ticket) return(false);

   // update levels and ticket data
   grid.level++;
   SetGridMinSize(MathMax(grid.minSize, grid.usedSize));

   if (type == OP_BUY) position.level++;
   else                position.level--;

   ArrayPushInt   (position.tickets,    ticket);
   ArrayPushDouble(position.lots,       oe.Lots(oe));
   ArrayPushDouble(position.openPrices, oe.OpenPrice(oe));

   UpdateExitConditions();
   UpdateStatus();
   return(!catch("OpenPosition(1)"));
}


/**
 * Check exit limits of open positions.
 *
 * @return bool - whether or not open positions exist (and have not yet been closed)
 */
bool CheckOpenPositions() {
   if (__STATUS_OFF || !position.level)
      return(false);

   double profit;
   bool resetCumulated;

   // check open positions
   for (int i=0; i < grid.level; i++) {
      OrderSelect(position.tickets[i], SELECT_BY_TICKET);
      if (!OrderCloseTime())                                      // position is open
         break;
      profit += OrderProfit() + OrderSwap() + OrderCommission();  // position is closed
   }

   // check TakeProfit
   if (i >= grid.level) {                                         // all positions are closed
      position.cumPl = NormalizeDouble(position.cumPl + profit, 2);
      SetPositionCumPlPct(position.cumPl / position.cumStartEquity * 100);
      log("CheckOpenPositions(1)  TP hit:  level="+ position.level +"  pct="+ DoubleToStr(position.cumPlPct, 2) +"%  min="+ DoubleToStr(position.cumPlPctMin, 2) +"%");

      if (!Trade.StopAtTarget) {                                  // continue trading?
         InitSequenceStatus(chicken.mode, "auto", STATUS_STARTING);
         return(false);
      }
   }

   // check StopLoss
   else {                                                         // prevent the limit from being triggered by spread widening
      if (position.level > 0) { if (Ask > position.slPrice) return(true); }
      else                    { if (Bid < position.slPrice) return(true); }

      profit         = ClosePositions();
      position.cumPl = NormalizeDouble(position.cumPl + profit, 2);
      SetPositionCumPlPct(position.cumPl / position.cumStartEquity * 100);
      log("CheckOpenPositions(2)  SL("+ StopLoss.Percent +"%) hit:  level="+ position.level);

      InitSequenceStatus(chicken.mode, "auto", STATUS_STARTING);
      return(false);
   }

   // Trade.StopAtTarget is On and the profit target is reached
   __STATUS_OFF        = true;
   __STATUS_OFF.reason = ERR_CANCELLED_BY_USER;
   return(false);
}


/**
 * Close all open positions.
 *
 * @return double - realized profit inclusive swaps and commissions or NULL in case of errors
 */
double ClosePositions() {
   if (__STATUS_OFF || !grid.level)
      return(NULL);

   if (!ConfirmFirstTickTrade("ClosePositions()", "Do you really want to close all open positions now?"))
      return(!SetLastError(ERR_CANCELLED_BY_USER));

   int oes[][ORDER_EXECUTION.intSize];
   int oeFlags = ifInt(IsTesting(), OE_MULTICLOSE_NOHEDGE, NULL);

   if (!OrderMultiClose(position.tickets, os.slippage, Orange, oeFlags, oes))
      return(NULL);

   int size = ArraySize(position.tickets);
   double profit;

   for (int i=0; i < size; i++) {
      profit += oes.Profit(oes, i) + oes.Swap(oes, i) + oes.Commission(oes, i);
   }
   return(NormalizeDouble(profit, 2));
}


/**
 * Update total position size and price.
 *
 * @return double - average position price
 */
double UpdateTotalPosition() {
   if (__STATUS_OFF) return(NULL);

   int    levels = ArraySize(position.lots);
   double sumPrice, sumLots;

   for (int i=0; i < levels; i++) {
      sumPrice += position.lots[i] * position.openPrices[i];
      sumLots  += position.lots[i];
   }

   if (!levels) {
      position.size     = 0;
      position.avgPrice = 0;
   }
   else {
      position.size     = NormalizeDouble(sumLots, 2);
      position.avgPrice = sumPrice / sumLots;
   }
   return(position.avgPrice);
}


/**
 * Update TakeProfit, StopLoss and TrailLimit of open positions. TakeProfit is sent to the broker, StopLoss and TrailLimit
 * are kept and managed internally (invisible).
 *
 * @return bool - success status
 */
bool UpdateExitConditions() {
   if (__STATUS_OFF || !grid.level)
      return(false);

   double fees, profitPips, drawdownPips, avgPrice = UpdateTotalPosition();
   int direction = Sign(position.level);

   // TakeProfit
   for (int i=0; i < grid.level; i++) {
      OrderSelect(position.tickets[i], SELECT_BY_TICKET);
      fees += OrderSwap() + OrderCommission();                    // always consider fees for TakeProfit calculation
   }
   if (Trade.Reverse) profitPips = (position.cumStartEquity * StopLoss.Percent/100 - position.cumPl - fees) / PipValue(position.size);
   else               profitPips = TakeProfit.Pips - fees/PipValue(position.size);
   double tpPrice = avgPrice + direction * profitPips*Pips;
   if (direction == 1) tpPrice = RoundCeil (tpPrice, Digits);
   else                tpPrice = RoundFloor(tpPrice, Digits);
   for (i=0; i < grid.level; i++) {
      OrderSelect(position.tickets[i], SELECT_BY_TICKET);
      if (NE(tpPrice, OrderTakeProfit())) OrderModify(OrderTicket(), NULL, OrderStopLoss(), tpPrice, NULL, Blue);
   }

   // StopLoss
   if (Trade.Reverse) drawdownPips = TakeProfit.Pips;             // never consider fees for StopLoss calculation
   else               drawdownPips = (position.startEquity * StopLoss.Percent/100) / PipValue(position.size);
   double slPrice = avgPrice - direction * drawdownPips*Pips;
   if (direction == 1) slPrice = RoundFloor(slPrice, Digits);
   else                slPrice = RoundCeil (slPrice, Digits);
   SetPositionSlPrice(slPrice);

   // TrailLimit
   if (exit.trailStop) {
      exit.trailLimitPrice = avgPrice + direction * Exit.Trail.Start.Pips*Pips;
      if (direction == 1) exit.trailLimitPrice = RoundCeil (exit.trailLimitPrice, Digits);
      else                exit.trailLimitPrice = RoundFloor(exit.trailLimitPrice, Digits);
   }

   return(!catch("UpdateExitConditions(1)"));
}


/**
 * Trail stops of a profitable trade sequence. Will fail in real life because it trails each order on every tick.
 *
 * @return bool - function success status; not if orders indeed have been trailed on the current tick
 */
void TrailProfits() {
   if (__STATUS_OFF || !grid.level)
      return(true);

   if (position.level > 0) {
      if (Bid < exit.trailLimitPrice) return(true);
      double stop = Bid - Exit.Trail.Pips*Pips;
   }
   else /*position.level < 0*/ {
      if (Ask > exit.trailLimitPrice) return(true);
      stop = Ask + Exit.Trail.Pips*Pips;
   }
   stop = NormalizeDouble(stop, Digits);


   for (int i=0; i < grid.level; i++) {
      OrderSelect(position.tickets[i], SELECT_BY_TICKET);

      if (position.level > 0) {
         if (stop > OrderStopLoss()) {
            if (!ConfirmFirstTickTrade("TrailProfits(1)", "Do you really want to trail TakeProfit now?"))
               return(!SetLastError(ERR_CANCELLED_BY_USER));
            OrderModify(OrderTicket(), NULL, stop, OrderTakeProfit(), NULL, Red);
         }
      }
      else /*position.level < 0*/ {
         if (!OrderStopLoss() || stop < OrderStopLoss()) {
            if (!ConfirmFirstTickTrade("TrailProfits(2)", "Do you really want to trail TakeProfit now?"))
               return(!SetLastError(ERR_CANCELLED_BY_USER));
            OrderModify(OrderTicket(), NULL, stop, OrderTakeProfit(), NULL, Red);
         }
      }
   }
   return(!catch("TrailProfits(3)"));
}


/**
 * Reset and initialize all non-constant runtime variables for the next sequence.
 *
 * @param  string startMode                     - "long"|"short"|"headless"|"legless"
 * @param  string direction                     - "long"|"short"|"auto"
 * @param  int    status                        - sequence status
 * @param  bool   resetCumulatedData [optional] - whether or not to reset cumulated data (default: no)
 *
 * @return bool - success status
 */
bool InitSequenceStatus(string startMode, string direction, int status, bool resetCumulatedData = false) {
   string modes[] = {"long", "short", "headless", "legless"};
   if (!StringInArray(modes, startMode))      return(!catch("InitSequenceStatus(1)  Invalid parameter startMode: "+ DoubleQuoteStr(startMode), ERR_INVALID_PARAMETER));
   string directions[] = {"long", "short", "auto"};
   if (!StringInArray(directions, direction)) return(!catch("InitSequenceStatus(2)  Invalid parameter direction: "+ DoubleQuoteStr(direction), ERR_INVALID_PARAMETER));
   int statusSize = ArraySize(statusDescr);
   if (status < 0 || status > statusSize-1)   return(!catch("InitSequenceStatus(3)  Invalid parameter status: "+ status, ERR_INVALID_PARAMETER));

   chicken.mode   = startMode;
   chicken.status = status;

   ArrayResize(position.tickets,    0);
   ArrayResize(position.lots,       0);
   ArrayResize(position.openPrices, 0);

   position.level       = 0;
   position.size        = 0;
   position.avgPrice    = 0;
   position.startEquity = 0;
   SetPositionSlPrice    (0);
   SetPositionTpPip    (TakeProfit.Pips);
   SetPositionPlPip    (EMPTY_VALUE);
   SetPositionPlPipMin (EMPTY_VALUE);
   SetPositionPlPipMax (EMPTY_VALUE);
   SetPositionPlUPip   (EMPTY_VALUE);
   SetPositionPlUPipMin(EMPTY_VALUE);
   SetPositionPlUPipMax(EMPTY_VALUE);
   SetPositionPlPct    (EMPTY_VALUE);
   SetPositionPlPctMin (EMPTY_VALUE);
   SetPositionPlPctMax (EMPTY_VALUE);

   if (resetCumulatedData) {
      position.cumStartEquity = 0;
      position.cumPl          = 0;
      SetPositionCumPlPct(EMPTY_VALUE);
   }

   exit.trailStop       = Exit.Trail.Pips > 0;
   exit.trailLimitPrice = 0;

   // wait with grid functions until position arrays have been resized to zero
   grid.startDirection = direction;
   grid.level          = 0;
   SetGridMinSize(Grid.Min.Pips);
   SetGridMarketSize    (0);
   grid.usedSize       = 0;
   UpdateGridSize();

   SetLotsStartSize     (0);
   lots.calculatedSize = 0;
   lots.startVola      = 0;
   CalculateLotsize(1);

   return(!catch("InitSequenceStatus(4)"));
}


/**
 * Additional safety net against execution errors. Ask for confirmation that a trade command is to be executed at the very
 * first tick (e.g. at terminal start). Will only ask once even if called multiple times during a single tick (in a loop).
 *
 * @param  string location - confirmation location for logging
 * @param  string message  - confirmation message
 *
 * @return bool - confirmation result
 */
bool ConfirmFirstTickTrade(string location, string message) {
   if (__STATUS_OFF) return(false);

   static bool done=false, confirmed=false;
   if (!done) {
      if (Tick > 1 || IsTesting()) {
         confirmed = true;
      }
      else {
         PlaySoundEx("Windows Notify.wav");
         int button = MessageBoxEx(__NAME__ + ifString(!StringLen(location), "", " - "+ location), ifString(IsDemoFix(), "", "- Real Account -\n\n") + message, MB_ICONQUESTION|MB_OKCANCEL);
         if (button == IDOK) confirmed = true;
      }
      done = true;
   }
   return(confirmed);
}


/**
 * Update the current runtime status (values that change on every tick).
 *
 * @return bool - success status
 */
bool UpdateStatus() {
   if (__STATUS_OFF) return(false);

   if (!IsTesting() || IsVisualMode())
      UpdateGridSize();                            // only for ShowStatus() on every tick/call

   if (position.level != 0) {
      // position.plPip
      double plPip;
      if (position.level > 0) plPip = SetPositionPlPip((Bid - position.avgPrice) / Pip);
      else                    plPip = SetPositionPlPip((position.avgPrice - Ask) / Pip);

      // position.plUPip
      double units  = position.size / lots.startSize;
      SetPositionPlUPip(units * plPip);

      // position.plPct
      double profit = plPip * PipValue(position.size);
      SetPositionPlPct(profit / position.startEquity * 100);

      // position.cumPlPct
      SetPositionCumPlPct((position.cumPl + profit) / position.cumStartEquity * 100);
   }
   return(true);
}


/**
 * Show the current runtime status on screen.
 *
 * @param  int error [optional] - user-defined error to display (default: none)
 *
 * @return int - the same error
 */
int ShowStatus(int error=NO_ERROR) {
   if (!__CHART)
      return(error);

   static bool statusBox; if (!statusBox)
      statusBox = ShowStatusBox();

   string str.status;

   if (__STATUS_OFF) {
      str.status = StringConcatenate(" switched OFF  [", ErrorDescription(__STATUS_OFF.reason), "]");
   }
   else {
      if (chicken.status == STATUS_PENDING) str.status = " waiting legless";
      if (!lots.startSize)                  CalculateLotsize(1);
   }

   string msg = StringConcatenate(" ", __NAME__, str.status,                                                                                                                   NL,
                                  " --------------",                                                                                                                           NL,
                                  " Grid level:    ",  grid.level,      "            MarketSize:   ", str.grid.marketSize,    "        MinSize:   ", str.grid.minSize,         NL,
                                  " StartLots:     ",  str.lots.startSize, "         Vola:   ",       lots.startVola, " %",                                                    NL,
                                  " TP:             ", str.position.tpPip,    "      Stop:   ",       StopLoss.Percent,    " %         SL:   ",      str.position.slPrice,     NL,
                                  " PL:             ", str.position.plPip,    "      max:    ",       str.position.plPipMax,   "       min:    ",    str.position.plPipMin,    NL,
                                  " PL upip:      ",   str.position.plUPip,    "     max:    ",       str.position.plUPipMax,    "     min:    ",    str.position.plUPipMin,   NL,
                                  " PL %:         ",   str.position.plPct,     "     max:    ",       str.position.plPctMax,    "      min:    ",    str.position.plPctMin,    NL,
                                  " PL % cum:  ",      str.position.cumPlPct,  "     max:    ",       str.position.cumPlPctMax, "      min:    ",    str.position.cumPlPctMin, NL);
   // 4 lines margin-top
   Comment(StringConcatenate(NL, NL, NL, NL, msg));

   if (StopLoss.ShowLevels)
      ShowStopLossLevel();

   if (__WHEREAMI__ == RF_INIT)
      WindowRedraw();
   return(error);
}


/**
 * Create and show a background box for the status display.
 *
 * @return bool - success status
 */
bool ShowStatusBox() {
   if (!__CHART)
      return(false);

   int x[]={2, 120, 141}, y[]={59}, fontSize=90, cols=ArraySize(x), rows=ArraySize(y);
   color  bgColor = C'248,248,248';                                  // chart background color - LightSalmon
   string label;

   for (int i, row=0; row < rows; row++) {
      for (int col=0; col < cols; col++, i++) {
         label = StringConcatenate(__NAME__, ".status."+ (i+1));
         if (ObjectFind(label) != 0)
            ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
         ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
         ObjectSet    (label, OBJPROP_XDISTANCE, x[col]);
         ObjectSet    (label, OBJPROP_YDISTANCE, y[row]);
         ObjectSetText(label, "g", fontSize, "Webdings", bgColor);   // "g" is a rectangle
         ObjectRegister(label);
      }
   }

   return(!catch("ShowStatusBox(1)"));
}


/**
 * Calculate and draw extrapolated stop levels. If the sequence is in STATUS_PENDING levels for both directions are
 * calculated and drawn. The calculated levels are guaranteed to be minimal values. They may widen with an expanding grid
 * size but will never narrow down.
 *
 * @return bool - success status
 */
bool ShowStopLossLevel() {
   if (!grid.usedSize) UpdateGridSize();
   if (!grid.usedSize) return(false);

   double gridSize    = grid.usedSize;                               // TODO: already open level will differ from grid.usedSize
   double startEquity = AccountEquity() - AccountCredit();           // TODO: resolve startEquity globally and in a better way
   static int level; if (level > 0) return(true);                    // TODO: remove static and monitor level changes

   double drawdown = startEquity * StopLoss.Percent/100, nextLots, fullLots, pipValue, fullDist;
   double curDist  = -gridSize;
   double nextDist = INT_MAX;

   // calculate stop levels
   while (nextDist > gridSize) {
      level++;
      curDist  += gridSize;
      drawdown -= (gridSize * pipValue);
      nextLots  = CalculateLotsize(level); if (!nextLots) return(false);
      fullLots += nextLots;
      pipValue  = PipValue(fullLots);
      nextDist  = drawdown / pipValue;
      fullDist  = curDist + nextDist;
      debug("ShowStopLossLevel(1)  level "+ StringPadRight(level, 2) +"  lots="+ DoubleToStr(fullLots, 2) +"  grid="+ StringPadRight(DoubleToStr(gridSize, 1), 4) +"  cd="+ StringPadRight(DoubleToStr(curDist, 1), 4) +"  nd="+ StringPadRight(DoubleToStr(nextDist, 1), 6) +"  fd="+ DoubleToStr(fullDist, 1));
   }
   double stopLong  = Ask - fullDist*Pips;
   double stopShort = Bid + fullDist*Pips;


   // draw stop levels
   string label = __NAME__ +".runtime.position.stop.long";
   if (ObjectFind(label) == -1) {
      ObjectCreate(label, OBJ_HLINE, 0, 0, 0);
      ObjectSet   (label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet   (label, OBJPROP_COLOR, OrangeRed  );
      ObjectSet   (label, OBJPROP_BACK,  true       );
      ObjectRegister(label);
   }
   ObjectSet    (label, OBJPROP_PRICE1, stopLong);
   ObjectSetText(label, StopLoss.Percent +"% DD (-"+ DoubleToStr(fullDist, 1) +" pip)  level "+ level);

   label = __NAME__ +".runtime.position.stop.short";
   if (ObjectFind(label) == -1) {
      ObjectCreate(label, OBJ_HLINE, 0, 0, 0);
      ObjectSet   (label, OBJPROP_STYLE, STYLE_DOT);
      ObjectSet   (label, OBJPROP_COLOR, OrangeRed  );
      ObjectSet   (label, OBJPROP_BACK,  true       );
      ObjectRegister(label);
   }
   ObjectSet    (label, OBJPROP_PRICE1, stopShort);
   ObjectSetText(label, StopLoss.Percent +"% DD (+"+ DoubleToStr(fullDist, 1) +" pip)  level "+ level);

   return(!catch("ShowStopLossLevel(2)"));
}


/**
 * Return a string representation of the (modified) input parameters for logging.
 *
 * @return string
 */
string InputsToStr() {
   static string ss.Trade.StartMode;        string s.Trade.StartMode        = "Trade.StartMode="       + DoubleQuoteStr(Trade.StartMode)           +"; ";
   static string ss.Trade.Reverse;          string s.Trade.Reverse          = "Trade.Reverse="         + BoolToStr(Trade.Reverse)                  +"; ";
   static string ss.Trade.StopAtTarget;     string s.Trade.StopAtTarget     = "Trade.StopAtTarget="    + BoolToStr(Trade.StopAtTarget)             +"; ";

   static string ss.Lots.StartSize;         string s.Lots.StartSize         = "Lots.StartSize="        + NumberToStr(Lots.StartSize, ".1+")        +"; ";
   static string ss.Lots.StartVola.Percent; string s.Lots.StartVola.Percent = "Lots.StartVola.Percent="+ Lots.StartVola.Percent                    +"; ";
   static string ss.Lots.Multiplier;        string s.Lots.Multiplier        = "Lots.Multiplier="       + NumberToStr(Lots.Multiplier, ".1+")       +"; ";

   static string ss.TakeProfit.Pips;        string s.TakeProfit.Pips        = "TakeProfit.Pips="       + NumberToStr(TakeProfit.Pips, ".1+")       +"; ";
   static string ss.StopLoss.Percent;       string s.StopLoss.Percent       = "StopLoss.Percent="      + StopLoss.Percent                          +"; ";
   static string ss.StopLoss.ShowLevels;    string s.StopLoss.ShowLevels    = "StopLoss.ShowLevels="   + BoolToStr(StopLoss.ShowLevels)            +"; ";

   static string ss.Grid.MaxLevels;         string s.Grid.MaxLevels         = "Grid.MaxLevels="        + Grid.MaxLevels                            +"; ";
   static string ss.Grid.Min.Pips;          string s.Grid.Min.Pips          = "Grid.Min.Pips="         + NumberToStr(Grid.Min.Pips, ".1+")         +"; ";
   static string ss.Grid.Max.Pips;          string s.Grid.Max.Pips          = "Grid.Max.Pips="         + NumberToStr(Grid.Max.Pips, ".1+")         +"; ";
   static string ss.Grid.Lookback.Periods;  string s.Grid.Lookback.Periods  = "Grid.Lookback.Periods=" + Grid.Lookback.Periods                     +"; ";
   static string ss.Grid.Lookback.Divider;  string s.Grid.Lookback.Divider  = "Grid.Lookback.Divider=" + Grid.Lookback.Divider                     +"; ";

   static string ss.Exit.Trail.Pips;        string s.Exit.Trail.Pips        = "Exit.Trail.Pips="       + NumberToStr(Exit.Trail.Pips, ".1+")       +"; ";
   static string ss.Exit.Trail.Start.Pips;  string s.Exit.Trail.Start.Pips  = "Exit.Trail.Start.Pips=" + NumberToStr(Exit.Trail.Start.Pips, ".1+") +"; ";

   string result;

   if (input.all == "") {
      // all input
      result = StringConcatenate("input: ",

                                 s.Trade.StartMode,
                                 s.Trade.Reverse,
                                 s.Trade.StopAtTarget,

                                 s.Lots.StartSize,
                                 s.Lots.StartVola.Percent,
                                 s.Lots.Multiplier,

                                 s.TakeProfit.Pips,
                                 s.StopLoss.Percent,
                                 s.StopLoss.ShowLevels,

                                 s.Grid.MaxLevels,
                                 s.Grid.Min.Pips,
                                 s.Grid.Max.Pips,
                                 s.Grid.Lookback.Periods,
                                 s.Grid.Lookback.Divider,

                                 s.Exit.Trail.Pips,
                                 s.Exit.Trail.Start.Pips);
   }
   else {
      // modified input
      result = StringConcatenate("modified input: ",

                                 ifString(s.Trade.StartMode        == ss.Trade.StartMode,        "", s.Trade.StartMode       ),
                                 ifString(s.Trade.Reverse          == ss.Trade.Reverse,          "", s.Trade.Reverse         ),
                                 ifString(s.Trade.StopAtTarget     == ss.Trade.StopAtTarget,     "", s.Trade.StopAtTarget    ),

                                 ifString(s.Lots.StartSize         == ss.Lots.StartSize,         "", s.Lots.StartSize        ),
                                 ifString(s.Lots.StartVola.Percent == ss.Lots.StartVola.Percent, "", s.Lots.StartVola.Percent),
                                 ifString(s.Lots.Multiplier        == ss.Lots.Multiplier,        "", s.Lots.Multiplier       ),

                                 ifString(s.TakeProfit.Pips        == ss.TakeProfit.Pips,        "", s.TakeProfit.Pips       ),
                                 ifString(s.StopLoss.Percent       == ss.StopLoss.Percent,       "", s.StopLoss.Percent      ),
                                 ifString(s.StopLoss.ShowLevels    == ss.StopLoss.ShowLevels,    "", s.StopLoss.ShowLevels   ),

                                 ifString(s.Grid.MaxLevels         == ss.Grid.MaxLevels,         "", s.Grid.MaxLevels        ),
                                 ifString(s.Grid.Min.Pips          == ss.Grid.Min.Pips,          "", s.Grid.Min.Pips         ),
                                 ifString(s.Grid.Max.Pips          == ss.Grid.Max.Pips,          "", s.Grid.Max.Pips         ),
                                 ifString(s.Grid.Lookback.Periods  == ss.Grid.Lookback.Periods,  "", s.Grid.Lookback.Periods ),
                                 ifString(s.Grid.Lookback.Divider  == ss.Grid.Lookback.Divider,  "", s.Grid.Lookback.Divider ),

                                 ifString(s.Exit.Trail.Pips        == ss.Exit.Trail.Pips,        "", s.Exit.Trail.Pips       ),
                                 ifString(s.Exit.Trail.Start.Pips  == ss.Exit.Trail.Start.Pips,  "", s.Exit.Trail.Start.Pips ));
   }

   ss.Trade.StartMode        = s.Trade.StartMode;
   ss.Trade.Reverse          = s.Trade.Reverse;
   ss.Trade.StopAtTarget     = s.Trade.StopAtTarget;

   ss.Lots.StartSize         = s.Lots.StartSize;
   ss.Lots.StartVola.Percent = s.Lots.StartVola.Percent;
   ss.Lots.Multiplier        = s.Lots.Multiplier;

   ss.TakeProfit.Pips        = s.TakeProfit.Pips;
   ss.StopLoss.Percent       = s.StopLoss.Percent;
   ss.StopLoss.ShowLevels    = s.StopLoss.ShowLevels;

   ss.Grid.MaxLevels         = s.Grid.MaxLevels;
   ss.Grid.Min.Pips          = s.Grid.Min.Pips;
   ss.Grid.Max.Pips          = s.Grid.Max.Pips;
   ss.Grid.Lookback.Periods  = s.Grid.Lookback.Periods;
   ss.Grid.Lookback.Divider  = s.Grid.Lookback.Divider;

   ss.Exit.Trail.Pips        = s.Exit.Trail.Pips;
   ss.Exit.Trail.Start.Pips  = s.Exit.Trail.Start.Pips;

   return(result);
}
