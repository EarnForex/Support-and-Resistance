//+------------------------------------------------------------------+
//|                                       Support and Resistance.mq4 |
//|                                 Copyright © 2010-2026, EarnForex |
//|                                        https://www.earnforex.com |
//|                       Based on indicator by Barry Stander (2004) |
//+------------------------------------------------------------------+
#property copyright "www.EarnForex.com, 2010-2026"
#property link      "https://www.earnforex.com/metatrader-indicators/Support-and-Resistance/"
#property version   "1.03"
#property strict

#property description "Blue and red support and resistance levels displayed directly on the chart."
#property description "Alerts for close above resistance and close below support."
#property description "Optional up/down arrows on the chart at those breakouts."
#property description "WARNING: Repainting indicator (based on Bill Williams' Fractals)."

#property indicator_chart_window
#property indicator_buffers 4
#property indicator_color1 clrRed
#property indicator_width1 2
#property indicator_type1  DRAW_ARROW
#property indicator_label1 "Resistance"
#property indicator_color2 clrBlue
#property indicator_width2 2
#property indicator_type2  DRAW_ARROW
#property indicator_label2 "Support"
#property indicator_color3 clrLimeGreen
#property indicator_width3 3
#property indicator_type3  DRAW_ARROW
#property indicator_label3 "Up"
#property indicator_color4 clrRed
#property indicator_width4 3
#property indicator_type4  DRAW_ARROW
#property indicator_label4 "Down"

enum enum_candle_to_check
{
    Current,  // Current (forming) candle
    Previous  // Previous (just-closed) candle
};

input string Comment_Alerts     = "======================="; // Alerts
input bool   EnableNativeAlerts = false;                     // Alert via popup
input bool   EnableEmailAlerts  = false;                     // Alert via email
input bool   EnablePushAlerts   = false;                     // Alert via push notification
input enum_candle_to_check TriggerCandle = Previous;         // Trigger candle for alerts and arrows

input string Comment_Arrows     = "======================="; // Arrows
input bool   EnableDrawArrows   = false;                     // Draw arrows on chart at breakouts
input int    ArrowBuyCode       = 241;                       // Buy arrow code (close above resistance)
input int    ArrowSellCode      = 242;                       // Sell arrow code (close below support)
input double ArrowDistance      = 0.3;                       // Distance to candle as fraction of ATR(14)

double Resistance[];
double Support[];
double BuyArrow[];
double SellArrow[];

datetime LastAlertTime = D'01.01.1970';

void OnInit()
{
    SetIndexBuffer(0, Resistance);
    SetIndexBuffer(1, Support);
    SetIndexBuffer(2, BuyArrow);
    SetIndexBuffer(3, SellArrow);

    SetIndexArrow(0, 119);
    SetIndexArrow(1, 119);
    SetIndexArrow(2, ArrowBuyCode);
    SetIndexArrow(3, ArrowSellCode);

    SetIndexDrawBegin(0, 5);
    SetIndexDrawBegin(1, 5);

    if (EnableDrawArrows)
    {
        // Draw type and label only - width and color are left to the Colors tab.
        SetIndexStyle(2, DRAW_ARROW);
        SetIndexStyle(3, DRAW_ARROW);
        SetIndexLabel(2, "Up");
        SetIndexLabel(3, "Down");
    }
    else
    {
        // Arrows off: keep the buffers out of the chart and the Data Window. They are not calculated either.
        SetIndexStyle(2, DRAW_NONE);
        SetIndexStyle(3, DRAW_NONE);
        SetIndexLabel(2, NULL);
        SetIndexLabel(3, NULL);
    }
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime& time[],
                const double& open[],
                const double& high[],
                const double& low[],
                const double& close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[]
)
{
    if (rates_total < 5) return 0;
    for (int i = rates_total - 2; i >= 0; i--)
    {
        double upper_fractal = iFractals(NULL, 0, MODE_UPPER, i);
        if (upper_fractal > 0)
            Resistance[i] = High[i];
        else
            Resistance[i] = Resistance[i + 1];

        double lower_fractal = iFractals(NULL, 0, MODE_LOWER, i);
        if (lower_fractal > 0)
            Support[i] = Low[i];
        else
            Support[i] = Support[i + 1];
    }

    // Alerts
    if (((TriggerCandle > 0) && (Time[0] > LastAlertTime)) || (TriggerCandle == 0))
    {
        string Text;
        // Resistance.
        if ((Close[TriggerCandle] > Resistance[TriggerCandle]) && (Close[TriggerCandle + 1] <= Resistance[TriggerCandle]))
        {
            Text = "S&R: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - Closed above Resistance: " + DoubleToString(Resistance[TriggerCandle], _Digits) + ".";
            if (EnableNativeAlerts) Alert(Text);
            if (EnableEmailAlerts) SendMail("S&R Alert", Text);
            if (EnablePushAlerts) SendNotification(Text);
            LastAlertTime = Time[0];
        }
        // Support.
        if ((Close[TriggerCandle] < Support[TriggerCandle]) && (Close[TriggerCandle + 1] >= Support[TriggerCandle]))
        {
            Text = "S&R: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - Closed below Support: " + DoubleToString(Support[TriggerCandle], _Digits) + ".";
            if (EnableNativeAlerts) Alert(Text);
            if (EnableEmailAlerts) SendMail("S&R Alert", Text);
            if (EnablePushAlerts) SendNotification(Text);
            LastAlertTime = Time[0];
        }
    }

    if (EnableDrawArrows)
    {
        int oldest_shift; // Oldest bar still waiting for its confirmed evaluation.
        if (prev_calculated == 0) oldest_shift = rates_total - 2;               // Full pass: every bar that has a previous close.
        else                      oldest_shift = rates_total - prev_calculated; // Bars closed since the previous call (0 if none).
        if (oldest_shift > rates_total - 2) oldest_shift = rates_total - 2;

        for (int s = oldest_shift; s >= 1; s--)
            SetArrowAt(s, rates_total);

        if (TriggerCandle == Current)
        {
            SetArrowAt(0, rates_total);
        }
        else
        {
            BuyArrow[0]  = EMPTY_VALUE;
            SellArrow[0] = EMPTY_VALUE;
        }
    }

    return rates_total;
}

void SetArrowAt(int s, int rates_total)
{
    if (s < 0)               return;
    if (s > rates_total - 2) return; // No previous close to compare against.

    double resistance_level = Resistance[s];
    double support_level    = Support[s];

    bool buy  = (resistance_level != EMPTY_VALUE) && (Close[s] > resistance_level) && (Close[s + 1] <= resistance_level);
    bool sell = (support_level    != EMPTY_VALUE) && (Close[s] < support_level)    && (Close[s + 1] >= support_level);

    BuyArrow[s]  = EMPTY_VALUE;
    SellArrow[s] = EMPTY_VALUE;
    if (!buy && !sell) return;

    double gap = ArrowDistance * iATR(NULL, 0, 14, s);
    if (buy)  BuyArrow[s]  = Low[s]  - gap;
    if (sell) SellArrow[s] = High[s] + gap;
}
//+------------------------------------------------------------------+