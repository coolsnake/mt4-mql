/**
 * Yen Trader
 *
 * @see  https://www.forexfactory.com/showthread.php?t=595898
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Magic_Number         = 160704;                               // Magic Number
extern string Signal.Timeframe     = "M1 | M5 | M15 | M30 | H1 | H4 | D1";
extern string pair_setup           = "--------------------";               // Pair Setup
extern string Major_Code           = "GBPUSD";                             // Major Pair Code
extern string UJ_Code              = "USDJPY";                             // DollarYen Pair Code
extern string JPY_Cross            = "GBPJPY";                             // Yen Cross Pair Code
extern string major_pos            = "L";                                  // Major Direction Left/Right
extern string trade_setup          = "--------------------";               // Trade Setup
extern double Fixed_Lot_Size       = 0;                                    // Fixed Lots (set to 0 enable variable lots)
extern double Bal_Perc_Lot_Size    = 1;                                    // Variable Lots as % of Balance
extern int    SL_Pips              = 1000;                                 // Stop Loss (Pips or Points)
extern int    TP_Pips              = 5000;                                 // Take Profit (Pips or Points)
extern int    BE_Pips              = 200;                                  // Break Even , 0 to disable (Pips or Points)
extern int    PL_Pips              = 200;                                  // Profit Lock , 0 to disable (Pips or Points)
extern int    Trail_Stop_Pips      = 200;                                  // Trailing Stop, 0 to disable (Pips or Points)
extern int    Trail_Stop_Jump_Pips = 10;                                   // Trail Stop Shift (Pips or Points)
extern string Averaging.Type       = "Pyramid | Average | Both*";          // averaging type for splitting positions
extern string Indicators           = "--------------------";               // Signal Multiple Indicators
extern int    lookback_bars        = 2;                                    // Lookback bars (0 to disable)
extern string Lookback.PriceType   = "Close | High/Low*";                  // Price Type of Lookback bars
extern bool   RSI                  = false;                                // Relative Strength Index (RSI)
extern bool   RVI                  = false;                                // Relative Vigor Index (RVI)
extern bool   CCI                  = false;                                // Commodity Channel Index (CCI)
extern int    MA_Period            = 34;                                   // Moving Average Period (0 to disable)
extern string MA.Method            = "SMA | EMA | SMMA* | LWMA";
extern string trade_conditions     = "--------------------";               // Trade Conditions
extern int    max_spread           = 100;                                  // Max Spread
extern int    max_slippage         = 10;                                   // Max Slippage
extern int    max_orders           = 10;                                   // Max Open Trades
extern bool   close_on_opposite    = false;                                // Close on Opposite Signal
extern bool   hedge_trades         = true;                                 // Hedge on Opposite Signal

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>

int      time_frame;                         // signal timeframe
int      entry_type;                         // averaging type
int      price_type;                         // price type of lookback bars
int      MA_Method;                          // moving average method

int      last_type = -1;
datetime bar_time, p_time;
int      ord_arr[100];
double   sell_price, buy_price, stop_loss, profit_target;
bool     OrderSelected, OrderDeleted, order_mod;
int      NewOrder;
int      tries, oper_max_tries = 3;
double   sl_price, tp_price, Lot_Size, ord_price;
int      trail_stop_pips;
int      tkt_num;
int      trend_tf;
bool     buy, sell;
double   sma, macd, rsi, min_lot;
int      lot_decimals = 2;
double   maj_pips, uj_pips, ma;
string   maj_dir, uj_dir;
double   ind1, ind2, sig1, sig2;
int      err_num;


#define ENTRY_PYRAMID   1              // pyramiding
#define ENTRY_AVERAGE   2              // averaging
#define ENTRY_BOTH      3              // both

#define TPRICE_CLOSE    1              // close price
#define TPRICE_HIGHLOW  2              // high/low price


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // Signal.Timeframe
   time_frame = StrToPeriod(Signal.Timeframe, F_ERR_INVALID_PARAMETER);
   if (time_frame==-1 || time_frame > PERIOD_D1) return(catch("onInit(1)  Invalid input parameter Signal.Timeframe = "+ DoubleQuoteStr(Signal.Timeframe), ERR_INVALID_INPUT_PARAMETER));
   Signal.Timeframe = PeriodDescription(time_frame);

   // Averaging.Type
   string elems[], sValue = StringToLower(Averaging.Type);
   if (Explode(sValue, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      sValue = elems[size-1];
   }
   sValue = StringTrim(sValue);
   if      (StringStartsWith("pyramid", sValue)) { entry_type = ENTRY_PYRAMID; Averaging.Type = "Pyramid"; }
   else if (StringStartsWith("average", sValue)) { entry_type = ENTRY_AVERAGE; Averaging.Type = "Average"; }
   else if (StringStartsWith("both",    sValue)) { entry_type = ENTRY_BOTH;    Averaging.Type = "Both";    }
   else                                          return(catch("onInit(2)  Invalid input parameter Averaging.Type = "+ DoubleQuoteStr(Averaging.Type), ERR_INVALID_INPUT_PARAMETER));

   // Lookback.PriceType
   sValue = StringToLower(Lookback.PriceType);
   if (Explode(sValue, "*", elems, 2) > 1) {
      size = Explode(elems[0], "|", elems, NULL);
      sValue = elems[size-1];
   }
   sValue = StringTrim(sValue);
   if      (StringStartsWith("close",    sValue)) { price_type = TPRICE_CLOSE;   Lookback.PriceType = "Close"; }
   else if (StringStartsWith("highlow",  sValue)) { price_type = TPRICE_HIGHLOW; Lookback.PriceType = "High/Low"; }
   else if (StringStartsWith("high-low", sValue)) { price_type = TPRICE_HIGHLOW; Lookback.PriceType = "High/Low"; }
   else if (StringStartsWith("high/low", sValue)) { price_type = TPRICE_HIGHLOW; Lookback.PriceType = "High/Low"; }
   else                                          return(catch("onInit(3)  Invalid input parameter Lookback.PriceType = "+ DoubleQuoteStr(Lookback.PriceType), ERR_INVALID_INPUT_PARAMETER));

   // MA.Method
   if (Explode(MA.Method, "*", elems, 2) > 1) {
      size = Explode(elems[0], "|", elems, NULL);
      sValue = elems[size-1];
   }
   else sValue = StringTrim(MA.Method);
   MA_Method = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
   if (MA_Method == -1 || MA_Method > MODE_LWMA) return(catch("onInit(4)  Invalid input parameter MA.Method = "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   MA.Method = MaMethodDescription(MA_Method);



   // legacy source
   min_lot = MarketInfo(Symbol(), MODE_MINLOT);
   if (min_lot == 0.01) lot_decimals = 2;
   if (min_lot == 0.1)  lot_decimals = 1;
   if (min_lot == 1)    lot_decimals = 0;

   if (invalid_pair(Major_Code))                             return(catch("onInit(5)  First pair code ("+ Major_Code +") is invalid", ERR_INVALID_INPUT_PARAMETER));
   if (invalid_pair(UJ_Code))                                return(catch("onInit(6)  Second pair code ("+ UJ_Code +") is invalid", ERR_INVALID_INPUT_PARAMETER));
   if (invalid_pair(JPY_Cross))                              return(catch("onInit(7)  Second pair code ("+ JPY_Cross +") is invalid", ERR_INVALID_INPUT_PARAMETER));
   if (time_frame < Period())                                return(catch("onInit(8)  Invalid input signal timeframe ("+ time_frame +") is less than trading timeframe ("+ Period() +")", ERR_INVALID_INPUT_PARAMETER));
   if (BE_Pips > Trail_Stop_Pips && Trail_Stop_Pips > 0)     return(catch("onInit(9)  Breakeven pips ("+ BE_Pips +") is greater than trailing stop ("+ Trail_Stop_Pips +")", ERR_INVALID_INPUT_PARAMETER));
   if (!lookback_bars && !MA_Period && !RSI && !RVI && !CCI) return(catch("onInit(10)  Error: No signal triggers/indicators selected.", ERR_INVALID_INPUT_PARAMETER));

   return(catch("onInit(11)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (BE_Pips         > 0) move_to_BE();
   if (PL_Pips         > 0) move_to_PL();
   if (Trail_Stop_Pips > 0) trail_stop();

   if (Time[0] > bar_time) {
      if (total_orders() < max_orders) {
         if (lookback_bars > 1) {
            if (price_type == TPRICE_HIGHLOW) {
               buy = (major_pos == "L"
                   && iClose(Major_Code, time_frame, 1) > iHigh(Major_Code, time_frame, iHighest(Major_Code, time_frame, MODE_HIGH, lookback_bars, 2))
                   && iClose(UJ_Code,    time_frame, 1) > iHigh(UJ_Code,    time_frame, iHighest(UJ_Code,    time_frame, MODE_HIGH, lookback_bars, 2)))
                   ||
                   (major_pos == "R"
                   && iClose(Major_Code, time_frame, 1) <  iLow(Major_Code, time_frame,  iLowest(Major_Code, time_frame, MODE_LOW,  lookback_bars, 2))
                   && iClose(UJ_Code,    time_frame, 1) > iHigh(UJ_Code,    time_frame, iHighest(UJ_Code,    time_frame, MODE_HIGH, lookback_bars, 2)));

               sell = (major_pos == "L"
                    && iClose(Major_Code, time_frame, 1) < iLow(Major_Code, time_frame, iLowest(Major_Code, time_frame, MODE_LOW, lookback_bars, 2))
                    && iClose(UJ_Code,    time_frame, 1) < iLow(UJ_Code,    time_frame, iLowest(UJ_Code,    time_frame, MODE_LOW, lookback_bars, 2)))
                    ||
                    (major_pos == "R"
                    && iClose(Major_Code, time_frame, 1) > iHigh(Major_Code, time_frame, iHighest(Major_Code, time_frame, MODE_HIGH, lookback_bars, 2))
                    && iClose(UJ_Code,    time_frame, 1) <  iLow(UJ_Code,    time_frame,  iLowest(UJ_Code,    time_frame, MODE_LOW,  lookback_bars, 2)));
            }
            else {
               buy = (major_pos == "L"
                      && iClose(Major_Code, time_frame, 1) > iClose(Major_Code, time_frame, lookback_bars)
                      && iClose(UJ_Code,    time_frame, 1) > iClose(UJ_Code,    time_frame, lookback_bars))
                     ||
                     (major_pos == "R"
                      && iClose(Major_Code, time_frame, 1) < iClose(Major_Code, time_frame, lookback_bars)
                      && iClose(UJ_Code,    time_frame, 1) > iClose(UJ_Code,    time_frame, lookback_bars));

               sell = (major_pos == "L"
                       && iClose(Major_Code, time_frame, 1) < iClose(Major_Code, time_frame, lookback_bars)
                       && iClose(UJ_Code,    time_frame, 1) < iClose(UJ_Code,    time_frame, lookback_bars))
                      ||
                      (major_pos == "R"
                       && iClose(Major_Code, time_frame, 1) > iClose(Major_Code, time_frame, lookback_bars)
                       && iClose(UJ_Code,    time_frame, 1) < iClose(UJ_Code,    time_frame, lookback_bars));
            }
         }
         else {
            buy  = true;
            sell = true;
         }

         buy  = buy  && (entry_type==ENTRY_BOTH
                     || (entry_type==ENTRY_AVERAGE && Close[1] < Open[1])
                     || (entry_type==ENTRY_PYRAMID && Close[1] > Open[1]));

         sell = sell && (entry_type==ENTRY_BOTH
                     || (entry_type==ENTRY_AVERAGE && Close[1] > Open[1])
                     || (entry_type==ENTRY_PYRAMID && Close[1] < Open[1]));

         if (RSI) {
            ind1 = iRSI(Major_Code, time_frame, 14, PRICE_CLOSE, 1);
            ind2 = iRSI(UJ_Code,    time_frame, 14, PRICE_CLOSE, 1);
            buy  = buy  && ind2 > 50 && ((major_pos=="L" && ind1 > 50)
                                      || (major_pos=="R" && ind1 < 50));
            sell = sell && ind2 < 50 && ((major_pos=="L" && ind1 < 50)
                                      || (major_pos=="R" && ind1 > 50));
         }

         if (CCI) {
            ind1 = iCCI(Major_Code, time_frame, 14, PRICE_TYPICAL, 1);
            ind2 = iCCI(UJ_Code,    time_frame, 14, PRICE_TYPICAL, 1);
            buy=buy &&
                (
                (ind1>0 && major_pos=="L")
                ||
                (ind1<0 && major_pos=="R")
                )
                && ind2>0;
            sell=sell &&
                 (
                 (ind1<0 && major_pos=="L")
                 ||
                 (ind1>0 && major_pos=="R")
                 )

                 && ind2<0;
         }

         if (RVI) {
            ind1=iRVI(Major_Code,time_frame,10,MODE_MAIN,1);
            ind2=iRVI(UJ_Code,time_frame,10,MODE_MAIN,1);
            sig1=iRVI(Major_Code,time_frame,10,MODE_SIGNAL,1);
            sig2=iRVI(UJ_Code,time_frame,10,MODE_SIGNAL,1);
            buy=buy &&
                (
                (ind1>sig1 && major_pos=="L")
                ||
                (ind1<sig1 && major_pos=="R")
                )
                && ind2>sig2;
            sell=sell &&
                 (
                 (ind1<sig1 && major_pos=="L")
                 ||
                 (ind1>sig1 && major_pos=="R")
                 )
                 && ind2<sig2;
         }

         if (MA_Period > 0) {
            ind1=iMA(Major_Code,time_frame,MA_Period,0,MA_Method,PRICE_CLOSE,1);
            ind2=iMA(UJ_Code,time_frame,MA_Period,0,MA_Method,PRICE_CLOSE,1);
            buy=buy &&
                (
                (iClose(Major_Code,time_frame,1)>ind1 && major_pos=="L")
                ||
                (iClose(Major_Code,time_frame,1)<ind1 && major_pos=="R")
                )
                && iClose(UJ_Code,time_frame,1)>ind2;
            sell=sell &&
                 (
                 (iClose(Major_Code,time_frame,1)<ind1 && major_pos=="L")
                 ||
                 (iClose(Major_Code,time_frame,1)>ind1 && major_pos=="R")
                 )

                 && iClose(UJ_Code,time_frame,1)<ind2;
         }

         if (buy) {
            if(close_on_opposite) close_current_orders(OP_SELL);
            if(hedge_trades || (!hedge_trades && !exist_order(OP_SELL))) market_buy_order();
         }
         if (sell) {
            if(close_on_opposite) close_current_orders(OP_BUY);
            if(hedge_trades || (!hedge_trades && !exist_order(OP_BUY))) market_sell_order();
         }
      }
      bar_time = Time[0];
   }

   return(catch("onTick(1)"));
}


/**
 * Count the number of open positions of the strategy.
 *
 * @return int - number of open positions or EMPTY (-1) in case of errors
 */
