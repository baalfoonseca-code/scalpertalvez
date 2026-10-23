# Validação experimental em MT5

Esta candidata exige compilação nativa e validação em conta de demonstração antes de qualquer avaliação com capital real. Os testes portáveis não executam o terminal nem o servidor da corretora.

1. Arquive a fonte, o EX5, o preset efetivamente usado e todos os arquivos financeiros do ambiente original. Trabalhe em instalação/pasta de dados separada, com AutoTrading desligado. Não substitua o executável em produção.
2. Copie `scalpertalvez.mq5` e a pasta `Include` com a mesma estrutura relativa para uma pasta experimental de `MQL5/Experts`. Compile com MetaEditor atual; guarde build, log completo, erros e avisos. Não carregue se houver erro ou referência ausente.
3. Use símbolos reais da corretora de WIN/IND e WDO/DOL e Magic Numbers sem concorrência. Netting compartilha a posição por símbolo: Magic diferente não torna seguro misturar EAs.
4. Compare a referência e a candidata com dados, relógios, ticks, posição e estado financeiro idênticos. Mantenha SL e TP originais, BE em 1R e locks desligados. Verifique matriz, rotas, book de cinco preços distintos, ARMED, ordens e contabilidade. Divergências por CSV inválido são a correção conservadora intencional, não equivalência de comportamento nessa condição.
5. Na demonstração, valide modos novos separadamente: WIN/WDO, compra/venda, cap sigma, grade, stops/freeze, sizing, slippage, fill parcial, salto de patamares, SL externo melhor, retcodes, atraso e incerteza. Não tome retorno booleano como prova do servidor.
6. Interrompa e reinicie em cada fase durável: antes/depois do despacho, solicitação SLTP pendente, confirmação, saída, mudança de dia e EOD. Compare journals com posição real e histórico. Nunca apague arquivos financeiros para liberar entradas.
7. Use cópias dos CSVs para testar corrupção. O CSV real do WDO não foi fornecido; precisa ser diagnosticado separadamente preservando o original. Não confunda fixtures com reparo do arquivo real.
8. Ative `RESPONSE_OBSERVAR` apenas para coleta comparativa. Novas leituras não autorizam entradas, inversões ou bloqueios. Registre origem/qualidade de volume e mantenha limiares não calibrados como indisponíveis.
9. Colete `[BOOK_PERF]`, métricas do observador, filas, descartes, bytes, memória e atraso sob carga de mercado; compare com a referência. Benchmarks C++ locais não substituem medição de OnTick e timers no MT5.

Aprovação exige evidências de compilação, compatibilidade em replay, recuperação financeira e execução em demonstração. Esta entrega não fornece EX5, backtest fabricado ou garantia de lucro/limite de perda realizada.
