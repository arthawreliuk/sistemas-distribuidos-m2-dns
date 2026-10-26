"""Gera docs/evidencias/*.png a partir das saídas gravadas pelos scripts (evidencias/eN/*.txt).

As imagens reproduzem trechos literais dessas saídas, em formato de terminal. Linhas muito longas
são cortadas com "[...]". Requer Google Chrome (modo headless) instalado no macOS.
Uso: python3 scripts/gerar_prints.py
"""
import html
import pathlib
import re
import subprocess

RAIZ = pathlib.Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "docs" / "evidencias"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
LARGURA = 160


def ler(rel):
    return (RAIZ / rel).read_text(encoding="utf-8").splitlines()


def secao(linhas, titulo):
    """Linhas da seção '===== ...titulo... =====' (sem o cabeçalho) até a próxima seção."""
    saida, dentro = [], False
    for linha in linhas:
        if linha.startswith("===== "):
            if dentro:
                break
            dentro = titulo in linha
            if dentro:
                saida.append(linha)
            continue
        if dentro:
            saida.append(linha)
    while saida and not saida[-1].strip():
        saida.pop()
    return saida


def filtra(linhas, padrao):
    return [l for l in linhas if l.startswith("=====") or re.search(padrao, l)]


def limpa(linha):
    linha = re.sub(r"client @0x[0-9a-f]+ ", "", linha)
    linha = linha.replace("\t", "  ")
    return linha if len(linha) <= LARGURA else linha[: LARGURA - 6] + " [...]"


def prints():
    e1 = ler("evidencias/e1/e1-20261021-193454.txt")
    e2 = ler("evidencias/e2/e2-20261026-145906.txt")
    e3 = ler("evidencias/e3/e3-20261026-150346.txt")
    e4 = ler("evidencias/e4/e4-20261026-150757.txt")
    e5 = ler("evidencias/e5/e5-20261026-151604.txt")
    e6 = ler("evidencias/e6/e6-20261026-151652.txt")
    e7a = ler("evidencias/e7/e7-20261026-152352-limite-60s-interrompido.txt")
    e7n = ler("evidencias/e7/observacao-recuperacao-natural.txt")
    e7 = ler("evidencias/e7/e7-20261026-153501.txt")
    e8 = ler("evidencias/e8/e8-20261026-154356.txt")
    e9 = ler("evidencias/e9/e9-20261026-154535.txt")

    rep4 = []
    dentro = False
    for l in secao(e4, "Parte B"):
        if l.startswith("--- rep 4"):
            dentro = True
        elif l.startswith("--- rep 5"):
            dentro = False
        if dentro:
            rep4.append(l)

    observ = e6[e6.index(next(l for l in e6 if l.startswith("instante |"))):]
    observ = [l for l in observ if "|" in l or l.startswith("=====")]
    observ = observ[:4] + ["(...)"] + [l for l in observ if re.search(r"\| (260|276|292|307) \|", l)]

    yield ("e1-topologia", "./scripts/e1.sh", "evidencias/e1/e1-20261021-193454.txt",
           secao(e1, "docker compose ps") + [""] + secao(e1, "SOA nos três") + [""]
           + secao(e1, "Flags da resposta SOA"))
    yield ("e1-transferencia", "./scripts/e1.sh", "evidencias/e1/e1-20261021-193454.txt",
           filtra(secao(e1, "Logs do ns1"), r"loaded serial|AXFR") + [""] + secao(e1, "Logs de transferência do ns2"))
    yield ("e2-leitura", "./scripts/e2.sh", "evidencias/e2/e2-20261026-145906.txt",
           secao(e2, "Leitura 1") + [""] + secao(e2, "Leitura 2") + [""] + secao(e2, "Leitura direta")
           + [""] + secao(e2, "Log de consultas"))
    yield ("e2-escrita", "./scripts/e2.sh", "evidencias/e2/e2-20261026-145906.txt",
           secao(e2, "Escrita") + [""] + filtra(secao(e2, "Logs do primário"), r"loaded|notifies|IXFR version|ended")
           + [""] + filtra(secao(e2, "secundário ns2"), r"notify from|Transfer completed") + [""] + secao(e2, "Depois da escrita"))
    yield ("e3-replicacao", "./scripts/e3.sh 5 8", "evidencias/e3/e3-20261026-150346.txt",
           filtra(secao(e3, "Série 1"), r"rep|notify") + filtra(secao(e3, "Série 2"), r"rep|notify") + [""]
           + secao(e3, "Estatística"))
    yield ("e4-cache-ttl", "./scripts/e4.sh 5", "evidencias/e4/e4-20261026-150757.txt",
           secao(e4, "Parte A") + ["", "===== Parte B (repetição 4) ====="] + rep4 + [""] + secao(e4, "Estatística"))
    yield ("e5-falha", "./scripts/e5.sh", "evidencias/e5/e5-20261026-151604.txt",
           [l for l in e5 if not re.match(r"\s+ns[123] Up", l) and not l.startswith("Evidências")])
    yield ("e6-particao", "./scripts/e6.sh", "evidencias/e6/e6-20261026-151652.txt",
           secao(e6, "Partição") + [""] + secao(e6, "Alteração no primário") + ["", "===== Observação até o expire ====="]
           + observ[1:] + [""] + filtra(secao(e6, "Logs do ns3"), r"retry limit|failed to connect|expired")[:4]
           + ["(...)"] + [l for l in secao(e6, "Logs do ns3") if "expired" in l])
    yield ("e7-recuperacao", "./scripts/e7.sh 5 40 900",
           "evidencias/e7/ (e7-20261026-152352-limite-60s-interrompido.txt, observacao-recuperacao-natural.txt, e7-20261026-153501.txt)",
           ["===== Primeira execução (após o expire do E6) ====="] + [l for l in e7a if "unreachable" in l or l.startswith("rep 0")]
           + ["", "===== Observação sem intervenção ====="] + [e7n[0]]
           + [l for l in e7n[1:] if "serial=2026102637" in l or "transferred serial" in l]
           + ["", "===== Execução revisada ====="] + [l for l in e7 if l.startswith("rep ")] + [""] + secao(e7, "Estatística"))
    yield ("e8-ordem", "./scripts/e8.sh", "evidencias/e8/e8-20261026-154356.txt",
           secao(e8, "Coordenador") + [""] + secao(e8, "Antes") + [""] + secao(e8, "Publicação com serial MENOR")
           + [""] + secao(e8, "Após 40 s") + [""] + secao(e8, "Logs do ns1") + [""] + secao(e8, "Logs do ns2")[:4]
           + [""] + secao(e8, "Correção"))
    remocao = [l for l in e9 if re.match(r"\s+rep [0-9]:", l) or l.startswith("===== TTL")]
    remocao = [l for l in remocao if "Parte A" not in l]
    yield ("e9-descoberta", "./scripts/e9.sh 5 60", "evidencias/e9/e9-20261026-154535.txt",
           [l for l in e9 if "consultas ao resolvedor;" in l or ("Parte A" in l)] + [""] + remocao)
    yield ("e9-estatistica", "./scripts/e9.sh 5 60", "evidencias/e9/e9-20261026-154535.txt",
           secao(e9, "Estatística"))


