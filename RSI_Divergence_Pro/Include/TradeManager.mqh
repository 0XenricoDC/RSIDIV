//+------------------------------------------------------------------+
//|                                                 TradeManager.mqh |
//|                                             RSI Divergence Pro   |
//|       Gestione ordini con partial close e trailing stop          |
//|            VERSIONE 3.0 - Single Position Architecture           |
//+------------------------------------------------------------------+
#property copyright "RSI Divergence Pro"
#property version   "3.00"
#property strict

#include <Trade/Trade.mqh>
#include "Utils.mqh"

//+------------------------------------------------------------------+
//| Classe: CTradeManager - Single Position with Partial Close       |
//+------------------------------------------------------------------+
class CTradeManager
{
private:
    CTrade          m_trade;
    string          m_symbol;
    ulong           m_magic;
    int             m_slippage;

    // SL/TP Configuration
    ENUM_SL_METHOD  m_slMethod;
    ENUM_TRAIL_METHOD m_trailMethod;
    double          m_slBufferPips;
    double          m_slATRMultiplier;
    int             m_slFixedPips;
    double          m_beBufferPips;

    // TP Configuration (R:R based)
    double          m_tp1RR;
    double          m_tp2RR;
    double          m_tp3RR;
    int             m_tp1Percent;
    int             m_tp2Percent;

    // Trailing configuration
    double          m_trailATRMultiplier;
    int             m_trailFixedPips;
    int             m_trailStartPips;

    // ATR Handle for SL/Trailing
    int             m_atrHandle;
    double          m_atrBuffer[];
    int             m_atrPeriod;
    ENUM_TIMEFRAMES m_timeframe;

    // Active trade tracking
    SingleTradeInfo m_activeTrade;
    bool            m_hasActiveTrade;

    // Move to BE settings
    bool            m_enableMoveToBE;

public:
    //+------------------------------------------------------------------+
    //| Constructor                                                       |
    //+------------------------------------------------------------------+
    CTradeManager()
    {
        m_symbol = "";
        m_magic = 0;
        m_slippage = 10;

        m_slMethod = SL_SWING;
        m_trailMethod = TRAIL_NONE;
        m_slBufferPips = 10.0;
        m_slATRMultiplier = 1.5;
        m_slFixedPips = 50;
        m_beBufferPips = 2.0;

        m_tp1RR = 1.5;
        m_tp2RR = 2.5;
        m_tp3RR = 4.0;
        m_tp1Percent = 50;
        m_tp2Percent = 30;

        m_trailATRMultiplier = 1.0;
        m_trailFixedPips = 30;
        m_trailStartPips = 50;

        m_atrHandle = INVALID_HANDLE;
        m_atrPeriod = 14;
        m_timeframe = PERIOD_H1;

        m_hasActiveTrade = false;
        m_enableMoveToBE = true;

        m_activeTrade.Reset();
    }

    ~CTradeManager() { Deinitialize(); }

    //+------------------------------------------------------------------+
    //| Inizializzazione                                                  |
    //+------------------------------------------------------------------+
    bool Initialize(string symbol, ulong magic, int slippage = 10,
                    ENUM_TIMEFRAMES timeframe = PERIOD_H1, int atrPeriod = 14)
    {
        m_symbol = symbol;
        m_magic = magic;
        m_slippage = slippage;
        m_timeframe = timeframe;
        m_atrPeriod = atrPeriod;

        m_trade.SetExpertMagicNumber(m_magic);
        m_trade.SetDeviationInPoints(m_slippage);
        m_trade.SetTypeFilling(GetSupportedFillingMode(m_symbol));

        // Create ATR handle for SL/Trailing calculations
        m_atrHandle = iATR(m_symbol, m_timeframe, m_atrPeriod);
        if(m_atrHandle == INVALID_HANDLE)
        {
            LogMessage("TradeManager: Impossibile creare handle ATR", true);
            return false;
        }

        ArraySetAsSeries(m_atrBuffer, true);

        LogMessage(StringFormat("TradeManager v3.0: Symbol=%s, Magic=%d, SL=%s, Trail=%s",
                                m_symbol, m_magic, SLMethodToString(m_slMethod),
                                TrailMethodToString(m_trailMethod)));
        return true;
    }

