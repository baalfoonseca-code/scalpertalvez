# BOOK PRO 1.125 — MATRIX_ID_FIX1

Candidata com os identificadores corrigidos para **nova compilação na VPS**.
Não há confirmação de compilação nativa nem homologação. O relatório recebido
do MetaEditor apontava **36 erros e 1 aviso** na cópia chamada `scalperbase1.mq5`.
Essas são contagens anteriores fornecidas pelo usuário; não são resultados desta
candidata. A distribuição mantém o nome `scalpertalvez_MONOLITICO.mq5`.

## Arquivo completo e alteração exata

- [Monolítico completo MATRIX_ID_FIX1](../scalpertalvez_MONOLITICO.mq5).
- [Diff exato dos três fontes afetados](../artifacts/matrix-id-fix1/source-exact.patch),
  relativo ao commit anterior `eee1b308ed1ee5c92a699f852705413eca9a74ec`.
- [Diff exclusivo do módulo de diagnóstico](../artifacts/matrix-id-fix1/module-identifiers.patch).
- [Hashes e inventário das alterações nos fontes](../artifacts/matrix-id-fix1/source-delta.json).

A correção foi feita primeiro em `Include/BookArmedDiagnostics.mqh` e registrada
no commit **`824e0ced7a3ebb3fd9893c60a4547562ef4cea05`**:

```diff
-   MatrixSnapshot matrix;
+   MatrixSnapshot matrixSnapshot;
-   string matrix=s.matrix_available?BookDiagOriginalMatrix(s.matrix):"";
-   BookDiagCell(row,matrix);
+   string matrixCsvCell=s.matrix_available?BookDiagOriginalMatrix(s.matrixSnapshot):"";
+   BookDiagCell(row,matrixCsvCell);
```

Todas as referências desse membro em `gBookDiagState`, `e.state` e `s` foram
atualizadas. `matrix_available`, as colunas, seus nomes e todos os literais
`matrix.*` foram preservados. O módulo difere somente por essas renomeações;
não houve mudança de expressões, fórmulas, predicados ou decisões.

O gerador existente `tools/generate_identity_inputs.py` atualizou somente a
revisão no momento da geração e o SHA-256 do pacote em `BookBuildIdentity.mqh`.
São metadados gravados pelo diagnóstico de identidade. `BOOK_BUILD_ID` e o
serializador de inputs permanecem iguais. O principal modular e os outros
**11 módulos** permanecem byte a byte iguais à entrega anterior.

ABS/CONT, C1–C5, book, Stage 2, ResponseObserver, microestrutura, gestão sigma,
BE, locks, stops, alvos, persistência e recuperação financeira foram preservados.
Não foi alterado nenhum input, default ou comportamento para facilitar compilação.

## Regeneração e equivalência

A monolítica foi produzida por `tools/build_monolithic.py`, sem edição manual
divergente. O commit **`f936c3a`** contém a regeneração e a atualização dos
verificadores. O cabeçalho identifica `MATRIX_ID_FIX1`; `#property version`
continua `1.125`.

O gerador passou a exigir o conteúdo modular corrigido do commit `824e0ce`,
mantendo os mesmos **49 caminhos de engenharia** da referência `323750a`.
Cada arquivo continua conferido integralmente contra seu conteúdo no Git.
Arquivos ausentes, modificados ou omitidos da referência são rejeitados; testes
negativos exercitam esses casos em um repositório temporário isolado.

Os 13 módulos foram incorporados na mesma ordem e nos mesmos locais. Somente
`<Trade\Trade.mqh>` e `<Trade\PositionInfo.mqh>` permanecem como dependências.
O novo arquivo tem **577.196 bytes e 12.896 linhas**.

O [comparador independente](../artifacts/matrix-id-fix1/independent-equivalence.json)
confirmou igualdade da sequência completa de **110.695 tokens ativos MQL5** e
dos inventários entre as versões corrigidas:

| Item | Modular | Monolítico |
|---|---:|---:|
| Inputs, mesmos tipos/nomes/ordem/defaults | 91 | 91 |
| Funções definidas | 490 | 490 |
| Estruturas | 31 | 31 |
| Enums | 18 | 18 |
| Globais, incluindo inputs | 468 | 468 |
| Duplicatas encontradas nesses inventários | 0 | 0 |

SHA-256 da sequência canônica de tokens nas duas versões:
`22d32727643b7d14a4d86ce5eead2682ea5978aab5dddad8d4710a0d532c7ff5`.
Há também [manifesto de geração](../artifacts/matrix-id-fix1/build-manifest.json)
e [mapa de origem](../artifacts/matrix-id-fix1/source-map.json).

## Testes e auditoria

