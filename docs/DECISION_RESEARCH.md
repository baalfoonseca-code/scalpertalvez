# Rêmora Decision Research — candidata observacional

A base efetivamente encontrada foi `94fddd73f0455c63a6cd238d6cb9f8924e9a497a`, HEAD local e remoto de `dev/book-pro-decisoria-abs-cont` em duas consultas. Não havia revisão posterior. O checkpoint é `checkpoint/book-decisoria-pre-research-94fddd7`; o desenvolvimento ocorre em `dev/remora-decision-research`. A BOOK histórica e seus relatórios continuam congelados.

## Ativação e preservação

O único input acrescentado é `input bool Inp_ResearchEnable = false;`, após os 103 anteriores. Nomes, tipos, ordem e defaults desses 103 são conferidos contra a base. Pesquisa OFF não inicializa coletores, simulações, arquivos ou filas de pesquisa. Para ativar, o operador seleciona `true`; para desativar, seleciona `false`. Nenhum outro input é alterado pelo pesquisador.

O modo operacional continua sendo o escolhido em `Inp_DecisionMode`. Os defaults já existentes continuam `DECISION_APLICAR` e `DECISION_FLAGS_RUNTIME_QUALIFIED`. `Inp_ResponseMode`, CSVs observacionais e `Inp_DOM_TradeGateEnable` permanecem independentes. Default do fonte não prova qual preset está carregado no gráfico. A identidade serializa os **104 valores efetivamente carregados**. `preset_hash` inclui todos; `trading_preset_hash` exclui apenas o novo bool e permite conferir os mesmos 103 valores sob ON/OFF.

Para ORIGINAL × APLICAR, o analisador lê os registros canônicos de configuração e calcula uma impressão de comparação excluindo exclusivamente `Inp_ResearchEnable` e `Inp_DecisionMode`. Os outros 102 valores precisam coincidir. Parâmetros iguais não demonstram exposição ao mesmo mercado nem um experimento estatístico pareado.

Abra diretamente `REMORA_BOOK_PRO_DECISORIA.mq5` no MetaEditor. Ele incorpora todos os módulos próprios; somente os includes oficiais `Trade\Trade.mqh` e `Trade\PositionInfo.mqh` permanecem externos. A manutenção modular continua em `scalpertalvez.mq5` e `Include/`.

Não houve implantação, substituição de EX5 ou alteração de produção. A compilação nativa desta candidata precisa ser feita no MetaEditor; testes de host não a substituem.

## Pontos de captura e isolamento

| Caminho original | Pesquisa acrescentada | Efeito operacional |
|---|---|---|
| M3/M1, matriz, conflito, região | Cópia imutável após seleção/região e antes de `BookDecisionCandidate` | Nenhum retorno de pesquisa é consumido |
| Snapshot inelegível ou região inválida | Registro separado com causa, sem tratá-lo como candidato negociável | Sem recuperação de rotas inelegíveis |
| Avaliação quantitativa APLICAR | Cópia de evidência/veredito e referências, antes do book final | Sem novo predicado ou limiar |
| Janela regular operacional encerrada | Arquivo de referências em memória, antes da inserção da amostra | Sem mudança na aritmética ou no coletor operacional |
| API de entrada já chamada e `CompletePendingExec` concluído | Cópia limitada de resultado, identidade e termos da chamada | Nenhuma chamada de ordem pelo pesquisador |
| Retorno de envio | Evento deduplicado por sinal, resultado, motivo e intenção | WAIT repetido não produz um evento por tick |
| Tick após todo processamento original | Snapshot de contexto, limitado a 10 Hz e nova candidatura | Sem história ou disco no caminho de despacho |
| Timer após o timer original e observadores existentes | Coleta incremental, reconstrução e gravação de pesquisa | Falha suspende apenas pesquisa |
| Trade finalizado/reconciliado | Cópia dos identificadores, custos e resultado confirmado | Trades.csv e journals continuam independentes |
| Desinicialização | Pesquisa encerrada **depois** da persistência/desinicialização original | Pesquisa não antecede a gravação financeira obrigatória |

