# Imagem única usada por ns1, ns2, ns3, resolvedor e cliente (roteiro, seção 5.2).
FROM alpine:3.20

# bind = servidor named; bind-tools = dig, host, nslookup, nsupdate;
# coreutils = date com frações de segundo (date +%s.%N) para as medições.
# rndc-confgen -a gera /etc/bind/rndc.key, que o named usa automaticamente
# no canal de controle padrão (127.0.0.1:953). Sem essa chave, "rndc reload"
# (usado no roteiro) não funciona. A chave fica embutida na imagem: aceitável
# num laboratório local, nunca em produção.
RUN apk add --no-cache bind bind-tools coreutils \
 && rndc-confgen -a \
 && chown root:named /etc/bind/rndc.key \
 && chmod 640 /etc/bind/rndc.key

# -g: primeiro plano, todo log no stderr (aparece em "docker logs").
CMD ["named", "-g", "-u", "named", "-c", "/etc/bind/named.conf"]
