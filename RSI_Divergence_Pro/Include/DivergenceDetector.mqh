//+------------------------------------------------------------------+
//|                                          DivergenceDetector.mqh  |
//|                                             RSI Divergence Pro   |
//|                    Detection divergenze RSI - NO REPAINTING      |
//|                         VERSIONE 3.0 - Con Adaptive Levels       |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Pro"
#property version   "3.00"
#property strict

#include "Utils.mqh"

//+------------------------------------------------------------------+
//| Struttura per Swing Point                                         |
//+------------------------------------------------------------------+
struct SwingPoint
{
    int       barIndex;      // Indice barra (1 = ultima chiusa)
    double    price;         // Prezzo del pivot
    double    rsi;           // Valore RSI
    datetime  time;          // Timestamp
    bool      isValid;

    void Reset()
    {
        barIndex = 0;
        price = 0;
        rsi = 0;
        time = 0;
        isValid = false;
    }
};

//+------------------------------------------------------------------+
//| Classe: CDivergenceDetector v3.0                                  |
//+------------------------------------------------------------------+
class CDivergenceDetector
{
private:
    string              m_symbol;
    ENUM_TIMEFRAMES     m_timeframe;
    int                 m_rsiHandle;
    double              m_rsiBuffer[];
    int                 m_rsiPeriod;
    int                 m_swingStrength;
    int                 m_minBarsBetween;
    int                 m_maxBarsBetween;

    // Livelli OB/OS standard
    int                 m_rsiOverbought;
    int                 m_rsiOversold;
    bool                m_requireExtremeZone;

    // Livelli adattivi
    bool                m_useAdaptiveLevels;
    int                 m_adaptiveOB_Uptrend;
    int                 m_adaptiveOS_Uptrend;
    int                 m_adaptiveOB_Downtrend;
    int                 m_adaptiveOS_Downtrend;
    ENUM_TREND_DIRECTION m_currentTrend;

    // Filtri
    double              m_minRSIDiff;

    // Anti-duplicati
    datetime            m_lastSignalTime;
    ENUM_DIVERGENCE_TYPE m_lastSignalType;
    int                 m_lastPivotBar;

    // Ultimo pivot per SL
    SwingPoint          m_entryPivot;

    // Swings per visualizzazione
    DivergenceSwings    m_lastDivergence;

    // Debug mode
    bool                m_debugMode;

public:
    //+------------------------------------------------------------------+
    //| Constructor                                                       |
    //+------------------------------------------------------------------+
    CDivergenceDetector()
    {
        m_symbol = "";
        m_timeframe = PERIOD_CURRENT;
        m_rsiHandle = INVALID_HANDLE;
        m_rsiPeriod = 14;
        m_swingStrength = 2;
        m_minBarsBetween = 3;
        m_maxBarsBetween = 50;
        m_rsiOverbought = 70;
        m_rsiOversold = 30;
        m_requireExtremeZone = false;
        m_useAdaptiveLevels = false;
        m_adaptiveOB_Uptrend = 80;
        m_adaptiveOS_Uptrend = 40;
        m_adaptiveOB_Downtrend = 60;
        m_adaptiveOS_Downtrend = 20;
        m_currentTrend = TREND_FLAT;
        m_minRSIDiff = 2.0;
        m_lastSignalTime = 0;
        m_lastSignalType = DIVERGENCE_NONE;
        m_lastPivotBar = 0;
        m_entryPivot.Reset();
        m_lastDivergence.Reset();
        m_debugMode = true;
    }

    ~CDivergenceDetector() { Deinitialize(); }

    //+------------------------------------------------------------------+
    //| Inizializzazione                                                  |
    //+------------------------------------------------------------------+
    bool Initialize(string symbol, ENUM_TIMEFRAMES timeframe,
                    int rsiPeriod = 14, int swingStrength = 2,
                    int minBars = 3, int maxBars = 50,
                    int overbought = 70, int oversold = 30,
                    bool requireExtremeZone = false)
    {
        m_symbol = symbol;
        m_timeframe = timeframe;
        m_rsiPeriod = rsiPeriod;
        m_swingStrength = swingStrength;
        m_minBarsBetween = minBars;
        m_maxBarsBetween = maxBars;
        m_rsiOverbought = overbought;
        m_rsiOversold = oversold;
        m_requireExtremeZone = requireExtremeZone;

        m_rsiHandle = iRSI(m_symbol, m_timeframe, m_rsiPeriod, PRICE_CLOSE);

        if(m_rsiHandle == INVALID_HANDLE)
        {
            Print("[ERROR] DivergenceDetector: Errore creazione handle RSI");
            return false;
        }

        ArraySetAsSeries(m_rsiBuffer, true);

        Print("[INFO] DivergenceDetector v3.0: RSI(", m_rsiPeriod,
              "), Swing=", m_swingStrength, ", Bars=", m_minBarsBetween, "-", m_maxBarsBetween);
        return true;
    }

