# Entrega complementar: modular e monolítico da BOOK PRO 1.125

A versão de engenharia continua sendo a entrega modular do commit
`323750ad5bc3a9f4e5c92570313b206966dfdff6`, na branch
`dev/book-pro-1.125-cirurgia`. Os **49 arquivos** desse commit, incluindo fonte,
13 módulos, documentação, testes e resultados anteriores, permanecem byte a byte
intactos. Nenhum commit anterior foi reescrito. A entrega complementar está na
branch `dev/book-pro-1.125-monolitico` e acrescenta arquivos; não substitui a
referência modular nem modifica o executável de produção.

A fonte solicitada é [`scalpertalvez_MONOLITICO.mq5`](../scalpertalvez_MONOLITICO.mq5):
**576.983 bytes, 12.895 linhas**, com todos os módulos personalizados incorporados.
Pode ser aberta diretamente no MetaEditor. Restam somente os includes oficiais
`<Trade\Trade.mqh>` e `<Trade\PositionInfo.mqh>`, fornecidos pela biblioteca padrão
do MT5; não depende de nenhum `.mqh` personalizado deste repositório.

**Ambas as versões permanecem sem compilação nativa comprovada e sem homologação.**
Não houve backtest MT5, replay de book, envio de ordem ou alteração no terminal
em produção durante esta entrega.

## Transposição integral e independência da verificação

`tools/build_monolithic.py` substitui cada include personalizado exatamente no
local original, recursivamente, conservando a ordem dos 13 módulos e suas
dependências. Não altera fórmulas, predicados, tipos, nomes, inputs, defaults,
estados, journals, callbacks, diagnósticos ou instrumentação. Mantém os guards e
demais diretivas de MQL5 na posição original. A fonte modular não é regravada.

Existem adaptadores exclusivos de testes C++ em ramos condicionais
`__cplusplus` e `BOOK_RISK_HOST`. Essas macros não são habilitadas no perfil MQL5.
O gerador preserva **33 linhas** desses ramos/diretivas como comentários
`HOST_CPP_INACTIVE`, mantendo ativo exatamente o correspondente código MQL5.
Assim, `<cmath>`, `std::` e assinaturas de arrays exclusivas do host não viram
dependências do MetaEditor. As informações originais dessas linhas continuam
presentes, com rastreabilidade; não são removidas da entrega modular.

Cada linha original de `scalpertalvez.mq5` e dos 13 `.mqh` foi conferida como
código literal preservado, diretiva de include incorporada como comentário ou
linha exclusiva do host preservada como comentário. O teste reprova omissões.
O [mapa de origem](../artifacts/monolitico/source-map.json) contém 87 segmentos
para relacionar linhas do monolítico ao arquivo/linha originais. O
[manifesto de geração](../artifacts/monolitico/build-manifest.json) registra ordem,
origem e hashes dos módulos, assim como os hashes dos 49 arquivos protegidos.

A comparação não depende apenas do próprio gerador.
`tools/verify_monolithic_independent.py` usa outra implementação para processar
os guards e o perfil MQL5 de ambas as representações. Rejeita diretivas não
suportadas, macros dependentes de localização/tempo, ciclos excessivos, includes
inesperados e redefinição dos flags de host. Nenhuma dessas construções foi
necessária para interpretar os fontes atuais. Os includes oficiais são mantidos
iguais, mas seus conteúdos não são expandidos ou validados neste ambiente.

A comparação alcança todos os tokens ativos, literais, diretivas preservadas e
corpos das rotinas. O inventário confere também declarações globais, estruturas,
enums e hashes dos corpos das funções, na mesma sequência.

| Verificação | Modular expandido no perfil MQL5 | Monolítico | Resultado |
|---|---:|---:|---|
| Tokens ativos | 110.695 | 110.695 | Idênticos, sem primeiro ponto de divergência |
| Inputs | 91 | 91 | Mesmos nomes, tipos, ordem e defaults |
| Funções próprias definidas | 490 | 490 | Mesmas assinaturas e corpos |
| Estruturas | 31 | 31 | Mesmas definições |
| Enums | 18 | 18 | Mesmos membros/valores |
| Variáveis globais, incluindo inputs | 468 | 468 | Mesmas declarações/inicializações |
| Includes oficiais restantes | 2 | 2 | Mesmos caminhos |
| Includes personalizados necessários | 13 arquivos de referência | 0 | Todos incorporados |
| Duplicatas nos inventários | 0 | 0 | Nenhuma introduzida ou omitida |

Digest SHA-256 da sequência canônica de tokens ativos, igual nas duas versões:
`d6f1315a267334f5e1068d75785197438b1fb938879bb3512dac9e8beda95ca1`.
O [relatório independente completo](../artifacts/monolitico/independent-equivalence.json)
contém os inventários e os hashes de cada rotina/estrutura/enum.

A igualdade cobre a gestão sigma/BE/locks/TP, persistência, ARMED/CSV,
ResponseObserver, microestrutura e a matriz ABS/CONT, além das demais rotinas.
Não é uma medição da execução no terminal, de latência, do servidor ou de resultado
financeiro. A identidade operacional embutida continua a identificar o pacote de
engenharia modular original; não foi regenerada para mudar build ou presets.
O hash externo do monolítico identifica sua representação adicional.

