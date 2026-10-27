# Seminário M2 — roteiro de apresentação e de gravação

Slides: `apresentacao/slides.pdf` (24 slides). Relatório: `relatorio/relatorio.pdf`.
Tempo do roteiro (seção 11): 10 min de apresentação + 5 min de arguição; todos apresentam;
demonstração ao vivo com o cluster já em execução; vídeo só como contingência.

## Divisão sugerida (ajustem como preferirem)

| Bloco | Slides | Tempo | Quem |
|---|---|---|---|
| 1. Problema e artigo seminal | 1–2 | 1 min | Guilherme |
| 2. Arquitetura e laboratório | 3–5 | 2 min | Guilherme |
| 3. Demonstração ao vivo (E2, E3, E5/E6, E7) + resultados E2–E8 | 6–19 e 24 | 4 min | Arthur |
| 4. Ênfase D — E9 (CoreDNS) | 20–22 | 2 min | Arthur |
| 5. Quadro-síntese | 23 | 1 min | Guilherme |

No bloco 3, o mais natural é rodar `./scripts/demo.sh` no terminal (cerca de 4 min) e usar os slides de
resultado e de evidência só para mostrar os números das cinco repetições, que não cabem na demonstração.

## O que dizer em cada slide (resumo das notas)

- **Problema:** traduzir nomes estáveis em endereços que mudam, em escala mundial, sem diretório central.
  Artigo seminal: Mockapetris e Dunlap, 1988.
- **Arquitetura:** cliente-servidor em todos os saltos; entre os servidores da zona também (o secundário pede,
  o primário serve; o NOTIFY só avisa). Não é P2P. Resolução hierárquica: raiz → TLD → autoritativo, com cache.
- **Laboratório:** 5 contêineres, 2 redes; a interna só para replicação, o que permite a partição do E6.
- **E2:** resolvedor responde com `ra` (do cache, TTL caindo); autoritativo com `aa`. Escrita só no primário;
  NOTIFY e transferência completa.
- **E3:** com NOTIFY 0,34 s; sem NOTIFY 16,2 s (refresh). O BIND manda no máximo um NOTIFY a cada 5 s.
- **E4:** o resolvedor serve o valor antigo até o TTL vencer; cache negativo 19,4 s. Consistência eventual.
- **E5:** leitura com 1 servidor; sem o primário não há escrita. Sem quórum: R = 1, W = 1.
- **E6:** isolado responde a versão antiga até o expire (AP); depois SERVFAIL.
- **E7:** recupera copiando a zona inteira; segundos após partição curta, 565,7 s após o expire
  (primário marcado como inalcançável).
- **E8:** serial menor é ignorado; o serial é um relógio lógico de um único escritor.
- **E9:** TTL 5 s: cliente larga a instância morta em 2,7 s, 12 consultas/min; TTL 60 s: 36,2 s, 1,2/min.
  Relação com Kubernetes: Service, EndpointSlices, CoreDNS, `cache 30`.

## Arguição

O professor pergunta Q1–Q14 e S1–S4 a qualquer integrante. As respostas estão no relatório (seções 6 e 7),
cada uma ligada ao experimento que a sustenta. Os dois devem ler essas seções antes do dia 28.

## Gravação do vídeo de contingência (passo a passo)

1. Abra o Docker Desktop e espere ficar "running".
2. No Terminal, entre na pasta do projeto e confira o laboratório:
   ```bash
   docker compose up -d
   ./scripts/demo.sh
   ```
   Rode a demo uma vez sem gravar para "aquecer" (ela altera a zona; pode rodar quantas vezes quiser).
3. Aumente a fonte do Terminal (`Cmd +` duas ou três vezes) para o texto ficar legível no vídeo.
4. Aperte `Cmd + Shift + 5`, escolha **Gravar parte da tela** (ou a janela do Terminal) e clique em **Gravar**.
5. Rode `./scripts/demo.sh` e vá apertando ENTER em cada etapa, falando o que aparece
   (use as frases da seção acima). São seis etapas: topologia, leitura, escrita/propagação,
   primário parado, partição e recuperação.
6. Pare a gravação pelo ícone na barra de menus. O vídeo vai para a Mesa (Desktop).
7. Assista uma vez e guarde em dois lugares (notebook e Google Drive/pendrive).

No dia da apresentação, deixe o Docker Desktop aberto e rode `docker compose up -d` antes de começar.
