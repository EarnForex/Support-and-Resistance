//+------------------------------------------------------------------+
//|                                       Support and Resistance.mq5 |
//|                                 Copyright © 2010-2022, EarnForex |
//|                                       https://www.earnforex.com/ |
//|                          Based on MT4 indicator by Barry Stander |
//+------------------------------------------------------------------+
#property copyright "www.EarnForex.com, 2010-2022"
#property link      "https://www.earnforex.com/metatrader-indicators/Support-and-Resistance/"
#property version   "1.02"

#property description "Blue and red support and resistance levels displayed directly on the chart."
#property description "Alerts for close above resistance and close below support."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_color1  clrRed
#property indicator_type1   DRAW_ARROW
#property indicator_width1  2
#property indicator_label1  "Resistance"
#property indicator_color2  clrBlue
#property indicator_type2   DRAW_ARROW
#property indicator_width2  2
#property indicator_label2  "Support"

enum enum_candle_to_check
{
    Current,
    Previous
};

input bool EnableNativeAlerts = false;
input bool EnableEmailAlerts  = false;
input bool EnablePushAlerts   = false;
input enum_candle_to_check TriggerCandle = Previous;

double Resistance[];
double Support[];

int myFractal;

datetime LastAlertTime = D'01.01.1970';

void OnInit()
{
    PlotIndexSetInteger(0, PLOT_ARROW, 119);
    PlotIndexSetInteger(1, PLOT_ARROW, 119);

    SetIndexBuffer(0, Resistance);
    SetIndexBuffer(1, Support);

    ArraySetAsSeries(Resistance, true);
    ArraySetAsSeries(Support, true);

    PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 5);
    PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, 5);
    
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

    //Get the values of the Fractals indicator before entering the cycle.
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

    return rates_total;
}
//+------------------------------------------------------------------+