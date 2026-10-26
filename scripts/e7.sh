#!/bin/bash
# E7 — Recuperação do ns3 após a partição.
# Repetição 0: reconexão logo após o E6 (zona já expirada no ns3).
# Repetições 1..N: partição curta (ns3 desatualizado, zona ainda válida) e reconexão.
# Uso: scripts/e7.sh [REPETICOES] [DURACAO_PARTICAO_S]   (padrão: 5 e 20 s)
source "$(dirname "$0")/lib.sh"
reps=${1:-5}; duracao=${2:-20}
mkdir -p evidencias/e7 resultados
saida="evidencias/e7/e7-$(date +%Y%m%d-%H%M%S).txt"
csv="resultados/e7.csv"
exec > >(tee "$saida") 2>&1
REDE=sdm2dns_interna
echo "repeticao,situacao,serial_ns3_antes,serial_primario,t_reconexao,t_igual,tempo_s" > "$csv"

reconecta_e_mede() {  # reconecta_e_mede REP SITUACAO
  local antes alvo tr ti tempo marca
  antes=$(docker exec cliente dig @172.31.0.13 sd.lab SOA +short +norecurse +time=1 +tries=1 | awk '{print $3}')
  [ -z "$antes" ] && antes="SERVFAIL"
  alvo=$(serial_de 172.31.0.11)
  marca=$(agora_s)
  docker network connect --ip 172.30.0.13 "$REDE" ns3
  tr=$(agora)
  ti=$(docker exec cliente sh /scripts/sonda_soa.sh 172.31.0.13 "$alvo" 60)
  tempo=$(awk -v a="$ti" -v b="$tr" 'BEGIN{ if (a ~ /NAO/) print "NAO_ATUALIZOU"; else printf "%.3f", a-b}')
  echo "rep $1 ($2): ns3 antes=$antes, primário=$alvo, reconectado em $tr, igualou em $ti -> $tempo s"
  echo "    endereço interno do ns3: $(docker exec ns3 ip -4 -o addr show | awk '/172\.30/{print $4}')"
  docker logs --since "$marca" ns3 2>&1 | grep -iE "transfer|IXFR|AXFR|refresh|loaded|expired" | grep -v "query:" | sed 's/^/    log ns3: /'
  echo "$1,$2,$antes,$alvo,$tr,$ti,$tempo" >> "$csv"
}

secao "Repetição 0: recuperação após o expire (continuação do E6)"
if docker exec ns3 ip -4 -o addr show | grep -q 172.30.0.13; then
  echo "ns3 já está na rede interna; repetição 0 ignorada"
else
  reconecta_e_mede 0 apos_expire
fi
sleep 5

for i in $(seq 1 "$reps"); do
  secao "Repetição $i: partição de $duracao s"
  docker network disconnect "$REDE" ns3
  serial=$(proximo_serial); novo="10.0.7.$((10#${serial: -2}))"
  escreve_zona "$serial" "$novo"
  recarrega > /dev/null
  sleep "$duracao"
  echo "durante a partição: ns2 serial $(serial_de 172.31.0.12), ns3 serial $(serial_de 172.31.0.13)"
  reconecta_e_mede "$i" particao_curta
  sleep 5
done

secao "Estado final"
for s in 11 12 13; do
  echo "172.31.0.$s: serial $(serial_de 172.31.0.$s), app $(docker exec cliente dig @172.31.0.$s app.sd.lab +short +norecurse)"
done

secao "Estatística das partições curtas (desvio padrão amostral, n - 1)"
python3 scripts/estatistica.py "$csv" tempo_s situacao
echo; echo "Dados brutos: $csv   Saída: $saida"
