# Microestrutura experimental em observação

Os módulos `BookMicroMath.mqh` e `BookMicrostructure.mqh` ampliam o
`ResponseObserver` existente. Não recebem autoridade para enviar, liberar,
bloquear, inverter ou cancelar operações. O modo histórico `RESPONSE_ORIGINAL`
permanece o default. Os seis novos inputs são adicionais aos 71 históricos:

| Input | Default | Significado |
|---|---:|---|
| `Inp_ObserveMicrostructure` | `true` | Ativo somente com `RESPONSE_OBSERVAR` |
| `Inp_Obs_TrustAggressorFlags` | `false` | Declara confiança explícita nos flags do provedor para rótulos de pressão robusta |
| `Inp_Obs_Min_Displ_Sigma` | `0.0` | Multiplicador hipotético ABS de M1; zero significa não configurado |
| `Inp_Obs_Max_Body_Sigma` | `0.0` | Corpo máximo hipotético ABS de M1; zero significa não configurado |
| `Inp_Obs_Cont_Min_Displ_Sigma` | `0.0` | Multiplicador hipotético CONT de M1; zero significa não configurado |
| `Inp_Obs_WindowBudgetUS` | `5000` | Suspende a extensão após snapshot que exceda esse orçamento |

Nenhum multiplicador de M5 foi importado como calibração de M1. A comparação C1
não configurada fica indisponível, sem escolher um valor financeiro silencioso.

## Fonte, causalidade e qualidade

O mesmo loop `ResponseFlowTick()` acumula percurso, extremos, volumes por lado
de um nível e cobertura. Não foi criado coletor de ticks nem nova chamada
`CopyTicks`. O volume mantém a origem histórica da BOOK, `MqlTick.volume`,
rotulada `TRADE_TICK_VOLUME` pelo observador. Volume real e tick volume das ondas
Weis permanecem identificados separadamente e nunca compartilham referências.

O nível estrutural é um POC calculado em snapshot original anterior. Sua data de
conhecimento é o horário do callback que o obteve, não o horário histórico do
último tick. Uma pequena fila de duas referências permite usar a anterior quando
a mais nova ainda não era conhecida estritamente antes do início da janela.
Referências de outro dia não são aceitas. A tolerância fica congelada em um tick.

`KnownCoverage=(Vbuy+Vsell)/V`, `KnownImbalance=Delta/(Vbuy+Vsell)` e o intervalo
`[Delta-Vunknown, Delta+Vunknown]` são calculados somente com denominadores
válidos. Intervalo excluindo zero não prova qualidade dos flags. O default
`Inp_Obs_TrustAggressorFlags=false` impede que essa suposição seja feita sem
declaração explícita; os números e o intervalo continuam registrados.

`NetProgress`, `MaxProgress` e `TotalPath` usam ticks e uma direção exportada.
Na ausência de direção líquida robusta matematicamente, a direção geométrica
segue o deslocamento observado e não é apresentada como pressão agressora
comprovada. O impacto assinado original é preservado. `small_delta_scale` permite
identificar sua instabilidade quando o delta é pequeno. Percurso zero resulta em
ER indisponível, e não em eficiência fabricada.

Cobertura temporal é a fração de segundos com negócios observados. Dwell usa
somente intervalos entre dois negócios separados por até 1 segundo; lacunas mais
longas não contam como permanência negociada. `AcceptanceTimeRatio` usa o tempo
efetivamente coberto como denominador, acompanhado de `TemporalCoverage`.
`ConsecutiveDwell` registra a maior sequência observada no mesmo lado/na zona;
não representa continuidade durante silêncio. Ausência de dados deixa célula
vazia, distinguindo-a de volume efetivamente zero.

## Referências causais e interpretação

Há no máximo 512 janelas históricas em memória por instância/símbolo. As
comparações exigem a mesma duração exata, fonte de volume e meia hora do relógio
do servidor. Não entram janelas futuras, duplicadas, sobrepostas ou com cobertura
inferior a 50%. No mínimo oito observações comparáveis são necessárias. A
comparação condicional exige ainda mesma direção confiável e esforço entre
metade e dobro do esforço atual. O registro atual é comparado antes de entrar
na história.

P20/P80 são rótulos descritivos experimentais. Atividade total, pressão direcional
e esforço Weis são relatados separadamente e não representam três confirmações
independentes. `Resistance_T=1-max(pY,pM)` só existe com referência condicional
suficiente. O CUSUM descritivo usa `kappa=0.05` e não possui calibração de falsos
alarmes. Memória histórica não é persistida entre reinicializações: o período de
aquecimento volta a produzir indisponibilidade explícita.

## Teste, reação e regimes

O toque da região previamente congelada gera `TEST_START`; o fechamento da
janela original define `TEST_END` de forma objetiva. As métricas gerais ainda
descrevem a janela inteira. Para não atribuir esforço anterior ao toque a um
teste posterior, somente uma janela cujo primeiro negócio já alcançou o nível
pode receber o rótulo de absorção candidata. Toque tardio recebe
`test_status=3`, exclusivamente triagem de janela, sem classificação de absorção.
Essa restrição conservadora reduz a cobertura e está explicitamente pendente de
validação empírica.

