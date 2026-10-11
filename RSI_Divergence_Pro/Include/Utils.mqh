//+------------------------------------------------------------------+
//|                                                        Utils.mqh |
//|                                             RSI Divergence Pro   |
//|                                    Utility functions and enums   |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Pro"
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| Enum: Tipo di divergenza                                         |
//+------------------------------------------------------------------+
enum ENUM_DIVERGENCE_TYPE
{
    DIVERGENCE_NONE            = 0,   // Nessuna divergenza
    DIVERGENCE_BULLISH_REGULAR = 1,   // Bullish Regular: Price LL, RSI HL
    DIVERGENCE_BEARISH_REGULAR = 2,   // Bearish Regular: Price HH, RSI LH
    DIVERGENCE_BULLISH_HIDDEN  = 3,   // Bullish Hidden: Price HL, RSI LL
    DIVERGENCE_BEARISH_HIDDEN  = 4    // Bearish Hidden: Price LH, RSI HH
};

//+------------------------------------------------------------------+
//| Enum: Tipo di conferma segnale                                   |
//+------------------------------------------------------------------+
enum ENUM_CONFIRM_TYPE
{
    CONFIRM_NONE        = 0,   // Nessuna conferma richiesta
    CONFIRM_PINBAR      = 1,   // Solo Pin Bar
    CONFIRM_ENGULFING   = 2,   // Solo Engulfing
    CONFIRM_DOJI        = 3,   // Solo Doji
    CONFIRM_ANY_PATTERN = 4,   // Pin Bar, Engulfing o Doji
    CONFIRM_EMA_TREND   = 5    // Prezzo allineato al trend EMA
};

//+------------------------------------------------------------------+
//| Enum: Metodo Stop Loss                                           |
//+------------------------------------------------------------------+
enum ENUM_SL_METHOD
{
    SL_SWING   = 0,   // SL su swing point + buffer
    SL_ATR     = 1,   // SL basato su ATR
    SL_HYBRID  = 2,   // Min tra Swing e ATR
    SL_FIXED   = 3    // SL fisso in pips
};

//+------------------------------------------------------------------+
//| Enum: Metodo Take Profit                                         |
//+------------------------------------------------------------------+
enum ENUM_TP_METHOD
{
    TP_FIXED_RR   = 0,   // TP fisso Risk:Reward
    TP_ATR        = 1,   // TP basato su ATR
    TP_STRUCTURE  = 2,   // TP su livelli strutturali (S/R)
    TP_MULTIPLE   = 3    // TP multipli con partial close
};

//+------------------------------------------------------------------+
//| Enum: Metodo Trailing Stop                                       |
//+------------------------------------------------------------------+
enum ENUM_TRAIL_METHOD
{
    TRAIL_NONE   = 0,   // Nessun trailing
    TRAIL_ATR    = 1,   // Trailing basato su ATR
    TRAIL_SWING  = 2,   // Trailing su swing points
    TRAIL_FIXED  = 3    // Trailing fisso in pips
};

//+------------------------------------------------------------------+
//| Enum: Direzione Trend                                            |
//+------------------------------------------------------------------+
enum ENUM_TREND_DIRECTION
{
    TREND_UP    = 0,   // Trend rialzista
    TREND_DOWN  = 1,   // Trend ribassista
    TREND_FLAT  = 2    // Mercato laterale
};

//+------------------------------------------------------------------+
//| Struttura: Pivot Point per divergenze                            |
//+------------------------------------------------------------------+
struct PivotPoint
{
    int       barIndex;      // Indice barra (>= 1, mai 0!)
    double    price;         // Prezzo high/low del pivot
    double    rsiValue;      // Valore RSI al pivot
    datetime  time;          // Timestamp per validazione
    bool      isHigh;        // true = swing high, false = swing low

    void Reset()
    {
        barIndex = -1;
        price = 0;
        rsiValue = 0;
        time = 0;
        isHigh = false;
    }
};

//+------------------------------------------------------------------+
//| Struttura: Info singolo trade con partial close                  |
//+------------------------------------------------------------------+
struct SingleTradeInfo
{
    ulong     ticket;             // Ticket posizione principale
    double    entryPrice;         // Prezzo di entrata
    double    originalSL;         // SL originale
    double    currentSL;          // SL corrente (dopo trailing)
    double    originalLots;       // Lotti originali
    double    remainingLots;      // Lotti rimanenti
    bool      isBuy;              // true = BUY, false = SELL

    // Stato partial close
    bool      tp1Hit;             // TP1 raggiunto
    bool      tp2Hit;             // TP2 raggiunto
    double    tp1Price;           // Prezzo TP1
    double    tp2Price;           // Prezzo TP2
    double    tp3Price;           // Prezzo TP3 (finale)

    // Move to BE
    bool      movedToBE;          // SL spostato a BE

