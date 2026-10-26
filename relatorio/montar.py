"""Monta relatorio/relatorio.html a partir das partes em relatorio/partes/ (ordem alfabética)."""
import pathlib

aqui = pathlib.Path(__file__).parent
cabecalho = (aqui / "partes" / "_cabecalho.html").read_text(encoding="utf-8")
partes = sorted(p for p in (aqui / "partes").glob("*.html") if not p.name.startswith("_"))
corpo = "\n".join(p.read_text(encoding="utf-8") for p in partes)
(aqui / "relatorio.html").write_text(cabecalho + corpo + "\n</body>\n</html>\n", encoding="utf-8")
print("relatorio.html montado com", len(partes), "partes")
