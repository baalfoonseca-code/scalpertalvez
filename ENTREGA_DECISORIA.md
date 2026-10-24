# Rêmora BOOK PRO Decisória — candidata experimental

Arquivo único: [REMORA_BOOK_PRO_DECISORIA.mq5](REMORA_BOOK_PRO_DECISORIA.mq5).
Branch: `dev/book-pro-decisoria-abs-cont`. Controle preservado: `815077efec40adf1897bcf64640756bb46c4c118`, checkpoint `checkpoint/book-1125-matrix-id-fix1-815077e`. Correção atual preserva também `7a2fcce` em `checkpoint/book-decisoria-pre-corretiva-7a2fcce`.
São **103 inputs: os 91 anteriores intactos e 12 novos ao final**. Os defaults do fonte não representam o preset do gráfico.

**Modo ativo: DECISION_APLICAR.** `DECISION_ORIGINAL` continua disponível para comparação; `Inp_ResponseMode` mantém sua função histórica.
A fonte agressora começa em **DECISION_FLAGS_RUNTIME_QUALIFIED**. A hipótese declarada é que BUY/SELL exclusivos em `COPY_TICKS_TRADE` representam a agressão; cada lote e segmento precisa passar pelas verificações de origem, identidade temporal/ordinal, completude, ordenação, flags, cobertura e atualidade. Isso não comprova a acurácia econômica da classificação da corretora: usar em demonstração exige que o feed forneça essa propriedade. `UNVERIFIED` continua bloqueando entradas quando selecionado explicitamente; presets antigos podem conservar esse valor. Nenhuma confiança é herdada de `Inp_Obs_TrustAggressorFlags`.

| Novo input | Default | Unidade/função |
|---|---|---|
| Inp_DecisionMode | DECISION_APLICAR | Camada operacional ativa |
| Inp_DecisionAggressorSource | DECISION_FLAGS_RUNTIME_QUALIFIED | Hipótese explícita + qualificação estrutural em execução |
| Inp_DecisionWindowSec | 5 | Segundos de referência regular |
| Inp_DecisionMinReferences | 16 | Amostras anteriores comparáveis |
| Inp_DecisionEffortQuantile | 0.80 | Percentil empírico de esforço |
| Inp_DecisionResultQuantile | 0.20 | Percentil condicional de resultado |
| Inp_DecisionMinCoverage | 0.80 | Volume classificado / total |
| Inp_DecisionMinDirectionalShare | 0.20 | Abs(delta) / volume total |
| Inp_DecisionMinAcceptance | 0.60 | Fração de volume E de tempo observado |
| Inp_DecisionMinObservedCoverage | 0.50 | Tempo observado / duração conhecida |
| Inp_DecisionMinProgressTicks | 1.0 | Progresso mínimo em ticks |
| Inp_DecisionComparableEffortFactor | 2.0 | Faixa esforço/fator até esforço*fator |

## Regras que afetam ordens

Os booleanos e suas unidades constam antes da implementação em `Include/BookDecisionCore.mqh` e nos testes. Todas as quantidades usam a mesma janela identificada; volume operacional é `MqlTick.volume` inteiro, sem troca silenciosa por `volume_real`.

- Qualidade: origem declarada, ordem e prefixo ordinal consistentes, lote/trecho conhecido completo, sem registros inválidos ou flags BUY+SELL ambíguas; cobertura classificada >=0,80 e tempo adjacente observado >=0,50. Volume não representável exatamente é recusado.
- Pressão material: qualidade válida, intervalo `[delta-Vunknown,delta+Vunknown]` exclui zero e `abs(delta)/V >=0,20`. Atividade bilateral e esforço Weis não são pressão direcional.
- ABS: pressão em `-direção_da_entrada`; esforço >=P80 e resistência `1-max(pNet,pMax) >= 1-P20`, com resultados condicionados a esforço comparável. T é distinto de R: R recupera o nível causal, progride >=1 tick e apresenta aceitação por volume E tempo >=0,60. A reação pode manter delta contrário; não precisa estagnar. STALL_STRICT, DIVERGENCE e FOLLOWING_REACTION são distinguidos.
- CONT: progresso >=1 tick, aceitação por volume E tempo, resultado condicional e migração direcional do VWAP da janela contra a referência anterior. Volume alto ou ER alto isolados não validam. Pausa/equilíbrio aguarda, sem cancelar automaticamente a tese.
- Rejeição: pressão oposta material, progresso contrário, aceitação contrária e preço além do contexto congelado. Só esse predicado objetivo pode invalidar ARMED; delta oposto isolado não basta.
- Dados insuficientes, fonte não verificada, atraso, lacuna, prefixo divergente, referência insuficiente ou saturação impeditiva bloqueiam novas entradas. Podem manter ARMED apenas até seu timeout original; nunca voltam silenciosamente para ORIGINAL.

As referências vêm de janelas regulares, sem depender de sinais: mesmo ativo, fonte, duração, direção/pressão, tamanho de tick, época e bucket de 30 minutos. A comparação ocorre antes de inserir a janela atual. O histórico comporta 384 projeções = 192 janelas; os testes demonstram disponibilidade com 16 referências compatíveis anteriores. O nível de cada janela é conhecido antes dela, não um extremo futuro.
As evidências recentes T/CONT-forward têm validade de até duas janelas (10s no default); R usa somente o prefixo posterior já conhecido. Dados/prova de despacho têm idade máxima de 2s, além dos clocks/timeout originais. Não existe espera adicional fixa de 20–30s ou obrigação de negociar após o trigger para formar a referência de contexto.

