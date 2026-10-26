#!/bin/bash
# E9 — Ênfase D: descoberta de serviços com CoreDNS.
# Serviço api.servicos.lab com três instâncias (api1..api3). Para TTL de 5 s e de 60 s:
#  Parte A (carga): cliente contínuo por JANELA s, sem alterações; conta as consultas
#                   que chegam ao CoreDNS (métrica coredns_dns_requests_total).
#  Parte B (remoção): com o cliente ativo, a instância api3 morre (docker stop) e é
#                   removida do registro (zona). Mede-se quando o CoreDNS, o resolvedor
#                   e o cliente deixam de usar o endereço removido.
# Uso: scripts/e9.sh [REPETICOES] [JANELA_S]   (padrão: 5 e 60)
source "$(dirname "$0")/lib.sh"
reps=${1:-5}; janela=${2:-60}
mkdir -p evidencias/e9 resultados
saida="evidencias/e9/e9-$(date +%Y%m%d-%H%M%S).txt"
exec > >(tee "$saida") 2>&1
CSV_CARGA=resultados/e9_carga.csv
CSV_REM=resultados/e9_remocao.csv
echo "ttl,repeticao,janela_s,consultas_cliente,consultas_coredns,consultas_coredns_por_min" > "$CSV_CARGA"
echo "ttl,repeticao,t_remocao,t_coredns,t_resolvedor,t_ultimo_uso,atraso_coredns_s,atraso_resolvedor_s,atraso_cliente_s,falhas_cliente" > "$CSV_REM"
MORTO=172.31.0.23

publica_servicos() {  # publica_servicos TTL IP...
  local ttl=$1; shift
  local serial; serial=$(docker exec cliente date +%s)
  {
    echo "\$TTL $ttl"
    echo "@ IN SOA ns.servicos.lab. admin.servicos.lab. ( $serial 30 10 300 $ttl )"
    echo "  IN NS ns.servicos.lab."
    echo "ns IN A 172.31.0.60"
    for ip in "$@"; do echo "api IN A $ip"; done
  } | docker exec -i cliente sh -c 'cat > /zona-servicos/.novo && mv /zona-servicos/.novo /zona-servicos/db.servicos.lab'
}

consultas_coredns() {
  docker exec cliente wget -qO- http://172.31.0.60:9153/metrics \
    | awk '/^coredns_dns_requests_total/{s += $NF} END{print s+0}'
}

espera_coredns() {  # espera_coredns N_ESPERADO -> imprime instante em que o CoreDNS responde N IPs
  local alvo=$1 n
  while :; do
    n=$(docker exec cliente dig @172.31.0.60 api.servicos.lab +short +norecurse | grep -c .)
    [ "$n" -eq "$alvo" ] && { agora; return; }
    sleep 0.1
  done
}

prepara() {  # prepara TTL: três instâncias no ar e anunciadas; cache do resolvedor vazio
  docker start api3 >/dev/null
  publica_servicos "$1" 172.31.0.21 172.31.0.22 172.31.0.23
  espera_coredns 3 >/dev/null
  docker exec resolvedor rndc flush
}

secao "Ambiente do E9"
docker compose --profile e9 ps --format '{{.Name}} {{.Image}} {{.Status}}' coredns api1 api2 api3
docker exec resolvedor grep -A4 'zone "servicos.lab"' /etc/bind/named.conf

for ttl in 5 60; do
  secao "TTL = $ttl s — Parte A: carga com o serviço estável ($reps janelas de $janela s)"
  prepara "$ttl"
  echo "zona publicada:"; docker exec cliente cat /zona-servicos/db.servicos.lab | sed 's/^/    /'
  for i in $(seq 1 "$reps"); do
    c0=$(consultas_coredns)
    nc=$(docker exec cliente sh /scripts/cliente_api.sh "$janela" 0.2 | wc -l | tr -d ' ')
    c1=$(consultas_coredns)
    d=$((c1 - c0)); pm=$(awk -v d="$d" -v j="$janela" 'BEGIN{printf "%.2f", d*60/j}')
    echo "  janela $i: cliente fez $nc consultas ao resolvedor; CoreDNS recebeu $d ($pm por minuto)"
    echo "$ttl,$i,$janela,$nc,$d,$pm" >> "$CSV_CARGA"
  done

  secao "TTL = $ttl s — Parte B: instância api3 ($MORTO) morre e é removida do registro"
  aquecimento=$(( ttl < 20 ? 10 : 20 ))
  depois=$(( ttl + 15 ))
  for i in $(seq 1 "$reps"); do
    prepara "$ttl"
    arq=$(mktemp)
    docker exec cliente sh /scripts/cliente_api.sh $((aquecimento + depois)) 0.2 > "$arq" &
    cli=$!
    sleep "$aquecimento"
    docker stop -t 0 api3 >/dev/null
    publica_servicos "$ttl" 172.31.0.21 172.31.0.22
    tr=$(agora)
    tc=$(espera_coredns 2)
    tres=""
    while [ -z "$tres" ]; do
      if ! docker exec cliente dig @172.31.0.53 api.servicos.lab +short | grep -q "$MORTO"; then tres=$(agora); fi
      sleep 0.2
    done
    wait $cli
    tu=$(awk -v m="$MORTO" '$2==m{t=$1} END{print t}' "$arq")
    falhas=$(awk '$3=="FALHA"{n++} END{print n+0}' "$arq")
    ac=$(awk -v a="$tc" -v b="$tr" 'BEGIN{printf "%.3f", a-b}')
    ar=$(awk -v a="$tres" -v b="$tr" 'BEGIN{printf "%.3f", a-b}')
    au=$(awk -v a="$tu" -v b="$tr" 'BEGIN{ if (a=="") print "NA"; else printf "%.3f", a-b}')
    echo "  rep $i: CoreDNS sem api3 após $ac s; resolvedor após $ar s; última tentativa do cliente em api3: $au s após a remoção; falhas do cliente: $falhas"
    echo "$ttl,$i,$tr,$tc,$tres,$tu,$ac,$ar,$au,$falhas" >> "$CSV_REM"
    [ "$i" -eq 1 ] && { echo "  trecho do log do cliente na rep 1 (instante IP resultado n):"; awk -v b="$tr" '{printf "    %+8.3f s  %s %s %s\n", $1-b, $2, $3, $4}' "$arq" | awk -v t="$ttl" '$1+0 > -2 && $1+0 < t+3'; }
    rm -f "$arq"
  done
done
docker start api3 >/dev/null

secao "Estatística (desvio padrão amostral, n - 1)"
echo "Carga no CoreDNS (consultas por minuto):"
python3 scripts/estatistica.py "$CSV_CARGA" consultas_coredns_por_min ttl
echo "Consultas do cliente ao resolvedor por janela:"
python3 scripts/estatistica.py "$CSV_CARGA" consultas_cliente ttl
for c in atraso_coredns_s atraso_resolvedor_s atraso_cliente_s falhas_cliente; do
  echo "$c:"; python3 scripts/estatistica.py "$CSV_REM" "$c" ttl
done
echo; echo "Dados brutos: $CSV_CARGA $CSV_REM   Saída: $saida"