A prova estática compara todas as funções antigas, retirando apenas chamadas observacionais `void` isoladas. Rejeita uso de resultado, condições e argumentos mutantes. Os módulos financeiros, matriz, book, saídas e núcleo decisório permanecem preservados. A execução continua M3/M1/ticks segundo os inputs existentes, independentemente do timeframe visual.

Uma posição, quota, sessão ou falha anterior pode impedir a própria execução da matriz. Quando não há snapshot válido, registra-se `ORIGINAL_NOT_EVALUATED`; não se inventa uma oportunidade. O denominador “candidaturas identificadas” representa candidaturas realmente selecionadas pela matriz, não todos os sinais que poderiam existir sob outra carteira.

## ARMED hipotético, elegibilidade e preço posterior

Cada candidatura possui estado próprio, sem referência mutável a `armed`, journals ou gestão. O timeout vem do input congelado, historicamente 90 segundos; nunca é reiniciado. A trajetória pode continuar após o cancelamento, por até 900 segundos, mas o ARMED cancelado não é reativado.

O núcleo puro reproduz timeout, sessão, breakout, overshoot, direção/esforço da onda viva, bandas VWAP, late direction e glass, incluindo a restrição de CONT. A contradição direcional usa apenas snapshot causal disponível para a barra M1 correspondente. Sem ele, não se presume ausência de contradição. A onda viva reaproveita a aritmética original sem chamar seu observador. SL sigma usa o próprio `BRSigmaStop`, com arredondamento estrito; os pontos originais conservam a tolerância da normalização histórica.

Há três observações diferentes:

1. `market_eligible`: Stage 2 de mercado demonstrado pelos dados disponíveis.
2. `dispatch_eligible_observed`: além de Stage 2, estado financeiro, sizing/stops/margem e book requerido foram reconstruídos no ponto observado.
3. `CONDITIONAL_MARKET_REFERENCE`: preço de referência para estudar trajetória, sem demonstração completa de despacho ORIGINAL.

Uma chamada real à API é registrada imediatamente em memória, mesmo que o timer ainda não tenha gravado a candidatura. Ela comprova que o caminho original chegou ao despacho e impede fabricar outra ordem hipotética contra a posição criada pela própria candidatura.

Em ORIGINAL, a comparação independente diferida pode reconstruir APLICAR no timestamp da **cotação de precificação**. Esse timestamp não é tratado como o instante exato da API após journals/revalidações. O escopo informa `AT_PRICING_QUOTE_NOT_DISPATCH`; a avaliação independente no despacho exato recebe `NOT_EVALUATED / EXACT_DISPATCH_MARKET_CLOCK_NOT_CAPTURED`. Essa vista de precificação fica disponível para auditoria, mas é excluída dos contadores de autorização no despacho. Em APLICAR, registra-se a evidência real usada pelo motor e sua identidade de despacho.

O estado financeiro é separado da elegibilidade de mercado. Cálculos de sizing/stops/margem observacionais não escrevem audits nem congelam o estado de risco real. Book histórico ausente não é presumido favorável: com gate habilitado e sem confirmação reconstruível, a referência permanece condicional. Um candidato já inelegível nunca se torna operação por esse acompanhamento.

Após a primeira prova de Stage 2, usa-se a **primeira cotação subsequente observável**, bid/ask conforme a direção, revalidando predicados quando existe contexto. Se a primeira cotação tem contexto Stage 2 ausente, conserva-se sua referência com a classificação condicional; não se procura retrospectivamente um preço melhor. Cancelamento, timeout ou sessão encerrada impedem criar a referência.

As distâncias e modos de SL/TP são congelados a partir do preset; sigma, teto e multiplicadores BASE/TURBO são aplicados pelo núcleo puro. Depois da referência, usa-se bid para fechar compra e ask para fechar venda. Registra-se primeiro toque observável de SL/TP e os tempos de cada toque. BE, locks, sizing e preenchimento de uma posição hipotética **não são simulados**: trata-se do estudo explícito das barreiras iniciais. A gestão real mantém suas regras completas.