int total_orders() {
   int tot_orders = 0;

   for (int i=0; i < OrdersTotal(); i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         break;
      if (OrderMagicNumber()==Magic_Number && OrderSymbol()==Symbol() && (OrderType()==OP_BUY || OrderType()==OP_SELL))
         tot_orders++;
   }

   if (!catch("tot_orders(1)"))
      return(tot_orders);
   return(EMPTY);
}


/**
 * Submit a Buy Market order.
 *
 * @return int - order ticket or NULL in case of errors
 */
int market_buy_order() {
   double rem=0; bool x=false;
   NewOrder=0;
   tries=0;
   double x_lots=0;
   if (Fixed_Lot_Size > 0) Lot_Size=Fixed_Lot_Size;
   else
   {
      Lot_Size=NormalizeDouble((AccountBalance()*Bal_Perc_Lot_Size/100)/MarketInfo(Symbol(),MODE_MARGINREQUIRED),lot_decimals);
   }
   if(SL_Pips==0) sl_price=0;
   else sl_price = MarketInfo(Symbol(),MODE_ASK)-SL_Pips*Point;
   if(TP_Pips==0) tp_price=0;
   else tp_price=MarketInfo(Symbol(),MODE_ASK)+TP_Pips*Point;

   while(NewOrder<=0 && tries< oper_max_tries && MarketInfo(Symbol(),MODE_ASK)-MarketInfo(Symbol(),MODE_BID)<=max_spread*Point)
   {
         NewOrder=OrderSend(Symbol(),OP_BUY,Lot_Size,MarketInfo(Symbol(),MODE_ASK),max_slippage,
                         sl_price,
                         tp_price,
                         "YT5",Magic_Number,0,Blue);
        if(NewOrder<0)
        {
            err_num=GetLastError();
            if(err_num!=ERR_NO_ERROR) Print("Error in Sending a Buy Order : ",ErrorDescription(err_num));
        }
      tries=tries+1;
   }

   if (!catch("market_buy_order(1)"))
      return(NewOrder);
   return(NULL);
}


