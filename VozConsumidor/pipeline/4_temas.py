"""
Radar de Voz do Consumidor — Etapa 4: Mineracao de temas
---------------------------------------------------------------
Descobre SOBRE O QUE os clientes falam. Cada review recebe um ou
mais temas de negocio, por meio de um dicionario de termos curado
(interpretavel, pronto para leitura executiva).

Saida: dados/04_temas.parquet
"""

from pathlib import Path
import re
import pandas as pd

RAIZ = Path(__file__).resolve().parents[1]
DADOS = RAIZ / "dados"

# Dicionario de temas: tema -> termos que o caracterizam.
# Mapeia a linguagem do cliente em categorias que o negocio age.
TEMAS = {
    "Prazo de entrega": ["atras", "demor", "prazo", "ainda nao cheg",
                          "nao chegou", "tempo de entrega", "entrega rapid",
                          "chegou antes", "chegou rapido", "chegou no prazo"],
    "Produto nao recebido": ["nao recebi", "nunca chegou", "nao entregue",
                             "extravi", "sumiu", "nao foi entregue"],
    "Qualidade / defeito": ["defeit", "quebrad", "danificad", "estragad",
                            "ruim", "pessima qualidade", "veio quebr",
                            "nao funciona", "parou de funcionar"],
    "Produto errado / incompleto": ["errad", "diferente", "nao era",
                                    "faltou", "incomplet", "veio so",
                                    "produto trocad"],
    "Atendimento / suporte": ["atendiment", "suporte", "sac", "resposta",
                              "nao responde", "contato", "reclamacao"],
    "Reembolso / estorno": ["estorno", "reembols", "dinheiro de volta",
                            "devolucao", "cancel", "nao devolveram"],
    "Embalagem": ["embalagem", "caixa", "mal embalad", "lacre", "aberto"],
    "Elogio geral": ["otimo", "excelente", "recomend", "amei", "perfeito",
                     "satisfeit", "muito bom", "maravilhos", "adorei",
                     "super indico"],
}


def normaliza(texto):
    texto = texto.lower()
    acentos = str.maketrans("áàâãäéèêëíìîïóòôõöúùûüç",
                            "aaaaaeeeeiiiiooooouuuuc")
    return texto.translate(acentos)


def main():
    print(">> Etapa 4 — Mineracao de temas")
    df = pd.read_parquet(DADOS / "03_classificado.parquet")
    txt = df["comentario"].map(normaliza)

    for tema, termos in TEMAS.items():
        padrao = "|".join(re.escape(t) for t in termos)
        df[tema] = txt.str.contains(padrao, regex=True, na=False)

    df["sem_tema"] = ~df[list(TEMAS)].any(axis=1)
    cobertura = 1 - df["sem_tema"].mean()
    df.to_parquet(DADOS / "04_temas.parquet", index=False)

    print(f"   cobertura por temas: {cobertura:.1%}")
    tot = df[list(TEMAS)].sum().sort_values(ascending=False)
    print(tot.to_string())
    print(f"   -> {DADOS / '04_temas.parquet'}")


if __name__ == "__main__":
    main()
