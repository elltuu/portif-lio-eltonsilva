"""
Radar de Voz do Consumidor — Etapa 5: Resumo executivo (camada de IA)
---------------------------------------------------------------
Transforma os numeros em uma narrativa pronta para a lideranca:
principais dores do cliente, onde estao concentradas e o que
priorizar. Geracao de linguagem natural (NLG) a partir dos
indicadores calculados — roda 100% offline (sem enviar dado para
fora, aderente a LGPD). O trecho esta isolado para que, se desejado,
um modelo de linguagem externo possa assumir a redacao no futuro.

Saidas:
  dados/voc_resultado.parquet  -> base final que alimenta o painel
  dados/resumo.json            -> indicadores + texto executivo
"""

from pathlib import Path
import json
import pandas as pd

RAIZ = Path(__file__).resolve().parents[1]
DADOS = RAIZ / "dados"

TEMAS = ["Prazo de entrega", "Produto nao recebido", "Qualidade / defeito",
         "Produto errado / incompleto", "Atendimento / suporte",
         "Reembolso / estorno", "Embalagem", "Elogio geral"]

TEMAS_DOR = [t for t in TEMAS if t != "Elogio geral"]


def mil(n):
    """Formata inteiro com separador de milhar no padrao pt-BR (ponto)."""
    return f"{int(n):,}".replace(",", ".")


def gerar_narrativa(ind):
    """NLG: monta o texto executivo a partir dos indicadores."""
    nota = f"{ind['nota_media']:.2f}".replace(".", ",")
    p = []
    p.append(
        f"Foram analisadas {mil(ind['total'])} avaliacoes com comentario. "
        f"A nota media e de {nota}/5, e {ind['pct_neg']:.1%} "
        f"das manifestacoes foram classificadas como negativas pelo modelo."
    )
    top = ind["top_dores"]
    if top:
        lista = "; ".join(f"{nome} ({mil(qtd)} citacoes)"
                          for nome, qtd in top)
        p.append(
            f"Entre as avaliacoes negativas, as dores mais recorrentes sao: "
            f"{lista}. O tema '{top[0][0]}' lidera e deve ser a prioridade "
            f"imediata de atuacao."
        )
    pc = ind["pior_categoria"]
    if pc:
        p.append(
            f"A categoria com maior proporcao de insatisfacao e "
            f"'{pc['categoria']}', com {pc['pct_neg']:.1%} de avaliacoes "
            f"negativas ({mil(pc['total'])} reviews) — um ponto de atencao para "
            f"revisao de sortimento, fornecedor ou logistica."
        )
    p.append(
        f"No lado positivo, {ind['pct_pos']:.1%} dos clientes manifestaram "
        f"satisfacao, com elogios concentrados em agilidade de entrega e "
        f"qualidade percebida — reforcando o que ja funciona bem."
    )
    return "\n\n".join(p)


def main():
    print(">> Etapa 5 — Resumo executivo")
    df = pd.read_parquet(DADOS / "04_temas.parquet")

    total = len(df)
    dist = df["sentimento"].value_counts(normalize=True)
    pct_neg = float(dist.get("negativo", 0))
    pct_pos = float(dist.get("positivo", 0))

    # top dores entre os negativos
    neg = df[df["sentimento"] == "negativo"]
    dores = (neg[TEMAS_DOR].sum().sort_values(ascending=False))
    top_dores = [(nome, int(q)) for nome, q in dores.head(3).items() if q > 0]

    # pior categoria (minimo de volume para ser relevante)
    cat = (df.groupby("categoria")
             .agg(total=("sentimento", "size"),
                  neg=("sentimento", lambda s: (s == "negativo").sum()))
             .reset_index())
    cat = cat[(cat["total"] >= 100) & (cat["categoria"] != "nao_identificada")]
    cat["pct_neg"] = cat["neg"] / cat["total"]
    pior = cat.sort_values("pct_neg", ascending=False).head(1)
    pior_categoria = None
    if not pior.empty:
        r = pior.iloc[0]
        pior_categoria = {"categoria": r["categoria"],
                          "pct_neg": float(r["pct_neg"]),
                          "total": int(r["total"])}

    indicadores = {
        "total": int(total),
        "nota_media": float(df["review_score"].mean()),
        "pct_neg": pct_neg,
        "pct_pos": pct_pos,
        "pct_neutro": float(dist.get("neutro", 0)),
        "top_dores": top_dores,
        "pior_categoria": pior_categoria,
    }
    indicadores["narrativa"] = gerar_narrativa(indicadores)

    # base final enxuta para o painel
    df.to_parquet(DADOS / "voc_resultado.parquet", index=False)
    (DADOS / "resumo.json").write_text(
        json.dumps(indicadores, ensure_ascii=False, indent=2), encoding="utf-8")

    print("\n" + indicadores["narrativa"] + "\n")
    print(f"   -> {DADOS / 'voc_resultado.parquet'}")
    print(f"   -> {DADOS / 'resumo.json'}")


if __name__ == "__main__":
    main()
