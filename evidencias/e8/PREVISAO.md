# E8 — Coordenação e ordem: previsão (registrada antes da execução)

1. O coordenador é fixo: ns1 é `type primary` por configuração; ns2 e ns3 são `type secondary` e
   apontam para ele. Não há eleição: se o ns1 cai, ninguém assume (E5).
2. Ao publicar no ns1 uma zona com serial menor (2026101401) que o dos secundários, o ns1 passa a
   servir a versão "nova" (porque é a que está no arquivo), mas os secundários comparam os seriais,
   concluem que a versão do primário é mais antiga que a deles e não transferem. As réplicas ficam
   divergentes: o primário responde 10.0.8.1, os secundários continuam com o valor anterior.
   O serial funciona como um relógio lógico que só pode avançar (comparação segundo a RFC 1982).
3. Publicando um serial maior que o dos secundários, todos convergem de novo.
