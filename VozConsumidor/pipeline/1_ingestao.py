"""
Radar de Voz do Consumidor — Etapa 1: Ingestao
---------------------------------------------------------------
Carrega as avaliacoes dos clientes (base Olist) e enriquece cada
review com a categoria do produto comprado. Entrega um arquivo
limpo e compacto para as etapas seguintes.

Saida: dados/01_reviews.parquet
"""

from pathlib import Path
import re
import pandas as pd

RAIZ = Path(__file__).resolve().parents[1]          # .../VozConsumidor
DADOS_BRUTOS = RAIZ.parent / "Dashboard" / "olist_data"
SAIDA = RAIZ / "dados"
SAIDA.mkdir(parents=True, exist_ok=True)


def carregar():
    rev = pd.read_csv(
        DADOS_BRUTOS / "olist_order_reviews_dataset.csv",
        usecols=["review_id", "order_id", "review_score",
                 "review_comment_title", "review_comment_message",
                 "review_creation_date"],
        parse_dates=["review_creation_date"],
    )
    itens = pd.read_csv(DADOS_BRUTOS / "olist_order_items_dataset.csv",
                        usecols=["order_id", "product_id"])
    prod = pd.read_csv(DADOS_BRUTOS / "olist_products_dataset.csv",
                       usecols=["product_id", "product_category_name"])
    trad = pd.read_csv(DADOS_BRUTOS / "product_category_name_translation.csv")
    return rev, itens, prod, trad


def categoria_por_pedido(itens, prod, trad):
    """Define uma categoria principal por pedido (a mais frequente)."""
    base = itens.merge(prod, on="product_id", how="left")
    base = base.merge(trad, on="product_category_name", how="left")
    # categoria em pt-br, com fallback para a original
    base["categoria"] = (base["product_category_name_english"]
                         .fillna(base["product_category_name"]))
    base = base.dropna(subset=["categoria"])
    # categoria principal = a que mais aparece no pedido
    principal = (base.groupby("order_id")["categoria"]
                 .agg(lambda s: s.value_counts().idxmax())
                 .reset_index())
    return principal


def limpar_texto(serie):
    """Junta titulo + mensagem, normaliza espacos e caixa."""
    return (serie.fillna("")
                 .str.replace(r"\s+", " ", regex=True)
                 .str.strip())


def main():
    print(">> Etapa 1 — Ingestao")
    rev, itens, prod, trad = carregar()
    print(f"   reviews brutos: {len(rev):,}")

    cat = categoria_por_pedido(itens, prod, trad)
    rev = rev.merge(cat, on="order_id", how="left")
    rev["categoria"] = rev["categoria"].fillna("nao_identificada")

    # texto do comentario = titulo + mensagem
    titulo = limpar_texto(rev["review_comment_title"])
    msg = limpar_texto(rev["review_comment_message"])
    rev["comentario"] = (titulo + " " + msg).str.strip()
    rev["tem_comentario"] = rev["comentario"].str.len() > 0

    # rotulo de sentimento a partir da nota (usado no treino)
    def rotulo(n):
        if n <= 2:
            return "negativo"
        if n == 3:
            return "neutro"
        return "positivo"
    rev["sentimento_nota"] = rev["review_score"].apply(rotulo)

    cols = ["review_id", "order_id", "review_score", "sentimento_nota",
            "categoria", "comentario", "tem_comentario",
            "review_creation_date"]
    out = rev[cols].copy()
    out.to_parquet(SAIDA / "01_reviews.parquet", index=False)

    print(f"   com comentario: {out['tem_comentario'].sum():,}")
    print(f"   categorias: {out['categoria'].nunique()}")
    print(f"   -> {SAIDA / '01_reviews.parquet'}")


if __name__ == "__main__":
    main()
