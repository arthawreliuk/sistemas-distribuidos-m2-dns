#!/bin/bash
# E3 — Tempo de propagação primário -> secundários, com e sem NOTIFY.
# Uso: scripts/e3.sh [REPETICOES] [INTERVALO_S]   (padrão: 5 por cenário, 8 s)
# O intervalo entre repetições precisa ser maior que 5 s: o BIND não envia
# NOTIFY da mesma zona mais de uma vez a cada 5 s (observado na 1ª execução).
source "$(dirname "$0")/lib.sh"
reps=${1:-5}
intervalo=${2:-8}
mkdir -p resultados
saida="evidencias/e3/e3-$(date +%Y%m%d-%H%M%S).txt"; mkdir -p evidencias/e3
csv="resultados/e3.csv"
exec > >(tee "$saida") 2>&1
echo "cenario,repeticao,serial,valor,t_reload,servidor,t_resposta,atraso_s" > "$csv"

serie() {  # serie NOME LIMITE_S
  local nome=$1 limite=$2 i serial valor t0 arq
  for i in $(seq 1 "$reps"); do
    serial=$(proximo_serial); valor="10.0.3.$((10#${serial: -2}))"
    escreve_zona "$serial" "$valor"
    arq=$(mktemp)
    docker exec cliente sh /scripts/sonda.sh "$valor" "$limite" 172.31.0.12 172.31.0.13 > "$arq" &
    sonda=$!
    sleep 0.5
    t0=$(recarrega)
    wait $sonda
    while read -r ip t; do
      if [ "$t" = "NAO_ATUALIZOU" ]; then atraso=NAO_ATUALIZOU
      else atraso=$(awk -v a="$t" -v b="$t0" 'BEGIN{printf "%.3f", a-b}'); fi
      echo "$nome,$i,$serial,$valor,$t0,$ip,$t,$atraso" >> "$csv"
      echo "$nome rep $i serial $serial valor $valor: $ip respondeu após $atraso s"
    done < "$arq"
    rm -f "$arq"
    sleep "$intervalo"
  done
}

secao "Série 1: com NOTIFY (configuração padrão do laboratório)"
docker exec ns1 grep -E "notify" /etc/bind/named.conf | grep -v "//"
serie com_notify 60

secao "Série 2: sem NOTIFY (ns1 recriado com ns1/named-semnotify.conf)"
docker compose -f docker-compose.yml -f docker-compose.semnotify.yml up -d ns1 2>&1 | tail -1
sleep 3
docker exec ns1 grep -E "notify" /etc/bind/named.conf
serie sem_notify 90

secao "Restaura o ns1 com NOTIFY"
docker compose up -d ns1 2>&1 | tail -1
sleep 3
docker exec ns1 grep -E "notify" /etc/bind/named.conf | grep -v "//"

secao "Estatística (desvio padrão amostral, n - 1)"
python3 scripts/estatistica.py "$csv" atraso_s cenario servidor
python3 scripts/estatistica.py "$csv" atraso_s cenario
echo; echo "Dados brutos: $csv   Saída: $saida"
