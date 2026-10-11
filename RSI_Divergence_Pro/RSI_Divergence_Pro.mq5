//+------------------------------------------------------------------+
//|                                          RSI_Divergence_Pro.mq5  |
//|                                             RSI Divergence Pro   |
//|            Expert Advisor per trading divergenze RSI             |
//|      Multi-Timeframe, Partial Close, Trailing, Dashboard         |
//|                         VERSIONE 3.0                              |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Pro"
#property link      ""
#property version   "3.00"
#property strict

//+------------------------------------------------------------------+
//| Includes                                                          |
//+------------------------------------------------------------------+
#include "Include/Utils.mqh"
#include "Include/DivergenceDetector.mqh"
#include "Include/RiskManager.mqh"
#include "Include/SignalConfirm.mqh"
#include "Include/TradeManager.mqh"

//+------------------------------------------------------------------+
//| Input Parameters - Sezione 1: RSI SETTINGS                        |
//+------------------------------------------------------------------+
input group "=== 1. RSI SETTINGS ==="
input int      InpRSIPeriod           = 14;          // RSI Period
input int      InpRSIOverbought       = 70;          // RSI Overbought
input int      InpRSIOversold         = 30;          // RSI Oversold
input bool     InpUseAdaptiveLevels   = false;       // Use Adaptive OB/OS Levels
input int      InpAdaptiveOB_Uptrend  = 80;          // Adaptive OB in Uptrend
input int      InpAdaptiveOS_Uptrend  = 40;          // Adaptive OS in Uptrend
input int      InpAdaptiveOB_Downtrend= 60;          // Adaptive OB in Downtrend
input int      InpAdaptiveOS_Downtrend= 20;          // Adaptive OS in Downtrend

//+------------------------------------------------------------------+
//| Input Parameters - Sezione 2: DIVERGENCE DETECTION                |
//+------------------------------------------------------------------+
input group "=== 2. DIVERGENCE DETECTION ==="
input int      InpSwingStrength       = 2;           // Swing Strength (2=sensitive, 3=moderate)
input int      InpMinBarsBetween      = 5;           // Min bars between swings
input int      InpMaxBarsBetween      = 50;          // Max bars between swings
input double   InpMinRSIDiff          = 2.0;         // Min RSI difference between swings
input bool     InpTradeRegular        = true;        // Trade Regular Divergence
input bool     InpTradeHidden         = true;        // Trade Hidden Divergence
input bool     InpRequireExtremeZone  = false;       // Require OB/OS zone for first swing

//+------------------------------------------------------------------+
//| Input Parameters - Sezione 3: TIMEFRAMES                          |
//+------------------------------------------------------------------+
input group "=== 3. TIMEFRAMES ==="
input ENUM_TIMEFRAMES InpTF_Trend     = PERIOD_D1;   // Trend Timeframe (EMA 50/200)
input ENUM_TIMEFRAMES InpTF_Setup     = PERIOD_H4;   // Setup Timeframe (Divergence)
input ENUM_TIMEFRAMES InpTF_Entry     = PERIOD_H1;   // Entry Timeframe (Patterns)
input bool     InpUseMTFConfirmation  = true;        // Require MTF Trend Alignment

//+------------------------------------------------------------------+
//| Input Parameters - Sezione 4: ENTRY CONFIRMATION                  |
//+------------------------------------------------------------------+
input group "=== 4. ENTRY CONFIRMATION ==="
input ENUM_CONFIRM_TYPE InpConfirmType= CONFIRM_ANY_PATTERN; // Candlestick Confirmation
input bool     InpRequireSRConfluence = false;       // Require S/R Confluence
input int      InpSRLookback          = 100;         // S/R Lookback Bars
input int      InpSRProximityPips     = 20;          // S/R Proximity (pips)