    void Deinitialize()
    {
        if(m_atrHandle != INVALID_HANDLE)
        {
            IndicatorRelease(m_atrHandle);
            m_atrHandle = INVALID_HANDLE;
        }
    }

    //+------------------------------------------------------------------+
    //| Configura metodi SL e Trailing                                   |
    //+------------------------------------------------------------------+
    void SetSLMethod(ENUM_SL_METHOD method, double atrMult = 1.5,
                     int fixedPips = 50, double bufferPips = 10.0)
    {
        m_slMethod = method;
        m_slATRMultiplier = atrMult;
        m_slFixedPips = fixedPips;
        m_slBufferPips = bufferPips;
    }

    void SetTrailingMethod(ENUM_TRAIL_METHOD method, double atrMult = 1.0,
                           int fixedPips = 30, int startPips = 50)
    {
        m_trailMethod = method;
        m_trailATRMultiplier = atrMult;
        m_trailFixedPips = fixedPips;
        m_trailStartPips = startPips;
    }

    //+------------------------------------------------------------------+
    //| Configura TP levels (R:R e percentuali partial close)            |
    //+------------------------------------------------------------------+
    void SetupTPLevels(double rr1, int pct1, double rr2, int pct2, double rr3)
    {
        m_tp1RR = rr1;
        m_tp2RR = rr2;
        m_tp3RR = rr3;
        m_tp1Percent = pct1;
        m_tp2Percent = pct2;
    }

    //+------------------------------------------------------------------+
    //| Abilita/disabilita Move to BE                                    |
    //+------------------------------------------------------------------+
    void EnableMoveToBE(bool enable) { m_enableMoveToBE = enable; }
    void SetBEBufferPips(double pips) { m_beBufferPips = pips; }

    //+------------------------------------------------------------------+
    //| CALCOLO SL - Metodo Swing                                        |
    //+------------------------------------------------------------------+
    double CalculateSL_Swing(ENUM_ORDER_TYPE orderType, int pivotBarIndex)
    {
        double buffer = PipsToPrice(m_symbol, m_slBufferPips);
        int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
        double stopLoss;

        if(orderType == ORDER_TYPE_BUY)
        {
            double pivotLow = iLow(m_symbol, m_timeframe, pivotBarIndex);
            stopLoss = pivotLow - buffer;
        }
        else
        {
            double pivotHigh = iHigh(m_symbol, m_timeframe, pivotBarIndex);
            stopLoss = pivotHigh + buffer;
        }

        return NormalizeDouble(stopLoss, digits);
    }

    //+------------------------------------------------------------------+
    //| CALCOLO SL - Metodo ATR                                          |
    //+------------------------------------------------------------------+
    double CalculateSL_ATR(ENUM_ORDER_TYPE orderType, double entryPrice)
    {
        if(CopyBuffer(m_atrHandle, 0, 1, 1, m_atrBuffer) < 1)
        {
            LogMessage("CalculateSL_ATR: Impossibile leggere ATR", true);
            return 0;
        }

        double atr = m_atrBuffer[0];
        double slDistance = atr * m_slATRMultiplier;
        int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);

        double stopLoss;
        if(orderType == ORDER_TYPE_BUY)
            stopLoss = entryPrice - slDistance;
        else
            stopLoss = entryPrice + slDistance;