    void Deinitialize()
    {
        if(m_rsiHandle != INVALID_HANDLE)
        {
            IndicatorRelease(m_rsiHandle);
            m_rsiHandle = INVALID_HANDLE;
        }
    }

    //+------------------------------------------------------------------+
    //| Configura livelli adattivi                                       |
    //+------------------------------------------------------------------+
    void SetAdaptiveLevels(bool enable, int obUp = 80, int osUp = 40,
                           int obDown = 60, int osDown = 20)
    {
        m_useAdaptiveLevels = enable;
        m_adaptiveOB_Uptrend = obUp;
        m_adaptiveOS_Uptrend = osUp;
        m_adaptiveOB_Downtrend = obDown;
        m_adaptiveOS_Downtrend = osDown;

        if(enable)
            Print("[INFO] Adaptive RSI levels ENABLED");
    }

    //+------------------------------------------------------------------+
    //| Imposta trend corrente per livelli adattivi                      |
    //+------------------------------------------------------------------+
    void SetCurrentTrend(ENUM_TREND_DIRECTION trend)
    {
        m_currentTrend = trend;
    }

    //+------------------------------------------------------------------+
    //| Ottiene livello overbought corrente (considera adaptive)         |
    //+------------------------------------------------------------------+
    int GetCurrentOverboughtLevel()
    {
        if(!m_useAdaptiveLevels)
            return m_rsiOverbought;

        switch(m_currentTrend)
        {
            case TREND_UP:   return m_adaptiveOB_Uptrend;
            case TREND_DOWN: return m_adaptiveOB_Downtrend;
            default:         return m_rsiOverbought;
        }
    }

    //+------------------------------------------------------------------+
    //| Ottiene livello oversold corrente (considera adaptive)           |
    //+------------------------------------------------------------------+
    int GetCurrentOversoldLevel()
    {
        if(!m_useAdaptiveLevels)
            return m_rsiOversold;

        switch(m_currentTrend)
        {
            case TREND_UP:   return m_adaptiveOS_Uptrend;
            case TREND_DOWN: return m_adaptiveOS_Downtrend;
            default:         return m_rsiOversold;
        }
    }

    //+------------------------------------------------------------------+
    //| Verifica se RSI e' in zona overbought                            |
    //+------------------------------------------------------------------+
    bool IsOverbought(int bar = 1)
    {
        double rsi = GetRSI(bar);
        return (rsi >= GetCurrentOverboughtLevel());
    }

    //+------------------------------------------------------------------+
    //| Verifica se RSI e' in zona oversold                              |
    //+------------------------------------------------------------------+
    bool IsOversold(int bar = 1)
    {
        double rsi = GetRSI(bar);
        return (rsi <= GetCurrentOversoldLevel());
    }

    //+------------------------------------------------------------------+
    //| Aggiorna buffer RSI                                               |
    //+------------------------------------------------------------------+
    bool UpdateBuffers()
    {
        int barsNeeded = m_maxBarsBetween + m_swingStrength * 2 + 10;
        int copied = CopyBuffer(m_rsiHandle, 0, 0, barsNeeded, m_rsiBuffer);

        if(copied < barsNeeded)
        {
            if(m_debugMode) Print("[DEBUG] Buffer RSI: ", copied, "/", barsNeeded);
            return false;
        }
        return true;
    }

