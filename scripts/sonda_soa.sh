#!/bin/sh
# Executado DENTRO do contêiner cliente.
# sonda_soa.sh IP SERIAL LIMITE_S
# Consulta o SOA de sd.lab em IP a cada 100 ms e imprime o instante em que o
# serial servido passa a ser SERIAL (ou NAO_ATUALIZOU ao fim do limite).
ip=$1; alvo=$2; limite=$3
fim=$(( $(date +%s) + limite ))
while [ "$(date +%s)" -lt "$fim" ]; do
  s=$(dig @"$ip" sd.lab SOA +short +norecurse +time=1 +tries=1 | awk '{print $3}')
  if [ "$s" = "$alvo" ]; then date +%s.%N; exit 0; fi
  sleep 0.1
done
echo NAO_ATUALIZOU
