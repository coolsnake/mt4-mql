
/**
 * Set lots.startSize and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetLotsStartSize(double value) {
   if (lots.startSize != value) {
      lots.startSize = value;

      if (__CHART) {
         if (!value) str.lots.startSize = "-";
         else        str.lots.startSize = NumberToStr(value, ".1+");
      }
   }
   return(value);
}


/**
 * Set grid.marketSize and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetGridMarketSize(double value) {
   if (grid.marketSize != value) {
      grid.marketSize = value;

      if (__CHART) {
         if (!value) str.grid.marketSize = "-";
         else        str.grid.marketSize = DoubleToStr(value, 1) +" pip";
      }
   }
   return(value);
}


/**
 * Set grid.minSize and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetGridMinSize(double value) {
   if (grid.minSize != value) {
      grid.minSize = value;

      if (__CHART) {
         if (!value) str.grid.minSize = "-";
         else        str.grid.minSize = DoubleToStr(value, 1) +" pip";
      }
   }
   return(value);
}


/**
 * Set position.slPrice and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionSlPrice(double value) {
   if (position.slPrice != value) {
      position.slPrice = value;

      if (__CHART) {
         if (!value) str.position.slPrice = "-";
         else        str.position.slPrice = NumberToStr(value, SubPipPriceFormat);
      }
   }
   return(value);
}


/**
 * Set the string representation of input parameter TakeProfit.Pips.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionTpPip(double value) {
   if (__CHART) {
      if (!value) str.position.tpPip = "-";
      else        str.position.tpPip = DoubleToStr(value, 1) +" pip";
   }
   return(value);
}


/**
 * Set position.plPip and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionPlPip(double value) {
   if (position.plPip != value) {
      position.plPip = value;

      if (__CHART) {
         if (value == EMPTY_VALUE) str.position.plPip = "-";
         else                      str.position.plPip = DoubleToStr(value, 1) +" pip";
      }

      if (value == EMPTY_VALUE) {
         SetPositionPlPipMin(value);
         SetPositionPlPipMin(value);
      }
      else {
         if (value < position.plPipMin || position.plPipMin==EMPTY_VALUE) SetPositionPlPipMin(value);
         if (value > position.plPipMax || position.plPipMax==EMPTY_VALUE) SetPositionPlPipMax(value);
      }
   }
   return(value);
}


/**
 * Set position.plPipMin and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionPlPipMin(double value) {
   if (position.plPipMin != value) {
      position.plPipMin = value;

      if (__CHART) {
         if (value == EMPTY_VALUE) str.position.plPipMin = "-";
         else                      str.position.plPipMin = DoubleToStr(value, 1) +" pip";
      }
   }
   return(value);
}


/**
 * Set position.plPipMax and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionPlPipMax(double value) {
   if (position.plPipMax != value) {
      position.plPipMax = value;

      if (__CHART) {
         if (value == EMPTY_VALUE) str.position.plPipMax = "-";
         else                      str.position.plPipMax = DoubleToStr(value, 1) +" pip";
      }
   }
   return(value);
}


/**
 * Set position.plUPip and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionPlUPip(double value) {
   if (position.plUPip != value) {
      position.plUPip = value;

      if (__CHART) {
         if (value == EMPTY_VALUE) str.position.plUPip = "-";
         else                      str.position.plUPip = DoubleToStr(value, 1) +" upip";
      }

      if (value == EMPTY_VALUE) {
         SetPositionPlUPipMin(value);
         SetPositionPlUPipMin(value);
      }
      else {
         if (value < position.plUPipMin || position.plUPipMin==EMPTY_VALUE) SetPositionPlPipMin(value);
         if (value > position.plUPipMax || position.plUPipMax==EMPTY_VALUE) SetPositionPlPipMax(value);
      }
   }
   return(value);
}


/**
 * Set position.plUPipMin and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionPlUPipMin(double value) {
   if (position.plUPipMin != value) {
      position.plUPipMin = value;

      if (__CHART) {
         if (value == EMPTY_VALUE) str.position.plUPipMin = "-";
         else                      str.position.plUPipMin = DoubleToStr(value, 1) +" upip";
      }
   }
   return(value);
}


/**
 * Set position.plUPipMax and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionPlUPipMax(double value) {
   if (position.plUPipMax != value) {
      position.plUPipMax = value;

      if (__CHART) {
         if (value == EMPTY_VALUE) str.position.plUPipMax = "-";
         else                      str.position.plUPipMax = DoubleToStr(value, 1) +" upip";
      }
   }
   return(value);
}


/**
 * Set position.plPct and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionPlPct(double value) {
   if (position.plPct != value) {
      position.plPct = value;

      if (__CHART) {
         if (value == EMPTY_VALUE) str.position.plPct = "-";
         else                      str.position.plPct = DoubleToStr(value, 2) +" %";
      }

      if (value == EMPTY_VALUE) {
         SetPositionPlPctMin(value);
         SetPositionPlPctMax(value);
      }
      else {
         if (value < position.plPctMin || position.plPctMin==EMPTY_VALUE) SetPositionPlPctMin(value);
         if (value > position.plPctMax || position.plPctMax==EMPTY_VALUE) SetPositionPlPctMax(value);
      }
   }
   return(value);
}


/**
 * Set position.plPctMin and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionPlPctMin(double value) {
   if (position.plPctMin != value) {
      position.plPctMin = value;

      if (__CHART) {
         if (value == EMPTY_VALUE) str.position.plPctMin = "-";
         else                      str.position.plPctMin = DoubleToStr(value, 2) +" %";
      }
   }
   return(value);
}


/**
 * Set position.plPctMax and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionPlPctMax(double value) {
   if (position.plPctMax != value) {
      position.plPctMax = value;

      if (__CHART) {
         if (value == EMPTY_VALUE) str.position.plPctMax = "-";
         else                      str.position.plPctMax = DoubleToStr(value, 2) +" %";
      }
   }
   return(value);
}


/**
 * Set position.cumPlPct and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionCumPlPct(double value) {
   if (position.cumPlPct != value) {
      position.cumPlPct = value;

      if (__CHART) {
         if (value == EMPTY_VALUE) str.position.cumPlPct = "-";
         else                      str.position.cumPlPct = DoubleToStr(value, 2) +" %";
      }

      if (value == EMPTY_VALUE) {
         SetPositionCumPlPctMin(value);
         SetPositionCumPlPctMax(value);
      }
      else {
         if (value < position.cumPlPctMin || position.cumPlPctMin==EMPTY_VALUE) SetPositionCumPlPctMin(value);
         if (value > position.cumPlPctMax || position.cumPlPctMax==EMPTY_VALUE) SetPositionCumPlPctMax(value);
      }
   }
   return(value);
}


/**
 * Set position.cumPlPctMin and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionCumPlPctMin(double value) {
   if (position.cumPlPctMin != value) {
      position.cumPlPctMin = value;

      if (__CHART) {
         if (value == EMPTY_VALUE) str.position.cumPlPctMin = "-";
         else                      str.position.cumPlPctMin = DoubleToStr(value, 2) +" %";
      }
   }
   return(value);
}


/**
 * Set position.cumPlPctMax and update its string representation.
 *
 * @param  double
 *
 * @return double - the same value
 */
double SetPositionCumPlPctMax(double value) {
   if (position.cumPlPctMax != value) {
      position.cumPlPctMax = value;

      if (__CHART) {
         if (value == EMPTY_VALUE) str.position.cumPlPctMax = "-";
         else                      str.position.cumPlPctMax = DoubleToStr(value, 2) +" %";
      }
   }
   return(value);
}
