# E1 — Subida e topologia: resultado

Execução: 21/10/2026, 19:34:54 (horário de Brasília) — `scripts/e1.sh`.
Saída completa: [`e1-20261021-193454.txt`](e1-20261021-193454.txt). Previsão: [`PREVISAO.md`](PREVISAO.md).
Diagrama: [`../../diagramas/topologia.svg`](../../diagramas/topologia.svg).

## Objetivo
Comprovar que o cluster está no ar com ≥ 3 servidores autoritativos e identificar o papel e o endereço de cada nó (roteiro, seção 4.2 e 5.3/E1).

## Ambiente
MacBook Air M3 (arm64), 16 GB RAM, macOS 26.4.1; Docker Desktop 29.4.3, Compose v5.1.3
(8 CPUs e ~7,75 GiB destinados à VM do Docker Desktop). Imagem `sd-bind` (39,1 MB): Alpine 3.20.10 + BIND 9.18.49 ESV.
Estado inicial: nenhum contêiner nem rede do projeto existia; secundários sem cópia da zona.

## Observado (logs, horários UTC do contêiner)

| Instante | Evento |
|---|---|
| 22:34:55.401 | ns1 carrega `sd.lab` serial 2026101401 e envia NOTIFY |
| 22:34:55.411 | ns2 recebe NOTIFY de 172.30.0.11 e inicia transferência |
| 22:34:55.412–.414 | ns2: **AXFR** de 172.30.0.11#53, 9 registros, 224 bytes |
| 22:34:55.892 | ns3: **AXFR** de 172.30.0.11#53, 9 registros, 224 bytes |
| 22:34:55.901 | ns3 recebe NOTIFY depois da transferência: "zone is up to date" |

O lado do primário confirma as duas transferências e a origem pela **rede interna**
(`172.30.0.12#44321` e `172.30.0.13#41145`, "AXFR started/ended").

SOA consultado diretamente em cada autoritativo pela rede de clientes:

```
172.31.0.11 -> ns1.sd.lab. admin.sd.lab. 2026101401 30 10 300 20
172.31.0.12 -> ns1.sd.lab. admin.sd.lab. 2026101401 30 10 300 20
172.31.0.13 -> ns1.sd.lab. admin.sd.lab. 2026101401 30 10 300 20
```

Os três respondem com flags `qr aa` (resposta autoritativa). Pelo resolvedor, `app.sd.lab`
volta `10.0.0.1` com `qr rd ra` e sem `aa`. `rndc status` e `rndc zonestatus` funcionam nos quatro
servidores: ns1 `type: primary`, ns2/ns3 `type: secondary` com `expires` = transferência + 300 s
(22:39:55) e próximo refresh dentro de ~30 s. Memória: ~26 MiB por servidor BIND, ~0,6 MiB no cliente
(≈ 104 MiB no total; o roteiro cita ≈ 100 MB).

## Previsão x resultado

| # | Previsão | Resultado |
|---|---|---|
| 1 | 5 contêineres, 2 redes | Confirmado (endereços conforme a tabela da seção 5.2) |
| 2 | ns1 carrega serial 2026101401 | Confirmado |
| 3 | Secundários recebem **AXFR** pela rede interna | Confirmado nos logs dos dois lados |
| 4 | Mesmo serial nos 3, com `aa` | Confirmado |
| 5 | Resolvedor com `ra`, sem `aa` | Confirmado |
| 6 | `rndc` funcional | Confirmado |

Detalhe não previsto: o ns2 transferiu **disparado pelo NOTIFY**; o ns3 transferiu ~0,5 s depois
**sem esperar o NOTIFY**, por sua própria verificação inicial (o NOTIFY chegou depois e foi
descartado como "zone is up to date"). Não foi investigado por que a verificação do ns3 levou
~0,5 s; a hipótese mais provável é o atraso aleatório que o BIND aplica à verificação inicial de
zonas secundárias. Os dois caminhos (NOTIFY e consulta periódica do secundário) serão separados no E3.

## Análise
- **Papéis**: há um coordenador fixo, escolhido pela configuração (ns1 `type primary`), e duas réplicas
  somente leitura (`type secondary`). Os três atendem leituras com autoridade (`aa`); só o ns1 aceita escritas.
  É replicação primário-backup *pull*: o secundário busca a zona (AXFR/IXFR), e o NOTIFY só avisa que existe
  versão nova (RFC 1996).
- **Primeira sincronização é sempre completa (AXFR)**: o secundário não tem versão anterior a partir da qual
  pedir um IXFR (RFC 1995).
- **O serial do SOA é o identificador de versão** que permite verificar a convergência: o mesmo serial nos três
  significa a mesma versão da zona.
- **Isolamento do tráfego**: toda a replicação usou 172.30.0.0/24, como exige o E6.

## Adaptações em relação aos trechos do roteiro (justificadas)
1. `rndc-confgen -a` no Dockerfile: sem `rndc.key`, `rndc reload` (usado no roteiro) falha.
2. `notify explicit` no ns1 (o PDF usa `notify yes`): evita NOTIFY pela rede de clientes,
   mantendo a replicação só na rede interna.
3. `notify no` nos secundários: eles não reenviam NOTIFY entre si.
4. Nome de projeto fixo `sdm2dns`: as redes chamam `sdm2dns_interna`/`sdm2dns_clientes`, independentemente da pasta.
5. `cliente` também recebe `build:` (via âncora), para o Compose não tentar baixar `sd-bind` de um registro.

## Limitações
Contêineres no mesmo host (dentro da VM do Docker Desktop): não há falhas físicas independentes nem
latência real de rede; os relógios dos contêineres são o mesmo relógio. Os horários em milissegundos
vêm do mesmo kernel e por isso são comparáveis entre contêineres.

## Conclusão
E1 concluído: 3 autoritativos (1 primário + 2 secundários), resolvedor e cliente em operação, com
serial idêntico e réplicas sincronizadas por AXFR pela rede interna. Evidências e diagrama registrados.
