#!/bin/bash
# E8 — Coordenação e ordem: o primário como coordenador estático e o serial
# do SOA como ordem das versões. Publica uma zona com serial MENOR que o atual.
source "$(dirname "$0")/lib.sh"
mkdir -p evidencias/e8
saida="evidencias/e8/e8-$(date +%Y%m%d-%H%M%S).txt"
exec > >(tee "$saida") 2>&1

mostra() {
  for s in 11 12 13; do
    echo "172.31.0.$s: serial $(serial_de 172.31.0.$s), app $(docker exec cliente dig @172.31.0.$s app.sd.lab +short +norecurse)"
  done
}

secao "Coordenador: tipo da zona em cada servidor"
for c in ns1 ns2 ns3; do echo "$c: $(docker exec $c rndc zonestatus sd.lab | grep -E '^type')"; done
echo "Primário declarado no SOA (MNAME): $(docker exec cliente dig @172.31.0.11 sd.lab SOA +short | awk '{print $1}')"

secao "Antes"
mostra
atual=$(serial_de 172.31.0.11)

secao "Publicação com serial MENOR (2026101401 < $atual) e app = 10.0.8.1"
marca=$(agora_s)
escreve_zona 2026101401 10.0.8.1
docker exec ns1 sh -c 'date +%s.%N; rndc reload sd.lab'
sleep 2
echo "Logo após o reload:"; mostra

secao "Após 40 s (mais que um ciclo de refresh de 30 s)"
sleep 38
mostra
secao "Logs do ns1"
docker logs --since "$marca" ns1 2>&1 | grep -iE "serial|notif|transfer" | grep -v "query:"
for c in ns2 ns3; do
  secao "Logs do $c"
  docker logs --since "$marca" $c 2>&1 | grep -iE "serial|notify|transfer|refresh" | grep -v "query:"
done

secao "Correção: publicação com serial maior que o dos secundários"
novo=$(( atual + 1 ))
marca=$(agora_s)
escreve_zona "$novo" 10.0.8.2
docker exec ns1 rndc reload sd.lab
sleep 3
mostra
for c in ns2 ns3; do
  docker logs --since "$marca" $c 2>&1 | grep -iE "transferred serial" | sed "s/^/$c: /"
done
echo; echo "Evidências gravadas em $saida"
