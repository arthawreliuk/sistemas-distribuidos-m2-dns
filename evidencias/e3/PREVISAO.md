# E3 — Replicação primário -> secundários: previsão (registrada antes da execução)

Procedimento: a cada repetição, uma nova versão da zona (serial incrementado, `app` com valor novo) é
publicada no ns1 com `rndc reload`; dentro do contêiner cliente, uma sonda consulta ns2 e ns3 a cada
100 ms (sem recursão) e registra o instante em que cada um responde o valor novo. O atraso é a diferença
entre esse instante e o instante do `rndc reload`, ambos no mesmo relógio (VM do Docker).
Cinco repetições com NOTIFY e cinco sem NOTIFY.

Com NOTIFY: o ns1 avisa os secundários logo após carregar a zona; eles pedem a transferência na hora.
Esperamos atrasos abaixo de 1 s (o roteiro relata menos de 1 s no teste do kit), limitados pela
resolução da sonda (cerca de 0,1 s). No E2 o NOTIFY ao ns3 chegou cerca de 0,5 s depois do NOTIFY ao
ns2, então o ns3 deve ter atraso maior.

Sem NOTIFY: o secundário só descobre a versão nova quando o seu temporizador de refresh (30 s) vence e
ele consulta o SOA do primário. Como o momento da alteração não tem relação com esse temporizador,
esperamos atrasos entre 0 e 30 s, variando bastante entre repetições e entre ns2 e ns3, com média
próxima da metade do refresh.