/**
 * Submit a Sell Market order.
 *
 * @return int - order ticket or NULL in case of errors
 */
int market_sell_order() {
   double rem=0; bool x=false;
   NewOrder=0;
   tries=0;
   double x_lots=0;
   if (Fixed_Lot_Size > 0) Lot_Size=Fixed_Lot_Size;
   else
   {
      Lot_Size=NormalizeDouble((AccountBalance()*Bal_Perc_Lot_Size/100)/MarketInfo(Symbol(),MODE_MARGINREQUIRED),lot_decimals);
   }

   if(SL_Pips==0) sl_price=0;
   else sl_price = MarketInfo(Symbol(),MODE_BID)+SL_Pips*Point;
   if(TP_Pips==0) tp_price=0;
   else tp_price=MarketInfo(Symbol(),MODE_BID)-TP_Pips*Point;

   while(NewOrder<=0 && tries< oper_max_tries && MarketInfo(Symbol(),MODE_ASK)-MarketInfo(Symbol(),MODE_BID)<=max_spread*Point)
   {
         NewOrder=OrderSend(Symbol(),OP_SELL,Lot_Size,MarketInfo(Symbol(),MODE_BID),max_slippage,
                            sl_price,
                            tp_price,
                            "YT5",Magic_Number,0,Red);
        if(NewOrder<0)
        {
            err_num=GetLastError();
            if(err_num!=ERR_NO_ERROR) Print("Error in Sending a Sell Order : ",ErrorDescription(err_num));
        }
      tries=tries+1;
   }

   if (!catch("market_sell_order(1)"))
      return(NewOrder);
   return(NULL);
}


