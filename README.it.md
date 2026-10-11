# RSI Divergence EA - Specifiche di Sviluppo
## Expert Advisor per MetaTrader 5

---

## 📋 Project Overview

**Nome EA**: RSI_Divergence_Pro
**Piattaforma**: MetaTrader 5
**Linguaggio**: MQL5
**Scopo**: Identificare e tradare automaticamente divergenze RSI con gestione rischio per prop firm

---

## 🎯 Obiettivi Principali

1. Rilevamento automatico divergenze RSI (Regular + Hidden)
2. Sistema di conferma multi-livello (candlestick, S/R, trend)
3. Gestione rischio rigorosa (max 5% DD totale, 0.5% per trade)
4. Multi-timeframe analysis (D1 trend, H4 setup, H1 entry)
5. Logging dettagliato per analisi performance

---

## 📁 Struttura File

```
RSI_Divergence_Pro/
├── RSI_Divergence_Pro.mq5      # EA principale
├── Include/
│   ├── DivergenceDetector.mqh   # Classe detection divergenze
│   ├── RiskManager.mqh          # Gestione rischio e sizing
│   ├── TradeManager.mqh         # Gestione ordini e trailing
│   ├── SignalConfirm.mqh        # Conferme entry (candles, S/R)
│   └── Utils.mqh                # Funzioni utility
├── Indicators/
│   └── RSI_Divergence_Visual.mq5 # Indicatore visuale (opzionale)
└── Presets/
    ├── Conservative_PropFirm.set
    ├── Moderate.set
    └── Aggressive.set
```

---

## ⚙️ Input Parameters

### Sezione 1: RSI Settings

```mql5
input group "=== RSI SETTINGS ==="
input int      RSI_Period = 14;              // RSI Period
input int      RSI_Overbought = 70;          // Overbought Level
input int      RSI_Oversold = 30;            // Oversold Level
input bool     UseAdaptiveLevels = false;    // Adaptive OB/OS based on trend
input int      AdaptiveOB_Uptrend = 80;      // OB in Uptrend
input int      AdaptiveOS_Uptrend = 40;      // OS in Uptrend
input int      AdaptiveOB_Downtrend = 60;    // OB in Downtrend
input int      AdaptiveOS_Downtrend = 20;    // OS in Downtrend
```

### Sezione 2: Divergence Detection

```mql5
input group "=== DIVERGENCE DETECTION ==="
input int      MinDivergenceBars = 5;        // Min bars between swings
input int      MaxDivergenceBars = 50;       // Max bars between swings
input int      SwingStrength = 3;            // Swing detection strength (bars L/R)
input bool     TradeRegularDiv = true;       // Trade Regular Divergence
input bool     TradeHiddenDiv = true;        // Trade Hidden Divergence
input bool     RequireExtremeZone = true;    // First swing must be in OB/OS
```

### Sezione 3: Timeframes

```mql5
input group "=== TIMEFRAMES ==="
input ENUM_TIMEFRAMES TF_Trend = PERIOD_D1;     // Trend Timeframe
input ENUM_TIMEFRAMES TF_Setup = PERIOD_H4;     // Setup Timeframe (divergence)
input ENUM_TIMEFRAMES TF_Entry = PERIOD_H1;     // Entry Timeframe
input bool     UseMTFConfirmation = true;       // Require MTF alignment
```

### Sezione 4: Entry Confirmation

```mql5
input group "=== ENTRY CONFIRMATION ==="
input bool     RequireCandleConfirm = true;     // Require candlestick pattern
input bool     UsePinBar = true;                // Pin Bar confirmation
input bool     UseEngulfing = true;             // Engulfing confirmation
input bool     UseDoji = false;                 // Doji confirmation
input bool     RequireSRConfluence = false;     // Require S/R level nearby
input int      SRLookback = 100;                // S/R lookback bars
input int      SRProximityPips = 20;            // Max distance from S/R (pips)
```

### Sezione 5: Risk Management

```mql5
input group "=== RISK MANAGEMENT ==="
input double   RiskPercent = 0.5;               // Risk % per trade
input double   MaxDailyLossPercent = 1.5;       // Max daily loss %
input double   MaxTotalDDPercent = 5.0;         // Max total drawdown %
input int      MaxOpenTrades = 2;               // Max simultaneous trades
input int      MaxTradesPerDay = 3;             // Max trades per day
input bool     UseCorrelationFilter = true;     // Avoid correlated pairs
```

