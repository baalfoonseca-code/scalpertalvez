# Compatibilidade verificada no host

Os testes de `tests/test_compatibility.py` usam como referência o arquivo
`scalpertalvez`, SHA-256
`c6e601429bea933ea937a3e985a2031a89b08bc42b199215dc5e8adfec2dd2a9`.
Eles verificam os 71 inputs históricos por tipo, nome, ordem e expressão de
default; a referência original deve permanecer byte a byte intacta.

O teste estático compara os corpos das funções protegidas de matriz, macro,
POC, Weis, contradição, book, sizing e Stage 2, além dos schemas legados de
BE, requests, obrigações de ordens, metadados e Trades CSV. Apenas chamadas
`void BookDiag*` independentes podem ser retiradas na comparação. O nome do
wrapper `BookMeasuredPOC` é normalizado para a chamada original. Isso não
autoriza alterações em predicados ou consumo de resultados observacionais.

Os fixtures C++ extraem os corpos reais das funções da fonte em cada execução;
não substituem as fórmulas por uma implementação de teste. As adaptações são
aliases de tipos, vetores para arrays dinâmicos MQL e APIs de mercado com dados
determinísticos. Original e candidata recebem a mesma sequência controlada.

Cobertura dos fixtures:

- 12.000 snapshots M1/M3 de WIN/WDO, com C1–C5, ABS/CONT, BASE/TURBO,
  classificações de POC, macro, empates, glass e contradição. A sequência exercita
  2 conflitos simultâneos ABS/CONT; não equivale a testar despacho de ordens.
- 4.096 avaliações Stage 2 com relógio controlado: timeout, fim de sessão,
  flags de negócio, dados ausentes, breakout, overshoot, direção/esforço vivo,
  VWAP, glass, spread, posição/cota/risco e request em andamento.
- 96 classificações DOM incluindo borda de 55%, profundidade insuficiente,
  volumes de ambos os lados, 100% e limiares inválidos.
- 514 casos POC a partir de ticks controlados, incluindo empate canônico no
  menor preço e janela vazia.
- 128 reconstruções Weis a partir de barras controladas, 64 com fallback de
  volume real indisponível para tick volume, além da avaliação da onda viva.
- Parser MQL efetivo: 12 casos de CSV com aspas, aspas duplicadas, CR/LF
  dentro de campo, campos vazios, corrupção; 9 casos de ID incluindo
  `ulong` máximo e overflow; falha de alocação injetada e oito combinações da política de criação
  de arquivo financeiro ausente.

Os hashes de saída são comparados entre original e candidata dentro da mesma
execução. Contagens são verificadas, evitando tratar uma execução sem casos
como validação.

## Limites explícitos

Esses fixtures não compilam o EA completo e não substituem MetaEditor. As APIs
de mercado, arquivo, transação, servidor e conta não são as do MT5. Em particular,
não provam equivalência de execução, latência, EOD, reconciliação financeira,
restart real ou comportamento do broker. Persistência e filas dos módulos novos
precisam também dos testes específicos e da validação nativa documentada.

Não foram encontradas, nesta inspeção e nesses recortes, evidências suficientes
para afirmar compilação nativa ou equivalência ao executável de produção. Os
cabeçalhos históricos citam múltiplas reconstruções e versões; nomes e contagem
de inputs não constituem prova de equivalência.

Execute:

```sh
python3 -m unittest discover -s tests -v
```

Os testes requerem `g++`; a ausência do compilador é registrada como teste
não executado, nunca como aprovação do fixture.