    //+------------------------------------------------------------------+
    //| FUNZIONE PRINCIPALE: Rileva divergenza                           |
    //+------------------------------------------------------------------+
    ENUM_DIVERGENCE_TYPE DetectDivergence()
    {
        if(!UpdateBuffers())
            return DIVERGENCE_NONE;

        // Reset last divergence swings
        m_lastDivergence.Reset();

        // Cerca swing lows per divergenza bullish
        SwingPoint swingLows[];
        int lowCount = FindSwingLows(swingLows, 10);

        if(m_debugMode && lowCount > 0)
            Print("[DEBUG] Trovati ", lowCount, " swing lows");

        // Cerca swing highs per divergenza bearish
        SwingPoint swingHighs[];
        int highCount = FindSwingHighs(swingHighs, 10);

        if(m_debugMode && highCount > 0)
            Print("[DEBUG] Trovati ", highCount, " swing highs");

        // Cerca divergenza bullish
        if(lowCount >= 2)
        {
            ENUM_DIVERGENCE_TYPE bullish = CheckBullishDivergence(swingLows, lowCount);
            if(bullish != DIVERGENCE_NONE)
            {
                if(IsDuplicate(bullish))
                {
                    if(m_debugMode) Print("[DEBUG] Bullish duplicato, skip");
                }
                else
                {
                    RecordSignal(bullish, m_entryPivot.barIndex);
                    Print("[TRADE SIGNAL] ", DivergenceTypeToString(bullish), " CONFERMATO @ Bar ", m_entryPivot.barIndex);
                    return bullish;
                }
            }
        }

        // Cerca divergenza bearish
        if(highCount >= 2)
        {
            ENUM_DIVERGENCE_TYPE bearish = CheckBearishDivergence(swingHighs, highCount);
            if(bearish != DIVERGENCE_NONE)
            {
                if(IsDuplicate(bearish))
                {
                    if(m_debugMode) Print("[DEBUG] Bearish duplicato, skip");
                }
                else
                {
                    RecordSignal(bearish, m_entryPivot.barIndex);
                    Print("[TRADE SIGNAL] ", DivergenceTypeToString(bearish), " CONFERMATO @ Bar ", m_entryPivot.barIndex);
                    return bearish;
                }
            }
        }

        return DIVERGENCE_NONE;
    }

    //+------------------------------------------------------------------+
    //| Cerca divergenza bullish tra swing lows                          |
    //+------------------------------------------------------------------+
    ENUM_DIVERGENCE_TYPE CheckBullishDivergence(SwingPoint &swings[], int count)
    {
        for(int i = 0; i < count - 1; i++)
        {
            SwingPoint recent = swings[i];

            for(int j = i + 1; j < count; j++)
            {
                SwingPoint older = swings[j];

                int barsBetween = older.barIndex - recent.barIndex;
                if(barsBetween < m_minBarsBetween) continue;
                if(barsBetween > m_maxBarsBetween) break;

                // Verifica zona estrema se richiesto
                if(m_requireExtremeZone)
                {
                    int osLevel = GetCurrentOversoldLevel();
                    if(older.rsi > osLevel && recent.rsi > osLevel)
                        continue;
                }

                double rsiDiff = MathAbs(recent.rsi - older.rsi);
                if(rsiDiff < m_minRSIDiff) continue;

                // REGULAR BULLISH: Price Lower Low, RSI Higher Low
                if(recent.price < older.price && recent.rsi > older.rsi)
                {
                    m_entryPivot = recent;
                    StoreDivergenceSwings(older, recent, DIVERGENCE_BULLISH_REGULAR);

                    if(m_debugMode)
                        Print("[SIGNAL] BULLISH REGULAR @ Bar ", recent.barIndex,
                              " | Price: ", older.price, " -> ", recent.price,
                              " | RSI: ", DoubleToString(older.rsi, 1), " -> ", DoubleToString(recent.rsi, 1));

                    return DIVERGENCE_BULLISH_REGULAR;
                }

                // HIDDEN BULLISH: Price Higher Low, RSI Lower Low
                if(recent.price > older.price && recent.rsi < older.rsi)
                {
                    m_entryPivot = recent;
                    StoreDivergenceSwings(older, recent, DIVERGENCE_BULLISH_HIDDEN);

                    if(m_debugMode)
                        Print("[SIGNAL] BULLISH HIDDEN @ Bar ", recent.barIndex,
                              " | Price: ", older.price, " -> ", recent.price,
                              " | RSI: ", DoubleToString(older.rsi, 1), " -> ", DoubleToString(recent.rsi, 1));

                    return DIVERGENCE_BULLISH_HIDDEN;
                }
            }
        }
        return DIVERGENCE_NONE;
    }

