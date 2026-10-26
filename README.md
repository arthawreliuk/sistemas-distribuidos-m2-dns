# Trabalho M2 — Sistemas Distribuídos (UNIVALI, 2026/2)

**Tema T1 — Sistema de nomes distribuído (DNS)** · **Ênfase D — Descoberta de serviços (cloud native)**

Laboratório local com BIND 9 em contêineres leves (Docker Compose), seguindo a seção 5.2 do
roteiro do Prof. Ramices dos Santos Silva, e CoreDNS para a ênfase D (E9).

Repositório: https://github.com/arthawreliuk/sistemas-distribuidos-m2-dns

Entregáveis:
- Relatório: [`relatorio/relatorio.pdf`](relatorio/relatorio.pdf) (montado de `relatorio/partes/` por `relatorio/montar.py`).
- Evidências em imagem: [`docs/evidencias/`](docs/evidencias/) (versões curtas para os slides em `docs/evidencias/slides/`),
  geradas por `scripts/gerar_prints.py` a partir das saídas gravadas em `evidencias/`.
- Demonstração ao vivo do seminário: `./scripts/demo.sh`.

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
docker compose build            # imagem sd-bind: alpine:3.20 + bind 9.18 + coreutils
./scripts/e1.sh                 # sobe o laboratório e grava evidências em evidencias/e1/
./scripts/e2.sh                 # caminho de leitura e de escrita
./scripts/e3.sh 5 8             # propagação com e sem NOTIFY (5 repetições, 8 s entre elas)
./scripts/e4.sh 5               # cache, TTL e cache negativo
./scripts/e5.sh                 # falha de 1 e 2 servidores
./scripts/e6.sh                 # partição do ns3 (rede interna) até o expire; deixa o ns3 isolado
./scripts/e7.sh 5 20            # reconexão do ns3 e 5 partições curtas de 20 s
./scripts/e8.sh                 # publicação com serial menor
docker compose --profile e9 up -d   # CoreDNS + instâncias api1..api3
./scripts/e9.sh 5 60            # descoberta de serviços: TTL 5 s x 60 s
./scripts/demo.sh               # demonstração ao vivo do seminário (avança com ENTER)
```

Cada script grava a saída completa em `evidencias/eN/` e as medições em `resultados/*.csv`.
A previsão de cada experimento está em `evidencias/eN/PREVISAO.md` (commitada antes da execução).
Os scripts usam apenas `docker` e `python3` (biblioteca padrão) no host.

Consultas manuais (sempre com `@IP` explícito, para não usar o DNS interno do Docker 127.0.0.11):

```bash
docker exec cliente dig @172.31.0.11 sd.lab SOA +short     # direto no primário
docker exec cliente dig @172.31.0.53 app.sd.lab            # via resolvedor (cache)
```

Para alterar a zona manualmente, use as funções de `scripts/lib.sh` (`escreve_zona`, `recarrega`):
elas gravam o arquivo de dentro do ns1, incrementam o serial e conferem se o primário carregou a versão.

Encerrar:

```bash
docker compose --profile e9 stop    # para os contêineres; os secundários mantêm a cópia da zona
docker compose --profile e9 down    # remove contêineres e redes do projeto (use -v para o volume do E9)
```

`docker compose down` afeta apenas o projeto `sdm2dns`. Não use `docker system prune`.

## Estrutura
```
Dockerfile, docker-compose.yml   ambiente
ns1/ ns2/ ns3/ resolvedor/       named.conf de cada servidor (ns1/named-semnotify.conf: E3)
coredns/Corefile                 CoreDNS do E9
zonas/db.sd.lab                  zona do primário (montada em ns1:/var/lib/bind)
scripts/                         um script por experimento
evidencias/eN/                   PREVISAO.md (antes da execução) e saídas brutas
diagramas/                       diagramas próprios
docs/evidencias/                 prints das saídas dos experimentos
resultados/                      medições brutas (CSV)
relatorio/                       relatório (partes HTML -> relatorio.pdf)
```

## Situação dos experimentos

Todos executados em 21/10/2026 (E1) e 26/10/2026 (E2 a E9); análise no relatório.

## Adaptações em relação ao roteiro
Chave `rndc` gerada na imagem; `notify explicit` no primário (NOTIFY só pela rede interna); `notify no`
nos secundários; nome de projeto fixo (`sdm2dns`); zona gravada de dentro do ns1 com conferência do serial após
cada `rndc reload`; `coreutils` para medir tempo com frações de segundo. Detalhes no relatório, seção 4.
