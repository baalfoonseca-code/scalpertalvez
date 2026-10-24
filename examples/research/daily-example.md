**EXEMPLO DETERMINÍSTICO — nenhuma operação real ou lucro demonstrado.**

# Rêmora Decision Research — análise offline

Observações reais e contrafactuais são apresentadas separadamente.

| Métrica | Quantidade |
|---|---:|
| Candidaturas originalmente elegíveis | 1 |
| Snapshots de inelegibilidade | 0 |
| Candidaturas avaliadas por APLICAR | 1 |
| Aprovação APLICAR observada | 0 |
| Veto APLICAR observado | 0 |
| Espera APLICAR observada | 0 |
| Dados insuficientes | 1 |
| Stage 2 ORIGINAL elegível demonstrado | 1 |
| ORIGINAL não reconstruível | 0 |
| Referências de entrada hipotética | 1 |
| TP observado primeiro | 1 |
| SL observado primeiro | 0 |
| Caminhos ambíguos | 0 |
| Horizonte inconclusivo | 0 |
| Candidaturas com colisão | 0 |
| Trades reais reconciliados | 0 |

PnL real reconciliado: INDISPONÍVEL.
Expectativa real por trade: INDISPONÍVEL.
Custo hipotético declarado (pontos, ida e volta): NÃO INFORMADO.
Média líquida de barreiras de referência em pontos: NÃO CALCULADA; amostras 0.

## Motivos APLICAR

- `TRADED_DATA_STALE_OR_UNAVAILABLE`: 1

## Cobertura da coleta

Arquivos: 4; linhas lidas: 6; eventos únicos: 6; duplicatas idênticas: 0; conflitos de ID: 0; rejeições de leitura: 0; identidades sem candidatura: 0.

## Limitações

- Research events and deterministic examples do not prove native MT5 behavior or trading advantage.
- Approval/wait/veto counts are overlapping candidate sets, not additive partitions.
- ORIGINAL market eligibility is separate from finance, book confirmation and actual execution.
- TP/SL are observed reference-price barriers, never confirmed fills or real PnL.
- Rejected TP/SL counts are potential sacrificed/avoided barrier observations, not money earned/saved.
- No price-point expectancy is aggregated across different symbols; no monetary PnL is aggregated across different accounts.
- Hypothetical reference expectancy uses declared cost points only; excludes known collisions, does not model a tradable portfolio, sizing, latency or slippage.
- Missing outcomes, research gaps, unmatched candidates and unqualified feeds limit denominators and statistical inference.
- No automatic input optimization or claim of statistical significance is produced.
