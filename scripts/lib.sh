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
  atual=$(awk '/; serial/{print $1}' "$ZONA")
  hoje=$(date +%Y%m%d)00
  if [ "$atual" -ge "$hoje" ]; then echo $((atual + 1)); else echo $((hoje + 1)); fi
}

# escreve_zona SERIAL IP_APP [linhas extras]
escreve_zona() {
  cat > "$ZONA" <<EOF
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
recarrega() {
  docker exec ns1 sh -c 'date +%s.%N; rndc reload sd.lab >/dev/null'
}

# Instante atual no relógio dos contêineres.
agora() { docker exec cliente date +%s.%N; }