MODELO = """<!doctype html><html><head><meta charset="utf-8"><style>
body{{margin:0;background:#ffffff;font-family:Menlo,'Courier New',monospace}}
.janela{{margin:16px;border:1.5px solid #222;border-radius:8px;overflow:hidden}}
.barra{{background:#e8e8e5;border-bottom:1.5px solid #222;padding:7px 12px;font:600 13px Arial,sans-serif;color:#222}}
pre{{margin:0;padding:12px 14px;font-size:13px;line-height:1.42;color:#111;white-space:pre}}
.cmd{{font-weight:700}}
</style></head><body><div class="janela"><div class="barra">{titulo}</div><pre><span class="cmd">$ {comando}</span>
{corpo}</pre></div></body></html>"""


def main():
    SAIDA.mkdir(parents=True, exist_ok=True)
    tmp = SAIDA / "_tmp.html"
    for nome, comando, origem, linhas in prints():
        linhas = [limpa(l) for l in linhas]
        titulo = f"Terminal — saída registrada em {origem}"
        tmp.write_text(MODELO.format(titulo=html.escape(titulo), comando=html.escape(comando),
                                     corpo=html.escape("\n".join(linhas))), encoding="utf-8")
        altura = 92 + 19 * (len(linhas) + 1)
        png = SAIDA / f"{nome}.png"
        subprocess.run([CHROME, "--headless", "--disable-gpu", "--hide-scrollbars", f"--screenshot={png}",
                        f"--window-size=1360,{altura}", "--force-device-scale-factor=2", tmp.as_uri()],
                       check=True, capture_output=True)
        print(f"{png.relative_to(RAIZ)}  ({len(linhas)} linhas)")
    tmp.unlink()


if __name__ == "__main__":
    main()


# ---- Versões curtas para os slides (docs/evidencias/slides/*.png): só as linhas-chave, fonte maior ----

