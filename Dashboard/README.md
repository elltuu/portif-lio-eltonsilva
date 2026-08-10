# 📊 Painel Executivo de E-commerce (Olist) — R / Shiny

Dashboard interativo que analisa o marketplace brasileiro **Olist**, transformando
~100 mil pedidos em indicadores de **vendas, logística, pagamentos e satisfação**
para apoiar decisões de negócio.

**Autor:** Elton Jose da Silva · **Stack:** R, Shiny, shinydashboard, dplyr, plotly, DT

---

## 🎯 O que o painel responde
- **Vendas:** receita por mês, ticket médio, categorias que mais faturam
- **Logística:** prazo médio de entrega, % no prazo x atrasos, desempenho por estado
- **Geografia:** receita e pedidos por UF
- **Pagamentos:** mix de meios de pagamento, parcelamento, ticket por meio
- **Satisfação:** distribuição de notas, evolução mensal, melhores e piores categorias

Filtros globais de **período** e **estado (UF)** atualizam todo o painel.

---

## ▶️ Como rodar

**Pré-requisitos:** R (4.x) e RStudio.

1. **Baixe os dados** no Kaggle: *Brazilian E-Commerce Public Dataset by Olist*
   → https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
   Extraia os 9 arquivos `.csv` na pasta `olist_data/`.

2. No R, instale os pacotes (uma vez):
   ```r
   install.packages(c("shiny","shinydashboard","dplyr","tidyr","readr",
                      "lubridate","plotly","DT","scales","stringr"))
   ```

3. **Prepare os dados** (gera `olist_prepared.rds`):
   ```r
   source("prep_data.R")
   ```

4. **Abra `app.R` no RStudio e clique em `Run App`** (ou `shiny::runApp()`).

---

## 🗂 Estrutura
```
Dashboard/
├── app.R            # Aplicação Shiny (UI + servidor)
├── prep_data.R      # ETL: lê e junta as 9 tabelas, salva olist_prepared.rds
├── olist_data/      # CSVs do Kaggle (não versionado)
└── README.md
```

---

## 📄 Dados e licença
Dados públicos da **Olist**, disponibilizados no Kaggle sob licença de banco de dados
aberto (ODbL / DbCL). Uso aqui é **educacional/demonstrativo**, com os devidos créditos.
**Fonte: Olist / Kaggle.**