    //+------------------------------------------------------------------+
    //| Cerca divergenza bearish tra swing highs                         |
    //+------------------------------------------------------------------+
    ENUM_DIVERGENCE_TYPE CheckBearishDivergence(SwingPoint &swings[], int count)
    {
        for(int i = 0; i < count - 1; i++)
        {
            SwingPoint recent = swings[i];

            for(int j = i + 1; j < count; j++)
            {
                SwingPoint older = swings[j];

                int barsBetween = older.barIndex - recent.barIndex;
                if(barsBetween < m_minBarsBetween) continue;
                if(barsBetween > m_maxBarsBetween) break;

                // Verifica zona estrema se richiesto
                if(m_requireExtremeZone)
                {
                    int obLevel = GetCurrentOverboughtLevel();
                    if(older.rsi < obLevel && recent.rsi < obLevel)
                        continue;
                }

                double rsiDiff = MathAbs(recent.rsi - older.rsi);
                if(rsiDiff < m_minRSIDiff) continue;

                // REGULAR BEARISH: Price Higher High, RSI Lower High
                if(recent.price > older.price && recent.rsi < older.rsi)
                {
                    m_entryPivot = recent;
                    StoreDivergenceSwings(older, recent, DIVERGENCE_BEARISH_REGULAR);

                    if(m_debugMode)
                        Print("[SIGNAL] BEARISH REGULAR @ Bar ", recent.barIndex,
                              " | Price: ", older.price, " -> ", recent.price,
                              " | RSI: ", DoubleToString(older.rsi, 1), " -> ", DoubleToString(recent.rsi, 1));

                    return DIVERGENCE_BEARISH_REGULAR;
                }

                // HIDDEN BEARISH: Price Lower High, RSI Higher High
                if(recent.price < older.price && recent.rsi > older.rsi)
                {
                    m_entryPivot = recent;
                    StoreDivergenceSwings(older, recent, DIVERGENCE_BEARISH_HIDDEN);

                    if(m_debugMode)
                        Print("[SIGNAL] BEARISH HIDDEN @ Bar ", recent.barIndex,
                              " | Price: ", older.price, " -> ", recent.price,
                              " | RSI: ", DoubleToString(older.rsi, 1), " -> ", DoubleToString(recent.rsi, 1));

                    return DIVERGENCE_BEARISH_HIDDEN;
                }
            }
        }
        return DIVERGENCE_NONE;
    }

    //+------------------------------------------------------------------+
    //| Salva i dati degli swings per visualizzazione                    |
    //+------------------------------------------------------------------+
    void StoreDivergenceSwings(SwingPoint &older, SwingPoint &recent, ENUM_DIVERGENCE_TYPE type)
    {
        m_lastDivergence.swing1Bar = older.barIndex;
        m_lastDivergence.swing2Bar = recent.barIndex;
        m_lastDivergence.swing1Price = older.price;
        m_lastDivergence.swing2Price = recent.price;
        m_lastDivergence.swing1RSI = older.rsi;
        m_lastDivergence.swing2RSI = recent.rsi;
        m_lastDivergence.type = type;
    }

    //+------------------------------------------------------------------+
    //| Trova swing lows                                                  |
    //+------------------------------------------------------------------+
    int FindSwingLows(SwingPoint &swings[], int maxCount)
    {
        ArrayResize(swings, 0);
        int found = 0;

        int startBar = m_swingStrength + 1;
        int endBar = m_maxBarsBetween + m_swingStrength;

        for(int bar = startBar; bar <= endBar && found < maxCount; bar++)
        {
            if(IsSwingLow(bar))
            {
                SwingPoint sp;
                sp.barIndex = bar;
                sp.price = iLow(m_symbol, m_timeframe, bar);
                sp.rsi = GetRSI(bar);
                sp.time = iTime(m_symbol, m_timeframe, bar);
                sp.isValid = true;

                ArrayResize(swings, found + 1);
                swings[found] = sp;
                found++;

                if(m_debugMode)
                    Print("[DEBUG] SwingLow @ Bar ", bar, " Price=", sp.price, " RSI=", DoubleToString(sp.rsi, 1));
            }
        }
        return found;
    }

    //+------------------------------------------------------------------+
    //| Trova swing highs                                                 |
    //+------------------------------------------------------------------+
    int FindSwingHighs(SwingPoint &swings[], int maxCount)
    {
        ArrayResize(swings, 0);
        int found = 0;

        int startBar = m_swingStrength + 1;
        int endBar = m_maxBarsBetween + m_swingStrength;

        for(int bar = startBar; bar <= endBar && found < maxCount; bar++)
        {
            if(IsSwingHigh(bar))
            {
                SwingPoint sp;
                sp.barIndex = bar;
                sp.price = iHigh(m_symbol, m_timeframe, bar);
                sp.rsi = GetRSI(bar);
                sp.time = iTime(m_symbol, m_timeframe, bar);
                sp.isValid = true;

                ArrayResize(swings, found + 1);
                swings[found] = sp;
                found++;

                if(m_debugMode)
                    Print("[DEBUG] SwingHigh @ Bar ", bar, " Price=", sp.price, " RSI=", DoubleToString(sp.rsi, 1));
            }
        }
        return found;
    }