    // Timestamps
    datetime  openTime;           // Ora apertura
    datetime  lastModifyTime;     // Ultima modifica

    void Reset()
    {
        ticket = 0;
        entryPrice = 0;
        originalSL = 0;
        currentSL = 0;
        originalLots = 0;
        remainingLots = 0;
        isBuy = false;
        tp1Hit = false;
        tp2Hit = false;
        tp1Price = 0;
        tp2Price = 0;
        tp3Price = 0;
        movedToBE = false;
        openTime = 0;
        lastModifyTime = 0;
    }
};

//+------------------------------------------------------------------+
//| Struttura: Livello Support/Resistance                            |
//+------------------------------------------------------------------+
struct SRLevel
{
    double    price;         // Prezzo del livello
    int       touches;       // Numero di tocchi
    datetime  lastTouch;     // Ultimo tocco
    bool      isSupport;     // true = support, false = resistance
    double    strength;      // Forza del livello (0-1)

    void Reset()
    {
        price = 0;
        touches = 0;
        lastTouch = 0;
        isSupport = false;
        strength = 0;
    }
};

//+------------------------------------------------------------------+
//| Struttura: Stato Dashboard                                       |
//+------------------------------------------------------------------+
struct DashboardState
{
    double    balance;
    double    equity;
    double    drawdown;
    double    dailyPnL;
    int       tradesToday;
    int       openPositions;
    double    totalProfit;
    double    currentRSI;
    double    currentADX;
    ENUM_TREND_DIRECTION trend;
    string    lastSignal;
    datetime  lastUpdate;

    void Reset()
    {
        balance = 0;
        equity = 0;
        drawdown = 0;
        dailyPnL = 0;
        tradesToday = 0;
        openPositions = 0;
        totalProfit = 0;
        currentRSI = 50;
        currentADX = 0;
        trend = TREND_FLAT;
        lastSignal = "None";
        lastUpdate = 0;
    }
};

//+------------------------------------------------------------------+
//| Struttura: Swings per visualizzazione divergenza                 |
//+------------------------------------------------------------------+
struct DivergenceSwings
{
    int       swing1Bar;     // Prima barra swing (piu' vecchia)
    int       swing2Bar;     // Seconda barra swing (piu' recente)
    double    swing1Price;   // Prezzo primo swing
    double    swing2Price;   // Prezzo secondo swing
    double    swing1RSI;     // RSI primo swing
    double    swing2RSI;     // RSI secondo swing
    ENUM_DIVERGENCE_TYPE type;

    void Reset()
    {
        swing1Bar = 0;
        swing2Bar = 0;
        swing1Price = 0;
        swing2Price = 0;
        swing1RSI = 0;
        swing2RSI = 0;
        type = DIVERGENCE_NONE;
    }
};

//+------------------------------------------------------------------+
//| Struttura: TradeGroup legacy (per compatibilita')                |
//+------------------------------------------------------------------+
struct TradeGroup
{
    ulong     tickets[3];       // Ticket delle posizioni (TP1, TP2, TP3)
    int       ticketCount;      // Numero posizioni attive
    double    entryPrice;       // Prezzo di entrata
    bool      isBuy;            // Direzione
    bool      tp1Hit;           // TP1 raggiunto
    bool      movedToBE;        // SL spostato a BE
    datetime  openTime;         // Timestamp apertura

    void Reset()
    {
        for(int i = 0; i < 3; i++) tickets[i] = 0;
        ticketCount = 0;
        entryPrice = 0;
        isBuy = false;
        tp1Hit = false;
        movedToBE = false;
        openTime = 0;
    }
};

//+------------------------------------------------------------------+
//| Normalizza prezzo al tick size del simbolo                       |
//+------------------------------------------------------------------+
double NormalizePrice(string symbol, double price)
{
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    if(tickSize == 0) return price;
    return MathRound(price / tickSize) * tickSize;
}

//+------------------------------------------------------------------+
//| Converte pips in prezzo per il simbolo corrente                  |
//+------------------------------------------------------------------+
double PipsToPrice(string symbol, double pips)
{
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

    if(digits == 5 || digits == 3)
        return pips * point * 10;
    else
        return pips * point;
}

//+------------------------------------------------------------------+
//| Converte prezzo in pips                                          |
//+------------------------------------------------------------------+
double PriceToPips(string symbol, double priceDistance)
{
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

    if(point == 0) return 0;

    if(digits == 5 || digits == 3)
        return priceDistance / (point * 10);
    else
        return priceDistance / point;
}

