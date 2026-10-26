# E6 — Partição de rede: previsão (registrada antes da execução)

O ns3 é desconectado apenas da rede interna. O cliente continua alcançando o ns3 pela rede de
clientes; o ns3 deixa de alcançar o primário (172.30.0.11).

1. Uma alteração publicada no ns1 chega ao ns2 (NOTIFY + transferência) e não chega ao ns3.
   O ns3 continua respondendo, com `aa`, a versão antiga: os dois lados da partição dão respostas
   diferentes para o mesmo nome. Disponibilidade é mantida, consistência não.
2. O ns3 tenta o refresh a cada retry (10 s) e falha. Quando o expire (300 s, contados a partir do
   último refresh bem-sucedido) vence, o ns3 deixa de servir a zona e passa a responder SERVFAIL
   (o roteiro relata esse comportamento no teste do kit). A partir daí ele troca disponibilidade por
   não servir dado possivelmente desatualizado.
3. O resolvedor continua respondendo, porque tem outros encaminhadores (ns1 e ns2) com a versão nova.
