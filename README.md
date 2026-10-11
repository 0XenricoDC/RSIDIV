# 📈 RSI Divergence Pro — MetaTrader 5 Expert Advisor

> An MQL5 Expert Advisor that detects **regular and hidden RSI divergences**, confirms them across timeframes and price action, and trades them with **prop-firm-grade risk management**.

![MQL5](https://img.shields.io/badge/MQL5-MetaTrader_5-0A64AD)
![Strategy](https://img.shields.io/badge/strategy-RSI_divergence-6E40C9)
![Risk](https://img.shields.io/badge/risk-prop_firm_ready-2EA043)

🇮🇹 [Specifiche di sviluppo (italiano)](./README.it.md)

---

## Strategy

| Step | Timeframe (default) | Logic |
|---|---|---|
| Trend | D1 | EMA 50 / 200 alignment |
| Setup | H4 | Regular or hidden RSI divergence between swing points |
| Entry | H1 | Candlestick confirmation, optional support/resistance confluence |

Extra filters: ADX range (avoid flat and over-extended markets), trading hours and weekdays, optional adaptive overbought/oversold levels in trends.

## Risk management

- Risk per trade as % of equity (default **0.5%**)
- Max daily loss (default **1.5%**) and max total drawdown (default **5%**) — trading stops when hit
- Max open trades and max trades per day
- Stop loss: swing-based, ATR, fixed or hybrid, with a buffer beyond the swing
- **Partial take profits**: TP1 1.5R (close 50%) → TP2 2.5R (close 30%) → TP3 4R
- Break-even after TP1 and ATR / fixed trailing stop

## Architecture

```
RSI_Divergence_Pro/
├── RSI_Divergence_Pro.mq5        main EA (inputs, OnTick orchestration)
├── Include/
│   ├── DivergenceDetector.mqh    swing detection + regular/hidden divergence
│   ├── SignalConfirm.mqh         candlestick patterns, S/R confluence, MTF trend
│   ├── RiskManager.mqh           position sizing, daily loss / drawdown guards
│   ├── TradeManager.mqh          orders, partial closes, break-even, trailing
│   └── Utils.mqh                 helpers
└── Presets/
    ├── PropFirm_Conservative.set
    ├── PropFirm_Moderate.set
    └── Backtest_Signals.set
```

## Installation

1. Copy the `RSI_Divergence_Pro` folder into `MQL5/Experts/` of your MetaTrader 5 data folder.
2. Compile `RSI_Divergence_Pro.mq5` in MetaEditor (or use the included `.ex5`).
3. Attach the EA to a chart and load one of the presets from `Presets/`.
4. Validate in the Strategy Tester before running on a live or funded account.

## Disclaimer

For educational and research purposes. Trading involves substantial risk of loss; past backtest results do not guarantee future performance.