### Sezione 6: Stop Loss

```mql5
input group "=== STOP LOSS ==="
input ENUM_SL_METHOD SL_Method = SL_SWING;      // SL Method
// enum ENUM_SL_METHOD { SL_SWING, SL_ATR, SL_HYBRID, SL_FIXED }
input double   SL_ATR_Multiplier = 1.5;         // ATR Multiplier for SL
input int      SL_FixedPips = 50;               // Fixed SL in pips
input int      SL_BufferPips = 10;              // Buffer beyond swing
input int      ATR_Period = 14;                 // ATR Period
```

### Sezione 7: Take Profit

```mql5
input group "=== TAKE PROFIT ==="
input ENUM_TP_METHOD TP_Method = TP_MULTIPLE;   // TP Method
// enum ENUM_TP_METHOD { TP_FIXED_RR, TP_ATR, TP_STRUCTURE, TP_MULTIPLE }
input double   TP1_RiskReward = 1.5;            // TP1 Risk:Reward
input double   TP2_RiskReward = 2.5;            // TP2 Risk:Reward
input double   TP3_RiskReward = 4.0;            // TP3 Risk:Reward (trailing)
input int      TP1_ClosePercent = 50;           // % to close at TP1
input int      TP2_ClosePercent = 30;           // % to close at TP2
input bool     MoveToBreakeven = true;          // Move SL to BE after TP1
input int      BreakevenBufferPips = 5;         // BE buffer in pips
```

### Sezione 8: Trailing Stop

```mql5
input group "=== TRAILING STOP ==="
input bool     UseTrailingStop = true;          // Enable trailing stop
input ENUM_TRAIL_METHOD TrailMethod = TRAIL_ATR; // Trailing method
// enum ENUM_TRAIL_METHOD { TRAIL_ATR, TRAIL_SWING, TRAIL_FIXED }
input double   TrailATRMultiplier = 1.0;        // ATR multiplier for trail
input int      TrailFixedPips = 30;             // Fixed trailing pips
input int      TrailStartPips = 50;             // Start trailing after X pips profit
```

### Sezione 9: Filters

```mql5
input group "=== FILTERS ==="
input bool     UseTrendFilter = true;           // Use EMA trend filter
input int      EMA_Fast = 50;                   // Fast EMA period
input int      EMA_Slow = 200;                  // Slow EMA period
input bool     UseADXFilter = true;             // Use ADX filter
input int      ADX_Period = 14;                 // ADX Period
input int      ADX_Min = 15;                    // Min ADX (avoid flat markets)
input int      ADX_Max = 35;                    // Max ADX (avoid strong trends)
input bool     AvoidNews = true;                // Avoid high-impact news
input int      NewsBufferMinutes = 30;          // Minutes before/after news
```

### Sezione 10: Trading Hours

```mql5
input group "=== TRADING HOURS ==="
input bool     UseTradingHours = true;          // Enable trading hours filter
input int      StartHour = 8;                   // Start hour (broker time)
input int      EndHour = 20;                    // End hour (broker time)
input bool     TradeMonday = true;
input bool     TradeTuesday = true;
input bool     TradeWednesday = true;
input bool     TradeThursday = true;
input bool     TradeFriday = true;
input bool     CloseOnFriday = true;            // Close all before weekend
input int      FridayCloseHour = 20;            // Friday close hour
```

### Sezione 11: Display & Logging

```mql5
input group "=== DISPLAY & LOGGING ==="
input bool     ShowDashboard = true;            // Show info panel
input bool     ShowDivergenceLines = true;      // Draw divergence lines
input bool     ShowSRLevels = true;             // Draw S/R levels
input bool     EnableAlerts = true;             // Enable alerts
input bool     SendPushNotification = false;    // Send push notifications
input bool     WriteLogFile = true;             // Write detailed log
input string   LogFileName = "RSI_Div_Log";     // Log file name
```

---

## 🔧 Classi e Funzioni Principali

### 1. DivergenceDetector.mqh