//+------------------------------------------------------------------+
//| Input Parameters - Sezione 5: RISK MANAGEMENT                     |
//+------------------------------------------------------------------+
input group "=== 5. RISK MANAGEMENT ==="
input double   InpRiskPercent         = 0.5;         // Risk % per trade
input double   InpMaxDailyLoss        = 1.5;         // Max daily loss %
input double   InpMaxTotalDD          = 5.0;         // Max total drawdown %
input int      InpMaxOpenTrades       = 2;           // Max simultaneous trades
input int      InpMaxTradesPerDay     = 3;           // Max trades per day

//+------------------------------------------------------------------+
//| Input Parameters - Sezione 6: STOP LOSS                           |
//+------------------------------------------------------------------+
input group "=== 6. STOP LOSS ==="
input ENUM_SL_METHOD InpSLMethod      = SL_SWING;    // SL Method
input double   InpSLATRMultiplier     = 1.5;         // ATR Multiplier (for ATR/Hybrid)
input int      InpSLFixedPips         = 50;          // Fixed SL (pips)
input int      InpSLBufferPips        = 10;          // SL Buffer beyond swing (pips)
input int      InpATRPeriod           = 14;          // ATR Period

//+------------------------------------------------------------------+
//| Input Parameters - Sezione 7: TAKE PROFIT                         |
//+------------------------------------------------------------------+
input group "=== 7. TAKE PROFIT (Partial Close) ==="
input double   InpTP1_RR              = 1.5;         // TP1 Risk:Reward
input int      InpTP1_ClosePercent    = 50;          // TP1 Close % of position
input double   InpTP2_RR              = 2.5;         // TP2 Risk:Reward
input int      InpTP2_ClosePercent    = 30;          // TP2 Close % of remaining
input double   InpTP3_RR              = 4.0;         // TP3 Risk:Reward (final target)
input bool     InpMoveToBreakeven     = true;        // Move SL to BE after TP1
input int      InpBEBufferPips        = 5;           // BE Buffer (pips profit)

//+------------------------------------------------------------------+
//| Input Parameters - Sezione 8: TRAILING STOP                       |
//+------------------------------------------------------------------+
input group "=== 8. TRAILING STOP ==="
input ENUM_TRAIL_METHOD InpTrailMethod= TRAIL_ATR;   // Trailing Method
input double   InpTrailATRMultiplier  = 1.0;         // Trail ATR Multiplier
input int      InpTrailFixedPips      = 30;          // Trail Fixed (pips)
input int      InpTrailStartPips      = 50;          // Start trailing after (pips profit)

//+------------------------------------------------------------------+
//| Input Parameters - Sezione 9: FILTERS                             |
//+------------------------------------------------------------------+
input group "=== 9. FILTERS ==="
input bool     InpUseTrendFilter      = true;        // Use EMA Trend Filter
input int      InpEMAFast             = 50;          // Fast EMA Period
input int      InpEMASlow             = 200;         // Slow EMA Period
input bool     InpUseADXFilter        = true;        // Use ADX Filter
input int      InpADXPeriod           = 14;          // ADX Period
input int      InpADXMin              = 15;          // Min ADX (avoid flat)
input int      InpADXMax              = 35;          // Max ADX (avoid strong trend)
input bool     InpAvoidNews           = false;       // Avoid News [PLACEHOLDER]
input int      InpNewsBufferMinutes   = 30;          // News Buffer (minutes) [PLACEHOLDER]

//+------------------------------------------------------------------+
//| Input Parameters - Sezione 10: TRADING HOURS                      |
//+------------------------------------------------------------------+
input group "=== 10. TRADING HOURS ==="
input bool     InpUseTradingHours     = false;       // Enable Trading Hours Filter
input int      InpStartHour           = 8;           // Start Hour (broker time)
input int      InpEndHour             = 20;          // End Hour (broker time)
input bool     InpTradeMonday         = true;        // Trade Monday
input bool     InpTradeTuesday        = true;        // Trade Tuesday
input bool     InpTradeWednesday      = true;        // Trade Wednesday
input bool     InpTradeThursday       = true;        // Trade Thursday
input bool     InpTradeFriday         = true;        // Trade Friday
input bool     InpCloseOnFriday       = true;        // Close all before weekend
input int      InpFridayCloseHour     = 20;          // Friday close hour

