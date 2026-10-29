"""
Radar de Voz do Consumidor — Etapa 3: Classificacao
---------------------------------------------------------------
Aplica o modelo treinado em TODOS os comentarios, gerando o
sentimento previsto e a confianca da previsao.

Saida: dados/03_classificado.parquet
"""

from pathlib import Path
import re
import joblib
import pandas as pd

RAIZ = Path(__file__).resolve().parents[1]
DADOS = RAIZ / "dados"
MODELO = RAIZ / "modelo"


def normaliza(texto):
    texto = texto.lower()
    acentos = str.maketrans("áàâãäéèêëíìîïóòôõöúùûüç",
                            "aaaaaeeeeiiiiooooouuuuc")
    texto = texto.translate(acentos)
    texto = re.sub(r"[^a-z\s]", " ", texto)
    return re.sub(r"\s+", " ", texto).strip()


def main():
    print(">> Etapa 3 — Classificacao")
    modelo = joblib.load(MODELO / "sentimento.joblib")
    df = pd.read_parquet(DADOS / "01_reviews.parquet")
    com = df[df["tem_comentario"]].copy()
    com["texto"] = com["comentario"].map(normaliza)
    com = com[com["texto"].str.len() >= 3]

    com["sentimento"] = modelo.predict(com["texto"])
    com["confianca"] = modelo.predict_proba(com["texto"]).max(axis=1).round(3)

    out = com.drop(columns=["texto", "tem_comentario"])
    out.to_parquet(DADOS / "03_classificado.parquet", index=False)
    print(f"   classificados: {len(out):,}")
    print(out["sentimento"].value_counts().to_string())
    print(f"   -> {DADOS / '03_classificado.parquet'}")


if __name__ == "__main__":
    main()
