# Trabalho M2 — Sistemas Distribuídos (UNIVALI, 2026/2)

**Tema T1 — Sistema de nomes distribuído (DNS)** · **Ênfase D — Descoberta de serviços (cloud native)**

Laboratório local com BIND 9 em contêineres leves (Docker Compose), seguindo a seção 5.2 do
roteiro do Prof. Ramices dos Santos Silva. A ênfase D (E9, CoreDNS) será adicionada depois dos
experimentos E1–E8.

## Requisitos
- Docker com Compose v2+ (testado: Docker Desktop 29.4.3 / Compose v5.1.3, macOS 26.4.1, Apple M3).
- Git. Nenhuma outra dependência no host: `dig` e `rndc` rodam dentro dos contêineres.
- Sub-redes `172.30.0.0/24` e `172.31.0.0/24` livres (`docker network ls`).
- Nomes de contêiner `ns1`, `ns2`, `ns3`, `resolvedor`, `cliente` livres.

## Topologia

| Nó | Papel | Rede interna (172.30.0.0/24) | Rede de clientes (172.31.0.0/24) |
|---|---|---|---|
| ns1 | primário autoritativo (`sd.lab`) | 172.30.0.11 | 172.31.0.11 |
| ns2 | secundário autoritativo | 172.30.0.12 | 172.31.0.12 |
| ns3 | secundário autoritativo | 172.30.0.13 | 172.31.0.13 |
| resolvedor | recursivo com cache (forward para os 3) | — | 172.31.0.53 |
| cliente | executa `dig` e scripts | — | 172.31.0.100 |

A replicação (NOTIFY, AXFR/IXFR) passa só pela rede interna; as consultas, pela rede de clientes.
Diagrama: [`diagramas/topologia.svg`](diagramas/topologia.svg).

## Como executar

```bash
docker compose build          # imagem sd-bind: alpine:3.20 + bind 9.18
./scripts/e1.sh               # sobe o ambiente e grava evidências em evidencias/e1/
```

Consultas manuais (sempre com `@IP` explícito, para não usar o DNS interno do Docker 127.0.0.11):

```bash
docker exec cliente dig @172.31.0.11 sd.lab SOA +short     # direto no primário
docker exec cliente dig @172.31.0.53 app.sd.lab            # via resolvedor (cache)
docker exec ns1 rndc reload sd.lab                         # após editar zonas/db.sd.lab e incrementar o serial
```

Encerrar:

```bash
docker compose stop    # para os contêineres; os secundários mantêm a cópia da zona
docker compose down    # remove contêineres e redes do projeto; secundários recomeçam sem zona
```

`docker compose down` afeta apenas o projeto `sdm2dns`. Não use `docker system prune`.

## Estrutura
```
Dockerfile, docker-compose.yml   ambiente
ns1/ ns2/ ns3/ resolvedor/       named.conf de cada servidor
zonas/db.sd.lab                  zona do primário (montada em ns1:/var/lib/bind)
scripts/                         um script por experimento
evidencias/eN/                   PREVISAO.md (antes), saídas brutas, RESULTADO.md (depois)
diagramas/                       diagramas próprios
```

## Situação dos experimentos

| Exp. | Situação |
|---|---|
| E1 Subida e topologia | **Executado** em 21/10/2026: [`evidencias/e1/RESULTADO.md`](evidencias/e1/RESULTADO.md) |
| E2–E8 | Não executados |
| E9 (ênfase D, CoreDNS) | Não executado |

## Adaptações em relação ao roteiro
Estão documentadas e justificadas em [`evidencias/e1/RESULTADO.md`](evidencias/e1/RESULTADO.md#adaptações-em-relação-aos-trechos-do-roteiro-justificadas).
Resumo: chave `rndc` gerada na imagem, `notify explicit` no primário, `notify no` nos secundários e nome de projeto fixo.
