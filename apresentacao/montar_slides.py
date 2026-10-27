"""Monta apresentacao/slides.pdf a partir de apresentacao/slides/*.html (ordem de deck.json).

As imagens são referenciadas na apresentação on-line por endereços de upload (/_blob/<id>); aqui
cada uma é trocada pelo arquivo local correspondente. Requer Google Chrome (headless).
Uso: python3 apresentacao/montar_slides.py
"""
import json
import pathlib
import re
import subprocess

AQUI = pathlib.Path(__file__).resolve().parent
RAIZ = AQUI.parent
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
IMAGENS = {
    "727da289d64ba05252e953d188edd38c": "relatorio/assets/univali.png",
    "a6704d302ca4d1b09c581d57126253de": "diagramas/arquitetura-dns.png",
    "37e2fab0794642a41580c1a23b19567e": "diagramas/topologia-pb.png",
    "d0ad25073f232014c6c2e9b6533ecacf": "diagramas/sequencia-e2.png",
    "9b747cd72af5b893af4be390100cec7e": "diagramas/e9-descoberta.png",
    "39123e9ad2466a3d5358dd42734e2b94": "docs/evidencias/slides/e1.png",
    "52f28f7ee98884c646006b0843298a9c": "docs/evidencias/slides/e2.png",
    "51c091e849fa19585765f4f35f6c7840": "docs/evidencias/slides/e3.png",
    "93036213624714819f1cebd4e19e91ac": "docs/evidencias/slides/e4.png",
    "d42a797b931bf42de0a3efa62b9703d2": "docs/evidencias/slides/e5.png",
    "7ed4ea93f1e8521a5434eedabc6cf597": "docs/evidencias/slides/e6.png",
    "99e7aba02aa48c42277b75418680f8bc": "docs/evidencias/slides/e7.png",
    "5c638a37117dff0804a9681d2d642b27": "docs/evidencias/slides/e8.png",
    "3a6f42998a0eb0a213df84e7bb38cc97": "docs/evidencias/slides/e9.png",
}

ordem = json.loads((AQUI / "deck.json").read_text(encoding="utf-8"))["order"]
partes = []
for sid in ordem:
    s = (AQUI / "slides" / f"{sid}.html").read_text(encoding="utf-8")
    s = re.sub(r"/_blob/([0-9a-f]{32})", lambda m: "../" + IMAGENS[m.group(1)], s)
    partes.append(s)
html = """<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><style>
@page { size: 1920px 1080px; margin: 0 }
body { margin: 0 }
section { position: relative; width: 1920px; height: 1080px; box-sizing: border-box; overflow: hidden;
          break-after: page; page-break-after: always }
section > * { margin: 0 }
h1, h2, h3, p { margin: 0 }
table { border-collapse: collapse; width: 100% }
th, td { border: 2px solid #1c1c1c; padding: 0.35em 0.6em; text-align: left; vertical-align: top }
aside { display: none }
</style></head><body>""" + "\n".join(partes) + "</body></html>"
tmp = AQUI / "_slides.html"
tmp.write_text(html, encoding="utf-8")
saida = AQUI / "slides.pdf"
subprocess.run([CHROME, "--headless", "--disable-gpu", "--no-pdf-header-footer", f"--print-to-pdf={saida}",
                tmp.as_uri()], check=True, capture_output=True)
tmp.unlink()
print(saida.relative_to(RAIZ), len(ordem), "slides")
