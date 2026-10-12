// -------------------------------------------------------------------------------
// Support and Resistance - blue and red support and resistance levels displayed
// directly on the chart, with alerts for close above resistance and close below
// support, and optional up/down arrows at those breakouts.
// WARNING: Repainting indicator (based on Bill Williams' Fractals).
//
//   Version 1.03
//   Copyright 2010-2026, EarnForex.com
//   https://www.earnforex.com/metatrader-indicators/Support-and-Resistance/
//   Based on MT4 indicator by Barry Stander
// -------------------------------------------------------------------------------
using System;
using System.Collections.Generic;
using cAlgo.API;

namespace cAlgo
{
    [Indicator(IsOverlay = true, AccessRights = AccessRights.None)]
    public class SupportAndResistance : Indicator
    {
        // Enumeration for the trigger candle:
        public enum ENUM_CANDLE_TO_CHECK
        {
            CURRENT_CANDLE,  // Current (forming) candle
            PREVIOUS_CANDLE  // Previous (just-closed) candle
        };

        [Parameter("Show Alert", DefaultValue = false, Group = "Alerts")]
        public bool IsShowAlert { get; set; }

        [Parameter("Play Sound", DefaultValue = false, Group = "Alerts")]
        public bool IsPlaySound { get; set; }

        [Parameter("Sound", DefaultValue = SoundType.Doorbell, Group = "Alerts")]
        public SoundType AlertSound { get; set; }

        [Parameter("Send Email", DefaultValue = false, Group = "Alerts")]
        public bool IsSendEmail { get; set; }

        [Parameter("Sender Email", Group = "Alerts")]
        public string SenderEmail { get; set; }

        [Parameter("Receiver Email", Group = "Alerts")]
        public string ReceiverEmail { get; set; }

        [Parameter("Trigger Candle (alerts and arrows)", DefaultValue = ENUM_CANDLE_TO_CHECK.PREVIOUS_CANDLE, Group = "Alerts")]
        public ENUM_CANDLE_TO_CHECK TriggerCandle { get; set; }

        [Parameter("Draw Arrows", DefaultValue = false, Group = "Arrows")]
        public bool EnableDrawArrows { get; set; }

        [Parameter("Buy Arrow Icon", DefaultValue = ChartIconType.UpArrow, Group = "Arrows")]
        public ChartIconType BuyArrowIcon { get; set; }

        [Parameter("Sell Arrow Icon", DefaultValue = ChartIconType.DownArrow, Group = "Arrows")]
        public ChartIconType SellArrowIcon { get; set; }

        [Parameter("Buy Arrow Color", DefaultValue = "LimeGreen", Group = "Arrows")]
        public Color BuyArrowColor { get; set; }

        [Parameter("Sell Arrow Color", DefaultValue = "Red", Group = "Arrows")]
        public Color SellArrowColor { get; set; }

        [Parameter("Arrow Distance (pixels)", DefaultValue = 10, MinValue = 0, Group = "Arrows")]
        public int ArrowDistance { get; set; }

        [Output("Resistance", LineColor = "Red", PlotType = PlotType.Points, Thickness = 2)]
        public IndicatorDataSeries Resistance { get; set; }

        [Output("Support", LineColor = "Blue", PlotType = PlotType.Points, Thickness = 2)]
        public IndicatorDataSeries Support { get; set; }

        private const int FractalWing = 2;       // Bars on each side of a fractal: 5-bar fractals, as in MetaTrader.
        private const int LevelRecalcDepth = 4;  // Newest bars whose levels are recomputed on every call: the fractal look-ahead (a fractal needs two newer bars) plus a bar of margin.
        private const string ObjectPrefix = "S&R-ARWS-";

        // Arrows are written once, when their bar is confirmed, and are never revisited afterwards - even though  the fractal levels behind them can still repaint for a few bars.
        // Historical bars are confirmed as soon as their levels are final (two bars later); live bars when they close (first call for the next bar).
        private int _lastConfirmed = -1; // Highest bar index whose arrow has had its confirmed evaluation.

        private readonly Dictionary<DateTime, ChartIcon> _buyArrows = new Dictionary<DateTime, ChartIcon>();
        private readonly Dictionary<DateTime, ChartIcon> _sellArrows = new Dictionary<DateTime, ChartIcon>();

        private DateTime _lastUpAlertBar = DateTime.MinValue;
        private DateTime _lastDownAlertBar = DateTime.MinValue;