A candidata exige pressão robusta declarada, esforço material relativo à
história, resistência P80, toque causal, cobertura e ausência de aceitação
direcional conclusiva. Não equivale a reversão garantida nem identifica
participante/ordem passiva. Sem história adequada, permanece indisponível.

A reação usa exclusivamente janelas posteriores independentes, mantém o nível e
tolerância do teste e começa no primeiro negócio efetivamente observado.
Recuperação, ER, migração do POC, volume e tempo no lado recuperado e fluxo
agressor são medidos separadamente. O rótulo de reversão observável exige
recuperação real, progresso eficiente e aceitação do lado recuperado; jamais
exige pouco deslocamento na reação. Há invalidação, lacuna e encerramento após
três janelas objetivas. Esse horizonte não acrescenta espera à execução real.

Enums exportados:

| Campo | Códigos |
|---|---|
| `regime_experimental` | 0 insuficiente, 1 eficiente, 2 deterioração candidata, 3 absorção candidata, 4 reação iniciada, 5 reversão observável, 6 equilíbrio |
| `test_status` | 1 teste de janela iniciado no primeiro negócio, 2 candidata reconhecida, 3 toque tardio/triagem apenas |
| `reaction_status` | 1 aguardando/observando, 2 iniciada, 3 critérios observáveis confirmados, 4 invalidada, 5 lacuna/dados insuficientes, 6 horizonte encerrado |

Os limiares descritivos 0.6 de aceitação/eficiência de tendência, 0.5 de ER de
reação, 0.2 de equilíbrio e cobertura de 0.5 são hipóteses de instrumentação, não
gates aprovados. São definidos no módulo e não devem ser interpretados como
validação estatística. `ER_M1_10` usa exatamente onze fechamentos de M1 fechadas.
ER elevado não é uma promessa de continuação futura.

Ondas Weis mantêm `RebuildWeisCache()` e `ComputeLiveWaveO1()` intactas. São
acrescentados duração, volume por segundo e percurso por fechamentos de onda;
o percurso não é anunciado como trajetória tick a tick. A comparação de
intensidade usa mesma direção, origem, meia hora e idade semelhante, excluindo
a própria onda. A onda viva permanece parcial e seu esforço existente não é
rebatizado como referência estatística nova. Idade não comprovável fica NA.

Durante ARMED, a camada aproveita apenas snapshots que a arquitetura original
já disponibilizou e registra candidatas da rota oposta; não força nova avaliação,
não consome outro relógio, não reinicia timeout e não afirma que a candidata
oposta constituiria uma operação válida.

## Desempenho e validação

Os registros microestruturais são cópias imutáveis anexadas ao snapshot do
ResponseObserver. `micro_window_from_msc/to_msc` identificam expressamente a
janela NOW, inclusive quando a linha legada descreve PREV. O histórico não é
consultado durante escrita posterior. Fila, limite de bytes, descartes,
overwrites e timer existentes são preservados.

As matrizes históricas têm capacidade fixa. O snapshot lê no máximo 150
fechamentos M1 uma vez para ER/percurso, quando necessários. A extensão registra
tempo da captura, total, contagem, máximo e descartes; exceder o orçamento
suspende somente a extensão com `SUSPENDED_BUDGET`. O ResponseObserver e a
arquitetura financeira continuam seus caminhos originais. A amostra que excedeu
o orçamento é marcada e a coleta de novos acumuladores microestruturais cessa.

`tests/test_micro_math.cpp` compila a aritmética compartilhada efetivamente usada
pelo MQL5. Verifica fluxo vendedor eficiente, esforço sem progresso, fluxo
bilateral, desconhecido, delta pequeno, recuperação dentro da janela, silêncio,
cobertura, atrasos, nível causal, ER de 11 fechamentos e 20.664 combinações C1 com
limiares equivalentes. O benchmark de um milhão de ticks mede apenas essa
aritmética em C++; não é latência do EA no MT5. O teste Python verifica esquema
CSV e ausência de APIs financeiras/coletores duplicados na extensão.

Não foram executados compilação MetaEditor, replay nativo de ticks/book, teste
de Strategy Tester ou calibração estatística. Estados de teste/reação, timings
do MT5 e comparação operacional completa ainda requerem replay nativo com dados
controlados. Nenhum desses resultados foi simulado como teste aprovado.

A medição de reação também exige que o início da janela seja posterior ao horário
em que a candidatura foi reconhecida pelo callback. Janelas já iniciadas nesse
instante recebem status interno 7 (espera por janela causal futura) e não são
reclassificadas retroativamente; isso não atrasa a execução do EA. Referências
Weis usam no máximo uma amostra de idade mais próxima por onda distinta, evitando
contar vários snapshots de uma onda longa como ondas independentes.
