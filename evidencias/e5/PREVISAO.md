# E5 — Falha e quórum: previsão (registrada antes da execução)

| Nós ativos | Leitura | Escrita |
|---|---|---|
| ns1, ns2, ns3 | sim, nos três e pelo resolvedor | sim, editando a zona no ns1 |
| ns2, ns3 (ns1 parado) | sim, nos dois secundários e pelo resolvedor | não: só o primário publica versões; os secundários recusam atualização (REFUSED) |
| ns3 (ns1 e ns2 parados) | sim, só no ns3; o resolvedor ainda responde, talvez mais devagar, porque tenta os encaminhadores parados antes | não |

Leituras continuam porque qualquer autoritativo com uma cópia válida da zona responde sozinho, sem
consultar os outros (R = 1). A escrita depende de um único nó, o primário (W = 1, sempre o mesmo nó).
Não há quórum: não existe maioria a formar, nem para ler nem para escrever. R + W = 2 não é maior que
N = 3, e mesmo assim a leitura não volta "errada" enquanto ninguém escreve; quando há escrita, a
leitura pode devolver uma versão antiga até a réplica sincronizar (consistência eventual, E3/E4).
Os secundários continuam respondendo sem o primário até o expire (300 s) — isso aparece no E6.