    //+------------------------------------------------------------------+
    //| Verifica swing low                                                |
    //+------------------------------------------------------------------+
    bool IsSwingLow(int bar)
    {
        if(bar < m_swingStrength + 1) return false;

        double centerLow = iLow(m_symbol, m_timeframe, bar);

        // Barre a destra (piu' recenti)
        for(int i = 1; i <= m_swingStrength; i++)
        {
            int checkBar = bar - i;
            if(checkBar < 1) return false;
            if(iLow(m_symbol, m_timeframe, checkBar) <= centerLow)
                return false;
        }

        // Barre a sinistra (piu' vecchie)
        for(int i = 1; i <= m_swingStrength; i++)
        {
            if(iLow(m_symbol, m_timeframe, bar + i) <= centerLow)
                return false;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| Verifica swing high                                               |
    //+------------------------------------------------------------------+
    bool IsSwingHigh(int bar)
    {
        if(bar < m_swingStrength + 1) return false;

        double centerHigh = iHigh(m_symbol, m_timeframe, bar);

        for(int i = 1; i <= m_swingStrength; i++)
        {
            int checkBar = bar - i;
            if(checkBar < 1) return false;
            if(iHigh(m_symbol, m_timeframe, checkBar) >= centerHigh)
                return false;
        }

        for(int i = 1; i <= m_swingStrength; i++)
        {
            if(iHigh(m_symbol, m_timeframe, bar + i) >= centerHigh)
                return false;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| Ottieni RSI per barra                                             |
    //+------------------------------------------------------------------+
    double GetRSI(int bar)
    {
        if(bar < 0 || bar >= ArraySize(m_rsiBuffer))
            return 50.0;
        return m_rsiBuffer[bar];
    }

    //+------------------------------------------------------------------+
    //| Trova swing low piu' recente                                      |
    //+------------------------------------------------------------------+
    bool FindRecentSwingLow(int maxBars, int &foundBar, double &price)
    {
        for(int bar = m_swingStrength + 1; bar <= maxBars; bar++)
        {
            if(IsSwingLow(bar))
            {
                foundBar = bar;
                price = iLow(m_symbol, m_timeframe, bar);
                return true;
            }
        }
        return false;
    }

    //+------------------------------------------------------------------+
    //| Trova swing high piu' recente                                     |
    //+------------------------------------------------------------------+
    bool FindRecentSwingHigh(int maxBars, int &foundBar, double &price)
    {
        for(int bar = m_swingStrength + 1; bar <= maxBars; bar++)
        {
            if(IsSwingHigh(bar))
            {
                foundBar = bar;
                price = iHigh(m_symbol, m_timeframe, bar);
                return true;
            }
        }
        return false;
    }

    //+------------------------------------------------------------------+
    //| Anti-duplicati                                                    |
    //+------------------------------------------------------------------+
    bool IsDuplicate(ENUM_DIVERGENCE_TYPE type)
    {
        datetime currentBar = iTime(m_symbol, m_timeframe, 1);

        if(type == m_lastSignalType && currentBar == m_lastSignalTime)
            return true;

        if(m_entryPivot.barIndex == m_lastPivotBar && m_lastPivotBar > 0)
            return true;

        return false;
    }

    void RecordSignal(ENUM_DIVERGENCE_TYPE type, int pivotBar)
    {
        m_lastSignalType = type;
        m_lastSignalTime = iTime(m_symbol, m_timeframe, 1);
        m_lastPivotBar = pivotBar;
    }

    //+------------------------------------------------------------------+
    //| Getters                                                           |
    //+------------------------------------------------------------------+
    double GetPivotPrice()    { return m_entryPivot.price; }
    int    GetPivotBarIndex() { return m_entryPivot.barIndex; }
    double GetPivotRSI()      { return m_entryPivot.rsi; }
    int    GetRSIHandle()     { return m_rsiHandle; }

    //+------------------------------------------------------------------+
    //| Ottieni swings dell'ultima divergenza per visualizzazione        |
    //+------------------------------------------------------------------+
    DivergenceSwings GetLastDivergenceSwings() { return m_lastDivergence; }

    //+------------------------------------------------------------------+
    //| Verifica se c'e' una divergenza valida da disegnare              |
    //+------------------------------------------------------------------+
    bool HasValidDivergenceForDrawing()
    {
        return (m_lastDivergence.type != DIVERGENCE_NONE &&
                m_lastDivergence.swing1Bar > 0 &&
                m_lastDivergence.swing2Bar > 0);
    }

    //+------------------------------------------------------------------+
    //| Setters                                                           |
    //+------------------------------------------------------------------+
    void SetMinRSIDiff(double diff)       { m_minRSIDiff = diff; }
    void SetRequireExtremeZone(bool req)  { m_requireExtremeZone = req; }
    void SetDebugMode(bool debug)         { m_debugMode = debug; }
};
