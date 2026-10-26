#!/bin/sh
# Executado DENTRO do contêiner cliente. Simula um cliente do serviço api.servicos.lab.
# cliente_api.sh DURACAO_S INTERVALO_S
# A cada INTERVALO_S: descobre as instâncias pelo resolvedor (172.31.0.53), escolhe
# uma em rodízio e faz uma requisição HTTP (timeout de 1 s).
# Saída por linha: instante IP resultado(OK|FALHA) número_de_instâncias_anunciadas
duracao=$1; intervalo=$2
fim=$(( $(date +%s) + duracao ))
i=0
while [ "$(date +%s)" -lt "$fim" ]; do
  t=$(date +%s.%N)
  ips=$(dig @172.31.0.53 api.servicos.lab A +short +time=1 +tries=1 | grep -E '^[0-9.]+$' | sort)
  n=$(echo "$ips" | grep -c .)
  if [ "$n" -eq 0 ]; then
    echo "$t - SEM_RESPOSTA 0"
  else
    ip=$(echo "$ips" | sed -n "$(( i % n + 1 ))p")
    if wget -q -T 1 -O /dev/null "http://$ip/" 2>/dev/null; then r=OK; else r=FALHA; fi
    echo "$t $ip $r $n"
  fi
  i=$((i + 1))
  sleep "$intervalo"
done