```mql5
//+------------------------------------------------------------------+
//| Classe per rilevamento divergenze RSI                             |
//+------------------------------------------------------------------+
class CDivergenceDetector
{
private:
    int         m_rsiHandle;
    double      m_rsiBuffer[];
    int         m_period;
    int         m_swingStrength;
    
    // Struttura per swing points
    struct SwingPoint
    {
        int      bar;
        double   price;
        double   rsi;
        bool     isHigh;
    };
    
    SwingPoint  m_swings[];
    
public:
    // Constructor/Destructor
    CDivergenceDetector(void);
    ~CDivergenceDetector(void);
    
    // Inizializzazione
    bool Init(string symbol, ENUM_TIMEFRAMES tf, int rsiPeriod, int swingStrength);
    void Deinit(void);
    
    // Detection principale
    ENUM_DIVERGENCE_TYPE DetectDivergence(int &swing1Bar, int &swing2Bar);
    
    // Metodi helper
    bool FindSwingHigh(int startBar, int &foundBar, double &price, double &rsi);
    bool FindSwingLow(int startBar, int &foundBar, double &price, double &rsi);
    bool IsValidDivergence(int bar1, int bar2, double price1, double price2, 
                           double rsi1, double rsi2, ENUM_DIVERGENCE_TYPE &type);
    
    // Getters
    double GetRSI(int bar);
    bool IsOverbought(int bar);
    bool IsOversold(int bar);
};

// Enum per tipi divergenza
enum ENUM_DIVERGENCE_TYPE
{
    DIV_NONE = 0,
    DIV_REGULAR_BULLISH = 1,    // Price LL, RSI HL
    DIV_REGULAR_BEARISH = 2,    // Price HH, RSI LH
    DIV_HIDDEN_BULLISH = 3,     // Price HL, RSI LL
    DIV_HIDDEN_BEARISH = 4      // Price LH, RSI HH
};
```

### 2. SignalConfirm.mqh

```mql5
//+------------------------------------------------------------------+
//| Classe per conferme segnale                                       |
//+------------------------------------------------------------------+
class CSignalConfirm
{
private:
    string      m_symbol;
    ENUM_TIMEFRAMES m_tf;
    
public:
    bool Init(string symbol, ENUM_TIMEFRAMES tf);
    
    // Candlestick patterns
    bool IsBullishPinBar(int bar);
    bool IsBearishPinBar(int bar);
    bool IsBullishEngulfing(int bar);
    bool IsBearishEngulfing(int bar);
    bool IsDoji(int bar);
    
    // Conferma combinata
    bool HasBullishConfirmation(int bar);
    bool HasBearishConfirmation(int bar);
    
    // Support/Resistance
    bool IsNearSupport(double price, int lookback, int proximityPips);
    bool IsNearResistance(double price, int lookback, int proximityPips);
    double FindNearestSupport(double price, int lookback);
    double FindNearestResistance(double price, int lookback);
    
    // Trend analysis
    ENUM_TREND_DIRECTION GetTrendDirection(int emaFast, int emaSlow);
    bool IsTrendAligned(ENUM_DIVERGENCE_TYPE divType, ENUM_TREND_DIRECTION trend);
};

enum ENUM_TREND_DIRECTION
{
    TREND_UP,
    TREND_DOWN,
    TREND_FLAT
};
```

### 3. RiskManager.mqh

```mql5
//+------------------------------------------------------------------+
//| Classe gestione rischio                                           |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
    double      m_riskPercent;
    double      m_maxDailyLoss;
    double      m_maxTotalDD;
    int         m_maxOpenTrades;
    int         m_maxTradesPerDay;
    
    double      m_initialBalance;
    double      m_dailyStartBalance;
    int         m_tradesToday;
    datetime    m_lastTradeDay;
    
public:
    bool Init(double riskPct, double maxDaily, double maxTotal, 
              int maxOpen, int maxPerDay);
    
    // Calcolo position size
    double CalculateLotSize(double slPips);
    double CalculateLotSizeByRisk(double entryPrice, double slPrice);
    
    // Controlli rischio
    bool CanOpenTrade(void);
    bool CheckDailyLimit(void);
    bool CheckTotalDrawdown(void);
    bool CheckMaxOpenTrades(void);
    bool CheckMaxTradesPerDay(void);
    
    // Update
    void OnNewDay(void);
    void OnTradeOpen(void);
    void OnTradeClose(double profit);
    
    // Getters
    double GetCurrentDrawdown(void);
    double GetDailyPnL(void);
    int GetOpenTradesCount(void);
    int GetTradesToday(void);
    
    // Emergency
    void CloseAllTrades(string reason);
};
```

### 4. TradeManager.mqh

