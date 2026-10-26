#!/bin/bash
# E7 — Recuperação do ns3 após uma partição da rede interna.
# Cenário A (natural): partição de DURACAO s, reconexão com o mesmo IP e nada mais;
#   mede o tempo até o ns3 servir o serial do primário.
# Cenário B (com NOTIFY): igual, mas 2 s após a reconexão o primário publica uma
#   nova versão (NOTIFY); mede o tempo até o ns3 servir essa versão.
# Uso: scripts/e7.sh [REPETICOES] [DURACAO_PARTICAO_S] [LIMITE_S]   (padrão: 5, 40, 900)
source "$(dirname "$0")/lib.sh"
reps=${1:-5}; duracao=${2:-40}; limite=${3:-900}
mkdir -p evidencias/e7 resultados
saida="evidencias/e7/e7-$(date +%Y%m%d-%H%M%S).txt"
csv="resultados/e7.csv"
exec > >(tee "$saida") 2>&1
REDE=sdm2dns_interna
echo "cenario,repeticao,serial_ns3_antes,serial_alvo,t_reconexao,t_igual,tempo_s" > "$csv"

sincronizado() { [ "$(serial_de 172.31.0.13)" = "$(serial_de 172.31.0.11)" ]; }

particao() {  # particao: isola o ns3, publica uma versão nova, espera $duracao s
  docker network disconnect "$REDE" ns3
  local serial; serial=$(proximo_serial)
  escreve_zona "$serial" "10.0.7.$((10#${serial: -2}))"
  recarrega > /dev/null
  sleep "$duracao"
  echo "  durante a partição: primário $(serial_de 172.31.0.11), ns2 $(serial_de 172.31.0.12), ns3 $(serial_de 172.31.0.13)"
}

repeticao() {  # repeticao CENARIO N
  local antes alvo tr ti tempo marca serial
  sincronizado || { echo "  ns3 não está sincronizado antes da repetição; abortando"; exit 1; }
  marca=$(agora_s)
  particao
  antes=$(serial_de 172.31.0.13)
  docker network connect --ip 172.30.0.13 "$REDE" ns3
  tr=$(agora)
  if [ "$1" = "com_notify" ]; then
    sleep 2
    serial=$(proximo_serial)
    escreve_zona "$serial" "10.0.7.$((10#${serial: -2}))"
    recarrega > /dev/null
  fi
  alvo=$(serial_de 172.31.0.11)
  ti=$(docker exec cliente sh /scripts/sonda_soa.sh 172.31.0.13 "$alvo" "$limite")
  tempo=$(awk -v a="$ti" -v b="$tr" 'BEGIN{ if (a ~ /NAO/) print "NAO_ATUALIZOU"; else printf "%.3f", a-b}')
  echo "rep $2 ($1): ns3 antes=$antes, alvo=$alvo, reconectado em $tr, igualou em $ti -> $tempo s"
  docker logs --since "$marca" ns3 2>&1 | grep -iE "unreachable|transfer of|transferred|expired|notify from" | grep -v "query:" | sed 's/^/    log ns3: /'
  echo "$1,$2,$antes,$alvo,$tr,$ti,$tempo" >> "$csv"
  sleep 5
}

secao "Estado inicial"
for s in 11 12 13; do echo "172.31.0.$s serial $(serial_de 172.31.0.$s)"; done

secao "Cenário A — recuperação natural (partição de $duracao s)"
for i in $(seq 1 "$reps"); do repeticao natural "$i"; done

secao "Cenário B — reconexão seguida de nova versão no primário (NOTIFY)"
for i in $(seq 1 "$reps"); do repeticao com_notify "$i"; done

secao "Estado final"
for s in 11 12 13; do
  echo "172.31.0.$s: serial $(serial_de 172.31.0.$s), app $(docker exec cliente dig @172.31.0.$s app.sd.lab +short +norecurse)"
done

secao "Estatística (desvio padrão amostral, n - 1)"
python3 scripts/estatistica.py "$csv" tempo_s cenario
echo; echo "Dados brutos: $csv   Saída: $saida"