## Testes repetidos e evidências

Em **23/10/2026, 11:32:16 (America/Sao_Paulo)**, foi executada a suíte inteira:
**44 testes passaram; 0 falhas, 0 erros, 0 pulados e 0 falhas esperadas**.
Python 3.12.14 e g++ 14.2.0. São os 36 testes anteriores mais 8 novos de entrega,
sem modificar os testes existentes ou seus resultados antigos.

Os testes novos comprovam preservação dos 49 arquivos, regeneração exata,
ordem/dependências, cobertura de cada linha, igualdade independente dos tokens e
inventários, 91 inputs, apenas includes oficiais e ZIP idêntico ao commit base.
Também testam a rejeição de seis construções não suportadas pelo checker e uma
seleção válida do ramo MQL5, evitando um checker que apenas aceite qualquer texto.

Os fixtures existentes foram repetidos e os corpos reais de matriz/Stage 2 e
POC/Weis de ambas as representações foram adicionalmente compilados em C++ com
os mesmos substitutos determinísticos das APIs de mercado/relógio:

- 12.000 matrizes, 4.096 avaliações Stage 2 e 96 classificações DOM por versão;
  saídas iguais, digest `aa16ed3577bb69ca`.
- 514 casos POC e 128 reconstruções Weis por versão; saídas iguais, digest
  `febf922085385281`.
- A suíte anterior repetiu gestão, BE, parser/journals, corrupção CSV, ARMED,
  microestrutura, causalidade e isolamento observacional. As contagens internas
  e resultados estão no log. São testes no host, não execução de ordens MT5.

Resultados novos, separados dos registros imutáveis da entrega modular:

- [Log completo dos 44 testes](../artifacts/monolitico/tests-complementar.log).
- [Resultado estruturado](../artifacts/monolitico/test-results-complementar.json).
- [Status de compilação nativa das duas versões](../artifacts/monolitico/native-compilation-status.json).
- [Descoberta das ferramentas de compilação](../artifacts/monolitico/compiler-discovery.log).

## Compilação e limitações preservadas

MetaEditor e Wine não foram encontrados no PATH ou nos locais acessíveis
inspecionados. Duas pastas do sistema não eram legíveis; a descoberta não é uma
prova de ausência absoluta de binários em toda a máquina. Não foi identificado
um compilador nativo acessível para executar a compilação solicitada.

| Versão | Compilação MetaEditor | Erros | Avisos | Log de compilador |
|---|---|---|---|---|
| Modular | Não executada | Não medidos | Não medidos | Não existe |
| Monolítica | Não executada | Não medidos | Não medidos | Não existe |

Não foram fabricados logs ou declarado “zero erros/avisos”. O arquivo de status
usa `null` para essas contagens. Os logs g++ dos fixtures não são logs MetaEditor
e não certificam sintaxe/tipos do EA completo.

A transposição não introduziu diferença nos tokens MQL5 ativos. Ainda assim,
possíveis erros de sintaxe, tipos, APIs ou avisos do compilador nativo da fonte
reconstruída continuam não verificados. Diagnósticos MetaEditor futuros podem
ser relacionados ao fonte modular pelo mapa de origem antes de propor uma
correção cirúrgica. Nenhum comportamento financeiro/decisório foi ajustado para
fazer esta verificação passar.

Achado legado preservado: `DOMGateDefer` contém duas verificações consecutivas
iguais com `BookRiskResolveTerms(...,false,...)`. O bloco existe no commit
`323750a`, foi transposto integralmente e não constitui, por si só, um erro de
compilação demonstrado. Não foi removido nesta entrega complementar; eventual
avaliação da redundância exige uma alteração funcional separada e testes próprios.
Os demais riscos e pendências da candidata permanecem os do
[relatório modular original](RELATORIO_TECNICO.md), incluindo o CSV real do WDO
não fornecido e a ausência de comprovação de equivalência com EX5 de produção.

## Arquivos e reprodução

- [Monolítico completo](../scalpertalvez_MONOLITICO.mq5).
- [ZIP exato da modular original 323750a](../artifacts/monolitico/scalpertalvez_MODULAR_323750a.zip).

O ZIP contém exatamente os 49 arquivos do commit original, inclusive os logs
originais dos 36 testes. Não mistura os novos resultados de 44 testes ou o
monolítico. A história Git permanece no repositório e nas branches; o ZIP é um
snapshot de arquivos, não um substituto da história de commits.

SHA-256 do monolítico:
`5366e6ce20188a5bac1e0b27f8d9f0fdb3c4b84b4cb3fb69cf570a428e3e3df2`.

SHA-256 do ZIP modular:
`68b410deb97daa2bbb2e7d87653932124b1e0349864ad4db8263c0a5b0029155`.

Comandos reproduzíveis no checkout desta branch:

```sh
python3 tools/build_monolithic.py --check
python3 tools/verify_monolithic_independent.py --output artifacts/monolitico/independent-equivalence.json
python3 tools/run_monolithic_checks.py
```

Para regenerar apenas os arquivos complementares, use
`python3 tools/build_monolithic.py`. O gerador recusa uma referência modular
alterada. Abra `scalpertalvez_MONOLITICO.mq5` no MetaEditor e use F7 para a
validação nativa; nenhuma implantação ou execução do EA foi automatizada.
