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
