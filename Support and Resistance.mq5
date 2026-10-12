//+------------------------------------------------------------------+
//|                                       Support and Resistance.mq5 |
//|                                 Copyright © 2010-2026, EarnForex |
//|                                       https://www.earnforex.com/ |
//|                          Based on MT4 indicator by Barry Stander |
//+------------------------------------------------------------------+
#property copyright "www.EarnForex.com, 2010-2026"
#property link      "https://www.earnforex.com/metatrader-indicators/Support-and-Resistance/"
#property version   "1.03"

#property description "Blue and red support and resistance levels displayed directly on the chart."
#property description "Alerts for close above resistance and close below support."
#property description "Optional up/down arrows on the chart at those breakouts."
#property description "WARNING: Repainting indicator (based on Bill Williams' Fractals)."

#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4
#property indicator_color1  clrRed
#property indicator_type1   DRAW_ARROW
#property indicator_width1  2
#property indicator_label1  "Resistance"
#property indicator_color2  clrBlue
#property indicator_type2   DRAW_ARROW
#property indicator_width2  2
#property indicator_label2  "Support"
#property indicator_color3  clrLimeGreen
#property indicator_type3   DRAW_ARROW
#property indicator_width3  3
#property indicator_label3  "Up"
#property indicator_color4  clrRed
#property indicator_type4   DRAW_ARROW
#property indicator_width4  3
#property indicator_label4  "Down"

enum enum_candle_to_check
{
    Current,  // Current (forming) candle
    Previous  // Previous (just-closed) candle
};

input group "Alerts"
input bool EnableNativeAlerts = false;   // Alert via popup
input bool EnableEmailAlerts  = false;   // Alert via email
input bool EnablePushAlerts   = false;   // Alert via push notification
input enum_candle_to_check TriggerCandle = Previous; // Trigger candle for alerts and arrows

input group "Arrows"
input bool EnableDrawArrows   = false;   // Draw arrows on chart at breakouts
input int  ArrowBuyCode       = 241;     // Buy arrow code (close above resistance)
input int  ArrowSellCode      = 242;     // Sell arrow code (close below support)
input int  ArrowDistance      = 10;      // Distance to candle in pixels

double Resistance[];
double Support[];
double BuyArrow[];
double SellArrow[];

int myFractal;

datetime LastAlertTime = D'01.01.1970';

