#!/bin/sh
# Executado DENTRO do contêiner cliente.
# sonda.sh VALOR LIMITE_S IP1 [IP2 ...]
# Consulta app.sd.lab em cada IP a cada 100 ms (sem recursão) e imprime
# "IP instante" na primeira vez que o IP responde VALOR. Termina quando todos
# responderam ou quando LIMITE_S segundos se passam.
valor=$1; limite=$2; shift 2
pendentes="$*"
fim=$(( $(date +%s) + limite ))
while [ -n "$pendentes" ] && [ "$(date +%s)" -lt "$fim" ]; do
  resto=""
  for ip in $pendentes; do
    r=$(dig @"$ip" app.sd.lab A +short +norecurse +time=1 +tries=1)
    if [ "$r" = "$valor" ]; then echo "$ip $(date +%s.%N)"; else resto="$resto $ip"; fi
  done
  pendentes=$(echo $resto)
  sleep 0.1
done
for ip in $pendentes; do echo "$ip NAO_ATUALIZOU"; done