        return NormalizeDouble(stopLoss, digits);
    }

    //+------------------------------------------------------------------+
    //| CALCOLO SL - Metodo Hybrid (min tra Swing e ATR)                 |
    //+------------------------------------------------------------------+
    double CalculateSL_Hybrid(ENUM_ORDER_TYPE orderType, double entryPrice, int pivotBarIndex)
    {
        double slSwing = CalculateSL_Swing(orderType, pivotBarIndex);
        double slATR = CalculateSL_ATR(orderType, entryPrice);

        if(slSwing == 0) return slATR;
        if(slATR == 0) return slSwing;

        // Per BUY: prendi SL piu' vicino (maggiore)
        // Per SELL: prendi SL piu' vicino (minore)
        if(orderType == ORDER_TYPE_BUY)
            return MathMax(slSwing, slATR);
        else
            return MathMin(slSwing, slATR);
    }

    //+------------------------------------------------------------------+
    //| CALCOLO SL - Metodo Fixed                                        |
    //+------------------------------------------------------------------+
    double CalculateSL_Fixed(ENUM_ORDER_TYPE orderType, double entryPrice)
    {
        double slDistance = PipsToPrice(m_symbol, m_slFixedPips);
        int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);

        double stopLoss;
        if(orderType == ORDER_TYPE_BUY)
            stopLoss = entryPrice - slDistance;
        else
            stopLoss = entryPrice + slDistance;

        return NormalizeDouble(stopLoss, digits);
    }

    //+------------------------------------------------------------------+
    //| CALCOLA SL in base al metodo configurato                         |
    //+------------------------------------------------------------------+
    double CalculateStopLoss(ENUM_ORDER_TYPE orderType, double entryPrice, int pivotBarIndex = 0)
    {
        switch(m_slMethod)
        {
            case SL_SWING:
                return CalculateSL_Swing(orderType, pivotBarIndex);

            case SL_ATR:
                return CalculateSL_ATR(orderType, entryPrice);

            case SL_HYBRID:
                return CalculateSL_Hybrid(orderType, entryPrice, pivotBarIndex);

            case SL_FIXED:
                return CalculateSL_Fixed(orderType, entryPrice);

            default:
                return CalculateSL_Swing(orderType, pivotBarIndex);
        }
    }

    //+------------------------------------------------------------------+
    //| CALCOLA TP in base a R:R                                         |
    //+------------------------------------------------------------------+
    double CalculateTakeProfit(ENUM_ORDER_TYPE orderType, double entryPrice,
                               double stopLoss, double rrRatio)
    {
        int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
        double slDistance = MathAbs(entryPrice - stopLoss);
        double tpDistance = slDistance * rrRatio;

        double takeProfit;
        if(orderType == ORDER_TYPE_BUY)
            takeProfit = entryPrice + tpDistance;
        else
            takeProfit = entryPrice - tpDistance;

        return NormalizeDouble(takeProfit, digits);
    }

    //+------------------------------------------------------------------+
    //| APRI POSIZIONE SINGOLA con TP finale                             |
    //+------------------------------------------------------------------+
    bool OpenPosition(ENUM_ORDER_TYPE orderType, double lots, double stopLoss)
    {
        if(m_hasActiveTrade)
        {
            LogMessage("OpenPosition: Trade gia' attivo", true);
            return false;
        }

        int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
        double entryPrice;

        if(orderType == ORDER_TYPE_BUY)
            entryPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        else
            entryPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);

        // Verifica stops level minimo
        double minDist = GetMinStopDistance(m_symbol);
        double slDist = MathAbs(entryPrice - stopLoss);
        if(slDist < minDist && minDist > 0)
        {
            LogMessage(StringFormat("SL troppo vicino: %.5f < min %.5f", slDist, minDist), true);
            return false;
        }

        // Calcola TP multipli
        double tp1 = CalculateTakeProfit(orderType, entryPrice, stopLoss, m_tp1RR);
        double tp2 = CalculateTakeProfit(orderType, entryPrice, stopLoss, m_tp2RR);
        double tp3 = CalculateTakeProfit(orderType, entryPrice, stopLoss, m_tp3RR);

        // Apri posizione con TP finale (TP3)
        string comment = "RSI_Div_Pro";
        bool success = false;

        if(orderType == ORDER_TYPE_BUY)
            success = m_trade.Buy(lots, m_symbol, entryPrice, stopLoss, tp3, comment);
        else
            success = m_trade.Sell(lots, m_symbol, entryPrice, stopLoss, tp3, comment);

        if(success)
        {
            ulong ticket = m_trade.ResultOrder();

            // Salva info trade
            m_activeTrade.Reset();
            m_activeTrade.ticket = ticket;
            m_activeTrade.entryPrice = entryPrice;
            m_activeTrade.originalSL = stopLoss;
            m_activeTrade.currentSL = stopLoss;
            m_activeTrade.originalLots = lots;
            m_activeTrade.remainingLots = lots;
            m_activeTrade.isBuy = (orderType == ORDER_TYPE_BUY);
            m_activeTrade.tp1Price = tp1;
            m_activeTrade.tp2Price = tp2;
            m_activeTrade.tp3Price = tp3;
            m_activeTrade.openTime = TimeCurrent();

            m_hasActiveTrade = true;

            LogMessage(StringFormat(">>> TRADE APERTO: %s | Ticket=%d | Lots=%.2f | Entry=%.5f | SL=%.5f | TP1=%.5f | TP2=%.5f | TP3=%.5f",
                                    orderType == ORDER_TYPE_BUY ? "BUY" : "SELL",
                                    ticket, lots, entryPrice, stopLoss, tp1, tp2, tp3));
            return true;
        }
        else
        {
            LogMessage(StringFormat("OpenPosition FAILED: %d - %s",
                                    m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription()), true);
            return false;
        }
    }

    //+------------------------------------------------------------------+
    //| CHIUSURA PARZIALE                                                |
    //+------------------------------------------------------------------+
    bool ClosePartial(ulong ticket, double percent)
    {
        if(!PositionSelectByTicket(ticket))
        {
            LogMessage(StringFormat("ClosePartial: Posizione %d non trovata", ticket), true);
            return false;
        }

        double currentLots = PositionGetDouble(POSITION_VOLUME);
        double lotsToClose = currentLots * percent / 100.0;

        // Normalizza ai limiti del broker
        double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
        double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);

        lotsToClose = MathFloor(lotsToClose / lotStep) * lotStep;
        lotsToClose = MathMax(lotsToClose, minLot);

        // Non chiudere piu' di quello che c'e'
        if(lotsToClose >= currentLots)
        {
            LogMessage(StringFormat("ClosePartial: Lotti da chiudere (%.2f) >= attuali (%.2f), chiudo tutto",
                                    lotsToClose, currentLots));
            return m_trade.PositionClose(ticket);
        }

        if(m_trade.PositionClosePartial(ticket, lotsToClose))
        {
            m_activeTrade.remainingLots = currentLots - lotsToClose;
            LogMessage(StringFormat(">>> PARTIAL CLOSE: %.2f lots (%.0f%%) | Remaining: %.2f",
                                    lotsToClose, percent, m_activeTrade.remainingLots));
            return true;
        }
        else
        {
            LogMessage(StringFormat("ClosePartial FAILED: %d", m_trade.ResultRetcode()), true);
            return false;
        }
    }

    //+------------------------------------------------------------------+
    //| GESTIONE PARTIAL CLOSE - Chiamare da OnTick                      |
    //+------------------------------------------------------------------+
    void ManagePartialCloses()
    {
        if(!m_hasActiveTrade) return;
        if(!PositionSelectByTicket(m_activeTrade.ticket))
        {
            // Posizione chiusa esternamente
            m_activeTrade.Reset();
            m_hasActiveTrade = false;
            LogMessage("Posizione chiusa esternamente");
            return;
        }

        double currentPrice;
        if(m_activeTrade.isBuy)
            currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        else
            currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);

        // Check TP1
        if(!m_activeTrade.tp1Hit)
        {
            bool tp1Reached = false;
            if(m_activeTrade.isBuy)
                tp1Reached = (currentPrice >= m_activeTrade.tp1Price);
            else
                tp1Reached = (currentPrice <= m_activeTrade.tp1Price);

            if(tp1Reached)
            {
                LogMessage(StringFormat(">>> TP1 RAGGIUNTO @ %.5f", currentPrice));

                // Chiudi parte TP1
                if(ClosePartial(m_activeTrade.ticket, m_tp1Percent))
                {
                    m_activeTrade.tp1Hit = true;

                    // Move to Breakeven
                    if(m_enableMoveToBE && !m_activeTrade.movedToBE)
                    {
                        MoveToBreakeven();
                    }
                }
            }
        }

        // Check TP2
        if(m_activeTrade.tp1Hit && !m_activeTrade.tp2Hit)
        {
            bool tp2Reached = false;
            if(m_activeTrade.isBuy)
                tp2Reached = (currentPrice >= m_activeTrade.tp2Price);
            else
                tp2Reached = (currentPrice <= m_activeTrade.tp2Price);

            if(tp2Reached)
            {
                LogMessage(StringFormat(">>> TP2 RAGGIUNTO @ %.5f", currentPrice));

                // Chiudi parte TP2
                if(ClosePartial(m_activeTrade.ticket, m_tp2Percent * 100 / (100 - m_tp1Percent)))
                {
                    m_activeTrade.tp2Hit = true;
                }
            }
        }

        // Aggiorna stato se posizione chiusa completamente
        if(!PositionSelectByTicket(m_activeTrade.ticket))
        {
            LogMessage(">>> TRADE COMPLETATO");
            m_activeTrade.Reset();
            m_hasActiveTrade = false;
        }
    }

    //+------------------------------------------------------------------+
    //| MOVE TO BREAKEVEN                                                |
    //+------------------------------------------------------------------+
    bool MoveToBreakeven()
    {
        if(!m_hasActiveTrade) return false;
        if(m_activeTrade.movedToBE) return true;

        if(!PositionSelectByTicket(m_activeTrade.ticket))
            return false;

        double buffer = PipsToPrice(m_symbol, m_beBufferPips);
        int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);

        double newSL;
        if(m_activeTrade.isBuy)
            newSL = m_activeTrade.entryPrice + buffer;
        else
            newSL = m_activeTrade.entryPrice - buffer;

        newSL = NormalizeDouble(newSL, digits);

        // Verifica che sia un miglioramento
        double currentSL = PositionGetDouble(POSITION_SL);
        bool shouldMove = false;

        if(m_activeTrade.isBuy)
            shouldMove = (newSL > currentSL);
        else
            shouldMove = (newSL < currentSL);

        if(!shouldMove)
        {
            LogMessage("MoveToBreakeven: Nuovo SL non e' un miglioramento");
            return false;
        }

        double currentTP = PositionGetDouble(POSITION_TP);

        if(m_trade.PositionModify(m_activeTrade.ticket, newSL, currentTP))
        {
            m_activeTrade.currentSL = newSL;
            m_activeTrade.movedToBE = true;
            m_activeTrade.lastModifyTime = TimeCurrent();
            LogMessage(StringFormat(">>> MOVED TO BE: SL = %.5f (entry + %.1f pips)", newSL, m_beBufferPips));
            return true;
        }
        else
        {
            LogMessage(StringFormat("MoveToBreakeven FAILED: %d", m_trade.ResultRetcode()), true);
            return false;
        }
    }

    //+------------------------------------------------------------------+
    //| TRAILING STOP - Metodo ATR                                       |
    //+------------------------------------------------------------------+
    bool TrailByATR()
    {
        if(!m_hasActiveTrade) return false;
        if(!PositionSelectByTicket(m_activeTrade.ticket)) return false;

        if(CopyBuffer(m_atrHandle, 0, 1, 1, m_atrBuffer) < 1) return false;

        double atr = m_atrBuffer[0];
        double trailDistance = atr * m_trailATRMultiplier;
        int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);

        double currentPrice, newSL;
        if(m_activeTrade.isBuy)
        {
            currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
            newSL = currentPrice - trailDistance;
        }
        else
        {
            currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
            newSL = currentPrice + trailDistance;
        }

        newSL = NormalizeDouble(newSL, digits);
        return ApplyTrailingStop(newSL);
    }

    //+------------------------------------------------------------------+
    //| TRAILING STOP - Metodo Swing                                     |
    //+------------------------------------------------------------------+
    bool TrailBySwing()
    {
        if(!m_hasActiveTrade) return false;
        if(!PositionSelectByTicket(m_activeTrade.ticket)) return false;

        double buffer = PipsToPrice(m_symbol, m_slBufferPips);
        int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);

        double newSL = 0;
        int swingStrength = 2;

        if(m_activeTrade.isBuy)
        {
            // Trova swing low recente
            for(int bar = swingStrength + 1; bar <= 20; bar++)
            {
                if(IsSwingLow(bar, swingStrength))
                {
                    double swingPrice = iLow(m_symbol, m_timeframe, bar);
                    newSL = swingPrice - buffer;
                    break;
                }
            }
        }
        else
        {
            // Trova swing high recente
            for(int bar = swingStrength + 1; bar <= 20; bar++)
            {
                if(IsSwingHigh(bar, swingStrength))
                {
                    double swingPrice = iHigh(m_symbol, m_timeframe, bar);
                    newSL = swingPrice + buffer;
                    break;
                }
            }
        }

        if(newSL == 0) return false;

        newSL = NormalizeDouble(newSL, digits);
        return ApplyTrailingStop(newSL);
    }

    //+------------------------------------------------------------------+
    //| TRAILING STOP - Metodo Fixed                                     |
    //+------------------------------------------------------------------+
    bool TrailByFixed()
    {
        if(!m_hasActiveTrade) return false;
        if(!PositionSelectByTicket(m_activeTrade.ticket)) return false;

        double trailDistance = PipsToPrice(m_symbol, m_trailFixedPips);
        int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);

        double currentPrice, newSL;
        if(m_activeTrade.isBuy)
        {
            currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
            newSL = currentPrice - trailDistance;
        }
        else
        {
            currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
            newSL = currentPrice + trailDistance;
        }

        newSL = NormalizeDouble(newSL, digits);
        return ApplyTrailingStop(newSL);
    }

    //+------------------------------------------------------------------+
    //| Applica trailing stop se miglioramento                           |
    //+------------------------------------------------------------------+
    bool ApplyTrailingStop(double newSL)
    {
        double currentSL = m_activeTrade.currentSL;

        // Verifica che sia un miglioramento
        bool shouldTrail = false;
        if(m_activeTrade.isBuy)
            shouldTrail = (newSL > currentSL);
        else
            shouldTrail = (newSL < currentSL);

        if(!shouldTrail) return false;

        double currentTP = PositionGetDouble(POSITION_TP);

        if(m_trade.PositionModify(m_activeTrade.ticket, newSL, currentTP))
        {
            m_activeTrade.currentSL = newSL;
            m_activeTrade.lastModifyTime = TimeCurrent();
            LogMessage(StringFormat(">>> TRAILING SL: %.5f", newSL));
            return true;
        }

        return false;
    }

    //+------------------------------------------------------------------+
    //| GESTIONE TRAILING STOP - Chiamare da OnTick                      |
    //+------------------------------------------------------------------+
    void ManageTrailingStop()
    {
        if(!m_hasActiveTrade) return;
        if(m_trailMethod == TRAIL_NONE) return;

        // Verifica se siamo in profitto sufficiente per iniziare trailing
        if(!PositionSelectByTicket(m_activeTrade.ticket)) return;

        double currentPrice;
        if(m_activeTrade.isBuy)
            currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        else
            currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);

        double profitPips = 0;
        if(m_activeTrade.isBuy)
            profitPips = PriceToPips(m_symbol, currentPrice - m_activeTrade.entryPrice);
        else
            profitPips = PriceToPips(m_symbol, m_activeTrade.entryPrice - currentPrice);

        if(profitPips < m_trailStartPips) return;

        // Applica metodo trailing
        switch(m_trailMethod)
        {
            case TRAIL_ATR:
                TrailByATR();
                break;
            case TRAIL_SWING:
                TrailBySwing();
                break;
            case TRAIL_FIXED:
                TrailByFixed();
                break;
            default:
                break;
        }
    }

    //+------------------------------------------------------------------+
    //| Verifica se ci sono posizioni aperte                             |
    //+------------------------------------------------------------------+
    bool HasOpenPosition()
    {
        // Prima verifica tracking interno
        if(m_hasActiveTrade)
        {
            if(PositionSelectByTicket(m_activeTrade.ticket))
                return true;
            else
            {
                // Posizione chiusa, reset tracking
                m_activeTrade.Reset();
                m_hasActiveTrade = false;
            }
        }

        // Poi verifica posizioni generiche
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;

            if(PositionGetInteger(POSITION_MAGIC) == m_magic &&
               PositionGetString(POSITION_SYMBOL) == m_symbol)
            {
                return true;
            }
        }
        return false;
    }

    //+------------------------------------------------------------------+
    //| Conta posizioni aperte                                           |
    //+------------------------------------------------------------------+
    int GetOpenPositionsCount()
    {
        int count = 0;
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;

            if(PositionGetInteger(POSITION_MAGIC) == m_magic &&
               PositionGetString(POSITION_SYMBOL) == m_symbol)
            {
                count++;
            }
        }
        return count;
    }

    //+------------------------------------------------------------------+
    //| Chiude tutte le posizioni                                        |
    //+------------------------------------------------------------------+
    void CloseAll()
    {
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;

            if(PositionGetInteger(POSITION_MAGIC) == m_magic &&
               PositionGetString(POSITION_SYMBOL) == m_symbol)
            {
                m_trade.PositionClose(ticket);
            }
        }

        m_activeTrade.Reset();
        m_hasActiveTrade = false;
    }

    //+------------------------------------------------------------------+
    //| Getters                                                          |
    //+------------------------------------------------------------------+
    ulong  GetMagicNumber()     { return m_magic; }
    string GetSymbol()          { return m_symbol; }
    bool   HasActiveTrade()     { return m_hasActiveTrade; }
    bool   IsTP1Hit()           { return m_activeTrade.tp1Hit; }
    bool   IsTP2Hit()           { return m_activeTrade.tp2Hit; }
    bool   IsMovedToBE()        { return m_activeTrade.movedToBE; }
    double GetEntryPrice()      { return m_activeTrade.entryPrice; }
    double GetCurrentSL()       { return m_activeTrade.currentSL; }
    double GetRemainingLots()   { return m_activeTrade.remainingLots; }
    int    GetATRHandle()       { return m_atrHandle; }

    SingleTradeInfo GetActiveTradeInfo() { return m_activeTrade; }