//+------------------------------------------------------------------+
//| Input Parameters - Sezione 11: DISPLAY & LOGGING                  |
//+------------------------------------------------------------------+
input group "=== 11. DISPLAY & LOGGING ==="
input bool     InpShowDashboard       = true;        // Show Dashboard Panel
input bool     InpShowDivergenceLines = true;        // Draw Divergence Lines
input bool     InpEnableAlerts        = true;        // Enable Alerts
input bool     InpWriteLogFile        = true;        // Write Log File
input string   InpLogFileName         = "RSI_Div_Log"; // Log File Name

//+------------------------------------------------------------------+
//| Input Parameters - GENERAL                                        |
//+------------------------------------------------------------------+
input group "=== GENERAL ==="
input ulong    InpMagicNumber         = 123456;      // Magic Number
input int      InpSlippage            = 10;          // Slippage (points)

//+------------------------------------------------------------------+
//| Global Objects                                                    |
//+------------------------------------------------------------------+
CDivergenceDetector g_divDetector;
CRiskManager        g_riskManager;
CSignalConfirm      g_signalConfirm;
CTradeManager       g_tradeManager;

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
datetime g_lastBarTimeEntry = 0;
datetime g_lastBarTimeSetup = 0;
DashboardState g_dashboard;

// Dashboard object names
string g_dashPrefix = "RSI_DIV_DASH_";

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
    LogMsg("==============================================");
    LogMsg("RSI Divergence Pro EA v3.0 - INITIALIZING");
    LogMsg("==============================================");

    // Validate inputs
    if(!ValidateInputs())
        return INIT_PARAMETERS_INCORRECT;

    // Initialize DivergenceDetector on TF_Setup
    if(!g_divDetector.Initialize(_Symbol, InpTF_Setup, InpRSIPeriod,
                                  InpSwingStrength, InpMinBarsBetween,
                                  InpMaxBarsBetween, InpRSIOverbought,
                                  InpRSIOversold, InpRequireExtremeZone))
    {
        Alert("Errore DivergenceDetector");
        return INIT_FAILED;
    }

    // Configure adaptive levels
    g_divDetector.SetAdaptiveLevels(InpUseAdaptiveLevels,
                                     InpAdaptiveOB_Uptrend, InpAdaptiveOS_Uptrend,
                                     InpAdaptiveOB_Downtrend, InpAdaptiveOS_Downtrend);
    g_divDetector.SetMinRSIDiff(InpMinRSIDiff);
    g_divDetector.SetDebugMode(false); // Disable verbose debug

    // Initialize RiskManager
    if(!g_riskManager.Initialize(_Symbol, InpRiskPercent, InpMaxDailyLoss,
                                  InpMaxTotalDD, InpMaxTradesPerDay,
                                  InpMaxOpenTrades, InpMagicNumber))
    {
        Alert("Errore RiskManager");
        return INIT_FAILED;
    }

    // Initialize SignalConfirm with MTF
    if(!g_signalConfirm.Initialize(_Symbol, InpTF_Entry, InpTF_Trend, InpTF_Setup,
                                    InpEMAFast, InpEMASlow, InpADXPeriod))
    {
        Alert("Errore SignalConfirm");
        return INIT_FAILED;
    }
    g_signalConfirm.SetSRParameters(InpSRLookback, InpSRProximityPips);

    // Initialize TradeManager
    if(!g_tradeManager.Initialize(_Symbol, InpMagicNumber, InpSlippage,
                                   InpTF_Entry, InpATRPeriod))
    {
        Alert("Errore TradeManager");
        return INIT_FAILED;
    }

    // Configure TradeManager
    g_tradeManager.SetSLMethod(InpSLMethod, InpSLATRMultiplier, InpSLFixedPips, InpSLBufferPips);
    g_tradeManager.SetTrailingMethod(InpTrailMethod, InpTrailATRMultiplier,
                                      InpTrailFixedPips, InpTrailStartPips);
    g_tradeManager.SetupTPLevels(InpTP1_RR, InpTP1_ClosePercent,
                                  InpTP2_RR, InpTP2_ClosePercent, InpTP3_RR);
    g_tradeManager.EnableMoveToBE(InpMoveToBreakeven);
    g_tradeManager.SetBEBufferPips(InpBEBufferPips);

    // Setup dashboard
    g_dashboard.Reset();
    if(InpShowDashboard)
        CreateDashboard();

    // Print configuration
    PrintConfiguration();

    LogMsg("RSI Divergence Pro EA v3.0 - INITIALIZED SUCCESSFULLY");

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up dashboard
    if(InpShowDashboard)
        DeleteDashboard();

    // Deinitialize components
    g_divDetector.Deinitialize();
    g_signalConfirm.Deinitialize();
    g_tradeManager.Deinitialize();

    LogMsg(StringFormat("RSI Divergence Pro - Deinit. Reason: %d", reason));
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // 1. Update Dashboard
    if(InpShowDashboard)
        UpdateDashboard();

    // 2. Manage open positions (partial close, trailing)
    g_tradeManager.ManagePartialCloses();
    g_tradeManager.ManageTrailingStop();

    // 3. Check risk limits
    if(g_riskManager.CheckAndCloseIfNeeded())
    {
        LogMsg("RISK LIMIT REACHED - Positions closed", true);
        return;
    }

    // 4. Check Friday close
    if(InpCloseOnFriday && ShouldCloseFriday())
    {
        g_tradeManager.CloseAll();
        LogMsg("Friday close - All positions closed");
        return;
    }

    // 5. Check new bar on TF_Entry for position management
    bool newBarEntry = IsNewBar(_Symbol, InpTF_Entry, g_lastBarTimeEntry);

    // 6. Check new bar on TF_Setup for divergence detection
    bool newBarSetup = IsNewBar(_Symbol, InpTF_Setup, g_lastBarTimeSetup);

    // Only proceed on new bar (ANTI-REPAINTING)
    if(!newBarSetup)
        return;

    // 7. Check trading conditions
    if(!CanTrade())
        return;

    // 8. Check if we can open new trades
    if(g_tradeManager.HasOpenPosition())
        return;

    if(!g_riskManager.CanOpenTrade())
        return;

    // 9. Get trend direction for adaptive levels
    ENUM_TREND_DIRECTION trend = g_signalConfirm.GetTrendDirection();
    g_divDetector.SetCurrentTrend(trend);

    // 10. Detect divergence on TF_Setup
    ENUM_DIVERGENCE_TYPE divType = g_divDetector.DetectDivergence();

    if(divType == DIVERGENCE_NONE)
        return;

    LogMsg(StringFormat(">>> DIVERGENCE DETECTED: %s", DivergenceTypeToString(divType)));

    // 11. Check if we should trade this divergence type
    if(!ShouldTradeDivergence(divType))
    {
        LogMsg("Divergence type not enabled, skip");
        return;
    }

    // 12. Apply filters
    if(!PassesFilters(divType, trend))
    {
        LogMsg("Filters not passed, skip");
        return;
    }

    // 13. Check candlestick confirmation on TF_Entry
    bool isBullish = IsBullishDivergence(divType);
    if(!g_signalConfirm.HasConfirmation(InpConfirmType, isBullish))
    {
        LogMsg("No candlestick confirmation, skip");
        return;
    }

    // 14. Check S/R confluence if required
    if(InpRequireSRConfluence)
    {
        double currentPrice = isBullish ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if(!g_signalConfirm.HasSRConfluence(isBullish, currentPrice))
        {
            LogMsg("No S/R confluence, skip");
            return;
        }
    }

    // 15. Execute trade
    LogMsg(">>> ALL CONDITIONS MET - Executing trade");
    ExecuteTrade(divType, isBullish);

    // 16. Draw divergence lines if enabled
    if(InpShowDivergenceLines && g_divDetector.HasValidDivergenceForDrawing())
    {
        DrawDivergenceLines();
    }
}

