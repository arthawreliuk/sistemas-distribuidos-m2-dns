# E4 — Consistência: cache, TTL e janela de inconsistência — previsão (antes da execução)

A. Consultas repetidas ao resolvedor mostram o TTL de `app.sd.lab` diminuindo a partir de 60 s:
   a resposta vem do cache, sem nova consulta aos autoritativos.

B. Com o cache preenchido, uma alteração em `app` publicada no primário chega aos três autoritativos
   em menos de 1 s (E3). O resolvedor, porém, continua devolvendo o valor antigo até o TTL do registro
   em cache vencer. A janela de leitura desatualizada para o cliente deve ser aproximadamente igual ao
   TTL restante no momento da alteração (cache preenchido há 10, 20, 30, 40 e 50 s → janelas de
   aproximadamente 50, 40, 30, 20 e 10 s). Janela máxima teórica: TTL (60 s) + atraso de replicação
   (cerca de 0,6 s, medido no E3).

C. Consultar um nome inexistente gera NXDOMAIN, que o resolvedor guarda em cache pelo TTL negativo
   do SOA (20 s). Criado o nome no primário logo em seguida, o resolvedor continua respondendo NXDOMAIN
   por até 20 s.

Esta é a consistência eventual: os autoritativos convergem rápido entre si (replicação), mas o
cliente que passa pelo resolvedor só vê a mudança quando o cache expira.