```mql5
//+------------------------------------------------------------------+
//| Classe gestione trade                                             |
//+------------------------------------------------------------------+
class CTradeManager
{
private:
    CTrade      m_trade;
    ulong       m_magic;
    string      m_symbol;
    
    // Struttura per gestire partial close
    struct TradeInfo
    {
        ulong    ticket;
        double   entryPrice;
        double   originalSL;
        double   originalTP;
        double   originalLots;
        int      partialCloseCount;
        bool     movedToBreakeven;
    };
    
    TradeInfo   m_activeTrades[];
    
public:
    bool Init(ulong magic, string symbol);
    
    // Open trade
    ulong OpenBuy(double lots, double sl, double tp, string comment);
    ulong OpenSell(double lots, double sl, double tp, string comment);
    
    // Modify
    bool ModifySL(ulong ticket, double newSL);
    bool ModifyTP(ulong ticket, double newTP);
    bool MoveToBreakeven(ulong ticket, int bufferPips);
    
    // Close
    bool ClosePartial(ulong ticket, double percent);
    bool ClosePosition(ulong ticket);
    void CloseAll(void);
    
    // Trailing
    void ManageTrailingStop(ENUM_TRAIL_METHOD method, double param);
    void TrailByATR(ulong ticket, double atrMultiplier);
    void TrailBySwing(ulong ticket);
    
    // Info
    bool HasOpenPosition(void);
    int GetOpenPositionsCount(void);
    double GetPositionProfit(ulong ticket);
    double GetTotalProfit(void);
};
```

---

## 🔄 Logica Principale EA

### OnInit()

```mql5
int OnInit()
{
    // 1. Validazione parametri
    if(!ValidateInputs())
        return INIT_PARAMETERS_INCORRECT;
    
    // 2. Inizializza classi
    if(!g_divDetector.Init(_Symbol, TF_Setup, RSI_Period, SwingStrength))
        return INIT_FAILED;
    
    if(!g_signalConfirm.Init(_Symbol, TF_Entry))
        return INIT_FAILED;
        
    if(!g_riskManager.Init(RiskPercent, MaxDailyLossPercent, 
                           MaxTotalDDPercent, MaxOpenTrades, MaxTradesPerDay))
        return INIT_FAILED;
        
    if(!g_tradeManager.Init(MagicNumber, _Symbol))
        return INIT_FAILED;
    
    // 3. Inizializza indicatori
    g_rsiHandle = iRSI(_Symbol, TF_Setup, RSI_Period, PRICE_CLOSE);
    g_atrHandle = iATR(_Symbol, TF_Entry, ATR_Period);
    g_adxHandle = iADX(_Symbol, TF_Setup, ADX_Period);
    g_emaFastHandle = iMA(_Symbol, TF_Trend, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
    g_emaSlowHandle = iMA(_Symbol, TF_Trend, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
    
    // 4. Setup dashboard
    if(ShowDashboard)
        CreateDashboard();
    
    // 5. Log start
    LogMessage("EA initialized successfully");
    
    return INIT_SUCCEEDED;
}
```

### OnTick()

```mql5
void OnTick()
{
    // 1. Check new bar (evita over-processing)
    if(!IsNewBar(TF_Entry))
        return;
    
    // 2. Update dashboard
    if(ShowDashboard)
        UpdateDashboard();
    
    // 3. Gestisci posizioni aperte
    ManageOpenPositions();
    
    // 4. Check se possiamo tradare
    if(!CanTrade())
        return;
    
    // 5. Cerca segnali
    CheckForSignal();
}
```

### CheckForSignal()

```mql5
void CheckForSignal()
{
    // 1. Detect divergenza su TF_Setup
    int swing1Bar, swing2Bar;
    ENUM_DIVERGENCE_TYPE divType = g_divDetector.DetectDivergence(swing1Bar, swing2Bar);
    
    if(divType == DIV_NONE)
        return;
    
    // 2. Verifica filtri
    if(!PassesFilters(divType))
        return;
    
    // 3. Cerca conferma su TF_Entry
    bool confirmed = false;
    
    if(divType == DIV_REGULAR_BULLISH || divType == DIV_HIDDEN_BULLISH)
        confirmed = g_signalConfirm.HasBullishConfirmation(1);
    else
        confirmed = g_signalConfirm.HasBearishConfirmation(1);
    
    if(!confirmed && RequireCandleConfirm)
        return;
    
    // 4. Calcola SL/TP
    double entryPrice, slPrice, tp1Price, tp2Price;
    CalculateLevels(divType, swing1Bar, swing2Bar, 
                    entryPrice, slPrice, tp1Price, tp2Price);
    
    // 5. Calcola lot size
    double lots = g_riskManager.CalculateLotSizeByRisk(entryPrice, slPrice);
    
    if(lots <= 0)
    {
        LogMessage("Lot size calculation failed or risk too high");
        return;
    }
    
    // 6. Esegui trade
    ExecuteTrade(divType, lots, entryPrice, slPrice, tp1Price);
}
```

