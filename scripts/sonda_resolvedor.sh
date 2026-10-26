#!/bin/sh
# Executado DENTRO do contêiner cliente.
# sonda_resolvedor.sh NOME VALOR LIMITE_S
# Consulta NOME no resolvedor (172.31.0.53) a cada 0,5 s e imprime
# "instante TTL resposta" a cada consulta, até a resposta ser VALOR.
nome=$1; valor=$2; limite=$3
fim=$(( $(date +%s) + limite ))
while [ "$(date +%s)" -lt "$fim" ]; do
  t=$(date +%s.%N)
  linha=$(dig @172.31.0.53 "$nome" A +noall +answer +authority +comments +time=1 +tries=1)
  status=$(echo "$linha" | sed -n 's/.*status: \([A-Z]*\).*/\1/p')
  resp=$(echo "$linha" | awk -v n="$nome." '$1==n && $4=="A"{print $5; exit}')
  ttl=$(echo "$linha" | awk -v n="$nome." '$1==n && $4=="A"{print $2; exit}')
  [ -z "$ttl" ] && ttl=$(echo "$linha" | awk '$4=="SOA"{print $2; exit}')
  echo "$t ${ttl:--} ${resp:-$status}"
  [ "$resp" = "$valor" ] && exit 0
  sleep 0.5
done
echo "LIMITE_ATINGIDO"
