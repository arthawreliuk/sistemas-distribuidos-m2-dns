#!/bin/bash
# Funções comuns aos scripts de experimento. Uso: source scripts/lib.sh
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

ZONA=zonas/db.sd.lab

secao() { printf '\n===== %s =====\n' "$1"; }

# Serial atualmente servido pelo servidor $1 (IP na rede de clientes).
serial_de() { docker exec cliente dig @"$1" sd.lab SOA +short +time=1 +tries=1 | awk '{print $3}'; }

# Próximo serial no formato AAAAMMDDnn, sempre maior que o atual do primário.
proximo_serial() {
  local atual hoje
  atual=$(docker exec ns1 awk '/; serial/{print $1}' /var/lib/bind/db.sd.lab)
  hoje=$(date +%Y%m%d)00
  if [ "$atual" -ge "$hoje" ]; then echo $((atual + 1)); else echo $((hoje + 1)); fi
}

# escreve_zona SERIAL IP_APP [linhas extras]
# O arquivo é gravado de dentro do ns1 (e não pelo host), para que o BIND veja
# a nova data de modificação imediatamente.
escreve_zona() {
  docker exec -i ns1 sh -c 'cat > /var/lib/bind/db.sd.lab' <<EOF
\$TTL 60
@   IN SOA ns1.sd.lab. admin.sd.lab. (
        $1 ; serial (AAAAMMDDnn): versão da zona
        30         ; refresh: secundário verifica o primário a cada 30 s
        10         ; retry: nova tentativa após falha
        300        ; expire: secundário sem contato para de responder após 300 s
        20 )       ; TTL do cache negativo
    IN NS ns1.sd.lab.
    IN NS ns2.sd.lab.
    IN NS ns3.sd.lab.
ns1 IN A 172.31.0.11
ns2 IN A 172.31.0.12
ns3 IN A 172.31.0.13
app IN A $2
${3:-}
EOF
}

# recarrega: executa rndc reload no ns1 e imprime o instante (relógio da VM).
# Confere se o primário passou a servir o serial do arquivo; se não, repete.
recarrega() {
  local esperado t i
  esperado=$(docker exec ns1 awk '/; serial/{print $1}' /var/lib/bind/db.sd.lab)
  for i in 1 2 3 4 5; do
    t=$(docker exec ns1 sh -c 'date +%s.%N; rndc reload sd.lab >/dev/null')
    sleep 0.3
    if [ "$(serial_de 172.31.0.11)" = "$esperado" ]; then echo "$t"; return 0; fi
    echo "aviso: reload $i não carregou o serial $esperado; repetindo" >&2
    sleep 1
  done
  echo "ERRO: primário não carregou o serial $esperado" >&2; return 1
}

# Instante atual no relógio dos contêineres (segundos desde a época).
agora() { docker exec cliente date +%s.%N; }
agora_s() { docker exec cliente date +%s; }