### ManageOpenPositions()

```mql5
void ManageOpenPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!PositionSelectByTicket(PositionGetTicket(i)))
            continue;
            
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
            continue;
        
        ulong ticket = PositionGetInteger(POSITION_TICKET);
        double profit = PositionGetDouble(POSITION_PROFIT);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        
        // 1. Check TP1 hit - partial close
        if(ShouldPartialClose(ticket, profit))
        {
            g_tradeManager.ClosePartial(ticket, TP1_ClosePercent);
            
            if(MoveToBreakeven)
                g_tradeManager.MoveToBreakeven(ticket, BreakevenBufferPips);
        }
        
        // 2. Check TP2 hit - more partial close
        if(ShouldSecondPartialClose(ticket, profit))
        {
            g_tradeManager.ClosePartial(ticket, TP2_ClosePercent);
        }
        
        // 3. Trailing stop
        if(UseTrailingStop && ShouldStartTrailing(ticket, profit))
        {
            g_tradeManager.ManageTrailingStop(TrailMethod, 
                TrailMethod == TRAIL_ATR ? TrailATRMultiplier : TrailFixedPips);
        }
    }
    
    // 4. Check emergency close
    if(g_riskManager.CheckTotalDrawdown() == false)
    {
        g_riskManager.CloseAllTrades("Max drawdown reached");
    }
}
```

---

## 📊 Dashboard Specifiche

```mql5
// Posizione e colori dashboard
#define DASHBOARD_X      10
#define DASHBOARD_Y      30
#define DASHBOARD_WIDTH  250
#define COLOR_HEADER     clrDodgerBlue
#define COLOR_PROFIT     clrLime
#define COLOR_LOSS       clrRed
#define COLOR_NEUTRAL    clrWhite

void CreateDashboard()
{
    // Header
    CreateLabel("dash_header", "RSI Divergence Pro v1.0", 
                DASHBOARD_X, DASHBOARD_Y, COLOR_HEADER, 12);
    
    // Account info
    CreateLabel("dash_balance", "Balance: ", DASHBOARD_X, DASHBOARD_Y + 25);
    CreateLabel("dash_equity", "Equity: ", DASHBOARD_X, DASHBOARD_Y + 40);
    CreateLabel("dash_dd", "Drawdown: ", DASHBOARD_X, DASHBOARD_Y + 55);
    
    // Daily stats
    CreateLabel("dash_daily_pnl", "Daily P/L: ", DASHBOARD_X, DASHBOARD_Y + 80);
    CreateLabel("dash_trades_today", "Trades Today: ", DASHBOARD_X, DASHBOARD_Y + 95);
    
    // Current signal
    CreateLabel("dash_signal", "Signal: None", DASHBOARD_X, DASHBOARD_Y + 120);
    CreateLabel("dash_rsi", "RSI: ", DASHBOARD_X, DASHBOARD_Y + 135);
    CreateLabel("dash_trend", "Trend: ", DASHBOARD_X, DASHBOARD_Y + 150);
    CreateLabel("dash_adx", "ADX: ", DASHBOARD_X, DASHBOARD_Y + 165);
    
    // Open positions
    CreateLabel("dash_positions", "Open Positions: 0", DASHBOARD_X, DASHBOARD_Y + 190);
    CreateLabel("dash_total_profit", "Total Profit: ", DASHBOARD_X, DASHBOARD_Y + 205);
}

void UpdateDashboard()
{
    // Update values
    ObjectSetString(0, "dash_balance", OBJPROP_TEXT, 
        StringFormat("Balance: $%.2f", AccountInfoDouble(ACCOUNT_BALANCE)));
    
    ObjectSetString(0, "dash_equity", OBJPROP_TEXT,
        StringFormat("Equity: $%.2f", AccountInfoDouble(ACCOUNT_EQUITY)));
    
    double dd = g_riskManager.GetCurrentDrawdown();
    ObjectSetString(0, "dash_dd", OBJPROP_TEXT,
        StringFormat("Drawdown: %.2f%%", dd));
    ObjectSetInteger(0, "dash_dd", OBJPROP_COLOR, 
        dd > 3.0 ? COLOR_LOSS : COLOR_NEUTRAL);
    
    // ... altri update
}
```

