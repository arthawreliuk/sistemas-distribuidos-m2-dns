"""Média e desvio padrão amostral (n - 1) de uma coluna de um CSV, agrupada.

Uso: python3 scripts/estatistica.py ARQUIVO.csv COLUNA_VALOR COLUNA_GRUPO [COLUNA_GRUPO ...]
Linhas cujo valor não é numérico (por exemplo, NAO_ATUALIZOU) são contadas à parte.
"""
import csv
import statistics
import sys
from collections import OrderedDict

arquivo, coluna, grupos = sys.argv[1], sys.argv[2], sys.argv[3:]
dados = OrderedDict()
falhas = OrderedDict()
with open(arquivo, newline="", encoding="utf-8") as f:
    for linha in csv.DictReader(f):
        chave = " / ".join(linha[g] for g in grupos)
        try:
            dados.setdefault(chave, []).append(float(linha[coluna]))
        except ValueError:
            falhas[chave] = falhas.get(chave, 0) + 1

print(f"{'grupo':<30} {'n':>3} {'média (s)':>10} {'desvio (s)':>11} {'mín (s)':>8} {'máx (s)':>8}")
for chave, v in dados.items():
    desvio = statistics.stdev(v) if len(v) > 1 else float("nan")
    print(f"{chave:<30} {len(v):>3} {statistics.mean(v):>10.3f} {desvio:>11.3f} {min(v):>8.3f} {max(v):>8.3f}")
for chave, n in falhas.items():
    print(f"{chave:<30} sem valor numérico em {n} linha(s)")