private:
    //+------------------------------------------------------------------+
    //| Helper: Determina filling mode supportato                        |
    //+------------------------------------------------------------------+
    ENUM_ORDER_TYPE_FILLING GetSupportedFillingMode(string symbol)
    {
        uint filling = (uint)SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);

        if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
            return ORDER_FILLING_FOK;

        if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
            return ORDER_FILLING_IOC;

        return ORDER_FILLING_RETURN;
    }

    //+------------------------------------------------------------------+
    //| Helper: Verifica swing low                                       |
    //+------------------------------------------------------------------+
    bool IsSwingLow(int bar, int strength)
    {
        double centerLow = iLow(m_symbol, m_timeframe, bar);

        for(int i = 1; i <= strength; i++)
        {
            if(bar - i < 1) return false;
            if(iLow(m_symbol, m_timeframe, bar - i) <= centerLow) return false;
            if(iLow(m_symbol, m_timeframe, bar + i) <= centerLow) return false;
        }
        return true;
    }

    //+------------------------------------------------------------------+
    //| Helper: Verifica swing high                                      |
    //+------------------------------------------------------------------+
    bool IsSwingHigh(int bar, int strength)
    {
        double centerHigh = iHigh(m_symbol, m_timeframe, bar);

        for(int i = 1; i <= strength; i++)
        {
            if(bar - i < 1) return false;
            if(iHigh(m_symbol, m_timeframe, bar - i) >= centerHigh) return false;
            if(iHigh(m_symbol, m_timeframe, bar + i) >= centerHigh) return false;
        }
        return true;
    }
};