//+------------------------------------------------------------------+
//| Verifica se e' una nuova barra - ANTI-REPAINTING                 |
//+------------------------------------------------------------------+
bool IsNewBar(string symbol, ENUM_TIMEFRAMES timeframe, datetime &lastBarTime)
{
    datetime currentBarTime = iTime(symbol, timeframe, 0);

    if(currentBarTime == 0)
        return false;

    if(currentBarTime != lastBarTime)
    {
        lastBarTime = currentBarTime;
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Ottiene il nome stringa del tipo di divergenza                   |
//+------------------------------------------------------------------+
string DivergenceTypeToString(ENUM_DIVERGENCE_TYPE type)
{
    switch(type)
    {
        case DIVERGENCE_BULLISH_REGULAR: return "Bullish Regular";
        case DIVERGENCE_BEARISH_REGULAR: return "Bearish Regular";
        case DIVERGENCE_BULLISH_HIDDEN:  return "Bullish Hidden";
        case DIVERGENCE_BEARISH_HIDDEN:  return "Bearish Hidden";
        default: return "None";
    }
}

//+------------------------------------------------------------------+
//| Verifica se la divergenza e' bullish                             |
//+------------------------------------------------------------------+
bool IsBullishDivergence(ENUM_DIVERGENCE_TYPE type)
{
    return (type == DIVERGENCE_BULLISH_REGULAR || type == DIVERGENCE_BULLISH_HIDDEN);
}

//+------------------------------------------------------------------+
//| Verifica se la divergenza e' bearish                             |
//+------------------------------------------------------------------+
bool IsBearishDivergence(ENUM_DIVERGENCE_TYPE type)
{
    return (type == DIVERGENCE_BEARISH_REGULAR || type == DIVERGENCE_BEARISH_HIDDEN);
}

//+------------------------------------------------------------------+
//| Converte SL method in stringa                                    |
//+------------------------------------------------------------------+
string SLMethodToString(ENUM_SL_METHOD method)
{
    switch(method)
    {
        case SL_SWING:  return "Swing";
        case SL_ATR:    return "ATR";
        case SL_HYBRID: return "Hybrid";
        case SL_FIXED:  return "Fixed";
        default: return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| Converte Trail method in stringa                                 |
//+------------------------------------------------------------------+
string TrailMethodToString(ENUM_TRAIL_METHOD method)
{
    switch(method)
    {
        case TRAIL_NONE:  return "None";
        case TRAIL_ATR:   return "ATR";
        case TRAIL_SWING: return "Swing";
        case TRAIL_FIXED: return "Fixed";
        default: return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| Converte Trend direction in stringa                              |
//+------------------------------------------------------------------+
string TrendToString(ENUM_TREND_DIRECTION trend)
{
    switch(trend)
    {
        case TREND_UP:   return "Uptrend";
        case TREND_DOWN: return "Downtrend";
        case TREND_FLAT: return "Flat";
        default: return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| Log formattato con timestamp                                      |
//+------------------------------------------------------------------+
void LogMessage(string message, bool isError = false)
{
    string prefix = isError ? "[ERROR] " : "[INFO] ";
    Print(prefix, message);
}

//+------------------------------------------------------------------+
//| Log su file                                                       |
//+------------------------------------------------------------------+
void LogToFile(string filename, string message)
{
    string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
    string fullMsg = StringFormat("[%s] %s", timestamp, message);

    int handle = FileOpen(filename + ".log",
                         FILE_WRITE|FILE_READ|FILE_TXT|FILE_SHARE_READ|FILE_COMMON);
    if(handle != INVALID_HANDLE)
    {
        FileSeek(handle, 0, SEEK_END);
        FileWriteString(handle, fullMsg + "\n");
        FileClose(handle);
    }
}

//+------------------------------------------------------------------+
//| Verifica validita' handle indicatore                             |
//+------------------------------------------------------------------+
bool IsValidHandle(int handle)
{
    return (handle != INVALID_HANDLE);
}

//+------------------------------------------------------------------+
//| Ottiene distanza minima SL/TP dal broker                         |
//+------------------------------------------------------------------+
double GetMinStopDistance(string symbol)
{
    long stopsLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    return stopsLevel * point;
}

//+------------------------------------------------------------------+
//| Verifica se il mercato e' aperto                                 |
//+------------------------------------------------------------------+
bool IsMarketOpen(string symbol)
{
    MqlDateTime currentTime;
    TimeToStruct(TimeCurrent(), currentTime);

    // Weekend check (0 = Sunday, 6 = Saturday)
    if(currentTime.day_of_week == 0 || currentTime.day_of_week == 6)
        return false;

    // Verifica se trading e' permesso per il simbolo
    return (bool)SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
}

//+------------------------------------------------------------------+
//| Ottiene ora corrente del broker                                  |
//+------------------------------------------------------------------+
int GetBrokerHour()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    return dt.hour;
}

//+------------------------------------------------------------------+
//| Ottiene giorno della settimana (0=Dom, 6=Sab)                    |
//+------------------------------------------------------------------+
int GetDayOfWeek()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    return dt.day_of_week;
}
