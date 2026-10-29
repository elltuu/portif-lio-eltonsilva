"""
Radar de Voz do Consumidor — Painel
---------------------------------------------------------------
Le a base ja processada pelo pipeline e apresenta, em um painel
interativo, o que os clientes sentem e sobre o que falam.

Rodar local:  streamlit run app.py
"""

from pathlib import Path
import json
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import streamlit as st

RAIZ = Path(__file__).resolve().parent
DADOS = RAIZ / "dados"

# ----- Identidade visual (cores do portfolio) -----------------------------
NAVY = "#12315e"
DOURADO = "#b08a3e"
VERDE = "#1baf7a"
AMBAR = "#eda100"
VERMELHO = "#c0392b"
INK = "#1f2937"
COR_SENT = {"positivo": VERDE, "neutro": AMBAR, "negativo": VERMELHO}
ORDEM_SENT = ["negativo", "neutro", "positivo"]

st.set_page_config(page_title="Radar de Voz do Consumidor",
                   page_icon="📊", layout="wide",
                   initial_sidebar_state="expanded")

st.markdown(f"""
<style>
  .stApp {{ background:#f7f8fa; }}
  h1,h2,h3 {{ color:{NAVY}; font-family:'Segoe UI',sans-serif; }}
  .bloco {{ background:#fff; border:1px solid #e6e8ec; border-radius:14px;
           padding:18px 20px; box-shadow:0 1px 3px rgba(16,24,40,.04); }}
  .kpi-rot {{ color:#6b7280; font-size:.80rem; text-transform:uppercase;
             letter-spacing:.04em; }}
  .kpi-val {{ color:{NAVY}; font-size:2.0rem; font-weight:700; line-height:1.1; }}
  .resumo {{ border-left:4px solid {DOURADO}; background:#fffdf7;
            padding:16px 20px; border-radius:0 12px 12px 0;
            color:{INK}; line-height:1.6; font-size:.98rem; }}
</style>
""", unsafe_allow_html=True)


@st.cache_data
def carregar():
    df = pd.read_parquet(DADOS / "voc_resultado.parquet")
    df["review_creation_date"] = pd.to_datetime(df["review_creation_date"])
    resumo = json.loads((DADOS / "resumo.json").read_text(encoding="utf-8"))
    metrica = json.loads((DADOS / "metrica_modelo.json").read_text(encoding="utf-8"))
    return df, resumo, metrica


TEMAS = ["Prazo de entrega", "Produto nao recebido", "Qualidade / defeito",
         "Produto errado / incompleto", "Atendimento / suporte",
         "Reembolso / estorno", "Embalagem", "Elogio geral"]
TEMAS_DOR = [t for t in TEMAS if t != "Elogio geral"]

df, resumo, metrica = carregar()

# ------------------------------- Cabecalho ---------------------------------
st.markdown("# 📊 Radar de Voz do Consumidor")
st.markdown(
    "<p style='color:#6b7280;margin-top:-8px'>Inteligência de avaliações com "
    "NLP e machine learning — do comentário do cliente à decisão de negócio."
    "</p>", unsafe_allow_html=True)

# ------------------------------- Filtros -----------------------------------
with st.sidebar:
    st.header("Filtros")
    cats = (df[df["categoria"] != "nao_identificada"]["categoria"]
            .value_counts().index.tolist())
    sel_cat = st.multiselect("Categoria de produto", cats,
                             help="Vazio = todas as categorias")
    sel_sent = st.multiselect("Sentimento", ORDEM_SENT, default=ORDEM_SENT)
    dmin, dmax = df["review_creation_date"].min(), df["review_creation_date"].max()
    periodo = st.date_input("Período", (dmin.date(), dmax.date()),
                            min_value=dmin.date(), max_value=dmax.date())
    st.markdown("---")
    st.caption("Base: avaliações Olist (e-commerce Brasil). "
               "Modelo de sentimento treinado sobre o texto dos comentários.")

f = df.copy()
if sel_cat:
    f = f[f["categoria"].isin(sel_cat)]
if sel_sent:
    f = f[f["sentimento"].isin(sel_sent)]
if isinstance(periodo, (list, tuple)) and len(periodo) == 2:
    ini, fim = pd.to_datetime(periodo[0]), pd.to_datetime(periodo[1])
    f = f[(f["review_creation_date"] >= ini) &
          (f["review_creation_date"] <= fim + pd.Timedelta(days=1))]

if f.empty:
    st.warning("Nenhuma avaliação para os filtros selecionados.")
    st.stop()

# -------------------------------- KPIs -------------------------------------
dist = f["sentimento"].value_counts(normalize=True)
pct_neg = dist.get("negativo", 0)
pct_pos = dist.get("positivo", 0)
nps = pct_pos - pct_neg


def kpi(col, rotulo, valor):
    col.markdown(
        f"<div class='bloco'><div class='kpi-rot'>{rotulo}</div>"
        f"<div class='kpi-val'>{valor}</div></div>", unsafe_allow_html=True)


c1, c2, c3, c4 = st.columns(4)
kpi(c1, "Avaliações analisadas", f"{len(f):,}".replace(",", "."))
kpi(c2, "Nota média", f"{f['review_score'].mean():.2f}".replace(".", ","))
kpi(c3, "% Negativas", f"{pct_neg:.1%}".replace(".", ","))
kpi(c4, "Saldo de sentimento", f"{nps:+.1%}".replace(".", ","))

st.markdown("")

# -------------------------- Resumo executivo (IA) --------------------------
st.markdown("### 🧠 Resumo executivo")
st.markdown(f"<div class='resumo'>{resumo['narrativa'].replace(chr(10)+chr(10), '<br><br>')}</div>",
            unsafe_allow_html=True)