        protected override void Initialize()
        {
            _lastConfirmed = -1;
            _buyArrows.Clear();
            _sellArrows.Clear();
            RemoveAllArrows(); // Leftovers from a previous initialization.

            if (EnableDrawArrows)
            {
                // Icons sit at a price, so a distance in pixels has to be re-derived from the chart scale whenever it changes (and on every tick, because the auto-scaled vertical range follows the price).
                Chart.ScrollChanged -= OnChartScrollChanged;
                Chart.ScrollChanged += OnChartScrollChanged;
                Chart.ZoomChanged -= OnChartZoomChanged;
                Chart.ZoomChanged += OnChartZoomChanged;
                Chart.SizeChanged -= OnChartSizeChanged;
                Chart.SizeChanged += OnChartSizeChanged;
            }
        }

        public override void Calculate(int index)
        {
            // cTrader restarts the calculation from the first bar when more history is loaded or the chart is reloaded, and bar indices shift with it.
            // The confirmation bookmark is reset and every bar gets re-evaluated against the levels as they stand then - the equivalent of MetaTrader's full recalculation.
            if (index <= _lastConfirmed) _lastConfirmed = -1;

            UpdateLevels(index);

            if (EnableDrawArrows)
            {
                int confirmUpTo = IsLastBar ? index - 1 : index - FractalWing;
                for (int i = _lastConfirmed + 1; i <= confirmUpTo; i++)
                    SetArrowAt(i);
                if (confirmUpTo > _lastConfirmed) _lastConfirmed = confirmUpTo;

                if (IsLastBar)
                {
                    // Live preview on the forming bar, re-evaluated on every tick; replaced by the confirmed evaluation once the bar closes.
                    if (TriggerCandle == ENUM_CANDLE_TO_CHECK.CURRENT_CANDLE) SetArrowAt(index);
                    RepositionArrows();
                }
            }

            if (IsLastBar) HandleAlerts(index);
        }

        // Resistance = high of the latest upper fractal, Support = low of the latest lower fractal, carried forward until the next one.
        // Only the newest bars can change: a fractal needs two newer bars, so the levels on the last few bars keep moving while those bars form.
        private void UpdateLevels(int index)
        {
            int from = Math.Max(0, index - LevelRecalcDepth);
            for (int i = from; i <= index; i++)
            {
                if (IsUpFractal(i, index)) Resistance[i] = Bars.HighPrices[i];
                else Resistance[i] = (i > 0) ? Resistance[i - 1] : double.NaN;

                if (IsDownFractal(i, index)) Support[i] = Bars.LowPrices[i];
                else Support[i] = (i > 0) ? Support[i - 1] : double.NaN;
            }
        }

        // Standard MetaTrader 5-bar fractal: strictly above the two newer bars, at or above the two older ones.
        // Bars newer than lastIndex are treated as not yet existing, so a historical bar is evaluated exactly as it was when it was the latest one.
        private bool IsUpFractal(int i, int lastIndex)
        {
            if ((i < FractalWing) || (i + FractalWing > lastIndex)) return false;
            double h = Bars.HighPrices[i];
            return (h > Bars.HighPrices[i + 1]) && (h > Bars.HighPrices[i + 2]) && (h >= Bars.HighPrices[i - 1]) && (h >= Bars.HighPrices[i - 2]);
        }

        private bool IsDownFractal(int i, int lastIndex)
        {
            if ((i < FractalWing) || (i + FractalWing > lastIndex)) return false;
            double l = Bars.LowPrices[i];
            return (l < Bars.LowPrices[i + 1]) && (l < Bars.LowPrices[i + 2]) && (l <= Bars.LowPrices[i - 1]) && (l <= Bars.LowPrices[i - 2]);
        }

        // Evaluate the breakout state of the bar at index i and draw or remove its arrow.
        // Same conditions as the alerts: a close above resistance after a close at or below it -> BUY arrow below the bar; a close below support after a close at or above it -> SELL arrow above the bar.
        private void SetArrowAt(int i)
        {
            if ((i < 1) || (i >= Bars.Count)) return; // No previous close to compare against.

            double resistance = Resistance[i];
            double support = Support[i];
            double close = Bars.ClosePrices[i];
            double prevClose = Bars.ClosePrices[i - 1];

            bool buy = (!double.IsNaN(resistance)) && (close > resistance) && (prevClose <= resistance);
            bool sell = (!double.IsNaN(support)) && (close < support) && (prevClose >= support);

            double distance = PixelsToPrice(ArrowDistance);
            DateTime t = Bars.OpenTimes[i];

            if (buy) _buyArrows[t] = Chart.DrawIcon(ArrowName("UP", t), BuyArrowIcon, i, Bars.LowPrices[i] - distance, BuyArrowColor);
            else RemoveArrow(_buyArrows, ArrowName("UP", t), t);

            if (sell) _sellArrows[t] = Chart.DrawIcon(ArrowName("DOWN", t), SellArrowIcon, i, Bars.HighPrices[i] + distance, SellArrowColor);
            else RemoveArrow(_sellArrows, ArrowName("DOWN", t), t);
        }