Horizontes de excursão desde a candidatura: **60, 300 e 900 segundos**. Horizonte das barreiras: **900 segundos desde a referência**. Nenhum preço posterior é usado na seleção original. Um evento depois do limite não entra retroativamente no horizonte. EOD/desinicialização antecipada são incompletos; não se transformam em “nenhum alvo/stop em 900 s”.

O encerramento pelo relógio exige watermark e filas processadas até a fronteira. Se houver atraso de coleta, permite-se apenas recuperar os dados de pesquisa por até 30 segundos adicionais; isso não estende o ARMED nem o horizonte de preços. Persistindo a lacuna, o resultado é indisponível/ambíguo.

`TP_FIRST`/`SL_FIRST` significam toque de cotação de referência. Não significam preenchimento, lucro ou prejuízo financeiro real. Spread é observado. Latência real, slippage, prioridade, custos e preenchimento hipotético permanecem desconhecidos. Lacunas ou ordem não demonstrável produzem `AMBIGUOUS_PATH`/`INSUFFICIENT_MARKET_DATA`. Colisões entre referências e impossibilidade por posição/capital são registradas; não se soma tudo como carteira executável.

## Dados, causalidade e matemática

A pesquisa aproveita lotes estritos já adquiridos, copiando um lote limitado para processamento no timer. Completa somente o trecho faltante por cursores próprios limitados. Não chama o coletor operacional para simular outra configuração e não varre o dia por tick.

`COPY_TICKS_TRADE` alimenta uma instância observacional de janelas/referências. Em ORIGINAL, essa instância avalia APLICAR pelo mesmo núcleo matemático, com histórico e teste T próprios. Em APLICAR, captura-se a evidência efetivamente usada pelo motor real. Decisões independentes deixam de ser calculadas após cancelamento/timeout; não se acrescenta uma aprovação tardia a uma oportunidade encerrada.

`COPY_TICKS_ALL` serve à trajetória bid/ask. Consultas sobrepostas validam prefixos completos e ordinais. Negócios/cotações distintos, inclusive idênticos no mesmo milissegundo, são preservados. Grupo de timestamp cheio no limite da consulta é indisponibilidade explícita. O milissegundo ainda aberto aguarda avanço do relógio de mercado antes de associar um callback a um ordinal. Um callback coalescido não é equiparado a um negócio.

A associação exige timestamp, bid, ask, last, volume, volume real e flags compatíveis. Grupo com mais de um ordinal não permite inventar qual contexto pertencia a cada linha. Isso afeta a reconstrução Stage 2, não apaga uma trajetória bruta cuja ordem foi verificada. Contexto M1 é copiado antes/depois de um testemunho de cotação estável e descartado como prova se houve mudança. Históricos posteriores são filtrados pelo instante do snapshot.

VWAP usa a base fechada congelada e o sufixo de negócios. Agregados de minuto conservam volume/PV mesmo após descarte de linhas antigas do tape; valores adquiridos depois do snapshot são subtraídos do sufixo. Ausência de cobertura impede uma prova de VWAP viva.

Os pressupostos agressor são os do controle já selecionado: flags BUY/SELL exclusivas sob hipótese declarada e qualificadas em runtime. Isso **não comprova externamente** a classificação econômica da corretora. Flags ausentes/ambíguas, cobertura insuficiente, origem inválida, desordem ou lote incompleto continuam indisponíveis. A flag observacional de confiança não autoriza nenhuma operação nem qualifica automaticamente a pesquisa.

Os limiares existentes permanecem intocados: mínimo 16 referências, P80/P20, fator comparável 2,0 e coberturas/aceitação carregadas. A referência é causal e regular, não selecionada apenas por oportunidades. O exemplo não é calibração desses valores.

## Arquivos e esquema V1

Arquivos UTF-8 com vírgula, aspas duplicadas e CRLF, separados dos arquivos financeiros:

