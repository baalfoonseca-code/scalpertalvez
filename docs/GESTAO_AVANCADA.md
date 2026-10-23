# Gestão opcional e recuperação

Os 13 inputs deste módulo são acrescentados depois dos 71 históricos. A unidade
`Pts` é ponto de cotação do ativo, não uma multiplicação por `SYMBOL_POINT`.

| Input | Default | Uso |
|---|---|---|
| `Inp_SL_Mode` | `SL_ORIGINAL_PONTOS` | SL histórico por ativo; alternativa `SL_SIGMA_COM_TETO` |
| `Inp_Mult_SL` | `1.0` | Multiplicador do SigmaD1 congelado na tentativa final de entrada |
| `Inp_Max_SL_Pts_WIN` | `150.0` | Teto do SL sigma para WIN/IND |
| `Inp_Max_SL_Pts_WDO` | `5.0` | Teto do SL sigma para WDO/DOL |
| `BE_Trigger_R` | `1.0` | Gatilho do BE em R inicial confirmado; respeita `Inp_EnableBreakEven` histórico |
| `EnableProfitLocks` | `false` | Ativa a escada de locks |
| `Lock1_Trigger_R` | `2.0` | Gatilho do primeiro degrau |
| `Lock1_Protected_R` | `1.0` | Preço de proteção pretendido do primeiro degrau |
| `Lock2_Trigger_R` | `3.0` | Gatilho do segundo degrau |
| `Lock2_Protected_R` | `2.0` | Preço de proteção pretendido do segundo degrau |
| `Inp_TP_Mode` | `TP_MODE_ORIGINAL` | TP histórico por ativo; alternativa `TP_MODE_BY_ROUTE_R` |
| `TP_BASE_R` | `5.0` | Exemplo experimental inativo no modo original, ABS/CONT BASE |
| `TP_TURBO_R` | `6.0` | Exemplo experimental inativo no modo original, ABS/CONT TURBO |

Os valores 2/1, 3/2 e 5/6 não são parâmetros homologados. A validação rejeita
valores não finitos/inválidos. A ordem dos gatilhos/proteções é exigida quando a
escada está ativa; um BE isolado de 3R é permitido com locks desligados. Um TP
abaixo dos degraus gera aviso, sem alteração automática do preset.

## Referência e envio

O SL sigma calcula `min(SigmaD1 * multiplicador, teto)` e arredonda a grade para
dentro dessa distância. Rejeita distância não positiva/subtick, referência
inválida e restrições de negociação; não expande silenciosamente o teto para
satisfazer stops level. A referência de sigma da tentativa é congelada antes do
envio e persistida antes da barreira de despacho. SigmaD1 de VWAP/C5 não muda.
As revalidações do book utilizam os mesmos termos financeiros opcionais.
Sizing, teto de lotes e margem usam o SL efetivamente solicitado e os controles
originais. Stop menor pode resultar em mais contratos no sizing percentual.

O SL/TP inicial acompanha a ordem. Depois de completo o preenchimento comprovado,
`R_INITIAL = abs(entrada média confirmada - SL inicial comprovado na ordem)`.
A referência não usa o SL já movido. Preenchimentos parciais aguardam a resolução
da ordem antes de congelar a média final. Slippage pode ampliar a distância e o
risco efetivo mesmo com teto no pedido: o diagnóstico
`SL_EFFECTIVE_CAP_EXCEEDED` torna isso explícito e não afasta o SL existente.
`OrderCalcProfit` estima o risco; custos conhecidos são informados separadamente.
Gaps, slippage e custos futuros impedem tratá-lo como perda máxima garantida.

TP por rota é inicialmente protegido no pedido e recalibrado a partir da entrada
confirmada/R inicial, preservando o SL atual. A requisição posterior é registrada
e reconciliada, sem enviar outra entrada. Desligar o modo TP por rota suspende
novas recalibrações; as confirmações pendentes continuam a ser processadas. O
multiplicador escolhido na entrada permanece registrado por operação.

## Confirmação, persistência e conflitos

Os journals novos começam por `BOOK_RISK1_` e usam `SCALPER_RISK1`, checksum e
marcador de conclusão. Ficam fora do prefixo que a certificação financeira antiga
enumera; `SCALPER_BE1`, metadados, receipts, request journals e schema de Trades
permanecem legíveis e com seu significado original. Não existe migração destrutiva.
A leitura exige bytes completos, tamanho estável, fechamento sem erro e registros
válidos até o fim. Uma cauda truncada não autoriza voltar a um estado anterior.

A barreira persistida antecede `PositionModify`. Retorno booleano/aceitação não
confirma proteção: exige resultado correlacionado e SL/TP observado no servidor,
ou comprovação histórica correspondente na saída. SL externo mais protetor é
preservado. Cada instante permite uma solicitação nova somente após resolução da
anterior. O maior lock elegível pode ser escolhido, sem trailing contínuo.

No-op ticks e recalibrações posteriores de TP não apagam a evidência de um lock:
a certificação é buscada no histórico append-only. Saída por lock nunca é
reclassificada como BE neutro. O resultado líquido e a contabilização original
continuam baseados nos deals, sem prometer lucro líquido pelo preço do stop.

Estados pendentes/incertos são recuperados e impedem BE conflitante. O EOD
original continua disponível sem depender do book; novos pedidos de proteção
param no horário EOD e respeitam intenção de saída pendente. Se um crash ocorrer
após a barreira e antes de persistir o ID/resultado, a gestão opcional permanece
suspensa para reconciliação externa; não inventa sucesso nem repete cegamente.
Não apague journals para contornar essa suspensão.

Posição preexistente sem referência verificável não recebe sigma/R inventado:
locks/TP opcionais ficam suspensos e as proteções existentes/gestão legada são
preservadas. O cache limitado reutiliza apenas posições encerradas duráveis ou
sem journal que já não estejam rastreadas, mantendo os arquivos. Journals acima
de 1 MiB são recusados conservadoramente. Falhas reais de disco, corretora,
reinício de terminal e transações assíncronas ainda exigem validação nativa.