//+------------------------------------------------------------------+
//| Validate inputs                                                   |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
    if(InpRSIPeriod < 2 || InpRSIPeriod > 100)
    {
        Alert("RSI Period: 2-100");
        return false;
    }

    if(InpSwingStrength < 1 || InpSwingStrength > 20)
    {
        Alert("Swing Strength: 1-20");
        return false;
    }

    if(InpMinBarsBetween >= InpMaxBarsBetween)
    {
        Alert("Min bars must be < Max bars");
        return false;
    }

    if(InpRiskPercent <= 0 || InpRiskPercent > 10)
    {
        Alert("Risk %: 0.1-10");
        return false;
    }

    if(InpTP1_ClosePercent + InpTP2_ClosePercent > 100)
    {
        Alert("TP1% + TP2% must be <= 100");
        return false;
    }

    if(InpStartHour >= InpEndHour)
    {
        Alert("Start hour must be < End hour");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Print configuration                                               |
//+------------------------------------------------------------------+
void PrintConfiguration()
{
    Print("----------------------------------------------");
    Print("CONFIGURATION:");
    Print(StringFormat("Symbol: %s", _Symbol));
    Print(StringFormat("TF: Trend=%s, Setup=%s, Entry=%s",
                       EnumToString(InpTF_Trend), EnumToString(InpTF_Setup), EnumToString(InpTF_Entry)));
    Print(StringFormat("RSI: Period=%d, OB=%d, OS=%d", InpRSIPeriod, InpRSIOverbought, InpRSIOversold));
    Print(StringFormat("Divergence: Swing=%d, Bars=%d-%d, Regular=%s, Hidden=%s",
                       InpSwingStrength, InpMinBarsBetween, InpMaxBarsBetween,
                       InpTradeRegular ? "ON" : "OFF", InpTradeHidden ? "ON" : "OFF"));
    Print(StringFormat("Risk: %.2f%%, MaxDaily=%.2f%%, MaxDD=%.2f%%",
                       InpRiskPercent, InpMaxDailyLoss, InpMaxTotalDD));
    Print(StringFormat("SL Method: %s | Trail: %s", SLMethodToString(InpSLMethod), TrailMethodToString(InpTrailMethod)));
    Print(StringFormat("TP: RR1=%.1f (%d%%), RR2=%.1f (%d%%), RR3=%.1f | BE=%s",
                       InpTP1_RR, InpTP1_ClosePercent, InpTP2_RR, InpTP2_ClosePercent, InpTP3_RR,
                       InpMoveToBreakeven ? "ON" : "OFF"));
    Print(StringFormat("Filters: Trend=%s, ADX=%s (%d-%d)",
                       InpUseTrendFilter ? "ON" : "OFF", InpUseADXFilter ? "ON" : "OFF",
                       InpADXMin, InpADXMax));
    Print(StringFormat("Magic: %d", InpMagicNumber));
    Print("----------------------------------------------");
}

//+------------------------------------------------------------------+
//| Check if we can trade now                                         |
//+------------------------------------------------------------------+
bool CanTrade()
{
    // Check market open
    if(!IsMarketOpen(_Symbol))
        return false;

    // Check trading hours
    if(InpUseTradingHours)
    {
        int hour = GetBrokerHour();
        if(hour < InpStartHour || hour >= InpEndHour)
            return false;

        // Check day of week
        int dow = GetDayOfWeek();
        switch(dow)
        {
            case 0: return false; // Sunday
            case 1: if(!InpTradeMonday) return false; break;
            case 2: if(!InpTradeTuesday) return false; break;
            case 3: if(!InpTradeWednesday) return false; break;
            case 4: if(!InpTradeThursday) return false; break;
            case 5: if(!InpTradeFriday) return false; break;
            case 6: return false; // Saturday
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| Check if should close on Friday                                   |
//+------------------------------------------------------------------+
bool ShouldCloseFriday()
{
    if(GetDayOfWeek() != 5) return false;
    if(GetBrokerHour() < InpFridayCloseHour) return false;
    return true;
}

//+------------------------------------------------------------------+
//| Check divergence type settings                                    |
//+------------------------------------------------------------------+
bool ShouldTradeDivergence(ENUM_DIVERGENCE_TYPE divType)
{
    if(divType == DIVERGENCE_BULLISH_REGULAR || divType == DIVERGENCE_BEARISH_REGULAR)
        return InpTradeRegular;

    if(divType == DIVERGENCE_BULLISH_HIDDEN || divType == DIVERGENCE_BEARISH_HIDDEN)
        return InpTradeHidden;

    return false;
}

//+------------------------------------------------------------------+
//| Apply filters                                                     |
//+------------------------------------------------------------------+
bool PassesFilters(ENUM_DIVERGENCE_TYPE divType, ENUM_TREND_DIRECTION trend)
{
    // Trend filter
    if(InpUseTrendFilter && InpUseMTFConfirmation)
    {
        if(!g_signalConfirm.IsTrendAligned(divType, trend))
        {
            LogMsg(StringFormat("Trend not aligned: %s vs %s",
                               DivergenceTypeToString(divType), TrendToString(trend)));
            return false;
        }
    }

    // ADX filter
    if(InpUseADXFilter)
    {
        if(!g_signalConfirm.PassesADXFilter(InpADXMin, InpADXMax))
        {
            double adx = g_signalConfirm.GetADX();
            LogMsg(StringFormat("ADX filter failed: %.1f (range: %d-%d)", adx, InpADXMin, InpADXMax));
            return false;
        }
    }

    // News filter placeholder
    if(InpAvoidNews)
    {
        // TODO: Implement news filter when news API available
        // For now, just log that it's enabled
        // LogMsg("News filter enabled but not implemented");
    }

    return true;
}

//+------------------------------------------------------------------+
//| Execute trade                                                     |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_DIVERGENCE_TYPE divType, bool isBullish)
{
    ENUM_ORDER_TYPE orderType = isBullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

    double entryPrice;
    if(isBullish)
        entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    else
        entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // Get pivot bar for SL calculation
    int pivotBarIndex = g_divDetector.GetPivotBarIndex();

    // Calculate SL based on configured method
    double stopLoss = g_tradeManager.CalculateStopLoss(orderType, entryPrice, pivotBarIndex);

    if(stopLoss == 0)
    {
        LogMsg("SL calculation failed", true);
        return;
    }

    double slDistance = MathAbs(entryPrice - stopLoss);
    if(slDistance == 0)
    {
        LogMsg("SL distance = 0", true);
        return;
    }

    // Calculate lot size
    double lots = g_riskManager.CalculateLotSize(entryPrice, stopLoss);
    if(lots <= 0)
    {
        LogMsg("Lot size calculation failed", true);
        return;
    }

    // Verify actual risk
    double actualRisk = g_riskManager.VerifyRisk(lots, entryPrice, stopLoss);
    LogMsg(StringFormat("Trade Setup: %s %s | Entry=%.5f | SL=%.5f | Lots=%.2f | Risk=%.2f%%",
                        isBullish ? "BUY" : "SELL", DivergenceTypeToString(divType),
                        entryPrice, stopLoss, lots, actualRisk));

    // Open position
    if(g_tradeManager.OpenPosition(orderType, lots, stopLoss))
    {
        g_riskManager.OnTradeOpen();

        // Alert
        if(InpEnableAlerts)
        {
            Alert(StringFormat("RSI Divergence Pro: %s %s opened on %s",
                              isBullish ? "BUY" : "SELL", DivergenceTypeToString(divType), _Symbol));
        }

        // Log to file
        if(InpWriteLogFile)
        {
            LogToFile(InpLogFileName, StringFormat("TRADE OPENED: %s %s | Entry=%.5f | SL=%.5f | Lots=%.2f",
                                                   isBullish ? "BUY" : "SELL", DivergenceTypeToString(divType),
                                                   entryPrice, stopLoss, lots));
        }
    }
}

//+------------------------------------------------------------------+
//| Create Dashboard                                                  |
//+------------------------------------------------------------------+
void CreateDashboard()
{
    int x = 10, y = 30;
    color headerColor = clrDodgerBlue;
    color textColor = clrWhite;

    // Background
    CreateRectLabel(g_dashPrefix + "BG", x - 5, y - 5, 260, 240, clrBlack, 200);

    // Header
    CreateLabel(g_dashPrefix + "Header", "RSI Divergence Pro v3.0", x, y, headerColor, 12, true);
    y += 25;

    // Account info
    CreateLabel(g_dashPrefix + "Balance", "Balance: $0.00", x, y, textColor); y += 15;
    CreateLabel(g_dashPrefix + "Equity", "Equity: $0.00", x, y, textColor); y += 15;
    CreateLabel(g_dashPrefix + "Drawdown", "Drawdown: 0.00%", x, y, textColor); y += 20;

    // Daily stats
    CreateLabel(g_dashPrefix + "DailyPnL", "Daily P/L: $0.00", x, y, textColor); y += 15;
    CreateLabel(g_dashPrefix + "TradesToday", "Trades Today: 0/0", x, y, textColor); y += 20;

    // Indicators
    CreateLabel(g_dashPrefix + "RSI", "RSI: 50.0", x, y, textColor); y += 15;
    CreateLabel(g_dashPrefix + "ADX", "ADX: 0.0", x, y, textColor); y += 15;
    CreateLabel(g_dashPrefix + "Trend", "Trend: Flat", x, y, textColor); y += 20;

    // Position info
    CreateLabel(g_dashPrefix + "Position", "Position: None", x, y, textColor); y += 15;
    CreateLabel(g_dashPrefix + "TP_Status", "TP Status: -", x, y, textColor); y += 15;
    CreateLabel(g_dashPrefix + "Signal", "Last Signal: None", x, y, textColor);
}

//+------------------------------------------------------------------+
//| Update Dashboard                                                  |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
    // Update account info
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double dd = g_riskManager.GetCurrentDrawdown();
    double dailyPnL = g_riskManager.GetDailyPnL();

    ObjectSetString(0, g_dashPrefix + "Balance", OBJPROP_TEXT,
                    StringFormat("Balance: $%.2f", balance));
    ObjectSetString(0, g_dashPrefix + "Equity", OBJPROP_TEXT,
                    StringFormat("Equity: $%.2f", equity));
    ObjectSetString(0, g_dashPrefix + "Drawdown", OBJPROP_TEXT,
                    StringFormat("Drawdown: %.2f%%", dd));
    ObjectSetInteger(0, g_dashPrefix + "Drawdown", OBJPROP_COLOR,
                     dd > 3.0 ? clrRed : clrWhite);

    ObjectSetString(0, g_dashPrefix + "DailyPnL", OBJPROP_TEXT,
                    StringFormat("Daily P/L: $%.2f", dailyPnL));
    ObjectSetInteger(0, g_dashPrefix + "DailyPnL", OBJPROP_COLOR,
                     dailyPnL >= 0 ? clrLime : clrRed);

    ObjectSetString(0, g_dashPrefix + "TradesToday", OBJPROP_TEXT,
                    StringFormat("Trades Today: %d/%d",
                                g_riskManager.GetTradesToday(), InpMaxTradesPerDay));

    // Update indicators
    double rsi = g_divDetector.GetRSI(1);
    double adx = g_signalConfirm.GetADX();
    ENUM_TREND_DIRECTION trend = g_signalConfirm.GetTrendDirection();

    ObjectSetString(0, g_dashPrefix + "RSI", OBJPROP_TEXT,
                    StringFormat("RSI: %.1f", rsi));
    ObjectSetInteger(0, g_dashPrefix + "RSI", OBJPROP_COLOR,
                     rsi > 70 ? clrRed : (rsi < 30 ? clrLime : clrWhite));

    ObjectSetString(0, g_dashPrefix + "ADX", OBJPROP_TEXT,
                    StringFormat("ADX: %.1f", adx));

    ObjectSetString(0, g_dashPrefix + "Trend", OBJPROP_TEXT,
                    StringFormat("Trend: %s", TrendToString(trend)));
    ObjectSetInteger(0, g_dashPrefix + "Trend", OBJPROP_COLOR,
                     trend == TREND_UP ? clrLime : (trend == TREND_DOWN ? clrRed : clrYellow));

    // Update position info
    if(g_tradeManager.HasActiveTrade())
    {
        SingleTradeInfo info = g_tradeManager.GetActiveTradeInfo();
        ObjectSetString(0, g_dashPrefix + "Position", OBJPROP_TEXT,
                        StringFormat("Position: %s @ %.5f",
                                    info.isBuy ? "LONG" : "SHORT", info.entryPrice));

        string tpStatus = "TP1: ";
        tpStatus += info.tp1Hit ? "HIT" : "Pending";
        tpStatus += " | TP2: ";
        tpStatus += info.tp2Hit ? "HIT" : "Pending";
        tpStatus += " | BE: ";
        tpStatus += info.movedToBE ? "Yes" : "No";

        ObjectSetString(0, g_dashPrefix + "TP_Status", OBJPROP_TEXT, tpStatus);
    }
    else
    {
        ObjectSetString(0, g_dashPrefix + "Position", OBJPROP_TEXT, "Position: None");
        ObjectSetString(0, g_dashPrefix + "TP_Status", OBJPROP_TEXT, "TP Status: -");
    }

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Delete Dashboard                                                  |
//+------------------------------------------------------------------+
void DeleteDashboard()
{
    ObjectsDeleteAll(0, g_dashPrefix);
}

//+------------------------------------------------------------------+
//| Create label helper                                               |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr,
                 int fontSize = 9, bool bold = false)
{
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| Create rectangle label helper                                     |
//+------------------------------------------------------------------+
void CreateRectLabel(string name, int x, int y, int width, int height,
                     color bgColor, uchar alpha = 200)
{
    ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
    ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Draw divergence lines on chart                                    |
//+------------------------------------------------------------------+
void DrawDivergenceLines()
{
    DivergenceSwings swings = g_divDetector.GetLastDivergenceSwings();

    if(swings.type == DIVERGENCE_NONE) return;

    // Delete old lines
    ObjectDelete(0, "DIV_PRICE_LINE");
    ObjectDelete(0, "DIV_RSI_LINE");

    // Get times for the swing bars
    datetime time1 = iTime(_Symbol, InpTF_Setup, swings.swing1Bar);
    datetime time2 = iTime(_Symbol, InpTF_Setup, swings.swing2Bar);

    // Determine color based on divergence type
    color lineColor = IsBullishDivergence(swings.type) ? clrLime : clrRed;

    // Draw price line
    ObjectCreate(0, "DIV_PRICE_LINE", OBJ_TREND, 0, time1, swings.swing1Price, time2, swings.swing2Price);
    ObjectSetInteger(0, "DIV_PRICE_LINE", OBJPROP_COLOR, lineColor);
    ObjectSetInteger(0, "DIV_PRICE_LINE", OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, "DIV_PRICE_LINE", OBJPROP_RAY_RIGHT, false);
}

//+------------------------------------------------------------------+
//| Log message helper                                                |
//+------------------------------------------------------------------+
void LogMsg(string message, bool isError = false)
{
    string prefix = isError ? "[ERROR] " : "[INFO] ";
    Print(prefix, message);

    if(InpWriteLogFile)
    {
        LogToFile(InpLogFileName, prefix + message);
    }
}
