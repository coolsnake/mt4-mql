/**
 * Derived Double Exponential Moving Average (DEMA) by Patrick G. Mulloy
 *
 *
 * The name suggests the DEMA is calculated by simply applying a double exponential smoothing which is not the case. Instead
 * the name "double" come from the fact that for the calculation a double smoothed EMA is subtracted from a previously doubled
 * simple EMA.
 *
 * Indicator buffers for use with iCustom():
 *  � MovingAverage.MODE_MA: MA values
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods            = 38;
extern string MA.AppliedPrice       = "Open | High | Low | Close* | Median | Typical | Weighted";

extern color  MA.Color              = DodgerBlue;        // indicator style management in MQL
extern string Draw.Type             = "Line* | Dot";
extern int    Draw.LineWidth        = 2;

extern int    Max.Values            = 3000;              // max. number of values to display: -1 = all
extern int    Shift.Vertical.Pips   = 0;                 // vertical indicator shift in pips
extern int    Shift.Horizontal.Bars = 0;                 // horizontal indicator shift in bars

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>
#include <functions/@Trend.mqh>

#define MODE_DEMA           MovingAverage.MODE_MA
#define MODE_EMA_1          1

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_width1  2

double dema    [];                                       // MA values: visible, displayed in "Data" window
double firstEma[];                                       // first EMA: invisible

int    ma.appliedPrice;
string ma.name;                                          // name for chart legend, "Data" window and context menues

int    draw.type      = DRAW_LINE;                       // DRAW_LINE | DRAW_ARROW
int    draw.arrowSize = 1;                               // default symbol size for Draw.Type="dot"
double shift.vertical;
string legendLabel;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   if (InitReason() == IR_RECOMPILE) {
      if (!RestoreInputParameters()) return(last_error);
   }

   // (1) validate inputs
   // MA.Periods
   if (MA.Periods < 1)     return(catch("onInit(1)  Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));

   // MA.AppliedPrice
   string elems[], sValue = MA.AppliedPrice;
   if (Explode(MA.AppliedPrice, "*", elems, 2) > 1) {
      int size = Explode(elems[0], "|", elems, NULL);
      sValue = elems[size-1];
   }
   sValue = StringTrim(sValue);
   if (sValue == "") sValue = "Close";                      // default
   ma.appliedPrice = StrToPriceType(sValue, F_ERR_INVALID_PARAMETER);
   if (ma.appliedPrice==-1 || ma.appliedPrice > PRICE_WEIGHTED)
                           return(catch("onInit(2)  Invalid input parameter MA.AppliedPrice = "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(ma.appliedPrice);

   // MA.Color
   if (MA.Color == 0xFF000000) MA.Color = CLR_NONE;         // after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)

   // Draw.Type
   sValue = StringToLower(Draw.Type);
   if (Explode(sValue, "*", elems, 2) > 1) {
      size = Explode(elems[0], "|", elems, NULL);
      sValue = elems[size-1];
   }
   sValue = StringTrim(sValue);
   if      (StringStartsWith("line", sValue)) { draw.type = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StringStartsWith("dot",  sValue)) { draw.type = DRAW_ARROW; Draw.Type = "Dot";  }
   else                    return(catch("onInit(3)  Invalid input parameter Draw.Type = "+ DoubleQuoteStr(Draw.Type), ERR_INVALID_INPUT_PARAMETER));

   // Draw.LineWidth
   if (Draw.LineWidth < 1) return(catch("onInit(4)  Invalid input parameter Draw.LineWidth = "+ Draw.LineWidth, ERR_INVALID_INPUT_PARAMETER));
   if (Draw.LineWidth > 5) return(catch("onInit(5)  Invalid input parameter Draw.LineWidth = "+ Draw.LineWidth, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1)    return(catch("onInit(6)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));


   // (2) setup buffer management
   IndicatorBuffers(3);
   SetIndexBuffer(MODE_DEMA,  dema    );
   SetIndexBuffer(MODE_EMA_1, firstEma);


   // (3) data display configuration, names and labels
   string shortName="DEMA("+ MA.Periods +")", strAppliedPrice="";
   if (ma.appliedPrice != PRICE_CLOSE) strAppliedPrice = ", "+ PriceTypeDescription(ma.appliedPrice);
   ma.name = "DEMA("+ MA.Periods + strAppliedPrice +")";
   if (!IsSuperContext()) {                                    // no chart legend if called by iCustom()
       legendLabel = CreateLegendLabel(ma.name);
       ObjectRegister(legendLabel);
   }
   IndicatorShortName(shortName);                              // context menu
   SetIndexLabel(MODE_DEMA,  shortName);                       // "Data" window and tooltips
   SetIndexLabel(MODE_EMA_1, NULL);
   IndicatorDigits(SubPipDigits);


   // (4) drawing options and styles
   int startDraw = Shift.Horizontal.Bars;
   if (Max.Values >= 0) startDraw += Bars - Max.Values;
   if (startDraw  <  0) startDraw  = 0;
   SetIndexShift    (MODE_DEMA, Shift.Horizontal.Bars);
   SetIndexDrawBegin(MODE_DEMA, startDraw);
   shift.vertical = Shift.Vertical.Pips * Pips;
   SetIndicatorStyles();

   return(catch("onInit(7)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);
   RepositionLegend();
   return(catch("onDeinit(1)"));
}


/**
 * Called before recompilation.
 *
 * @return int - error status
 */