/**
 * Whether or not an open ticket of the specified order type exists.
 *
 * @return bool
 */
bool exist_order(int ord_type) {
   bool result = false;

   for (int i=0; i < OrdersTotal(); i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         break;
      if (OrderMagicNumber()==Magic_Number && OrderSymbol()==Symbol() && OrderType()==ord_type) {
         result = true;
         break;
      }
   }

   if (!catch("exist_order(1)"))
      return(result);
   return(false);
}


/**
 * Close all open positions of the specified type.
 */
void close_current_orders(int ord_type) {
   int  k = -1;
   bool x = false;

   for (int j=0; j < 100; j++) {
      ord_arr[j] = 0;
   }

   int ot = OrdersTotal();

   for (j=0; j < ot; j++) {
      if (!OrderSelect(j,SELECT_BY_POS,MODE_TRADES))
         break;

      if (OrderSymbol()==Symbol() && OrderMagicNumber()==Magic_Number) {
         if (OrderType() == ord_type) {
            k++;
            ord_arr[k] = OrderTicket();
         }
      }
   }

   for (j=0; j <= k; j++) {
      bool OrderClosed = false;
      tries = 0;

      while (!OrderClosed && tries < oper_max_tries) {
         RefreshRates();
         x = OrderSelect(ord_arr[j], SELECT_BY_TICKET, MODE_TRADES);
         if (OrderType() == OP_SELL) OrderClosed = OrderClose(ord_arr[j], OrderLots(), MarketInfo(Symbol(), MODE_ASK), 100, NULL);
         if (OrderType() == OP_BUY ) OrderClosed = OrderClose(ord_arr[j], OrderLots(), MarketInfo(Symbol(), MODE_BID), 100, NULL);
         tries++;
      }
    }
    catch("close_current_orders(1)");
}