---

## 📝 Logging System

```mql5
void LogMessage(string message, bool toFile = true, bool toExperts = true)
{
    string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
    string fullMsg = StringFormat("[%s] %s", timestamp, message);
    
    if(toExperts)
        Print(fullMsg);
    
    if(toFile && WriteLogFile)
    {
        int handle = FileOpen(LogFileName + ".log", 
                             FILE_WRITE|FILE_READ|FILE_TXT|FILE_SHARE_READ);
        if(handle != INVALID_HANDLE)
        {
            FileSeek(handle, 0, SEEK_END);
            FileWriteString(handle, fullMsg + "\n");
            FileClose(handle);
        }
    }
}

void LogTrade(string action, ulong ticket, double price, double sl, double tp, double lots)
{
    string msg = StringFormat("%s - Ticket: %d, Price: %.5f, SL: %.5f, TP: %.5f, Lots: %.2f",
                              action, ticket, price, sl, tp, lots);
    LogMessage(msg);
}
```

---

## ✅ Test Cases

### Unit Tests da Implementare

```
1. DivergenceDetector Tests:
   - [ ] Rileva correttamente Regular Bullish Divergence
   - [ ] Rileva correttamente Regular Bearish Divergence
   - [ ] Rileva correttamente Hidden Bullish Divergence
   - [ ] Rileva correttamente Hidden Bearish Divergence
   - [ ] Non genera falsi positivi in trend forte
   - [ ] Rispetta MinDivergenceBars e MaxDivergenceBars

2. RiskManager Tests:
   - [ ] Calcola correttamente lot size per 0.5% risk
   - [ ] Blocca trade quando DD > 5%
   - [ ] Blocca trade quando daily loss > 1.5%
   - [ ] Rispetta MaxOpenTrades
   - [ ] Rispetta MaxTradesPerDay
   - [ ] Reset corretto contatori a nuovo giorno

3. TradeManager Tests:
   - [ ] Apertura ordini corretta (Buy/Sell)
   - [ ] Partial close funziona correttamente
   - [ ] Move to breakeven funziona
   - [ ] Trailing stop funziona (tutti i metodi)
   - [ ] CloseAll chiude tutte le posizioni

4. SignalConfirm Tests:
   - [ ] Identifica Pin Bar correttamente
   - [ ] Identifica Engulfing correttamente
   - [ ] Trova S/R levels correttamente
   - [ ] Trend filter funziona
```

---

## 🚀 Deployment Checklist

### Pre-Launch

- [ ] Backtest su 3+ anni di dati
- [ ] Optimization senza overfitting
- [ ] Forward test su demo 1+ mese
- [ ] Test su tutti gli asset target
- [ ] Verifica gestione errori (no connection, etc.)
- [ ] Test weekend/holiday handling
- [ ] Verifica news filter funzionante

### Parametri Consigliati per Prop Firm

```
RiskPercent = 0.5
MaxDailyLossPercent = 1.5
MaxTotalDDPercent = 4.5  // Buffer di sicurezza
MaxOpenTrades = 2
MaxTradesPerDay = 3
SL_Method = SL_SWING
TP1_RiskReward = 1.5
MoveToBreakeven = true
UseTrailingStop = true
UseTrendFilter = true
ADX_Max = 35
```

---

## 📚 Note per Claude Code

### Priorità Sviluppo

1. **ALTA**: DivergenceDetector (core logic)
2. **ALTA**: RiskManager (sicurezza capitale)
3. **MEDIA**: TradeManager (esecuzione)
4. **MEDIA**: SignalConfirm (filtri qualità)
5. **BASSA**: Dashboard e Logging

### Comandi Utili

```bash
# Compila EA
# (da terminale MT5 o IDE)

# Test su strategy tester
# Usa "Every tick based on real ticks" per accuracy

# Genera report
# Export HTML dal strategy tester
```

### Riferimenti

- MQL5 Documentation: https://www.mql5.com/en/docs
- RSI Indicator: https://www.mql5.com/en/docs/indicators/irsi
- Trade Class: https://www.mql5.com/en/docs/standardlibrary/tradeclasses

---

*Documento Versione: 1.0*
*Creato per sviluppo con Claude Code*
*Ultimo aggiornamento: Gennaio 2026*
