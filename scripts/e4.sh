#!/bin/bash
# E4 — Consistência: cache, TTL e cache negativo no resolvedor.
# Uso: scripts/e4.sh [REPETICOES]   (padrão: 5)
source "$(dirname "$0")/lib.sh"
reps=${1:-5}
mkdir -p evidencias/e4 resultados
saida="evidencias/e4/e4-$(date +%Y%m%d-%H%M%S).txt"
csv="resultados/e4.csv"
exec > >(tee "$saida") 2>&1
echo "tipo,repeticao,espera_s,ttl_restante_s,t_reload,t_primeira_nova,janela_s" > "$csv"

secao "Parte A — TTL diminuindo no cache do resolvedor"
docker exec resolvedor rndc flush
for i in 1 2 3 4; do
  printf '%s  ' "$(agora)"; docker exec cliente dig @172.31.0.53 app.sd.lab +noall +answer
  sleep 5
done

secao "Parte B — Janela de leitura desatualizada (registro existente)"
esperas=(10 20 30 40 50)
for i in $(seq 1 "$reps"); do
  espera=${esperas[$(( (i - 1) % 5 ))]}
  docker exec resolvedor rndc flush
  antigo=$(docker exec cliente dig @172.31.0.53 app.sd.lab +short)
  sleep "$espera"
  ttl=$(docker exec cliente dig @172.31.0.53 app.sd.lab +noall +answer | awk '{print $2}')
  serial=$(proximo_serial); novo="10.0.4.$((10#${serial: -2}))"
  escreve_zona "$serial" "$novo"
  t0=$(recarrega)
  sleep 1
  echo "--- rep $i: valor antigo $antigo, novo $novo (serial $serial), cache preenchido há ${espera} s, TTL restante $ttl s, reload em $t0"
  for s in 11 12 13; do printf '    autoritativo 172.31.0.%s -> %s\n' $s "$(docker exec cliente dig @172.31.0.$s app.sd.lab +short +norecurse)"; done
  docker exec cliente sh /scripts/sonda_resolvedor.sh app.sd.lab "$novo" 90 > /tmp/e4_$$.txt
  sed 's/^/    resolvedor: /' /tmp/e4_$$.txt
  t1=$(awk -v v="$novo" '$3==v{print $1; exit}' /tmp/e4_$$.txt)
  janela=$(awk -v a="$t1" -v b="$t0" 'BEGIN{printf "%.3f", a-b}')
  echo "    janela de leitura desatualizada: $janela s (teórico: até $ttl s + atraso de replicação)"
  echo "positivo,$i,$espera,$ttl,$t0,$t1,$janela" >> "$csv"
done

secao "Parte C — Cache negativo (nome criado depois de consultado)"
for i in $(seq 1 "$reps"); do
  nome="novo$i-$(date +%H%M%S).sd.lab"
  docker exec resolvedor rndc flush
  printf '%s  ' "$(agora)"; docker exec cliente dig @172.31.0.53 "$nome" A +noall +comments +authority | grep -E "status|SOA"
  ttl=$(docker exec cliente dig @172.31.0.53 "$nome" A +noall +authority | awk '$4=="SOA"{print $2}')
  serial=$(proximo_serial); app=$(docker exec cliente dig @172.31.0.11 app.sd.lab +short +norecurse)
  escreve_zona "$serial" "$app" "${nome%.sd.lab} IN A 10.0.5.$i"
  t0=$(recarrega)
  sleep 1
  echo "--- rep $i: $nome criado (serial $serial) em $t0; TTL negativo restante no cache: $ttl s"
  printf '    autoritativo ns1 -> %s\n' "$(docker exec cliente dig @172.31.0.11 "$nome" +short +norecurse)"
  docker exec cliente sh /scripts/sonda_resolvedor.sh "$nome" "10.0.5.$i" 60 > /tmp/e4_$$.txt
  sed 's/^/    resolvedor: /' /tmp/e4_$$.txt
  t1=$(awk -v v="10.0.5.$i" '$3==v{print $1; exit}' /tmp/e4_$$.txt)
  janela=$(awk -v a="$t1" -v b="$t0" 'BEGIN{printf "%.3f", a-b}')
  echo "    janela de NXDOMAIN em cache após a criação: $janela s (teórico: até $ttl s)"
  echo "negativo,$i,0,$ttl,$t0,$t1,$janela" >> "$csv"
done
rm -f /tmp/e4_$$.txt

secao "Estatística (desvio padrão amostral, n - 1)"
python3 scripts/estatistica.py "$csv" janela_s tipo
echo; echo "Dados brutos: $csv   Saída: $saida"