/**
 * Trail stops of matching open positions.
 */
void trail_stop() {
   double new_sl=0; bool OrderMod=false;
   trail_stop_pips=Trail_Stop_Pips;

   if (trail_stop_pips==0) return;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderMagicNumber()==Magic_Number && OrderSymbol()==Symbol())
      {
         if(OrderType()==OP_BUY)
         {  new_sl=0;
            if(MarketInfo(Symbol(),MODE_BID)-OrderOpenPrice()>trail_stop_pips*Point && (OrderOpenPrice()>OrderStopLoss()||OrderStopLoss()==0))
               new_sl=OrderOpenPrice()+Point;
            if (MarketInfo(Symbol(),MODE_BID)-OrderStopLoss()>(trail_stop_pips*Point+Trail_Stop_Jump_Pips*Point) && OrderStopLoss()>OrderOpenPrice())
               new_sl = MarketInfo(Symbol(),MODE_BID)-trail_stop_pips*Point;
            OrderMod=false;
            tries=0;

             while(!OrderMod && tries<oper_max_tries && new_sl>0 && new_sl>OrderStopLoss())
            {
               OrderMod=OrderModify(OrderTicket(),OrderOpenPrice(),new_sl,OrderTakeProfit(),0,White);
               if(!OrderMod) err_num=GetLastError();
               if(err_num!=ERR_NO_ERROR) Print("Order SL Modify Error: ",ErrorDescription(err_num));
               tries=tries+1;
            }

         }
         if(OrderType()==OP_SELL)
         {   new_sl=0;
             if(OrderOpenPrice()-MarketInfo(Symbol(),MODE_ASK)>trail_stop_pips*Point && (OrderOpenPrice()<OrderStopLoss()||OrderStopLoss()==0))
               new_sl=OrderOpenPrice()-Point;
             if(OrderStopLoss()-MarketInfo(Symbol(),MODE_ASK)>trail_stop_pips*Point+Trail_Stop_Jump_Pips*Point && OrderStopLoss()<OrderOpenPrice())
               new_sl=MarketInfo(Symbol(),MODE_ASK)+trail_stop_pips*Point;
             OrderMod=false;
             tries=0;

             while(!OrderMod && tries<oper_max_tries && new_sl>0 && new_sl<OrderStopLoss())
            {
               OrderMod=OrderModify(OrderTicket(),OrderOpenPrice(),new_sl,OrderTakeProfit(),0,White);
               if(!OrderMod) err_num=GetLastError();
               if(err_num!=ERR_NO_ERROR) Print("Order SL Modify Error: ",ErrorDescription(err_num));
               tries=tries+1;
            }
         }
      }
   }
   catch("trail_stop(1)");
}


