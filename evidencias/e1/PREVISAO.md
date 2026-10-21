# E1 — Subida e topologia: previsão (registrada antes da execução)

Data: 21/10/2026.

1. `docker compose up -d` cria 5 contêineres (ns1, ns2, ns3, resolvedor, cliente)
   e duas redes (`sdm2dns_interna` 172.30.0.0/24 e `sdm2dns_clientes` 172.31.0.0/24).
2. O ns1 carrega a zona `sd.lab` do arquivo com serial 2026101401.
3. ns2 e ns3, que começam sem cópia da zona, recebem do ns1 uma transferência
   **completa (AXFR)**, porque não têm versão anterior para pedir um incremento.
   Nos logs deve aparecer "transfer of 'sd.lab/IN' from 172.30.0.11#53" e
   "Transfer completed", com origem no endereço **interno** do ns1.
4. A consulta SOA direta aos três autoritativos (pela rede de clientes) devolve o
   mesmo serial 2026101401, com flag `aa`.
5. O resolvedor responde `app.sd.lab` = 10.0.0.1 com flag `ra` e sem `aa`.
6. `rndc status` funciona nos servidores (canal de controle com a chave da imagem).

Justificativa: é o comportamento de primário/secundário descrito na RFC 1034/1035
(transferência de zona) e no roteiro (seção 5.3, E1).