`Research_<conta>_<símbolo>_<magic>_<run_id>_{Candidates,Decisions,Outcomes,Health,DailySummary}.csv`

O esquema exato e ordenado está em `artifacts/research/schema.json`, exportável com:

```bash
python3 tools/export_research_schema.py --output artifacts/research/schema.json
```

| Arquivo | Conteúdo e interpretação |
|---|---|
| Candidates | Registro imutável, elegibilidade original/causa, rota/subtipo/direção/BASE-TURBO, clocks, região/trigger e distâncias; `context_json` contém matriz com cabeçalho/valores, M3 congelado e guardas operacionais |
| Decisions | Uma avaliação correlacionada, linhas CURRENT/T/R/FORWARD, resultado/motivo e escopo real ou independente; valores ausentes ficam vazios |
| Outcomes | Elegibilidade, referência, excursões/horizontes, SL/TP, toques e incerteza; eventos reais possuem identificadores e somente o fechamento reconciliado publica PnL confirmado |
| Health | Configuração canônica completa, erros de dados/escrita, suspensão, lacunas, filas/custos, interrupção/reinício e encerramento |
| DailySummary | Contagens observadas, denominadores de elegibilidade, cobertura/descartes e advertências; consolidação detalhada no analisador |

Identidade de evento: `(run_id,event_id)`; candidatura: `(run_id,candidate_id)`. IDs financeiros são strings inteiras, sem conversão por double. `code_hash` é o SHA-256 do bundle modular; o hash do monolítico é entregue nos artefatos de build. `server` evita misturar logins iguais de servidores distintos.

Decisions registra `vbuy/vsell/vunknown`, delta e intervalo, cobertura conhecida e temporal, participação direcional, esforço, ranks, resistência, referências elegíveis/comparáveis, bucket de 30 min, progresso, aceitação, migração VWAP, ER e identidade temporal. `total_path` usa unidades de preço; `total_path_ticks` divide pelo tick. Progresso usa ticks. Eventos de timer/API usam o relógio de servidor com resolução de segundos, multiplicado por 1.000; isso não comprova o milissegundo exato da chamada. Cotações/deals usam seus timestamps nativos quando disponíveis. Volumes usam as unidades inteiras do feed; frações são adimensionais; clocks/dwell usam ms. `measurement_direction` é contrária à operação em T e igual à operação em R/CONT. `window_epoch`, `signal_generation`, `collector_epoch` e `data_version` têm campos distintos.

`prior_reference_members` contém referências anteriores comparáveis no formato `from:to:source:bucket:geometry_direction:pressure_direction:tick_size:effort:net_progress:max_progress:epoch`, separadas por `;`. Snapshots no fechamento da janela preservam o conjunto usado para seus ranks, antes da inserção da própria janela. `reference_membership_status` sinaliza a proveniência ou a impossibilidade de reconstrução do conjunto; um desencontro não é ocultado.

`reference_shortage` distingue NO_PRIOR_HISTORY, NEW_BUCKET_NO_PRIOR_REFERENCES, MINORITY_PRESSURE_REFERENCE_SHORTAGE, PRIOR_HISTORY_REFERENCE_SHORTAGE, EFFORT_NOT_COMPARABLE, COVERAGE_INSUFFICIENT, INVALID_DATA e AGGRESSOR_FLAGS_AMBIGUOUS. Referências da reação R são não aplicáveis, não “zero referências históricas”.

`observed_msc` é o clock do evento; `observed_dwell_msc` é duração efetivamente observada entre negócios. Ausência não equivale a zero, silêncio não equivale a permanência negociada. `reference_kind` separa hipótese executável, referência condicional e observação real. `mae_mfe_partial` conserva a limitação de reinício do registro real. Os campos `gross/commission/fee/swap/net` só são publicados como confirmados pelo record reconciliado, nunca por cálculo hipotético.

## Limites, falhas e reinício

