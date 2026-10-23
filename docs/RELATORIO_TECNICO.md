# Entrega experimental — Rêmora Scalper BOOK PRO 1.125

A cirurgia foi implementada na branch `dev/book-pro-1.125-cirurgia`, a partir de
`main` em `a31f7b03701dd13b5c26801669552001d3ed634c`. A fonte completa de trabalho
é [`scalpertalvez.mq5`](../scalpertalvez.mq5), acompanhada dos 13 módulos em
[`Include`](../Include). O arquivo original `scalpertalvez` e `comando.pdf`
permanecem byte a byte intactos. O PDF de 27 páginas e a fonte integral foram
lidos antes/durante a implementação. [Proveniência](PROVENIENCIA.md).

**Candidata experimental, sem homologação. A compilação nativa não foi executada.**
Não há MetaEditor/MT5, dados de replay, preset de produção ou sessão de corretora
neste ambiente. Não foi acessado/modificado o terminal de produção, enviado pedido
de negociação ou criado EX5. Os documentos e a fonte 2.436 citados no PDF não
foram fornecidos; a implementação usa os requisitos explícitos do comando mestre.

## Comportamento e entradas de configuração

Os 71 inputs históricos conservam nomes, tipos, ordem, defaults e conexões
originais. Há **91 inputs no total: 71 históricos + 20 novos**. A geração do
snapshot e os testes expandem os includes locais para verificar todos eles.

Os defaults mantêm SL por pontos, TP original por ativo, BE em 1R e profit locks
**desligados**. O modo histórico de ResponseObserver continua
`RESPONSE_ORIGINAL`. A configuração efetiva, incluindo os 20 novos inputs,
recebe representação canônica e SHA-256 em cada inicialização, acompanhada de
símbolo, conta/servidor, Magic, volume, revisão de base, build e digest dos fontes.
Audit/Shadow novos são separados por contexto; Trades e os journals legados
mantêm seus nomes/schema. As correlações observadas após restart não são
apresentadas como prova do preset que originou uma operação antiga.

- 13 inputs financeiros: [nomes, unidades, defaults e recuperação](GESTAO_AVANCADA.md).
- `Inp_EnableArmedDiagnostics=true`: coleta diagnóstica, sem autoridade financeira.
- 6 inputs de microestrutura: [descrição e limitações](MICROESTRUTURA_OBSERVACIONAL.md).

A correção deliberada de segurança é impedir novas entradas com infraestrutura
CSV incerta. Não se afirma equivalência com o comportamento defeituoso nessa
condição. Os caminhos de proteção/EOD não ganham dependência do book.

## Alterações entregues

| Área | Implementação |
|---|---|
| Infraestrutura CSV | Scanner estrito, linha lógica, colunas esperadas/recebidas, causa e offset; BOM/encoding, aspas, truncamento, identidade, PID/overflow, duplicatas e gravação parcial. Arquivo preservado e entradas bloqueadas na incerteza. Marcador durável de presença impede recriação de arquivo desaparecido após reinício. |
| Identidade | Serializer dos valores efetivamente carregados; hash canônico, contexto por reinicialização, build/source SHA e correlação sem atribuir retrospectivamente presets. |
| ARMED | IDs únicos, matriz congelada completa, subtipo, região/trigger/timeout, melhores/piores preços amostrados, toque e tempo observado, primeiro/último impedimento, máscaras de avaliados/não avaliados, onda viva, spread, overshoot, bandas e desfechos. Book só é rotulado após consulta real; pedido enviado/aceito não equivale a execução confirmada. |
| Bandas | Sigma e dias válidos da rotina original; bandas/largura/distâncias do snapshot efetivamente utilizado. Aberturas D1/sessão indisponíveis são explicitamente NA. Resumo na primeira referência original válida e nas mudanças de referência. |
| Gestão | SL sigma opcional com teto/grade conservadora; BE configurável em R inicial comprovado; dois locks com triggers/proteções independentes; TP BASE/TURBO por R opcional, preservando ABS/CONT. Sizing, margem, limites e inicial SL/TP do envio permanecem na infraestrutura original. |
| Persistência financeira nova | Journal separado `BOOK_RISK1_`/`SCALPER_RISK1`, barreira anterior ao despacho, checksum/readback, identidade e resultado correlacionados, comprovação SL/TP e recuperação conservadora. Nunca reinterpreta `SCALPER_BE1` nem usa SL movido para recriar R inicial. |
| Microestrutura | Extensão do ResponseObserver existente: cobertura/imbalance/intervalo do delta, percurso/ER/progresso/excursão, referências causais comparáveis, resistência descritiva, teste/reação independentes, aceitação/rejeição, regimes experimentais, ER de 11 closes M1, Weis e comparação C1 sigma paralela. Sem novo coletor CopyTicks ou gate. |
| Desempenho | `[BOOK_PERF]` mede OnTick/timer/POC e memória; observadores mantêm filas, descartes, bytes, tempos e suspensão identificável por orçamento. Sem afirmação de latência nativa aprovada. |

