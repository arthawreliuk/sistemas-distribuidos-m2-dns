# E2 — Caminho de uma operação: previsão (registrada antes da execução)

Leitura:
1. Pelo resolvedor (`dig @172.31.0.53 app.sd.lab`), a resposta vem com a flag `ra` e sem `aa`:
   o resolvedor não é a autoridade da zona. Na primeira consulta (cache vazio), o log de consultas de
   um dos autoritativos registra a pergunta vinda do resolvedor (172.31.0.53). Na segunda consulta
   nenhum autoritativo registra nada: a resposta sai do cache do resolvedor, com TTL menor que 60.
2. Direto no primário (`dig @172.31.0.11 app.sd.lab +norecurse`), a resposta vem com `aa` e sem `ra`.

Escrita:
3. A escrita só acontece no primário: edição do arquivo da zona com serial maior e `rndc reload`.
4. O ns1 envia NOTIFY aos secundários pela rede interna; cada secundário consulta o SOA do primário,
   vê o serial maior e pede a transferência. Como o primário carrega a zona de um arquivo, sem
   histórico de diferenças, a transferência deve ser completa (AXFR).
5. Ao final os três autoritativos respondem o novo valor; o resolvedor continua com o valor antigo
   enquanto o TTL do cache não vencer.
