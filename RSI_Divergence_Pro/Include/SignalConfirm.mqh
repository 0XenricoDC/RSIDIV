//+------------------------------------------------------------------+
//|                                                SignalConfirm.mqh |
//|                                             RSI Divergence Pro   |
//|            Conferma segnali - MTF, Pattern, S/R, ADX             |
//|                         VERSIONE 2.0                              |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Pro"
#property version   "2.00"
#property strict

#include "Utils.mqh"

//+------------------------------------------------------------------+
//| Classe: CSignalConfirm - Multi-Timeframe Signal Confirmation     |
//+------------------------------------------------------------------+
class CSignalConfirm
{
private:
    string              m_symbol;
    ENUM_TIMEFRAMES     m_tfEntry;       // Timeframe entry (H1)
    ENUM_TIMEFRAMES     m_tfTrend;       // Timeframe trend (D1)
    ENUM_TIMEFRAMES     m_tfSetup;       // Timeframe setup (H4)

    // Handle indicatori
    int                 m_emaFastHandle;  // EMA 50 su TF_Trend
    int                 m_emaSlowHandle;  // EMA 200 su TF_Trend
    int                 m_adxHandle;      // ADX su TF_Setup

    // Buffer indicatori
    double              m_emaFastBuffer[];
    double              m_emaSlowBuffer[];
    double              m_adxBuffer[];
    double              m_plusDIBuffer[];
    double              m_minusDIBuffer[];

    // Parametri candlestick
    double              m_pinBarBodyRatio;
    double              m_pinBarWickRatio;
    double              m_dojiBodyRatio;

    // Parametri EMA e ADX
    int                 m_emaFastPeriod;
    int                 m_emaSlowPeriod;
    int                 m_adxPeriod;

    // S/R parameters
    int                 m_srLookback;
    double              m_srProximityPips;

public:
    //+------------------------------------------------------------------+
    //| Constructor                                                       |
    //+------------------------------------------------------------------+
    CSignalConfirm()
    {
        m_symbol = "";
        m_tfEntry = PERIOD_H1;
        m_tfTrend = PERIOD_D1;
        m_tfSetup = PERIOD_H4;
        m_emaFastHandle = INVALID_HANDLE;
        m_emaSlowHandle = INVALID_HANDLE;
        m_adxHandle = INVALID_HANDLE;
        m_pinBarBodyRatio = 0.3;
        m_pinBarWickRatio = 0.6;
        m_dojiBodyRatio = 0.1;
        m_emaFastPeriod = 50;
        m_emaSlowPeriod = 200;
        m_adxPeriod = 14;
        m_srLookback = 100;
        m_srProximityPips = 20.0;
    }

    ~CSignalConfirm() { Deinitialize(); }