st.caption("Texto gerado automaticamente (NLG) a partir dos indicadores — "
           "reflete os filtros globais da base.")

st.markdown("")

# --------------------------- Linha 1 de graficos ---------------------------
g1, g2 = st.columns(2)

with g1:
    st.markdown("#### Distribuição de sentimento")
    d = (f["sentimento"].value_counts().reindex(ORDEM_SENT).fillna(0)
         .reset_index())
    d.columns = ["sentimento", "n"]
    fig = px.pie(d, names="sentimento", values="n", hole=.58,
                 color="sentimento", color_discrete_map=COR_SENT)
    fig.update_traces(textinfo="percent", sort=False)
    fig.update_layout(margin=dict(t=10, b=10, l=10, r=10), height=320,
                      legend_orientation="h", legend_y=-.1,
                      paper_bgcolor="rgba(0,0,0,0)")
    st.plotly_chart(fig, use_container_width=True)

with g2:
    st.markdown("#### Evolução mensal do sentimento")
    tmp = f.copy()
    tmp["mes"] = tmp["review_creation_date"].dt.to_period("M").dt.to_timestamp()
    evo = (tmp.groupby(["mes", "sentimento"]).size()
           .reset_index(name="n"))
    fig = px.area(evo, x="mes", y="n", color="sentimento",
                  color_discrete_map=COR_SENT,
                  category_orders={"sentimento": ORDEM_SENT})
    fig.update_layout(margin=dict(t=10, b=10, l=10, r=10), height=320,
                      legend_orientation="h", legend_y=-.2,
                      xaxis_title="", yaxis_title="avaliações",
                      paper_bgcolor="rgba(0,0,0,0)",
                      plot_bgcolor="rgba(0,0,0,0)")
    st.plotly_chart(fig, use_container_width=True)

# --------------------------- Linha 2 de graficos ---------------------------
g3, g4 = st.columns(2)

with g3:
    st.markdown("#### Principais dores (avaliações negativas)")
    neg = f[f["sentimento"] == "negativo"]
    dores = (neg[TEMAS_DOR].sum().sort_values(ascending=True)
             .reset_index())
    dores.columns = ["tema", "n"]
    dores = dores[dores["n"] > 0]
    fig = px.bar(dores, x="n", y="tema", orientation="h", text="n")
    fig.update_traces(marker_color=VERMELHO, textposition="outside")
    fig.update_layout(margin=dict(t=10, b=10, l=10, r=10), height=340,
                      xaxis_title="citações", yaxis_title="",
                      paper_bgcolor="rgba(0,0,0,0)",
                      plot_bgcolor="rgba(0,0,0,0)")
    st.plotly_chart(fig, use_container_width=True)

with g4:
    st.markdown("#### Categorias com mais insatisfação")
    cat = (f[f["categoria"] != "nao_identificada"]
           .groupby("categoria")
           .agg(total=("sentimento", "size"),
                neg=("sentimento", lambda s: (s == "negativo").sum()))
           .reset_index())
    cat = cat[cat["total"] >= 50]
    cat["pct_neg"] = cat["neg"] / cat["total"]
    cat = cat.sort_values("pct_neg", ascending=False).head(10)
    cat = cat.sort_values("pct_neg")
    fig = px.bar(cat, x="pct_neg", y="categoria", orientation="h",
                 text=cat["pct_neg"].map(lambda v: f"{v:.0%}"))
    fig.update_traces(marker_color=NAVY, textposition="outside")
    fig.update_layout(margin=dict(t=10, b=10, l=10, r=10), height=340,
                      xaxis_tickformat=".0%", xaxis_title="% negativas",
                      yaxis_title="", paper_bgcolor="rgba(0,0,0,0)",
                      plot_bgcolor="rgba(0,0,0,0)")
    st.plotly_chart(fig, use_container_width=True)

# ----------------------- Desempenho do modelo ------------------------------
st.markdown("### 🎯 Desempenho do modelo")
m1, m2 = st.columns([1, 1.3])
with m1:
    st.markdown(
        f"<div class='bloco'><div class='kpi-rot'>Acurácia (teste)</div>"
        f"<div class='kpi-val'>{metrica['acuracia']:.1%}</div>"
        f"<div class='kpi-rot' style='margin-top:12px'>F1-macro</div>"
        f"<div class='kpi-val'>{metrica['f1_macro']:.2f}</div></div>",
        unsafe_allow_html=True)
    st.caption(f"Treino: {metrica['n_treino']:,} · Teste: {metrica['n_teste']:,}"
               .replace(",", "."))
with m2:
    st.markdown("#### Matriz de confusão")
    cm = metrica["matriz_confusao"]
    classes = metrica["classes"]
    fig = px.imshow(cm, x=classes, y=classes, text_auto=True,
                    color_continuous_scale="Blues", aspect="auto",
                    labels=dict(x="previsto", y="real", color="n"))
    fig.update_layout(margin=dict(t=10, b=10, l=10, r=10), height=300,
                      coloraxis_showscale=False,
                      paper_bgcolor="rgba(0,0,0,0)")
    st.plotly_chart(fig, use_container_width=True)

# --------------------------- Amostra de reviews ----------------------------
with st.expander("🔎 Ver avaliações (amostra filtrada)"):
    amostra = (f[["review_score", "sentimento", "confianca",
                  "categoria", "comentario"]]
               .sort_values("confianca", ascending=False).head(200))
    st.dataframe(amostra, use_container_width=True, hide_index=True)

st.markdown("---")
st.caption("Pipeline em Python (pandas · scikit-learn · NLP) · painel em "
           "Streamlit · dados públicos Olist. Desenvolvido por Elton Jose da Silva.")