Matriz C1–C5, ABS/CONT, BASE/TURBO, conflitos, glass, M3/M1, POC/empates, Weis,
book de cinco preços distintos/dominância, contradição, sizing e schemas
financeiros foram protegidos por comparação de corpos/fixtures. Os hooks
observacionais retornam `void` e seus resultados não autorizam decisões.

## Testes executados

Resultado final: **36 testes passaram; 0 falhas, 0 erros, 0 pulados, 0 falhas
esperadas**. Python 3.12.14 e g++ 14.2.0. Evidências:
[`tests-host.log`](../artifacts/tests-host.log) e
[`test-results.json`](../artifacts/test-results.json).

| Grupo | Evidência executada no host |
|---|---|
| Compatibilidade | Corpos reais extraídos da fonte original e atualizada: 12.000 matrizes, 4.096 Stage 2, 96 DOM, 514 POC e 128 Weis, com preços/relógios/estados controlados; saídas comparadas. Inputs, funções protegidas e schemas legados comparados. |
| BE | 7.234 casos com os corpos reais do trigger: equivalência em default 1R, compra/venda, média fracionária, bid/ask e gatilhos opcionais. |
| Gestão matemática | 2.216 asserções no núcleo compartilhado: WIN/WDO, lados, sigma abaixo/no/acima do teto, inválidos, grade, slippage/R, locks, saltos, SL melhor, stops/freeze e estados de confirmação/incerteza. |
| Journal novo | 56 asserções executam serializer/parser/validador reais: roundtrip, PIDs grandes, identidade, checksum, truncamento, etapas, R inicial, PnL negativo e zero-ID pendente. Namespace novo validado fora do prefixo EMR legado. |
| CSV | 15 testes offline de corrupção/leitura conservadora, mais parser MQL real adaptado: 12 casos de quoting/linhas, 9 IDs, falha de alocação e 8 combinações de política de arquivo ausente. |
| ARMED | Núcleo real: 23 casos de traço e 21 de coleta adaptada, inclusive toque/retração, timeout, consulta book ausente, pedido versus confirmação e saturação. Esquema de 83 colunas validado. |
| Microestrutura | 20.705 asserções no núcleo compartilhado, incluindo 20.664 combinações C1; fluxo eficiente, sem progresso, bilateral/desconhecido, delta pequeno, silêncio, cobertura, atraso, ER e referências causais. Lifecycle real de reação extraído: reconhecimento atrasado, confirmação, lacuna, invalidação e toque tardio. |
| Integridade | SHA do original/PDF, delimitadores/literais/includes locais de 15 arquivos, serializer dos 91 inputs e digest do pacote de fontes. Não constitui compilação MQL5. |

O benchmark de 1 milhão de ticks do núcleo aritmético C++ registrou 9.140,13 µs
no total e 0,00914 µs por tick nessa execução; mede somente aritmética do fixture.
Não mede o OnTick do MT5, arquivos, broker, latência de book nem performance do EA
completo. O log bruto é a evidência desse resultado, sem extrapolação ao terminal.