def prints_slides():
    e = {n: ler(f) for n, f in {
        "e1": "evidencias/e1/e1-20261021-193454.txt", "e2": "evidencias/e2/e2-20261026-145906.txt",
        "e3": "evidencias/e3/e3-20261026-150346.txt", "e4": "evidencias/e4/e4-20261026-150757.txt",
        "e5": "evidencias/e5/e5-20261026-151604.txt", "e6": "evidencias/e6/e6-20261026-151652.txt",
        "e7a": "evidencias/e7/e7-20261026-152352-limite-60s-interrompido.txt",
        "e7": "evidencias/e7/e7-20261026-153501.txt", "e8": "evidencias/e8/e8-20261026-154356.txt",
        "e9": "evidencias/e9/e9-20261026-154535.txt"}.items()}
    corta = lambda l: re.sub(r"^\d\d-Oct-2026 ", "", l)
    yield ("e1", "./scripts/e1.sh", secao(e["e1"], "SOA nos três") + [""] + secao(e["e1"], "Flags da resposta SOA") + [""]
           + [corta(l.replace("ns2  | ", "ns2: ")) for l in secao(e["e1"], "transferência do ns2") if "Transfer completed" in l])
    e2 = e["e2"]
    yield ("e2", "./scripts/e2.sh",
           [l for l in secao(e2, "Leitura 1") + secao(e2, "Leitura 2") + secao(e2, "Leitura direta") if l.startswith(("=====", ";; flags", "app."))]
           + [""] + [corta(l) for l in secao(e2, "Logs do primário") if re.search(r"loaded|sending|falling back", l)][:3]
           + [""] + secao(e2, "Depois da escrita"))
    e3 = e["e3"]
    yield ("e3", "./scripts/e3.sh 5 8", [l for l in e3 if " rep 1 " in l] + [""] + secao(e3, "Estatística")[:6])
    e4 = e["e4"]
    rep4 = [l for l in secao(e4, "Parte B") if "10.0.4.26" in l or "10.0.4.27" in l]
    yield ("e4", "./scripts/e4.sh 5", secao(e4, "Parte A") + ["", "===== Parte B, repetição 4 (fim da janela) ====="]
           + [l.strip() for l in rep4[-4:]] + [l.strip() for l in secao(e4, "Parte B") if "desatualizada: 17.948" in l]
           + [""] + [l.strip() for l in e4 if "janela de NXDOMAIN" in l][:3])
    e5 = e["e5"]
    yield ("e5", "./scripts/e5.sh", [l.strip() for l in e5 if l.startswith("=====") and "Estado" in l or "172.31.0.11:" in l
                                     or "resolvedor (cache" in l or "secundário 172.31.0.12" in l or "primário:" in l][:16])
    e6 = e["e6"]
    obs = [l for l in e6 if re.search(r"\| (7|23|260|276|292|307) \|", l)]
    yield ("e6", "./scripts/e6.sh", ["instante | s desde a partição | ns2 (status serial app) | ns3 (status serial app)"] + obs
           + [""] + [corta(l) for l in secao(e6, "Logs do ns3") if "expired" in l or "failed to connect" in l][:2])
    yield ("e7", "./scripts/e7.sh 5 40 900", [l.strip() for l in e["e7a"] if "unreachable" in l]
           + [""] + [l for l in e["e7"] if l.startswith("rep ")][:3] + ["(...)"] + secao(e["e7"], "Estatística"))
    e8 = e["e8"]
    yield ("e8", "./scripts/e8.sh", [corta(l) for l in secao(e8, "Logs do ns1") if "backwards" in l or "loaded" in l]
           + [corta(l) for l in secao(e8, "Logs do ns2")][:3] + [""] + secao(e8, "Após 40 s") + [""]
           + [l for l in secao(e8, "Correção") if l.startswith(("172.31.0.13", "ns2:", "ns3:"))])
    e9 = e["e9"]
    est = secao(e9, "Estatística")
    blocos = []
    for chave in ("atraso_resolvedor_s:", "atraso_cliente_s:", "falhas_cliente:"):
        k = est.index(chave)
        blocos += est[k:k + 4]
    yield ("e9", "./scripts/e9.sh 5 60",
           [l for l in secao(e9, "TTL = 5 s — Parte A") if l.startswith("=====") or "janela 1:" in l]
           + [l for l in secao(e9, "TTL = 60 s — Parte A") if l.startswith("=====") or "janela 1:" in l]
           + [""] + blocos)


MODELO_SLIDE = MODELO.replace("font-size:13px;line-height:1.42", "font-size:19px;line-height:1.38")


def main_slides():
    pasta = SAIDA / "slides"
    pasta.mkdir(parents=True, exist_ok=True)
    tmp = pasta / "_tmp.html"
    for nome, comando, linhas in prints_slides():
        linhas = [re.sub(r"client @0x[0-9a-f]+ ", "", x).replace("\t", "  ") for x in linhas if not x.startswith("Evidências gravadas")]
        linhas = [l if len(l) <= 132 else l[:126] + " [...]" for l in linhas]
        tmp.write_text(MODELO_SLIDE.format(titulo="Terminal — trecho da saída registrada", comando=html.escape(comando),
                                           corpo=html.escape("\n".join(linhas))), encoding="utf-8")
        altura = 100 + 27 * (len(linhas) + 1)
        png = pasta / f"{nome}.png"
        subprocess.run([CHROME, "--headless", "--disable-gpu", "--hide-scrollbars", f"--screenshot={png}",
                        f"--window-size=1640,{altura}", "--force-device-scale-factor=1", tmp.as_uri()],
                       check=True, capture_output=True)
        print(f"{png.relative_to(RAIZ)}  ({len(linhas)} linhas, {altura}px)")
    tmp.unlink()


if __name__ == "__main__":
    import sys
    if "--slides" in sys.argv:
        main_slides()
