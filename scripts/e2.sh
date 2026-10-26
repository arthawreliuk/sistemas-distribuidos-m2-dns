#!/bin/bash
# E2 — Caminho de uma leitura e de uma escrita.
source "$(dirname "$0")/lib.sh"
saida="evidencias/e2/e2-$(date +%Y%m%d-%H%M%S).txt"
exec > >(tee "$saida") 2>&1

secao "Estado inicial (SOA nos três autoritativos)"
for s in 11 12 13; do echo "172.31.0.$s -> $(serial_de 172.31.0.$s)"; done

secao "Ativa o log de consultas e esvazia o cache do resolvedor"
for c in resolvedor ns1 ns2 ns3; do docker exec $c rndc querylog on; done
docker exec resolvedor rndc flush
marca=$(agora_s)
sleep 1

secao "Leitura 1: cliente -> resolvedor (cache vazio)"
docker exec cliente dig @172.31.0.53 app.sd.lab A | grep -E "^;; flags|^app\.sd\.lab|^;; SERVER"
sleep 2
secao "Leitura 2: cliente -> resolvedor (dois segundos depois)"
docker exec cliente dig @172.31.0.53 app.sd.lab A | grep -E "^;; flags|^app\.sd\.lab|^;; SERVER"
secao "Leitura direta no primário, sem recursão"
docker exec cliente dig @172.31.0.11 app.sd.lab A +norecurse | grep -E "^;; flags|^app\.sd\.lab|^;; SERVER"
sleep 1

secao "Log de consultas de cada servidor (desde o instante $marca)"
for c in resolvedor ns1 ns2 ns3; do
  echo "--- $c"
  docker logs --since "$marca" $c 2>&1 | grep "query: app.sd.lab" || echo "(nenhuma consulta a app.sd.lab)"
done

secao "Escrita: nova versão da zona no primário"
serial=$(proximo_serial)
escreve_zona "$serial" 10.0.0.3
echo "novo serial: $serial  app -> 10.0.0.3"
marca=$(agora_s)
t0=$(recarrega); echo "rndc reload em $t0"
sleep 3

secao "Logs do primário (ns1)"
docker logs --since "$marca" ns1 2>&1 | grep -iE "loaded serial|notif|transfer|IXFR|AXFR"
for c in ns2 ns3; do
  secao "Logs do secundário $c"
  docker logs --since "$marca" $c 2>&1 | grep -iE "notify|transfer|IXFR|AXFR|serial"
done

secao "Depois da escrita"
for s in 11 12 13; do printf '172.31.0.%s -> ' $s; docker exec cliente dig @172.31.0.$s app.sd.lab +short +norecurse; done
printf 'resolvedor 172.31.0.53 -> '; docker exec cliente dig @172.31.0.53 app.sd.lab | grep -E "^app\.sd\.lab"

for c in resolvedor ns1 ns2 ns3; do docker exec $c rndc querylog off; done
echo; echo "Evidências gravadas em $saida"
