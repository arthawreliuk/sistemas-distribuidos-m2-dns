#!/bin/bash
# E6 — Partição de rede: ns3 desconectado APENAS da rede interna.
# Ao final, ns3 permanece isolado; o E7 (scripts/e7.sh) faz a reconexão.
source "$(dirname "$0")/lib.sh"
mkdir -p evidencias/e6
saida="evidencias/e6/e6-$(date +%Y%m%d-%H%M%S).txt"
exec > >(tee "$saida") 2>&1
REDE=sdm2dns_interna

secao "Estado inicial"
docker network ls --filter name=sdm2dns --format '{{.Name}}'
for s in 11 12 13; do echo "172.31.0.$s serial $(serial_de 172.31.0.$s)"; done
docker exec ns3 ip -4 -o addr show | awk '{print $2, $4}'

secao "Partição: docker network disconnect $REDE ns3"
docker network disconnect "$REDE" ns3
tp=$(agora); echo "desconectado em $tp"
docker exec ns3 ip -4 -o addr show | awk '{print $2, $4}'
echo "ns3 -> ns1 pela rede interna (deve falhar):"
docker exec ns3 dig @172.30.0.11 sd.lab SOA +short +time=2 +tries=1 2>&1 | head -2
echo "cliente -> ns3 pela rede de clientes (deve funcionar):"
docker exec cliente dig @172.31.0.13 sd.lab SOA +short
echo "ns3: $(docker exec ns3 rndc zonestatus sd.lab | grep -E 'serial|expires' | tr '\n' ' ')"

secao "Alteração no primário durante a partição"
serial=$(proximo_serial); novo="10.0.6.$((10#${serial: -2}))"
escreve_zona "$serial" "$novo"
t0=$(recarrega); echo "serial $serial, app $novo, reload em $t0"
sleep 3
for s in 11 12 13; do
  echo "172.31.0.$s: serial $(serial_de 172.31.0.$s), app $(docker exec cliente dig @172.31.0.$s app.sd.lab +short +norecurse)"
done

secao "Observação até o expire (consulta a cada 15 s)"
echo "instante | s desde a partição | ns2 (status serial app) | ns3 (status serial app)"
for i in $(seq 1 26); do
  t=$(agora)
  linha="$(awk -v a="$t" -v b="$tp" 'BEGIN{printf "%.0f", a-b}')"
  out="$t | $linha"
  for s in 12 13; do
    st=$(docker exec cliente dig @172.31.0.$s sd.lab SOA +norecurse +time=2 +tries=1 | sed -n 's/.*status: \([A-Z]*\).*/\1/p')
    sr=$(serial_de 172.31.0.$s); ap=$(docker exec cliente dig @172.31.0.$s app.sd.lab +short +norecurse +time=2 +tries=1)
    out="$out | $st ${sr:--} ${ap:--}"
  done
  echo "$out"
  sleep 15
done

secao "Logs do ns3 durante a partição"
docker logs --since "${tp%.*}" ns3 2>&1 | grep -iE "refresh|retry|expire|notify|transfer|sd.lab" | grep -v "query:" | tail -25

secao "Resolvedor durante a partição (cache vazio, 3 consultas)"
for i in 1 2 3; do
  docker exec resolvedor rndc flush
  docker exec cliente dig @172.31.0.53 app.sd.lab | awk '/status:/{print "status", $6} /^app\.sd\.lab/{print "valor", $5}' | tr '\n' ' '; echo
done
echo; echo "ns3 continua isolado da rede interna. Evidências: $saida"
