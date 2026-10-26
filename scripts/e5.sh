#!/bin/bash
# E5 — Falha e quórum: leitura e escrita com 3, 2 e 1 servidor autoritativo ativo.
source "$(dirname "$0")/lib.sh"
mkdir -p evidencias/e5
saida="evidencias/e5/e5-$(date +%Y%m%d-%H%M%S).txt"
exec > >(tee "$saida") 2>&1

leituras() {
  local s r st val
  for s in 11 12 13; do
    r=$(docker exec cliente dig @172.31.0.$s app.sd.lab +norecurse +time=2 +tries=1 2>&1)
    st=$(echo "$r" | sed -n 's/.*status: \([A-Z]*\).*/\1/p')
    val=$(echo "$r" | awk '/^app\.sd\.lab/{print $5}')
    if [ -z "$st" ]; then echo "    leitura direta 172.31.0.$s: sem resposta (tempo esgotado)"
    else echo "    leitura direta 172.31.0.$s: $st valor $val"; fi
  done
  docker exec resolvedor rndc flush
  r=$(docker exec cliente dig @172.31.0.53 app.sd.lab +time=5 +tries=1)
  echo "    leitura pelo resolvedor (cache vazio): $(echo "$r" | awk '/status:/{print $6} /^app\.sd\.lab/{print "valor", $5} /Query time/{print "tempo", $4, "ms"}' | tr '\n' ' ')"
}

escrita_primario() {
  local serial novo
  if ! docker exec ns1 true 2>/dev/null; then
    echo "    escrita no primário: IMPOSSÍVEL ($(docker exec ns1 true 2>&1 | head -1))"
    return
  fi
  serial=$(proximo_serial); novo="10.0.5.$((10#${serial: -2}))"
  if escreve_zona "$serial" "$novo" && t=$(recarrega); then
    sleep 2
    echo "    escrita no primário (serial $serial, app $novo): publicada"
    for s in 12 13; do echo "      172.31.0.$s serve serial $(serial_de 172.31.0.$s)"; done
  else
    echo "    escrita no primário: IMPOSSÍVEL ($(docker exec ns1 true 2>&1 | head -1))"
  fi
}

escrita_secundario() {
  for s in 12 13; do
    r=$(printf 'server 172.31.0.%s\nzone sd.lab\nupdate add teste.sd.lab 60 A 10.9.9.9\nsend\n' $s | docker exec -i cliente nsupdate -t 3 2>&1 | head -1)
    echo "    escrita (atualização dinâmica) no secundário 172.31.0.$s: ${r:-aceita}"
  done
}

estado() {
  secao "$1"
  docker compose ps --format '{{.Name}} {{.Status}}' ns1 ns2 ns3 | sed 's/^/    /'
  leituras
  escrita_primario
  escrita_secundario
}

estado "Estado 1: três autoritativos ativos"

docker stop ns1 >/dev/null; echo; echo ">>> docker stop ns1 em $(agora)"
sleep 2
estado "Estado 2: ns1 (primário) parado — ns2 e ns3 ativos"
echo "    ns2: $(docker exec ns2 rndc zonestatus sd.lab | grep -E 'expires')"

docker stop ns2 >/dev/null; echo; echo ">>> docker stop ns2 em $(agora)"
sleep 2
estado "Estado 3: ns1 e ns2 parados — só ns3 ativo"
echo "    ns3: $(docker exec ns3 rndc zonestatus sd.lab | grep -E 'expires')"

secao "Restauração"
docker start ns1 ns2 >/dev/null; echo ">>> docker start ns1 ns2 em $(agora)"
sleep 5
for s in 11 12 13; do echo "    172.31.0.$s serial $(serial_de 172.31.0.$s)"; done
echo; echo "Evidências gravadas em $saida"