Limites fixos: 32 acompanhamentos, 128 eventos, 256 contextos, 32 capturas de candidatura/evidência/dispatch; tape de 8.192 negócios e cotações; consultas de até 2.048 linhas por fonte por timer; 32 agregados de minuto; referência de 384 projeções e arquivos de até 64 MiB. Cada linha tem limite de 65.536 bytes estimados. O orçamento de arrays/filas de pesquisa é conservador, aproximadamente 16 MiB, além do EA original e overhead do runtime.

Loops de processamento/escrita têm orçamento cooperativo de 3 ms por fase e no máximo 16 eventos gravados por timer, além do marcador e de um aviso de falha. Uma chamada MT5/arquivo não pode ser preemptada por esse orçamento. Custos totais/máximos, aquisições e memória são observações locais; o host não comprova latência MT5. O timer histórico do tester pode ser de 60 s; capacidade e coalescência nesse ambiente precisam de validação nativa. Saturação é sinalizada, não convertida em cobertura completa.

Falha de escrita mantém a linha como incerta e suspende a pesquisa; não há retentativa de append após escrita parcial/flush incerto. Nenhuma limpeza/reenvio financeiro é acionada. Saturação suspende somente pesquisa e registra lacuna quando o disco permite; um aviso Experts é emitido uma vez. Falha do próprio disco também pode impedir o aviso em arquivo.

O marcador `Research_<conta>_<símbolo>_<magic>_State.txt` é exclusivo da pesquisa. Ele registra run e acompanhamentos pendentes. Reinício fecha explicitamente os IDs conhecidos como `RESTART_INTERRUPTED`; não emenda segmentos para inventar MAE/MFE contínuos ou primeiro toque. Marcador ilegível/incompleto fica registrado como lacuna. Arquivos históricos de pesquisa e todos os arquivos financeiros são preservados. O mesmo contexto conta/símbolo/magic deve ter uma única instância de pesquisa por pasta do terminal.

## Análise offline e exemplo

```bash
python3 tools/analyze_research.py /pasta/dia1 /pasta/dia2 --json diario.json --markdown diario.md
# Opcional: overlay EXPLÍCITO de custo de ida/volta em pontos do mesmo ativo
python3 tools/analyze_research.py /pasta --hypothetical-cost-points 1.0 --json custos.json
python3 tools/generate_research_example.py
```

Somente biblioteca padrão Python; gerar o exemplo também requer g++ e os testes do repositório. O analisador deduplica IDs, exclui IDs conflitantes, preserva ausência/ambiguidade, separa contas/servidores/ativos/rotas/modos/direção/bucket/qualidade e distingue PnL confirmado de barreiras hipotéticas. Não agrega pontos de WIN com WDO. Overlay de custos exclui colisões, caminhos ambíguos e referências condicionais; não constitui carteira, preenchimento ou PnL real.

O exemplo em `examples/research/` é produzido pelo caso integrado: **M3 e C1–C5 calculados pelo fonte**, candidatura ABS, APLICAR sem referências impede API, ARMED independente, Stage 2 original e primeira referência subsequente, cotação posterior toca TP. OHLC, volumes, POC agregado, APIs de terminal/journals e contexto de execução são fixtures declarados. Os números/preset do exemplo são sintéticos, não o preset de um gráfico WIN/WDO nem dados de corretora. O exemplo registra zero ordens e nenhum PnL real. Não importar seus CSVs como histórico de mercado.

A suíte também cobre SL primeiro, sem toque, ambiguidade, spread, overshoot, timeout, flags ausentes/ambíguas, bucket novo, aquecimento concluído, ON/OFF, reinício, fila/disco, EOD, causalidade e proibição de APIs de ordens. Os resultados completos e as exclusões históricas estão em `artifacts/research/test-results.json` e `tests.log`.

Não foram demonstrados: compilação MetaEditor, latência/locking nativos, replay MT5, classificação econômica externa do agressor, fills/slippage hipotéticos, preset real do gráfico e superioridade estatística. Não existem dados reais novos para afirmar acerto, expectativa líquida, oportunidades sacrificadas/evitadas ou rentabilidade. Contagens de testes não são estatísticas de mercado.