    //+------------------------------------------------------------------+
    //| Inizializzazione Multi-Timeframe                                  |
    //+------------------------------------------------------------------+
    bool Initialize(string symbol, ENUM_TIMEFRAMES tfEntry,
                    ENUM_TIMEFRAMES tfTrend = PERIOD_D1,
                    ENUM_TIMEFRAMES tfSetup = PERIOD_H4,
                    int emaFast = 50, int emaSlow = 200, int adxPeriod = 14)
    {
        m_symbol = symbol;
        m_tfEntry = tfEntry;
        m_tfTrend = tfTrend;
        m_tfSetup = tfSetup;
        m_emaFastPeriod = emaFast;
        m_emaSlowPeriod = emaSlow;
        m_adxPeriod = adxPeriod;

        // Crea handle EMA Fast su TF_Trend
        m_emaFastHandle = iMA(m_symbol, m_tfTrend, m_emaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
        if(!IsValidHandle(m_emaFastHandle))
        {
            LogMessage("SignalConfirm: Impossibile creare handle EMA Fast", true);
            return false;
        }

        // Crea handle EMA Slow su TF_Trend
        m_emaSlowHandle = iMA(m_symbol, m_tfTrend, m_emaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
        if(!IsValidHandle(m_emaSlowHandle))
        {
            LogMessage("SignalConfirm: Impossibile creare handle EMA Slow", true);
            return false;
        }

        // Crea handle ADX su TF_Setup
        m_adxHandle = iADX(m_symbol, m_tfSetup, m_adxPeriod);
        if(!IsValidHandle(m_adxHandle))
        {
            LogMessage("SignalConfirm: Impossibile creare handle ADX", true);
            return false;
        }

        // Configura buffer
        ArraySetAsSeries(m_emaFastBuffer, true);
        ArraySetAsSeries(m_emaSlowBuffer, true);
        ArraySetAsSeries(m_adxBuffer, true);
        ArraySetAsSeries(m_plusDIBuffer, true);
        ArraySetAsSeries(m_minusDIBuffer, true);

        LogMessage(StringFormat("SignalConfirm MTF: Entry=%s, Trend=%s, Setup=%s | EMA %d/%d | ADX %d",
                                EnumToString(m_tfEntry), EnumToString(m_tfTrend), EnumToString(m_tfSetup),
                                m_emaFastPeriod, m_emaSlowPeriod, m_adxPeriod));
        return true;
    }

    //+------------------------------------------------------------------+
    //| Inizializzazione semplificata (compatibilita')                    |
    //+------------------------------------------------------------------+
    bool Initialize(string symbol, ENUM_TIMEFRAMES timeframe, int emaPeriod = 200)
    {
        return Initialize(symbol, timeframe, PERIOD_D1, PERIOD_H4, 50, emaPeriod, 14);
    }

    //+------------------------------------------------------------------+
    //| Deinizializzazione                                                |
    //+------------------------------------------------------------------+
    void Deinitialize()
    {
        if(m_emaFastHandle != INVALID_HANDLE)
        {
            IndicatorRelease(m_emaFastHandle);
            m_emaFastHandle = INVALID_HANDLE;
        }
        if(m_emaSlowHandle != INVALID_HANDLE)
        {
            IndicatorRelease(m_emaSlowHandle);
            m_emaSlowHandle = INVALID_HANDLE;
        }
        if(m_adxHandle != INVALID_HANDLE)
        {
            IndicatorRelease(m_adxHandle);
            m_adxHandle = INVALID_HANDLE;
        }
    }

    //+------------------------------------------------------------------+
    //| Setters per parametri                                             |
    //+------------------------------------------------------------------+
    void SetSRParameters(int lookback, double proximityPips)
    {
        m_srLookback = lookback;
        m_srProximityPips = proximityPips;
    }

    void SetPinBarParameters(double bodyRatio, double wickRatio)
    {
        m_pinBarBodyRatio = bodyRatio;
        m_pinBarWickRatio = wickRatio;
    }

    void SetDojiBodyRatio(double ratio) { m_dojiBodyRatio = ratio; }

    //+------------------------------------------------------------------+
    //| Verifica conferma in base al tipo                                 |
    //+------------------------------------------------------------------+
    bool HasConfirmation(ENUM_CONFIRM_TYPE confirmType, bool isBullish)
    {
        switch(confirmType)
        {
            case CONFIRM_NONE:
                return true;

            case CONFIRM_PINBAR:
                return IsPinBar(isBullish);

            case CONFIRM_ENGULFING:
                return IsEngulfing(isBullish);

            case CONFIRM_DOJI:
                return IsDoji(1);

            case CONFIRM_ANY_PATTERN:
                return IsPinBar(isBullish) || IsEngulfing(isBullish) || IsDoji(1);

            case CONFIRM_EMA_TREND:
                return ConfirmEMATrend(isBullish);

            default:
                return true;
        }
    }

    //+------------------------------------------------------------------+
    //| Verifica Pin Bar - ANTI-REPAINTING: solo barra 1 (chiusa)        |
    //+------------------------------------------------------------------+
    bool IsPinBar(bool bullish, int bar = 1)
    {
        double open  = iOpen(m_symbol, m_tfEntry, bar);
        double high  = iHigh(m_symbol, m_tfEntry, bar);
        double low   = iLow(m_symbol, m_tfEntry, bar);
        double close = iClose(m_symbol, m_tfEntry, bar);

        double body = MathAbs(close - open);
        double range = high - low;

        if(range == 0) return false;
        if((body / range) > m_pinBarBodyRatio) return false;

        if(bullish)
        {
            double lowerWick = MathMin(open, close) - low;
            double upperWick = high - MathMax(open, close);
            return ((lowerWick / range) >= m_pinBarWickRatio && (upperWick / range) <= 0.2);
        }
        else
        {
            double upperWick = high - MathMax(open, close);
            double lowerWick = MathMin(open, close) - low;
            return ((upperWick / range) >= m_pinBarWickRatio && (lowerWick / range) <= 0.2);
        }
    }

    //+------------------------------------------------------------------+
    //| Verifica Engulfing - ANTI-REPAINTING: solo barre 1 e 2           |
    //+------------------------------------------------------------------+
    bool IsEngulfing(bool bullish, int bar = 1)
    {
        double open1  = iOpen(m_symbol, m_tfEntry, bar);
        double close1 = iClose(m_symbol, m_tfEntry, bar);
        double open2  = iOpen(m_symbol, m_tfEntry, bar + 1);
        double close2 = iClose(m_symbol, m_tfEntry, bar + 1);

        double body1 = MathAbs(close1 - open1);
        double body2 = MathAbs(close2 - open2);

        if(body1 == 0 || body1 <= body2) return false;

        if(bullish)
        {
            bool bar2Bearish = open2 > close2;
            bool bar1Bullish = close1 > open1;
            bool engulfs = (open1 <= close2) && (close1 >= open2);
            return bar2Bearish && bar1Bullish && engulfs;
        }
        else
        {
            bool bar2Bullish = close2 > open2;
            bool bar1Bearish = open1 > close1;
            bool engulfs = (open1 >= close2) && (close1 <= open2);
            return bar2Bullish && bar1Bearish && engulfs;
        }
    }

    //+------------------------------------------------------------------+
    //| Verifica Doji - Candela con body molto piccolo                   |
    //+------------------------------------------------------------------+
    bool IsDoji(int bar = 1)
    {
        double open  = iOpen(m_symbol, m_tfEntry, bar);
        double high  = iHigh(m_symbol, m_tfEntry, bar);
        double low   = iLow(m_symbol, m_tfEntry, bar);
        double close = iClose(m_symbol, m_tfEntry, bar);

        double body = MathAbs(close - open);
        double range = high - low;

        if(range == 0) return false;

        // Doji ha un body molto piccolo rispetto al range
        return (body / range) <= m_dojiBodyRatio;
    }

    //+------------------------------------------------------------------+
    //| Conferma EMA Trend su TF_Trend                                   |
    //+------------------------------------------------------------------+
    bool ConfirmEMATrend(bool bullish)
    {
        if(CopyBuffer(m_emaFastHandle, 0, 1, 1, m_emaFastBuffer) < 1) return false;
        if(CopyBuffer(m_emaSlowHandle, 0, 1, 1, m_emaSlowBuffer) < 1) return false;

        double emaFast = m_emaFastBuffer[0];
        double emaSlow = m_emaSlowBuffer[0];
        double close = iClose(m_symbol, m_tfTrend, 1);

        if(bullish)
        {
            // Bullish: EMA50 > EMA200 e prezzo > EMA50
            return (emaFast > emaSlow && close > emaFast);
        }
        else
        {
            // Bearish: EMA50 < EMA200 e prezzo < EMA50
            return (emaFast < emaSlow && close < emaFast);
        }
    }

    //+------------------------------------------------------------------+
    //| Ottiene direzione trend da EMA 50/200 su TF_Trend                |
    //+------------------------------------------------------------------+
    ENUM_TREND_DIRECTION GetTrendDirection()
    {
        if(CopyBuffer(m_emaFastHandle, 0, 1, 3, m_emaFastBuffer) < 3) return TREND_FLAT;
        if(CopyBuffer(m_emaSlowHandle, 0, 1, 3, m_emaSlowBuffer) < 3) return TREND_FLAT;

        double emaFast = m_emaFastBuffer[0];
        double emaSlow = m_emaSlowBuffer[0];
        double close = iClose(m_symbol, m_tfTrend, 1);

        // EMA50 significativamente sopra EMA200 = uptrend
        double threshold = emaSlow * 0.001; // 0.1% tolerance

        if(emaFast > emaSlow + threshold && close > emaFast)
            return TREND_UP;
        else if(emaFast < emaSlow - threshold && close < emaFast)
            return TREND_DOWN;
        else
            return TREND_FLAT;
    }

    //+------------------------------------------------------------------+
    //| Verifica allineamento trend con divergenza                       |
    //+------------------------------------------------------------------+
    bool IsTrendAligned(ENUM_DIVERGENCE_TYPE divType, ENUM_TREND_DIRECTION trend)
    {
        // Regular divergence: contro trend (reversal)
        // Hidden divergence: con trend (continuation)

        bool isBullishDiv = IsBullishDivergence(divType);
        bool isRegular = (divType == DIVERGENCE_BULLISH_REGULAR || divType == DIVERGENCE_BEARISH_REGULAR);

        if(isRegular)
        {
            // Regular bullish: preferito in downtrend (reversal)
            // Regular bearish: preferito in uptrend (reversal)
            if(isBullishDiv)
                return (trend == TREND_DOWN || trend == TREND_FLAT);
            else
                return (trend == TREND_UP || trend == TREND_FLAT);
        }
        else
        {
            // Hidden bullish: preferito in uptrend (continuation)
            // Hidden bearish: preferito in downtrend (continuation)
            if(isBullishDiv)
                return (trend == TREND_UP || trend == TREND_FLAT);
            else
                return (trend == TREND_DOWN || trend == TREND_FLAT);
        }
    }

    //+------------------------------------------------------------------+
    //| Verifica filtro ADX                                              |
    //+------------------------------------------------------------------+
    bool PassesADXFilter(int minADX = 15, int maxADX = 35)
    {
        if(CopyBuffer(m_adxHandle, 0, 1, 1, m_adxBuffer) < 1) return true; // Se errore, passa

        double adx = m_adxBuffer[0];
        return (adx >= minADX && adx <= maxADX);
    }

    //+------------------------------------------------------------------+
    //| Ottiene valore ADX corrente                                      |
    //+------------------------------------------------------------------+
    double GetADX()
    {
        if(CopyBuffer(m_adxHandle, 0, 1, 1, m_adxBuffer) < 1) return 0;
        return m_adxBuffer[0];
    }

    //+------------------------------------------------------------------+
    //| Ottiene +DI e -DI                                                |
    //+------------------------------------------------------------------+
    bool GetDI(double &plusDI, double &minusDI)
    {
        if(CopyBuffer(m_adxHandle, 1, 1, 1, m_plusDIBuffer) < 1) return false;
        if(CopyBuffer(m_adxHandle, 2, 1, 1, m_minusDIBuffer) < 1) return false;

        plusDI = m_plusDIBuffer[0];
        minusDI = m_minusDIBuffer[0];
        return true;
    }

    //+------------------------------------------------------------------+
    //| Trova supporto piu' vicino                                       |
    //+------------------------------------------------------------------+
    double FindNearestSupport(double currentPrice, int lookback = 0)
    {
        if(lookback == 0) lookback = m_srLookback;

        double nearestSupport = 0;
        double minDistance = DBL_MAX;

        for(int i = 1; i <= lookback; i++)
        {
            double low = iLow(m_symbol, m_tfEntry, i);

            // Verifica se e' un supporto (swing low locale)
            if(IsLocalSwingLow(i, 3))
            {
                double distance = currentPrice - low;
                if(distance > 0 && distance < minDistance)
                {
                    minDistance = distance;
                    nearestSupport = low;
                }
            }
        }

        return nearestSupport;
    }

    //+------------------------------------------------------------------+
    //| Trova resistenza piu' vicina                                     |
    //+------------------------------------------------------------------+
    double FindNearestResistance(double currentPrice, int lookback = 0)
    {
        if(lookback == 0) lookback = m_srLookback;

        double nearestResistance = 0;
        double minDistance = DBL_MAX;

        for(int i = 1; i <= lookback; i++)
        {
            double high = iHigh(m_symbol, m_tfEntry, i);

            // Verifica se e' una resistenza (swing high locale)
            if(IsLocalSwingHigh(i, 3))
            {
                double distance = high - currentPrice;
                if(distance > 0 && distance < minDistance)
                {
                    minDistance = distance;
                    nearestResistance = high;
                }
            }
        }

        return nearestResistance;
    }

    //+------------------------------------------------------------------+
    //| Verifica se prezzo e' vicino a supporto                          |
    //+------------------------------------------------------------------+
    bool IsNearSupport(double price, int lookback = 0, double proximityPips = 0)
    {
        if(lookback == 0) lookback = m_srLookback;
        if(proximityPips == 0) proximityPips = m_srProximityPips;

        double support = FindNearestSupport(price, lookback);
        if(support == 0) return false;

        double distance = MathAbs(price - support);
        double proximityPrice = PipsToPrice(m_symbol, proximityPips);

        return (distance <= proximityPrice);
    }

    //+------------------------------------------------------------------+
    //| Verifica se prezzo e' vicino a resistenza                        |
    //+------------------------------------------------------------------+
    bool IsNearResistance(double price, int lookback = 0, double proximityPips = 0)
    {
        if(lookback == 0) lookback = m_srLookback;
        if(proximityPips == 0) proximityPips = m_srProximityPips;

        double resistance = FindNearestResistance(price, lookback);
        if(resistance == 0) return false;

        double distance = MathAbs(resistance - price);
        double proximityPrice = PipsToPrice(m_symbol, proximityPips);

        return (distance <= proximityPrice);
    }

    //+------------------------------------------------------------------+
    //| Verifica confluenza S/R per divergenza                           |
    //+------------------------------------------------------------------+
    bool HasSRConfluence(bool isBullish, double price, int lookback = 0, double proximityPips = 0)
    {
        if(isBullish)
            return IsNearSupport(price, lookback, proximityPips);
        else
            return IsNearResistance(price, lookback, proximityPips);
    }

    //+------------------------------------------------------------------+
    //| Ottiene EMA values                                               |
    //+------------------------------------------------------------------+
    double GetEMAFast()
    {
        if(CopyBuffer(m_emaFastHandle, 0, 1, 1, m_emaFastBuffer) < 1) return 0;
        return m_emaFastBuffer[0];
    }

    double GetEMASlow()
    {
        if(CopyBuffer(m_emaSlowHandle, 0, 1, 1, m_emaSlowBuffer) < 1) return 0;
        return m_emaSlowBuffer[0];
    }

    //+------------------------------------------------------------------+
    //| Getter handles per uso esterno                                   |
    //+------------------------------------------------------------------+
    int GetEMAFastHandle()  { return m_emaFastHandle; }
    int GetEMASlowHandle()  { return m_emaSlowHandle; }
    int GetADXHandle()      { return m_adxHandle; }

private:
    //+------------------------------------------------------------------+
    //| Helper: Verifica swing low locale                                |
    //+------------------------------------------------------------------+
    bool IsLocalSwingLow(int bar, int strength)
    {
        if(bar < strength || bar + strength >= m_srLookback) return false;

        double centerLow = iLow(m_symbol, m_tfEntry, bar);

        for(int i = 1; i <= strength; i++)
        {
            if(iLow(m_symbol, m_tfEntry, bar - i) <= centerLow) return false;
            if(iLow(m_symbol, m_tfEntry, bar + i) <= centerLow) return false;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| Helper: Verifica swing high locale                               |
    //+------------------------------------------------------------------+
    bool IsLocalSwingHigh(int bar, int strength)
    {
        if(bar < strength || bar + strength >= m_srLookback) return false;

        double centerHigh = iHigh(m_symbol, m_tfEntry, bar);

        for(int i = 1; i <= strength; i++)
        {
            if(iHigh(m_symbol, m_tfEntry, bar - i) >= centerHigh) return false;
            if(iHigh(m_symbol, m_tfEntry, bar + i) >= centerHigh) return false;
        }

        return true;
    }
};
