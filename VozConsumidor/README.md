# 📊 Radar de Voz do Consumidor

Inteligência de avaliações de clientes com **NLP e machine learning**: do
comentário em texto livre à decisão de negócio. Um pipeline automatizado em
Python lê milhares de avaliações, classifica o sentimento com um modelo
treinado sobre os próprios dados, descobre **sobre o que** os clientes falam e
entrega um painel interativo com um resumo executivo.

**Painel ao vivo:** _(link após publicação no Streamlit Community Cloud)_

---

## Por que este projeto

A pergunta central de qualquer área de insights de consumo é _"o que o cliente
sente e por quê?"_. Este projeto responde isso de forma escalável e
reproduzível, transformando texto não estruturado em prioridades acionáveis
(prazo de entrega, qualidade, atendimento, reembolso…).

## Como funciona

```
pipeline/
  1_ingestao.py    Carrega as avaliações e enriquece com a categoria do produto
  2_treino.py      Treina o classificador de sentimento (TF-IDF + Reg. Logística)
  3_classifica.py  Aplica o modelo em todas as avaliações (sentimento + confiança)
  4_temas.py       Minera os temas de cada manifestação (dicionário curado)
  5_resumo.py      Gera o resumo executivo (NLG, 100% offline / LGPD)
app.py             Painel Streamlit que lê o resultado compacto
```

Rodar tudo:

```bash
pip install -r requirements.txt
python pipeline/run_all.py
streamlit run app.py
```

## Modelo

- **Técnica:** TF-IDF (1–2 n-gramas) + Regressão Logística com pesos
  balanceados por classe.
- **Rótulo:** derivado da nota de 1 a 5 (negativo / neutro / positivo).
- **Desempenho:** ~80% de acurácia em teste; a classe "neutro" é
  naturalmente ambígua e puxa o F1-macro para baixo — reportado com
  transparência na matriz de confusão do painel.

## Dados

Base pública **Olist** (e-commerce brasileiro, ~100 mil pedidos). Os CSVs
brutos não são versionados; o painel consome apenas o artefato compacto
gerado pelo pipeline (`dados/voc_resultado.parquet`).

## Stack

`Python` · `pandas` · `scikit-learn` · `NLP` · `Streamlit` · `Plotly`

---

Desenvolvido por **Elton Jose da Silva** — Analista de Dados & BI.
