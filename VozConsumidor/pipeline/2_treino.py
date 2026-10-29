"""
Radar de Voz do Consumidor — Etapa 2: Treino do modelo
---------------------------------------------------------------
Treina um classificador de sentimento (negativo / neutro / positivo)
a partir do TEXTO do comentario, usando a nota de 1 a 5 como rotulo.

Tecnica: TF-IDF (1 a 2 n-gramas) + Regressao Logistica com pesos
balanceados por classe. Simples, interpretavel e forte para texto.

Saidas:
  modelo/sentimento.joblib   -> pipeline treinado (vetor + modelo)
  dados/metrica_modelo.json  -> acuracia, F1 e matriz de confusao
"""

from pathlib import Path
import json
import re
import joblib
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.model_selection import train_test_split
from sklearn.metrics import (accuracy_score, f1_score,
                             classification_report, confusion_matrix)

RAIZ = Path(__file__).resolve().parents[1]
DADOS = RAIZ / "dados"
MODELO = RAIZ / "modelo"
MODELO.mkdir(parents=True, exist_ok=True)

# Stopwords de portugues (lista enxuta, sem dependencia externa)
STOP_PT = {
    "a", "o", "e", "de", "da", "do", "das", "dos", "em", "um", "uma", "uns",
    "umas", "no", "na", "nos", "nas", "ao", "aos", "que", "com", "para", "por",
    "se", "os", "as", "me", "meu", "minha", "foi", "ja", "mas", "muito", "mais",
    "sua", "seu", "ele", "ela", "eu", "voce", "esta", "este", "isso", "sao",
    "ser", "ter", "tem", "pra", "pela", "pelo", "ate", "la", "aqui", "sem",
}


def normaliza(texto):
    """Minuscula, remove acentos simples e pontuacao."""
    texto = texto.lower()
    acentos = str.maketrans("áàâãäéèêëíìîïóòôõöúùûüç",
                            "aaaaaeeeeiiiiooooouuuuc")
    texto = texto.translate(acentos)
    texto = re.sub(r"[^a-z\s]", " ", texto)
    return re.sub(r"\s+", " ", texto).strip()


def main():
    print(">> Etapa 2 — Treino do modelo")
    df = pd.read_parquet(DADOS / "01_reviews.parquet")
    df = df[df["tem_comentario"]].copy()
    df["texto"] = df["comentario"].map(normaliza)
    df = df[df["texto"].str.len() >= 3]
    print(f"   amostras com texto: {len(df):,}")

    X, y = df["texto"], df["sentimento_nota"]
    X_tr, X_te, y_tr, y_te = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y)

    modelo = Pipeline([
        ("tfidf", TfidfVectorizer(ngram_range=(1, 2), min_df=5,
                                  max_features=30000, stop_words=list(STOP_PT))),
        ("clf", LogisticRegression(max_iter=1000, class_weight="balanced",
                                   C=4.0, n_jobs=-1)),
    ])
    modelo.fit(X_tr, y_tr)

    pred = modelo.predict(X_te)
    acc = accuracy_score(y_te, pred)
    f1m = f1_score(y_te, pred, average="macro")
    print(f"   acuracia: {acc:.3f}  |  F1-macro: {f1m:.3f}")
    print(classification_report(y_te, pred))

    classes = ["negativo", "neutro", "positivo"]
    cm = confusion_matrix(y_te, pred, labels=classes)

    joblib.dump(modelo, MODELO / "sentimento.joblib")
    metrica = {
        "acuracia": round(float(acc), 4),
        "f1_macro": round(float(f1m), 4),
        "n_treino": int(len(X_tr)),
        "n_teste": int(len(X_te)),
        "classes": classes,
        "matriz_confusao": cm.tolist(),
        "relatorio": classification_report(y_te, pred, output_dict=True),
    }
    (DADOS / "metrica_modelo.json").write_text(
        json.dumps(metrica, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"   -> {MODELO / 'sentimento.joblib'}")
    print(f"   -> {DADOS / 'metrica_modelo.json'}")


if __name__ == "__main__":
    main()
