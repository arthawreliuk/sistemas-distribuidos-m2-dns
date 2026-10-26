# E7 — Recuperação: previsão (registrada antes da execução)

Ao reconectar o ns3 à rede interna (mesmo IP 172.30.0.13):
1. Após o expire (continuação do E6): o ns3 não tem zona válida; na próxima tentativa (retry de
   10 s) consulta o SOA do primário e faz uma transferência completa (AXFR). Tempo até igualar o
   serial: até cerca de 10 s.
2. Partições curtas (20 s, zona ainda válida): o ns3 está com serial menor; na próxima tentativa de
   refresh/retry consulta o SOA, vê serial maior e pede IXFR; como o primário não guarda histórico
   de diferenças, recebe a zona inteira (como no E2). Tempo esperado: entre 0 e 10 s (retry),
   variando conforme o momento da reconexão em relação ao temporizador.
3. Estado final: os três autoritativos com o mesmo serial e o mesmo valor.
A recuperação não reaplica um log de operações: o secundário copia o estado atual (snapshot) da zona.

## Revisão da previsão (26/10/2026, antes da nova execução)

A primeira execução (evidencias/e7/e7-20261026-152352-limite-60s-interrompido.txt) contrariou o item 1:
após reconectar o ns3, o BIND registrou "refresh: skipping zone transfer as primary 172.30.0.11#53 is
unreachable (cached)" e não tentou o refresh por vários minutos. O secundário guarda o primário como
inalcançável depois das falhas da partição. Nova previsão:
- Cenário A (só reconexão, partição de 40 s): a recuperação demora até esse registro de "inalcançável"
  vencer, da ordem de minutos (não de segundos), com variação entre repetições.
- Cenário B (reconexão seguida de nova versão no primário): o NOTIFY vindo do primário faz o ns3
  consultar o SOA na hora e transferir; recuperação em cerca de 1 a 3 s após a reconexão.
- Nos dois casos a transferência é completa (IXFR com fallback para AXFR), como no E2.
