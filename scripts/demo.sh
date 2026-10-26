#!/bin/bash
# Demonstração ao vivo para o seminário (cerca de 4 minutos).
# Pré-requisito: laboratório no ar (docker compose up -d). Avança com ENTER.
source "$(dirname "$0")/lib.sh"
pausa() { printf '\n[ENTER] '; read -r _; }
soa() {
  local s r
  for s in 11 12 13; do
    r=$(docker exec cliente dig @172.31.0.$s sd.lab SOA +short +time=1 +tries=1 2>/dev/null | awk '$3 ~ /^[0-9]+$/ {print $3}')
    if [ -n "$r" ]; then echo "  172.31.0.$s  serial $r"; else echo "  172.31.0.$s  sem resposta"; fi
  done
}

secao "Topologia: contêineres em execução e serial em cada autoritativo"
docker compose ps --format '  {{.Name}}\t{{.Status}}'
soa; pausa

secao "E2 — Leitura: pelo resolvedor (ra) e direto no autoritativo (aa)"
docker exec resolvedor rndc flush
docker exec cliente dig @172.31.0.53 app.sd.lab | grep -E '^;; flags|^app'
sleep 2
docker exec cliente dig @172.31.0.53 app.sd.lab | grep -E '^;; flags|^app'
docker exec cliente dig @172.31.0.11 app.sd.lab +norecurse | grep -E '^;; flags|^app'; pausa

secao "E2/E3 — Escrita no primário e propagação com NOTIFY"
serial=$(proximo_serial); novo="10.0.9.$((10#${serial: -2}))"
escreve_zona "$serial" "$novo"
docker exec cliente sh /scripts/sonda.sh "$novo" 30 172.31.0.12 172.31.0.13 > /tmp/demo_$$ &
sleep 0.3; t0=$(recarrega)
wait
echo "  app -> $novo, serial $serial"
while read -r ip t; do awk -v a="$t" -v b="$t0" -v ip="$ip" 'BEGIN{printf "  %s respondeu o valor novo após %.2f s\n", ip, a-b}'; done < /tmp/demo_$$
rm -f /tmp/demo_$$
echo "  resolvedor (cache): $(docker exec cliente dig @172.31.0.53 app.sd.lab +short)"; pausa

secao "E5 — Primário parado: leitura continua, escrita não"
docker stop ns1 >/dev/null; echo "  docker stop ns1"
soa
printf 'server 172.31.0.12\nzone sd.lab\nupdate add x.sd.lab 60 A 10.9.9.9\nsend\n' | docker exec -i cliente nsupdate -t 3 2>&1 | sed 's/^/  nsupdate no ns2: /'
docker start ns1 >/dev/null; echo "  docker start ns1"; pausa

secao "E6 — Partição: ns3 fora da rede interna, ainda acessível ao cliente"
docker network disconnect sdm2dns_interna ns3; echo "  docker network disconnect sdm2dns_interna ns3"
serial=$(proximo_serial); novo="10.0.9.$((10#${serial: -2}))"
escreve_zona "$serial" "$novo"; recarrega >/dev/null
docker exec cliente sh /scripts/sonda.sh "$novo" 15 172.31.0.12 >/dev/null
for s in 11 12 13; do echo "  172.31.0.$s -> $(docker exec cliente dig @172.31.0.$s app.sd.lab +short +norecurse)"; done
echo "  (o ns3 serve a versão antiga até o expire de 300 s)"; pausa

secao "E7 — Reconexão e recuperação do ns3"
docker network connect --ip 172.30.0.13 sdm2dns_interna ns3; tr=$(agora)
ti=$(docker exec cliente sh /scripts/sonda_soa.sh 172.31.0.13 "$serial" 30)
awk -v a="$ti" -v b="$tr" 'BEGIN{printf "  ns3 igualou o serial do primário %.2f s após reconectar\n", a-b}'
soa
