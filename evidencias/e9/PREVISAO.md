# E9 — Ênfase D: descoberta de serviços com CoreDNS — previsão (registrada antes da execução)

Montagem: CoreDNS autoritativo da zona servicos.lab (172.31.0.60), com o registro de instâncias em
um arquivo de zona recarregado a cada 1 s; três instâncias HTTP (api1..api3, 172.31.0.21-23); o
resolvedor BIND encaminha servicos.lab ao CoreDNS e guarda as respostas em cache; o cliente descobre
as instâncias pelo resolvedor a cada 0,2 s e chama uma delas em rodízio.

Carga (parte A): o cliente faz cerca de 5 consultas por segundo ao resolvedor. O CoreDNS só recebe uma
consulta quando o cache vence: cerca de 60/TTL consultas por minuto — ~12/min com TTL 5 s e ~1/min com
TTL 60 s. TTL baixo multiplica a carga no servidor de nomes (cerca de 12 vezes aqui).

Remoção (parte B): a instância api3 morre e é retirada do registro no mesmo instante.
1. O CoreDNS deixa de anunciá-la em até ~1 s (intervalo de recarga do arquivo).
2. O resolvedor continua entregando o endereço antigo até o TTL em cache vencer: até ~5 s com TTL 5 e
   até ~60 s com TTL 60 (em média, metade disso, porque a remoção cai em um ponto qualquer do TTL).
3. O cliente continua tentando a instância morta (requisições com falha, cerca de 1 a cada 3) até
   receber a lista nova: o tempo até o cliente abandonar a instância morta acompanha o do resolvedor.
Compromisso: TTL baixo = clientes param de usar instâncias mortas mais cedo, ao custo de mais consultas.