Em **23/10/2026, 12:49:30 (America/Sao_Paulo)**, passaram **52 testes**:
zero falhas, erros ou testes pulados. São os 44 testes anteriores e oito testes
específicos desta correção. A execução completa levou 49,793 segundos, com
Python 3.12.14 e g++ 14.2.0.

- [Log completo](../artifacts/matrix-id-fix1/tests-complementar.log).
- [Resultado estruturado](../artifacts/matrix-id-fix1/test-results-complementar.json).
- [Auditoria de identificadores reservados](../artifacts/matrix-id-fix1/reserved-identifier-audit.json).

Os testes específicos comparam a renomeação e todos os 241 literais do módulo
com `eee1b30`. Também materializam os 14 fontes anteriores e comparam o programa
MQL5 ativo completo: somente 16 tokens de identificadores e os dois valores
fixados de proveniência mudam; todos os demais tokens permanecem iguais. O formatador real é exercitado com os mesmos adaptadores C++ antes da
correção, depois dela e na monolítica: **24 linhas de dados, 83 colunas**, incluindo
valores indisponíveis, infinito e escape de aspas/separadores/quebras de linha.
Os **57.614 bytes** de CSV resultantes são iguais nas três versões, SHA-256
`f9cabb9029bc0b5f0af74af69a4493c601dc8745351efc7c6a6fa8df702c0118`.

A auditoria lexical das declarações ativas MQL5 não encontrou outras colisões
com os tipos/palavras reservadas enumerados no relatório, incluindo
`matrix`, `matrixf`, `matrixc`, `vector`, `vectorf`, `vectorc` e `complex`.
Testes confirmam detecção de membros, locais, parâmetros e declarações múltiplas.
Essa inspeção não é um parser completo MQL5 e não valida os headers oficiais.
O uso de `matrix` em fixtures exclusivamente C++ e em textos CSV é preservado.

A suíte anterior de finanças, journals/CSV, ARMED, microestrutura e compatibilidade
também foi repetida. Os fixtures continuam produzindo os mesmos resultados:
12.000 matrizes, 4.096 avaliações Stage 2 e 96 classificações DOM por versão
(`aa16ed3577bb69ca`); 514 casos POC e 128 reconstruções Weis por versão
(`febf922085385281`). Esses são testes no host, não execução MT5.

## Compilação nativa e limites

MetaEditor e Wine não foram encontrados no PATH nem nos locais acessíveis
inspecionados. A busca registrou duas pastas sem permissão de leitura; não se
afirma ausência absoluta de binários na máquina.

| Versão corrigida | Compilação MetaEditor | Erros | Avisos |
|---|---|---|---|
| Modular | Não executada | Não medidos | Não medidos |
| Monolítica | Não executada | Não medidos | Não medidos |

[Status nativo](../artifacts/matrix-id-fix1/native-compilation-status.json) e
[log da descoberta](../artifacts/matrix-id-fix1/compiler-discovery.log).
Não existem logs novos de compilação MetaEditor; contagens nativas são `null`.
Os testes g++ compilam fixtures e não comprovam a compilação do EA completo.

**A eliminação dos 36 erros e do aviso só pode ser confirmada por nova compilação
nativa.** Outros problemas de sintaxe/tipos/APIs podem permanecer na fonte
experimental reconstruída. Não houve backtest MT5, envio de ordens, geração de
EX5 ou alteração no executável/terminal de produção. A branch de cirurgia
original e os commits anteriores foram preservados.

## Arquivos históricos e reprodução

Os relatórios antigos e seus hashes descrevem a entrega anterior; foram
preservados sem sobrescrita. O
[ZIP modular original 323750a](../artifacts/monolitico/scalpertalvez_MODULAR_323750a.zip)
permanece intacto. Um
[ZIP modular com a correção](../artifacts/matrix-id-fix1/scalpertalvez_MODULAR_MATRIX_ID_FIX1.zip)
contém os mesmos 49 caminhos, com apenas o módulo e seus metadados corrigidos.
Os documentos e resultados dentro desses snapshots são históricos; este
relatório e a pasta `matrix-id-fix1` registram a validação atual.

```sh
python3 tools/build_monolithic.py --check
python3 tools/generate_identity_inputs.py --check
python3 tools/run_monolithic_checks.py
```

Para regenerar, use `python3 tools/build_monolithic.py`. Para compilar a candidata
na VPS, abra `scalpertalvez_MONOLITICO.mq5` no MetaEditor e pressione F7, mantendo
o EA fora do gráfico/produção durante essa verificação.

SHA-256 do arquivo completo:
`c3a2e1bd2ea4f9f04eeafa48a2c8fb70cd20af441d2c09b296e41f44c30534ae`.
Os [checksums da entrega](../artifacts/matrix-id-fix1/SHA256SUMS) permitem conferir
os arquivos recebidos.