/**
 * Move stops of matching open positions to Breakeven.
 */
void move_to_BE() {
   double new_sl   = 0;
   bool   OrderMod = false;

   trail_stop_pips = BE_Pips;
   if (!trail_stop_pips) return;

   for (int i=0; i < OrdersTotal(); i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;

      if (OrderMagicNumber()==Magic_Number && OrderSymbol()==Symbol()) {
         if (OrderType() == OP_BUY) {
            new_sl = 0;
            if (MarketInfo(Symbol(), MODE_BID)-OrderOpenPrice() > trail_stop_pips*Point && (OrderOpenPrice() > OrderStopLoss()|| !OrderStopLoss()))
               new_sl = OrderOpenPrice() + trail_stop_pips*Point;
            OrderMod = false;
            tries    = 0;

            while (!OrderMod && tries < oper_max_tries && new_sl > 0 && new_sl > OrderStopLoss()) {
               OrderMod = OrderModify(OrderTicket(), OrderOpenPrice(), new_sl, OrderTakeProfit(), 0, White);
               if (!OrderMod) err_num = GetLastError();
               if (err_num != ERR_NO_ERROR) Print("Order move to BE Modify error: ", ErrorDescription(err_num));
               tries++;
            }
         }
         if (OrderType() == OP_SELL) {
            new_sl = 0;
            if (OrderOpenPrice()-MarketInfo(Symbol(), MODE_ASK) > trail_stop_pips*Point && (OrderOpenPrice() < OrderStopLoss() || !OrderStopLoss()))
               new_sl = OrderOpenPrice() - trail_stop_pips*Point;
            OrderMod = false;
            tries    = 0;

            while (!OrderMod && tries < oper_max_tries && new_sl > 0 && new_sl < OrderStopLoss()) {
               OrderMod = OrderModify(OrderTicket(), OrderOpenPrice(), new_sl, OrderTakeProfit(), 0, White);
               if (!OrderMod) err_num = GetLastError();
               if (err_num != ERR_NO_ERROR) Print("Order move to BE Modify error: ", ErrorDescription(err_num));
               tries++;
            }
         }
      }
   }
   catch("move_to_BE(1)");
}