A camada é consumida após a seleção original, durante ARMED, antes de `PreparePendingExec`, após preparação/journal e antes da única `PositionOpen`. Nunca resolve ROUTE_CONFLICT_BLOCK, recupera glass/rota inelegível ou substitui a confirmação original do book. Stops, sizing e margem originais precedem uma nova espera. Alteração após preparação exige prova local de não chamada da API, intenção exata, resolução durável e confirmação de ausência do journal; incerteza conserva a obrigação e impede reenvio. O teste posterior ao book aprovado não faz cópia histórica, escrita observacional ou log.

Coleta e decisão independem de Response/CSV/filas/logs. O núcleo reaproveita os lotes POC/VWAP de `CopyTradeTicksStrict` e completa o cursor com consultas limitadas a 8192 registros, no máximo uma por 10ms. Preserva ordinais distintos no mesmo milissegundo, inclusive negócios idênticos. O contrato é o histórico disponível na API do terminal, não certificação externa da completude do provedor. Backlog/lacunas/capacidade impedem autorização até recuperação comprovada; uma nova época precisa aquecer novamente. A coleta adicional roda depois de BE, locks, contabilidade e EOD. Contadores registram custo, consultas, memória do processo e descartes; não são latência MT5 comprovada por C++.

Configuração estruturalmente inválida agora faz `OnInit()` retornar `INIT_PARAMETERS_INCORRECT`; aquecimento normal inicializa com sucesso e não interrompe a gestão. Prefixo novo apenas esparso não apaga T/R ou CONT já comprovados; flags ruins ou perda do contexto impedem fallback. R termina em negócio efetivamente observado, seu endpoint válido não é diluído por silêncio posterior e T vencido pode ser substituído por outro teste causal sem mudar `armedAt` nem os 90s.

CSV WDO: a varredura só publica PIDs e obrigações de recuperação depois da validação integral/duplicatas; o handle de escrita é exclusivo e liberado em rejeição. Gravação parcial continua preservada e bloqueada; gravação completa com flush incerto é recuperada por releitura, sem repetição. O arquivo real `Scalper01_RC1_WDOX26_60002_Trades.csv` não foi fornecido: nenhuma linha real foi reparada ou apagada. Os testes simulam restauração externa autoritativa, não a inventam no código.

## Provas executadas

**90/90 testes na candidata corrigida e 52/52 no controle congelado: zero falhas, erros ou testes pulados. Incluem seis testes de defaults/fluxos irregulares e nove de CSV integrado.** Os 36 testes herdados aplicáveis também rodaram na candidata; 16 contratos antigos específicos do empacotamento/renomeação MATRIX_ID_FIX1 foram conferidos no controle. O fixture isolado da matriz recebeu somente um adaptador host para o reset privado; suas assertivas foram mantidas, e o reset real foi executado no pipeline completo.

| Caminho completo, com coletor/histórico/predicados/controlador reais | Operandos medidos nos fixtures | Chamadas à API |
|---|---|---:|
| ABS aprovada | 16 referências; resistência T=1; R=+6 ticks; aceitação volume/tempo=1/1 | 1 |
| ABS impedida | Progresso contrário=6 ticks; pressão material; aceitação contrária=1/1 | 0 |
| CONT aprovada | 16 referências; avanço=10 ticks; migração VWAP positiva; aceitação=1/1 | 1 |
| CONT impedida | Rejeição contrária=13,5 ticks; aceitação contrária=1/1 | 0 |

Além dos 16 cenários anteriores, os defaults corrigidos produzem 16 aprovados e 16 impedidos com tempos/volumes irregulares, até aproximadamente 17% de volume desconhecido e negócios idênticos no mesmo milissegundo. Evidência completa sobrevive à nova janela parcial, ao silêncio curto e à substituição causal de T vencido; dados antigos permanecem bloqueados. São cenários cruzando rotas, compra/venda, WIN/WDO e book ligado/desligado, com observação e logs desligados. Alterar apenas o veredito muda API 1/0; alterar apenas logs não muda a decisão. ORIGINAL reproduz 192 rastros de envio do controle. Há ainda provas de limpeza PREPARED/MAY, intenção incerta sem reenvio, timeout/sessão/overshoot, glass/conflito/inelegibilidade, aquecimento, flags/delta/cobertura, ordinais sobrepostos, capacidade e sensibilidade dos limiares.

Nos fixtures de candidaturas originalmente elegíveis, **por rota**: 20 casos, 4 aprovados, 4 aguardados, 4 vetados, 4 perdidos por timeout e 4 por overshoot; 4 entradas válidas preservadas. São contagens de cenários determinísticos, não oportunidades observadas no mercado nem medida de superioridade.

[Resultados e limites](artifacts/decisoria/test-results.json) · [Log dos testes](artifacts/decisoria/tests.log) · [Diff modular exato](artifacts/decisoria/alteracoes-modulares.patch) · [Comparação dos monolíticos](artifacts/decisoria/monolitico.diff).

**MetaEditor não acessível: compilação nativa, avisos/erros nativos, replay MT5, latência real e comparação financeira não executados.** Não há EX5 novo, homologação, preset real inferido ou implantação em produção. Sem dados cronológicos de mercado, não se afirma melhora de acerto/expectativa nem que reduzir ordens seja melhor. Os limiares são experimentais; os testes de sensibilidade não os otimizam.

Reprodução: `python3 tools/generate_identity_inputs.py --check`, `python3 tools/build_decisoria.py --check`, `python3 tools/run_decision_checks.py`. A versão modular e o único arquivo novo foram comparados integralmente, incluindo os 103 inputs e os eventos. A monolítica de controle 815077e e seus documentos/resultados permanecem intactos; a entrega anterior 7a2fcce está integralmente preservada no checkpoint.