Durante revisão/testes foram corrigidos: validação CSV sem bloqueio de entradas,
namespace novo incompatível com o enumerador legado, leitura de prefixo de
journal após falha, perda de certificado de lock em no-op/TP, retry da gravação
CLOSED, ordenação de locks inativos, cache limitado, relatório de custos e PnL
negativo. Os resultados acima são da rodada posterior às correções.

## Testes não executados e riscos remanescentes

1. **MetaEditor/MT5 ausentes:** não houve compilação do EA completo, backtest,
   replay nativo, teste B3/broker nem equivalência com o EX5 em produção. A fonte
   reconstruída pode conter incompatibilidades que os recortes C++ não detectam.
2. A compatibilidade integral de despacho, fills parciais reais, retcodes,
   confirmação atrasada, lock/TP, restart de terminal, power loss, EOD durante
   pendência, virada diária e contabilidade completa exige MT5/demonstração. Nos
   testes do host foram executados os núcleos e fixtures descritos, sem simular
   ordens/backtest aprovados. O roteiro está em [VALIDACAO_MT5.md](VALIDACAO_MT5.md).
3. **O CSV real `Scalper01_RC1_WDOX26_60002_Trades.csv` não foi fornecido.** A
   causa do incidente de 22/10 não pode ser estabelecida e esse arquivo não foi
   reparado. A nova instrumentação e fixtures tornam as causas reproduzíveis
   diagnosticáveis. O utilitário offline apenas lê, não migra valores econômicos.
4. Sem marcador de presença legado e sem qualquer evidência financeira
   recuperada, um arquivo nunca criado e um histórico antigo desaparecido são
   indistinguíveis. Erro de sentinel é explicitado; não se inventa restauração.
   Scanner limitado a 64 MiB e journals novos a 1 MiB recusam excesso de forma
   conservadora, sem apagar registros.
5. Não há garantia de atomicidade contra duas instâncias escrevendo o mesmo
   ledger, alteração externa de mesmo tamanho ou perda física de disco. Exige
   isolamento por conta/símbolo/Magic; em netting, outros EAs compartilham posição.
6. Crash após barreira SLTP antes de ID/resultado durável pode exigir
   reconciliação externa. Não existe autorização automática para retransmitir,
   inventar sigma ou apagar journals. SL/TP existentes e EOD são preservados.
7. Coleta observacional é limitada/amostrada: filas/tempo/disco podem suspender
   dados, trajetória ARMED não é fita exaustiva e correlação observacional de
   confirmação não sobrevive ao restart. Lacunas são registradas; journals
   financeiros continuam sendo a referência financeira.
8. Volume POC legado usa `MqlTick.volume`. A Weis legada seleciona real volume
   pela disponibilidade da série; série retornada toda zerada não provoca novo
   fallback. Esses comportamentos foram preservados e exigem validação do feed.
9. Confiança nos flags, limiares de regimes/aceitação/resistência, diferenças C1
   sigma e falsos alertas não foram calibrados. Histórico causal precisa aquecer;
   ausência de referência permanece NA. Não há evidência de superioridade,
   expectativa financeira, stops garantidos ou rentabilidade.

## Reprodução e entrega

No diretório do repositório:

```sh
python3 tools/run_tests.py
python3 tools/generate_identity_inputs.py --check
git diff --check
```

Após alterar fonte/inputs/modules, gere novamente a identidade antes dos checks:
`python3 tools/generate_identity_inputs.py`. O campo de revisão é explicitamente
`revision_at_generation`; o digest dos fontes identifica o conteúdo testado.
Não se fabrica um commit futuro dentro do próprio código.

Diagnóstico de uma **cópia preservada** do CSV real, quando disponível:

```sh
python3 tools/audit_trade_csv.py copia_Trades.csv --symbol WDOX26 --magic 60002
```

O [diff da fonte](../artifacts/source.diff) compara diretamente a referência com
`.mq5`; o [diff completo](../artifacts/BOOK1125.patch) parte do checkpoint
`02a8465`, incluindo módulos, ferramentas e testes. O [histórico de commits](../artifacts/commits.txt)
identifica as etapas; `cab2cc8` contém gestão e `f538a34` observação/integração.
A lista de hashes da entrega permite conferir os arquivos. Publicar branch de
código não implanta nem homologa o EA no MT5.