void OnInit()
{
    SetIndexBuffer(0, Resistance);
    SetIndexBuffer(1, Support);
    SetIndexBuffer(2, BuyArrow);
    SetIndexBuffer(3, SellArrow);

    ArraySetAsSeries(Resistance, true);
    ArraySetAsSeries(Support, true);
    ArraySetAsSeries(BuyArrow, true);
    ArraySetAsSeries(SellArrow, true);

    PlotIndexSetInteger(0, PLOT_ARROW, 119);
    PlotIndexSetInteger(1, PLOT_ARROW, 119);

    PlotIndexSetInteger(2, PLOT_ARROW_SHIFT,  ArrowDistance);
    PlotIndexSetInteger(3, PLOT_ARROW_SHIFT, -ArrowDistance);


    PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 5);
    PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 5);

    PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);

    if (EnableDrawArrows)
    {
        PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_ARROW);
        PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_ARROW);
        PlotIndexSetInteger(2, PLOT_ARROW, ArrowBuyCode);
        PlotIndexSetInteger(3, PLOT_ARROW, ArrowSellCode);
        PlotIndexSetInteger(2, PLOT_SHOW_DATA, true);
        PlotIndexSetInteger(3, PLOT_SHOW_DATA, true);
    }
    else
    {
        PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
        PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_NONE);
        PlotIndexSetInteger(2, PLOT_SHOW_DATA, false);
        PlotIndexSetInteger(3, PLOT_SHOW_DATA, false);
    }

    myFractal = iFractals(NULL, 0);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &Time[],
                const double &open[],
                const double &High[],
                const double &Low[],
                const double &Close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    ArraySetAsSeries(High, true);
    ArraySetAsSeries(Low, true);
    ArraySetAsSeries(Close, true);
    ArraySetAsSeries(Time, true);

    // Get the values of the Fractals indicator before entering the cycle.
    double FractalUpperBuffer[];
    double FractalLowerBuffer[];

    CopyBuffer(myFractal, 0, 0, rates_total, FractalUpperBuffer);
    CopyBuffer(myFractal, 1, 0, rates_total, FractalLowerBuffer);

    ArraySetAsSeries(FractalUpperBuffer, true);
    ArraySetAsSeries(FractalLowerBuffer, true);

    for (int i = rates_total - 2; i >= 0; i--)
    {
        if (FractalUpperBuffer[i] != EMPTY_VALUE) Resistance[i] = High[i];
        else Resistance[i] = Resistance[i + 1];

        if (FractalLowerBuffer[i] != EMPTY_VALUE) Support[i] = Low[i];
        else Support[i] = Support[i + 1];
    }

    // Alerts
    if (((TriggerCandle > 0) && (Time[0] > LastAlertTime)) || (TriggerCandle == 0))
    {
        string Text, TextNative;
        // Resistance.
        if ((Close[TriggerCandle] > Resistance[TriggerCandle]) && (Close[TriggerCandle + 1] <= Resistance[TriggerCandle]))
        {
            Text = "S&R: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - Closed above Resistance: " + DoubleToString(Resistance[TriggerCandle], _Digits) + ".";
            TextNative = "S&R: Closed above Resistance: " + DoubleToString(Resistance[TriggerCandle], _Digits) + ".";
            if (EnableNativeAlerts) Alert(TextNative);
            if (EnableEmailAlerts) SendMail("S&R Alert", Text);
            if (EnablePushAlerts) SendNotification(Text);
            LastAlertTime = Time[0];
        }
        // Support.
        if ((Close[TriggerCandle] < Support[TriggerCandle]) && (Close[TriggerCandle + 1] >= Support[TriggerCandle]))
        {
            Text = "S&R: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - Closed below Support: " + DoubleToString(Support[TriggerCandle], _Digits) + ".";
            TextNative = "S&R: Closed below Support: " + DoubleToString(Support[TriggerCandle], _Digits) + ".";
            if (EnableNativeAlerts) Alert(TextNative);
            if (EnableEmailAlerts) SendMail("S&R Alert", Text);
            if (EnablePushAlerts) SendNotification(Text);
            LastAlertTime = Time[0];
        }
    }

    if (EnableDrawArrows)
    {
        int oldest_shift; // Oldest bar still waiting for its confirmed evaluation.
        if (prev_calculated == 0)
        {
            ArrayInitialize(BuyArrow, EMPTY_VALUE);
            ArrayInitialize(SellArrow, EMPTY_VALUE);
            oldest_shift = rates_total - 2;               // Full pass: every bar that has a previous close.
        }
        else
        {
            oldest_shift = rates_total - prev_calculated; // Bars closed since the previous call (0 if none).
        }
        if (oldest_shift > rates_total - 2) oldest_shift = rates_total - 2;

        for (int s = oldest_shift; s >= 1; s--)
            SetArrowAt(s, rates_total, High, Low, Close);

        if (TriggerCandle == Current)
        {
            SetArrowAt(0, rates_total, High, Low, Close);
        }
        else
        {
            BuyArrow[0]  = EMPTY_VALUE;
            SellArrow[0] = EMPTY_VALUE;
        }
    }

    return rates_total;
}

void SetArrowAt(const int s, const int rates_total, const double &High[], const double &Low[], const double &Close[])
{
    if (s < 0)               return;
    if (s > rates_total - 2) return; // No previous close to compare against.

    double resistance_level = Resistance[s];
    double support_level    = Support[s];

    bool buy  = (resistance_level != EMPTY_VALUE) && (Close[s] > resistance_level) && (Close[s + 1] <= resistance_level);
    bool sell = (support_level    != EMPTY_VALUE) && (Close[s] < support_level)    && (Close[s + 1] >= support_level);

    BuyArrow[s]  = buy  ? Low[s]  : EMPTY_VALUE;
    SellArrow[s] = sell ? High[s] : EMPTY_VALUE;
}
//+------------------------------------------------------------------+