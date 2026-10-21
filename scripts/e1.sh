#!/bin/bash
# E1 — Subida e topologia. Sobe o laboratório e grava as evidências em
# evidencias/e1/e1-<data-hora>.txt. Não apaga nada: se o ambiente já estiver
# no ar, apenas confere o estado atual.
set -u
cd "$(dirname "$0")/.."

saida="evidencias/e1/e1-$(date +%Y%m%d-%H%M%S).txt"
exec > >(tee "$saida") 2>&1

secao() { printf '\n===== %s =====\n' "$1"; }

secao "Data/hora do host"; date
secao "Versões"
docker --version; docker compose version
docker exec ns1 named -V 2>/dev/null | head -1 || true

secao "docker compose up -d"
docker compose up -d
echo "aguardando 5 s para as transferências iniciais..."; sleep 5

secao "docker compose ps"
docker compose ps --format 'table {{.Name}}\t{{.Service}}\t{{.Status}}'

secao "Redes e endereços"
for r in sdm2dns_interna sdm2dns_clientes; do
  docker network inspect "$r" --format \
    '{{.Name}} {{range .IPAM.Config}}{{.Subnet}}{{end}}{{range .Containers}}
  {{.Name}} {{.IPv4Address}}{{end}}'
done

secao "Logs do ns1 (carga da zona / NOTIFY)"
docker compose logs --no-color ns1 | grep -iE "zone sd.lab|notify|transfer|loaded serial|running"

for s in ns2 ns3; do
  secao "Logs de transferência do $s"
  docker compose logs --no-color "$s" | grep -iE "transfer|sd.lab"
done

secao "SOA nos três autoritativos (consulta direta, rede de clientes)"
for s in 11 12 13; do
  printf '172.31.0.%s -> ' "$s"
  docker exec cliente dig @172.31.0.$s sd.lab SOA +short
done

secao "Flags da resposta SOA de cada autoritativo (+norecurse)"
for s in 11 12 13; do
  printf '172.31.0.%s -> ' "$s"
  docker exec cliente dig @172.31.0.$s sd.lab SOA +norecurse | grep -E "^;; flags"
done

secao "app.sd.lab: autoritativo direto x resolvedor"
docker exec cliente dig @172.31.0.11 app.sd.lab A +norecurse | grep -E "^;; flags|^app\.sd\.lab|^;; SERVER"
docker exec cliente dig @172.31.0.53 app.sd.lab A | grep -E "^;; flags|^app\.sd\.lab|^;; SERVER"

secao "rndc status (canal de controle)"
for c in ns1 ns2 ns3 resolvedor; do
  echo "--- $c"; docker exec "$c" rndc status | grep -E "version|zones|server is up"
done

secao "rndc zonestatus sd.lab nos autoritativos"
for c in ns1 ns2 ns3; do
  echo "--- $c"; docker exec "$c" rndc zonestatus sd.lab | grep -E "type|serial|files|next refresh|expires"
done

secao "Uso de memória"
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}' ns1 ns2 ns3 resolvedor cliente

echo; echo "Evidências gravadas em $saida"
