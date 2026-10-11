//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                                             RSI Divergence Pro   |
//|            Position sizing e gestione rischio avanzata           |
//|                         VERSIONE 2.0                              |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Pro"
#property version   "2.00"
#property strict

#include <Trade/Trade.mqh>
#include "Utils.mqh"

//+------------------------------------------------------------------+
//| Classe: CRiskManager - Advanced Risk Management                   |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
    string      m_symbol;
    ulong       m_magic;
    double      m_riskPercent;
    double      m_maxDailyLossPercent;
    double      m_maxTotalDDPercent;
    double      m_minLot;
    double      m_maxLot;
    double      m_lotStep;
    double      m_initialBalance;
    double      m_dailyStartBalance;
    datetime    m_lastTradeDay;
    int         m_tradesToday;
    int         m_maxTradesPerDay;
    int         m_maxOpenTrades;

    CTrade      m_trade;

public:
    //+------------------------------------------------------------------+
    //| Constructor                                                       |
    //+------------------------------------------------------------------+
    CRiskManager()
    {
        m_symbol = "";
        m_magic = 0;
        m_riskPercent = 0.5;
        m_maxDailyLossPercent = 1.5;
        m_maxTotalDDPercent = 5.0;
        m_minLot = 0.01;
        m_maxLot = 100.0;
        m_lotStep = 0.01;
        m_initialBalance = 0;
        m_dailyStartBalance = 0;
        m_lastTradeDay = 0;
        m_tradesToday = 0;
        m_maxTradesPerDay = 5;
        m_maxOpenTrades = 2;
    }

    //+------------------------------------------------------------------+
    //| Inizializzazione                                                  |
    //+------------------------------------------------------------------+
    bool Initialize(string symbol, double riskPercent = 0.5,
                    double maxDailyLoss = 1.5, double maxTotalDD = 5.0,
                    int maxTradesPerDay = 5, int maxOpenTrades = 2,
                    ulong magic = 0)
    {
        m_symbol = symbol;
        m_magic = magic;
        m_riskPercent = riskPercent;
        m_maxDailyLossPercent = maxDailyLoss;
        m_maxTotalDDPercent = maxTotalDD;
        m_maxTradesPerDay = maxTradesPerDay;
        m_maxOpenTrades = maxOpenTrades;

        m_minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
        m_maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
        m_lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);

        if(m_minLot == 0 || m_lotStep == 0)
        {
            LogMessage("RiskManager: Impossibile ottenere limiti volume", true);
            return false;
        }

        m_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        m_dailyStartBalance = m_initialBalance;
        m_lastTradeDay = TimeCurrent();

        m_trade.SetExpertMagicNumber(m_magic);

        LogMessage(StringFormat("RiskManager v2.0: Risk=%.2f%%, MaxDaily=%.2f%%, MaxDD=%.2f%%, MaxOpen=%d, MaxPerDay=%d",
                                m_riskPercent, m_maxDailyLossPercent, m_maxTotalDDPercent,
                                m_maxOpenTrades, m_maxTradesPerDay));
        return true;
    }

    //+------------------------------------------------------------------+
    //| Set Magic Number (per uso con TradeManager)                      |
    //+------------------------------------------------------------------+
    void SetMagicNumber(ulong magic)
    {
        m_magic = magic;
        m_trade.SetExpertMagicNumber(m_magic);
    }

    //+------------------------------------------------------------------+
    //| Calcola lot size in base al rischio percentuale                  |
    //+------------------------------------------------------------------+
    double CalculateLotSize(double entryPrice, double stopLossPrice)
    {
        double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
        double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);

        if(tickValue == 0)
            tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);

        if(tickSize == 0 || tickValue == 0 || m_lotStep == 0)
        {
            LogMessage("CalculateLotSize: Dati simbolo non disponibili", true);
            return 0;
        }

        double slDistance = MathAbs(entryPrice - stopLossPrice);
        if(slDistance == 0)
        {
            LogMessage("CalculateLotSize: SL distance = 0", true);
            return 0;
        }

        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskMoney = accountBalance * m_riskPercent / 100.0;
        double ticksInSL = slDistance / tickSize;
        double lossPerLot = ticksInSL * tickValue;

        if(lossPerLot == 0)
        {
            LogMessage("CalculateLotSize: lossPerLot = 0", true);
            return 0;
        }

        double rawLots = riskMoney / lossPerLot;
        double lots = MathFloor(rawLots / m_lotStep) * m_lotStep;
        lots = MathMax(lots, m_minLot);
        lots = MathMin(lots, m_maxLot);

        LogMessage(StringFormat("LotSize: Balance=%.2f, Risk$=%.2f, SL=%.5f, Lots=%.2f",
                                accountBalance, riskMoney, slDistance, lots));

        return NormalizeDouble(lots, 2);
    }

    //+------------------------------------------------------------------+
    //| Verifica rischio effettivo di un trade                           |
    //+------------------------------------------------------------------+
    double VerifyRisk(double lots, double entryPrice, double stopLossPrice)
    {
        double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
        double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);

        if(tickValue == 0)
            tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);

        if(tickSize == 0 || tickValue == 0) return 0;

        double slDistance = MathAbs(entryPrice - stopLossPrice);
        double ticksInSL = slDistance / tickSize;
        double potentialLoss = ticksInSL * tickValue * lots;
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);

        if(accountBalance == 0) return 0;

        return (potentialLoss / accountBalance) * 100.0;
    }

    //+------------------------------------------------------------------+
    //| Verifica se possiamo aprire un nuovo trade                       |
    //+------------------------------------------------------------------+
    bool CanOpenTrade()
    {
        CheckNewDay();

        // Check max trades per day
        if(m_tradesToday >= m_maxTradesPerDay)
        {
            LogMessage(StringFormat("Max trades giornalieri raggiunti: %d/%d", m_tradesToday, m_maxTradesPerDay));
            return false;
        }

        // Check max open trades
        if(!CheckMaxOpenTrades())
        {
            LogMessage(StringFormat("Max posizioni aperte raggiunte: %d", m_maxOpenTrades));
            return false;
        }

        // Check daily loss limit
        if(!CheckDailyLimit())
        {
            LogMessage("Limite perdita giornaliera raggiunto");
            return false;
        }

        // Check total drawdown
        if(!CheckTotalDrawdown())
        {
            LogMessage("Limite drawdown totale raggiunto");
            return false;
        }

        return true;
    }

    //+------------------------------------------------------------------+
    //| Verifica numero massimo di posizioni aperte                      |
    //+------------------------------------------------------------------+
    bool CheckMaxOpenTrades()
    {
        int openCount = GetOpenTradesCount();
        return (openCount < m_maxOpenTrades);
    }

    //+------------------------------------------------------------------+
    //| Conta posizioni aperte con magic number                          |
    //+------------------------------------------------------------------+
    int GetOpenTradesCount()
    {
        int count = 0;
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;

            if(m_magic == 0 || PositionGetInteger(POSITION_MAGIC) == m_magic)
            {
                if(m_symbol == "" || PositionGetString(POSITION_SYMBOL) == m_symbol)
                    count++;
            }
        }
        return count;
    }

    //+------------------------------------------------------------------+
    //| Verifica limite perdita giornaliera                              |
    //+------------------------------------------------------------------+
    bool CheckDailyLimit()
    {
        double dailyPnL = GetDailyPnL();
        double dailyLossPercent = 0;

        if(m_dailyStartBalance > 0)
            dailyLossPercent = (dailyPnL / m_dailyStartBalance) * 100.0;

        if(dailyLossPercent < -m_maxDailyLossPercent)
        {
            LogMessage(StringFormat("Max daily loss: %.2f%% (limit: %.2f%%)",
                                    dailyLossPercent, -m_maxDailyLossPercent));
            return false;
        }
        return true;
    }

    //+------------------------------------------------------------------+
    //| Verifica drawdown totale                                         |
    //+------------------------------------------------------------------+
    bool CheckTotalDrawdown()
    {
        double currentDD = GetCurrentDrawdown();
        if(currentDD > m_maxTotalDDPercent)
        {
            LogMessage(StringFormat("Max drawdown: %.2f%% (limit: %.2f%%)",
                                    currentDD, m_maxTotalDDPercent));
            return false;
        }
        return true;
    }

    //+------------------------------------------------------------------+
    //| Calcola P/L giornaliero                                          |
    //+------------------------------------------------------------------+
    double GetDailyPnL()
    {
        return AccountInfoDouble(ACCOUNT_BALANCE) - m_dailyStartBalance;
    }

    //+------------------------------------------------------------------+
    //| Calcola drawdown corrente                                        |
    //+------------------------------------------------------------------+
    double GetCurrentDrawdown()
    {
        double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        if(m_initialBalance == 0 || currentEquity >= m_initialBalance) return 0;
        return ((m_initialBalance - currentEquity) / m_initialBalance) * 100.0;
    }

    //+------------------------------------------------------------------+
    //| Verifica cambio giorno e resetta contatori                       |
    //+------------------------------------------------------------------+
    void CheckNewDay()
    {
        MqlDateTime currentTime, lastTime;
        TimeToStruct(TimeCurrent(), currentTime);
        TimeToStruct(m_lastTradeDay, lastTime);

        if(currentTime.day != lastTime.day || currentTime.mon != lastTime.mon)
        {
            m_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
            m_tradesToday = 0;
            m_lastTradeDay = TimeCurrent();
            LogMessage("Nuovo giorno - contatori resettati");
        }
    }

    //+------------------------------------------------------------------+
    //| Chiude tutte le posizioni (EMERGENCY)                            |
    //+------------------------------------------------------------------+
    void CloseAll(string reason = "Emergency close")
    {
        LogMessage(StringFormat("=== CLOSE ALL: %s ===", reason), true);

        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;

            // Filtra per magic se specificato
            if(m_magic != 0 && PositionGetInteger(POSITION_MAGIC) != m_magic)
                continue;

            // Filtra per simbolo se specificato
            if(m_symbol != "" && PositionGetString(POSITION_SYMBOL) != m_symbol)
                continue;

            if(m_trade.PositionClose(ticket))
            {
                LogMessage(StringFormat("Posizione %d chiusa: %s", ticket, reason));
            }
            else
            {
                LogMessage(StringFormat("Errore chiusura posizione %d: %d",
                                        ticket, m_trade.ResultRetcode()), true);
            }
        }
    }

    //+------------------------------------------------------------------+
    //| Callback quando si apre un trade                                 |
    //+------------------------------------------------------------------+
    void OnTradeOpen()
    {
        m_tradesToday++;
        LogMessage(StringFormat("Trade aperto. Trades oggi: %d/%d", m_tradesToday, m_maxTradesPerDay));
    }

    //+------------------------------------------------------------------+
    //| Callback quando si chiude un trade                               |
    //+------------------------------------------------------------------+
    void OnTradeClose(double profit)
    {
        LogMessage(StringFormat("Trade chiuso. P/L: %.2f | Daily P/L: %.2f",
                                profit, GetDailyPnL()));
    }

    //+------------------------------------------------------------------+
    //| Verifica e chiude se limiti raggiunti                            |
    //+------------------------------------------------------------------+
    bool CheckAndCloseIfNeeded()
    {
        // Check drawdown critico
        double dd = GetCurrentDrawdown();
        if(dd > m_maxTotalDDPercent)
        {
            CloseAll(StringFormat("Max DD reached: %.2f%%", dd));
            return true;
        }

        // Check daily loss critico
        double dailyPnL = GetDailyPnL();
        double dailyLossPercent = 0;
        if(m_dailyStartBalance > 0)
            dailyLossPercent = (dailyPnL / m_dailyStartBalance) * 100.0;

        if(dailyLossPercent < -m_maxDailyLossPercent)
        {
            CloseAll(StringFormat("Max daily loss reached: %.2f%%", dailyLossPercent));
            return true;
        }

        return false;
    }

    //+------------------------------------------------------------------+
    //| Getters                                                          |
    //+------------------------------------------------------------------+
    double GetRiskPercent()         { return m_riskPercent; }
    int    GetTradesToday()         { return m_tradesToday; }
    int    GetMaxTradesPerDay()     { return m_maxTradesPerDay; }
    int    GetMaxOpenTrades()       { return m_maxOpenTrades; }
    double GetMaxDailyLossPercent() { return m_maxDailyLossPercent; }
    double GetMaxTotalDDPercent()   { return m_maxTotalDDPercent; }
    double GetInitialBalance()      { return m_initialBalance; }
    double GetDailyStartBalance()   { return m_dailyStartBalance; }

    //+------------------------------------------------------------------+
    //| Setters                                                          |
    //+------------------------------------------------------------------+
    void SetMaxOpenTrades(int max)      { m_maxOpenTrades = max; }
    void SetMaxTradesPerDay(int max)    { m_maxTradesPerDay = max; }
    void SetRiskPercent(double risk)    { m_riskPercent = risk; }
};