int onDeinitRecompile() {
   StoreInputParameters();
   return(last_error);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // check for finished buffer initialization
   if (!ArraySize(dema))                                          // can happen on terminal start
      return(debug("onTick(1)  size(dema) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(dema,     EMPTY_VALUE);
      ArrayInitialize(firstEma, EMPTY_VALUE);
      SetIndicatorStyles();
   }

   // synchronize buffers with a shifted offline chart (if applicable)
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(dema,     Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(firstEma, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int changedBars = ChangedBars;
   if (Max.Values >= 0) /*&&*/ if (Max.Values < ChangedBars)
      changedBars = Max.Values;                                      // Because EMA(EMA) is used in the calculation, DEMA needs 2*<period>-1 samples
   int bar, startBar = Min(changedBars-1, Bars - (2*MA.Periods-1));  // to start producing values in contrast to <period> samples needed by a regular EMA.
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));


   // (2) recalculate invalid bars
   double secondEma;
   for (bar=ChangedBars-1; bar >= 0; bar--)   firstEma[bar] =    iMA(NULL,     NULL,        MA.Periods, 0, MODE_EMA, ma.appliedPrice, bar);
   for (bar=startBar;      bar >= 0; bar--) { secondEma = iMAOnArray(firstEma, WHOLE_ARRAY, MA.Periods, 0, MODE_EMA,                  bar);
      dema[bar] = 2 * firstEma[bar] - secondEma + shift.vertical;
   }


   // (3) update chart legend
   if (!IsSuperContext()) {
       @Trend.UpdateLegend(legendLabel, ma.name, "", MA.Color, MA.Color, dema[0], NULL, Time[0]);
   }
   return(last_error);
}


/**
 * Set indicator styles. Workaround for various terminal bugs when setting styles. Usually styles are applied in init().
 * However after recompilation styles must be applied in start() to not get lost.
 */
void SetIndicatorStyles() {
   int width = ifInt(draw.type==DRAW_ARROW, draw.arrowSize, Draw.LineWidth);

   SetIndexStyle(MODE_DEMA, draw.type, EMPTY, width, MA.Color); SetIndexArrow(MODE_DEMA, 159);
}


/**
 * Store input parameters in the chart for restauration after recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   Chart.StoreInt   (__NAME__ +".input.MA.Periods",            MA.Periods           );
   Chart.StoreString(__NAME__ +".input.MA.AppliedPrice",       MA.AppliedPrice      );
   Chart.StoreInt   (__NAME__ +".input.MA.Color",              MA.Color             );
   Chart.StoreString(__NAME__ +".input.Draw.Type",             Draw.Type            );
   Chart.StoreInt   (__NAME__ +".input.Draw.LineWidth",        Draw.LineWidth       );
   Chart.StoreInt   (__NAME__ +".input.Max.Values",            Max.Values           );
   Chart.StoreInt   (__NAME__ +".input.Shift.Vertical.Pips",   Shift.Vertical.Pips  );
   Chart.StoreInt   (__NAME__ +".input.Shift.Horizontal.Bars", Shift.Horizontal.Bars);
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   string label = __NAME__ +".input.MA.Periods";
   if (ObjectFind(label) == 0) {
      string sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreInputParameters(1)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      MA.Periods = StrToInteger(sValue);                          // (int) string
   }

   label = __NAME__ +".input.MA.AppliedPrice";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      MA.AppliedPrice = sValue;                                   // string
   }

   label = __NAME__ +".input.MA.Color";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsInteger(sValue)) return(!catch("RestoreInputParameters(2)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      int iValue = StrToInteger(sValue);
      if (iValue < CLR_NONE || iValue > C'255,255,255')
                                    return(!catch("RestoreInputParameters(3)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)) +" (0x"+ IntToHexStr(iValue) +")", ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      MA.Color = iValue;                                          // (color)(int) string
   }

   label = __NAME__ +".input.Draw.Type";
   if (ObjectFind(label) == 0) {
      sValue = ObjectDescription(label);
      ObjectDelete(label);
      Draw.Type = sValue;                                         // string
   }

   label = __NAME__ +".input.Draw.LineWidth";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsDigit(sValue))   return(!catch("RestoreInputParameters(4)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Draw.LineWidth = StrToInteger(sValue);                      // (int) string
   }

   label = __NAME__ +".input.Max.Values";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsInteger(sValue)) return(!catch("RestoreInputParameters(5)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Max.Values = StrToInteger(sValue);                          // (int) string
   }

   label = __NAME__ +".input.Shift.Vertical.Pips";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsInteger(sValue)) return(!catch("RestoreInputParameters(6)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Shift.Vertical.Pips = StrToInteger(sValue);                 // (int) string
   }

   label = __NAME__ +".input.Shift.Horizontal.Bars";
   if (ObjectFind(label) == 0) {
      sValue = StringTrim(ObjectDescription(label));
      if (!StringIsInteger(sValue)) return(!catch("RestoreInputParameters(6)  illegal chart value "+ label +" = "+ DoubleQuoteStr(ObjectDescription(label)), ERR_INVALID_CONFIG_PARAMVALUE));
      ObjectDelete(label);
      Shift.Horizontal.Bars = StrToInteger(sValue);               // (int) string
   }

   return(!catch("RestoreInputParameters(7)"));
}


/**
 * Return a string representation of the input parameters (logging).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input: ",

                            "MA.Periods=",            MA.Periods,                      "; ",
                            "MA.AppliedPrice=",       DoubleQuoteStr(MA.AppliedPrice), "; ",
                            "MA.Color=",              ColorToStr(MA.Color),            "; ",

                            "Draw.Type=",             DoubleQuoteStr(Draw.Type),       "; ",
                            "Draw.LineWidth=",        Draw.LineWidth,                  "; ",

                            "Max.Values=",            Max.Values,                      "; ",
                            "Shift.Vertical.Pips=",   Shift.Vertical.Pips,             "; ",
                            "Shift.Horizontal.Bars=", Shift.Horizontal.Bars,           "; ")
   );
}
