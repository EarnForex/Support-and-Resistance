//+------------------------------------------------------------------+
//|                                       Support and Resistance.mq4 |
//|                                 Copyright © 2010-2022, EarnForex |
//|                                        https://www.earnforex.com |
//|                       Based on indicator by Barry Stander (2004) |
//+------------------------------------------------------------------+
#property copyright "www.EarnForex.com, 2010-2022"
#property link      "https://www.earnforex.com/metatrader-indicators/Support-and-Resistance/"
#property version   "1.02"
#property strict

#property description "Blue and red support and resistance levels displayed directly on the chart."
#property description "Alerts for close above resistance and close below support."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1 clrRed
#property indicator_width1 2
#property indicator_type1  DRAW_ARROW
#property indicator_label1 "Resistance"
#property indicator_color2 clrBlue
#property indicator_width2 2
#property indicator_type2  DRAW_ARROW
#property indicator_label2 "Support"

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

datetime LastAlertTime = D'01.01.1970';

void OnInit()
{
    SetIndexBuffer(0, Resistance);
    SetIndexBuffer(1, Support);

    SetIndexArrow(0, 119);
    SetIndexArrow(1, 119);

    SetIndexDrawBegin(0, 5);
    SetIndexDrawBegin(1, 5);
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
    
    return rates_total;
}
//+------------------------------------------------------------------+