        private string ArrowName(string direction, DateTime t)
        {
            return ObjectPrefix + direction + "-" + t.ToString("yyyyMMddHHmmss");
        }

        private void RemoveArrow(Dictionary<DateTime, ChartIcon> arrows, string name, DateTime t)
        {
            if (arrows.Remove(t)) Chart.RemoveObject(name);
        }

        private void RemoveAllArrows()
        {
            List<string> names = new List<string>();
            foreach (ChartObject obj in Chart.Objects)
            {
                if (obj.Name.StartsWith(ObjectPrefix)) names.Add(obj.Name);
            }
            foreach (string name in names) Chart.RemoveObject(name);
        }

        // Price equivalent of a vertical distance in pixels at the current chart scale.
        private double PixelsToPrice(int pixels)
        {
            double height = Chart.Height;
            if (height <= 0) return 0;
            return pixels * (Chart.TopY - Chart.BottomY) / height;
        }

        // Re-anchor the arrows in view to the current chart scale.
        // Only visible bars are touched, so the cost is bounded by the number of bars on screen rather than by the number of arrows in history.
        private void RepositionArrows()
        {
            if ((_buyArrows.Count == 0) && (_sellArrows.Count == 0)) return;

            double distance = PixelsToPrice(ArrowDistance);
            int first = Math.Max(0, Chart.FirstVisibleBarIndex);
            int last = Math.Min(Bars.Count - 1, Chart.LastVisibleBarIndex);

            for (int i = first; i <= last; i++)
            {
                DateTime t = Bars.OpenTimes[i];
                ChartIcon icon;
                if (_buyArrows.TryGetValue(t, out icon)) icon.Y = Bars.LowPrices[i] - distance;
                if (_sellArrows.TryGetValue(t, out icon)) icon.Y = Bars.HighPrices[i] + distance;
            }
        }

        private void OnChartScrollChanged(ChartScrollEventArgs args)
        {
            RepositionArrows();
        }

        private void OnChartZoomChanged(ChartZoomEventArgs args)
        {
            RepositionArrows();
        }

        private void OnChartSizeChanged(ChartSizeEventArgs args)
        {
            RepositionArrows();
        }

        // Each alert type fires at most once per trigger bar: the just-closed bar in PREVIOUS_CANDLE mode, the forming bar in CURRENT_CANDLE mode.
        private void HandleAlerts(int index)
        {
            if ((!IsShowAlert) && (!IsPlaySound) && (!IsSendEmail)) return;

            int shift = (TriggerCandle == ENUM_CANDLE_TO_CHECK.PREVIOUS_CANDLE) ? index - 1 : index;
            if (shift < 1) return;

            DateTime bar = Bars.OpenTimes[shift];
            double resistance = Resistance[shift];
            double support = Support[shift];
            double close = Bars.ClosePrices[shift];
            double prevClose = Bars.ClosePrices[shift - 1];

            // Resistance.
            if ((!double.IsNaN(resistance)) && (close > resistance) && (prevClose <= resistance) && (_lastUpAlertBar != bar))
            {
                Notify("Closed above Resistance: " + FormatPrice(resistance) + ".");
                _lastUpAlertBar = bar;
            }
            // Support.
            if ((!double.IsNaN(support)) && (close < support) && (prevClose >= support) && (_lastDownAlertBar != bar))
            {
                Notify("Closed below Support: " + FormatPrice(support) + ".");
                _lastDownAlertBar = bar;
            }
        }

        private void Notify(string text)
        {
            string message = "S&R: " + Symbol.Name + " - " + TimeFrame.ToString() + " - " + text;

            if (IsShowAlert)
            {
                Notifications.ShowPopup("S&R Alert", message, PopupNotificationState.Information);
                Print(message);
            }
            if (IsPlaySound)
            {
                Notifications.PlaySound(AlertSound);
            }
            if ((IsSendEmail) && (!string.IsNullOrWhiteSpace(SenderEmail)) && (!string.IsNullOrWhiteSpace(ReceiverEmail)))
            {
                Notifications.SendEmail(SenderEmail, ReceiverEmail, "S&R Alert", message);
            }
        }

        private string FormatPrice(double price)
        {
            return price.ToString("F" + Symbol.Digits);
        }
    }
}