/**
 * Move stops of matching open positions to Breakeven + a defined amount of profit.
 */
void move_to_PL() {
   double new_sl=0; bool OrderMod=false;
   trail_stop_pips=PL_Pips;

   if(trail_stop_pips==0) return;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderMagicNumber()==Magic_Number && OrderSymbol()==Symbol())
      {
         if(OrderType()==OP_BUY)
         {  new_sl=0;
            if(MarketInfo(Symbol(),MODE_BID)-OrderOpenPrice()>trail_stop_pips*Point && OrderOpenPrice()<OrderStopLoss())
               new_sl=OrderOpenPrice()+trail_stop_pips*Point;
            OrderMod=false;
            tries=0;

             while(!OrderMod && tries<oper_max_tries && new_sl>0 && new_sl>OrderStopLoss())
            {
               OrderMod=OrderModify(OrderTicket(),OrderOpenPrice(),new_sl,OrderTakeProfit(),0,White);
               if(!OrderMod) err_num=GetLastError();
               if(err_num!=ERR_NO_ERROR) Print("Order move to PL Modify Error: ",ErrorDescription(err_num));

               tries=tries+1;

            }

         }
         if(OrderType()==OP_SELL)
         {   new_sl=0;
             if(OrderOpenPrice()-MarketInfo(Symbol(),MODE_ASK)>trail_stop_pips*Point && OrderOpenPrice()>OrderStopLoss())
               new_sl=OrderOpenPrice()-trail_stop_pips*Point;
             OrderMod=false;
             tries=0;

             while(!OrderMod && tries<oper_max_tries && new_sl>0 && new_sl<OrderStopLoss())
            {
               OrderMod=OrderModify(OrderTicket(),OrderOpenPrice(),new_sl,OrderTakeProfit(),0,White);
               if(!OrderMod) err_num=GetLastError();
               if(err_num!=ERR_NO_ERROR) Print("Order move to PL Modify Error: ",ErrorDescription(err_num));
               tries=tries+1;
            }
         }
      }
   }
   catch("move_to_PL(1)");
}


/**
 * Whether or not a symbol is subscribed. A symbol is subscribed if it's visible in the MarketWatch window.
 *
 * @param  string symbol
 *
 * @return bool
 */
bool invalid_pair(string symbol) {
   return(!MarketInfo(symbol, MODE_TIME) || GetLastError());

   //original MQL5:
   //
   //for (int i=0; i < SymbolsTotal(true); i++) {
   //   if (SymbolName(i, true) == symbol)
   //      return(false);
   //}
   //return(true);
}

