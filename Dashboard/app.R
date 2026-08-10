# =====================================================================
# app.R — Painel Executivo de E-commerce (dataset Olist)
# Autor: Elton Jose da Silva  |  Fonte: Olist / Kaggle
# Stack: R, Shiny, bs4Dash, dplyr, plotly, DT
# Rodar:  1) Rscript prep_data.R   2) abrir no RStudio e "Run App"
# =====================================================================

suppressPackageStartupMessages({
  library(shiny); library(bs4Dash); library(fresh); library(dplyr); library(tidyr)
  library(lubridate); library(plotly); library(DT); library(scales); library(stringr)
  library(jsonlite)
})
source("tema.R")

if (!file.exists("olist_prepared.rds"))
  stop("Arquivo 'olist_prepared.rds' nao encontrado. Rode antes:  Rscript prep_data.R")
DADOS <- readRDS("olist_prepared.rds")$orders

# Mapa dos estados (GeoJSON leve gerado por prep_map.R)
GEO <- tryCatch(jsonlite::fromJSON("br_mapa.geojson", simplifyVector = FALSE), error = function(e) NULL)

# UF -> Região
REGIAO <- c(AC="Norte",AP="Norte",AM="Norte",PA="Norte",RO="Norte",RR="Norte",TO="Norte",
  AL="Nordeste",BA="Nordeste",CE="Nordeste",MA="Nordeste",PB="Nordeste",PE="Nordeste",
  PI="Nordeste",RN="Nordeste",SE="Nordeste", DF="Centro-Oeste",GO="Centro-Oeste",
  MT="Centro-Oeste",MS="Centro-Oeste", ES="Sudeste",MG="Sudeste",RJ="Sudeste",SP="Sudeste",
  PR="Sul",RS="Sul",SC="Sul")

# rótulos e hovertemplates por métrica do mapa/ranking
MET_ROT <- c(receita="Receita", pedidos="Pedidos", ticket="Ticket médio",
             nota="Nota média", prazo="Prazo médio (dias)")
hov_mapa <- function(m) switch(m,
  receita = "<b>%{location}</b><br>Receita: R$ %{z:,.0f}<extra></extra>",
  pedidos = "<b>%{location}</b><br>Pedidos: %{z:,}<extra></extra>",
  ticket  = "<b>%{location}</b><br>Ticket médio: R$ %{z:,.2f}<extra></extra>",
  nota    = "<b>%{location}</b><br>Nota média: %{z:.2f}<extra></extra>",
  prazo   = "<b>%{location}</b><br>Prazo médio: %{z:.1f} dias<extra></extra>")
hov_rank <- function(m) switch(m,
  receita = "%{y}<br>R$ %{x:,.0f}<extra></extra>",
  pedidos = "%{y}<br>%{x:,} pedidos<extra></extra>",
  ticket  = "%{y}<br>R$ %{x:,.2f}<extra></extra>",
  nota    = "%{y}<br>Nota %{x:.2f}<extra></extra>",
  prazo   = "%{y}<br>%{x:.1f} dias<extra></extra>")

# Formatadores pt-BR
brl  <- function(x) paste0("R$ ", formatC(x, format = "f", digits = 0, big.mark = ".", decimal.mark = ","))
brl2 <- function(x) paste0("R$ ", formatC(x, format = "f", digits = 2, big.mark = ".", decimal.mark = ","))
num  <- function(x) formatC(x, format = "d", big.mark = ".", decimal.mark = ",")

pagina <- function(t, s) shiny::tagList(shiny::h2(t, class = "page-title"), shiny::p(s, class = "page-sub"))

MESES <- c("Jan","Fev","Mar","Abr","Mai","Jun","Jul","Ago","Set","Out","Nov","Dez")
DIAS  <- c("Seg","Ter","Qua","Qui","Sex","Sáb","Dom")
PMIN  <- as.Date(min(DADOS$data_compra, na.rm = TRUE))
PMAX  <- as.Date(max(DADOS$data_compra, na.rm = TRUE))

# ---------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------
ui <- dashboardPage(
  freshTheme = tema_olist, dark = NULL, help = NULL, fullscreen = FALSE,
  title = "Olist — Painel Executivo",
  header = dashboardHeader(title = dashboardBrand(title = "Olist", color = NULL), status = "white", border = TRUE),
  sidebar = dashboardSidebar(skin = "light", status = "primary", elevation = 1, fixed = TRUE,
    sidebarMenu(id = "menu",
      menuItem("Visão Geral", tabName = "geral", icon = icon("gauge-high")),
      menuItem("Logística", tabName = "logistica", icon = icon("truck")),
      menuItem("Geografia", tabName = "geo", icon = icon("map-location-dot")),
      menuItem("Pagamentos", tabName = "pgto", icon = icon("credit-card")),
      menuItem("Satisfação", tabName = "satisf", icon = icon("star")),
      menuItem("Dados", tabName = "dados", icon = icon("table"))
    )
  ),
  body = dashboardBody(
    tags$head(tags$style(css_olist)), js_kpi_nav, js_resize,
    # ── Barra de filtros no topo (vale para todas as abas) ──
    div(class = "topbar-filtros",
      div(class = "filtros-cab", style = "justify-content:space-between;",
          span(icon("filter"), "Filtros"),
          actionButton("limpar", "Limpar filtros", icon = icon("eraser"), class = "btn-limpar")),
      fluidRow(
        column(4, dateRangeInput("periodo", "Período (compra)",
          start = as.Date(min(DADOS$data_compra, na.rm = TRUE)),
          end   = as.Date(max(DADOS$data_compra, na.rm = TRUE)),
          min   = as.Date(min(DADOS$data_compra, na.rm = TRUE)),
          max   = as.Date(max(DADOS$data_compra, na.rm = TRUE)),
          separator = "até", language = "pt-BR", format = "dd/mm/yyyy")),
        column(4, selectizeInput("estado", "Estado (UF)",
          choices = sort(unique(na.omit(DADOS$estado))), multiple = TRUE,
          options = list(placeholder = "Todos os estados"))),
        column(4, selectizeInput("categoria", "Categoria",
          choices = sort(unique(na.omit(DADOS$categoria))), multiple = TRUE,
          options = list(placeholder = "Todas as categorias")))
      )
    ),
    tabItems(
      tabItem("geral",
        pagina("Visão Geral do Marketplace", "Momentum, concentração e retenção — a leitura executiva do negócio."),
        uiOutput("kpis_geral"),
        fluidRow(
          box(title = titulo_info("Receita e média móvel (3 meses)", "Linha cheia = receita mensal; pontilhada âmbar = média móvel de 3 meses (suaviza a sazonalidade)."),
              width = 8, collapsible = FALSE, plotlyOutput("g_receita_mes", height = 300)),
          box(title = titulo_info("Crescimento mês a mês", "Variação % da receita frente ao mês anterior. Verde = alta, vermelho = queda."),
              width = 4, collapsible = FALSE, plotlyOutput("g_cresc_mom", height = 300))
        ),
        fluidRow(
          box(title = titulo_info("Concentração de categorias (Pareto 80/20)", "Barras = receita por categoria; linha = % acumulado. Mostra quantas categorias concentram a maior parte da receita."),
              width = 8, collapsible = FALSE, plotlyOutput("g_pareto_cat", height = 340)),
          box(title = titulo_info("Novos vs Recorrentes", "Pedidos por mês conforme o cliente compra pela 1ª vez (novo) ou volta a comprar (recorrente)."),
              width = 4, collapsible = FALSE, plotlyOutput("g_novos_recorr", height = 340))
        ),
        fluidRow(
          box(title = titulo_info("Ticket médio × Volume", "Barras = pedidos; linha = ticket médio. Revela se o crescimento vem de mais pedidos ou de tickets maiores."),
              width = 6, collapsible = FALSE, plotlyOutput("g_ticket_volume", height = 320)),
          box(title = titulo_info("Sazonalidade dos pedidos", "Volume de pedidos por mês do ano e dia da semana — cores mais fortes = mais pedidos."),
              width = 6, collapsible = FALSE, plotlyOutput("g_saz", height = 320))
        ),
        fluidRow(
          box(title = titulo_info("Categorias por receita", "Área de cada bloco = receita da categoria (composição do portfólio)."),
              width = 12, collapsible = FALSE, plotlyOutput("g_treemap_cat", height = 300))
        ),
        guia(
          "<b>Momentum:</b> use a <b>média móvel</b> e o <b>crescimento MoM</b> para ver a tendência real, sem o ruído dos picos sazonais.",
          "<b>Concentração:</b> a <b>curva de Pareto</b> mostra o 80/20 do portfólio — poucas categorias sustentam a receita; foque nelas e questione a cauda longa.",
          "<b>Retenção:</b> <b>Novos vs Recorrentes</b> e a <b>taxa de recompra</b> revelam o maior ponto de alavancagem de marcas de consumo — reter custa menos que adquirir.",
          "<b>Drivers de receita:</b> em <b>Ticket × Volume</b>, veja se o crescimento vem de preço (ticket) ou de volume (pedidos) — cada caso pede uma estratégia.",
          "Meses com dados incompletos são omitidos das séries temporais para não distorcer a leitura."
        )
      ),
      tabItem("logistica",
        pagina("Logística & Prazo de Entrega", "Do clique à porta do cliente: onde o tempo vai, promessa vs realidade e nível de serviço."),
        uiOutput("kpis_log"),
        fluidRow(
          box(title = titulo_info("Nível de serviço (no prazo)", "Percentual de pedidos entregues até a data estimada."),
              width = 4, collapsible = FALSE, plotlyOutput("g_gauge_prazo", height = 300)),
          box(title = titulo_info("SLA no prazo por mês", "Evolução do % de entregas dentro do prazo — o serviço está melhorando?"),
              width = 8, collapsible = FALSE, plotlyOutput("g_sla_mes", height = 300))
        ),
        fluidRow(
          box(title = titulo_info("Onde o tempo vai (lead time)", "Decomposição do prazo médio: aprovação do pagamento, manuseio/despacho e transporte."),
              width = 6, collapsible = FALSE, plotlyOutput("g_lead_comp", height = 300)),
          box(title = titulo_info("Prazo de entrega por região", "Distribuição do prazo (mediana, quartis e amplitude) em cada macrorregião — mostra não só o valor típico, mas a variabilidade."),
              width = 6, collapsible = FALSE, plotlyOutput("g_prazo_regiao", height = 300))
        ),
        fluidRow(
          box(title = titulo_info("Antes ou depois do prometido?", "Distribuição de dias de antecipação (verde) ou atraso (vermelho) frente à data estimada."),
              width = 6, collapsible = FALSE, plotlyOutput("g_dist_prometido", height = 320)),
          box(title = titulo_info("Satisfação × Prazo", "Cada ponto é um estado; tamanho = volume de pedidos."),
              width = 6, collapsible = FALSE, plotlyOutput("g_nota_prazo", height = 320))
        ),
        fluidRow(
          box(title = titulo_info("Prometido vs Realizado por estado", "Ponto azul = prazo real; âmbar = prazo prometido. A distância é o 'colchão' de cada UF."),
              width = 8, collapsible = FALSE, plotlyOutput("g_dumbbell_uf", height = 400)),
          box(title = titulo_info("Prazo médio por estado", "15 UFs mais lentas."),
              width = 4, collapsible = FALSE, plotlyOutput("g_prazo_uf", height = 400))
        ),
        guia(
          "<b>Nível de serviço:</b> o <b>gauge</b> e o <b>SLA mensal</b> mostram o cumprimento do prazo — a métrica que o cliente sente.",
          "<b>Onde o tempo vai:</b> a decomposição revela que o <b>transporte</b> é o maior componente do lead time — é ali que estão os maiores ganhos.",
          "<b>Promessa vs realidade:</b> a distribuição e o gráfico por estado mostram que o marketplace entrega, em média, ~11 dias <b>antes</b> do prometido — há espaço para prometer prazos mais competitivos.",
          "<b>Prazo × satisfação:</b> estados mais distantes têm prazos maiores e notas menores — priorize logística onde o impacto na experiência é maior.",
          "Meses e pedidos incompletos são omitidos para não distorcer a leitura."
        )
      ),
      tabItem("geo",
        pagina("Distribuição Geográfica", "Explore o marketplace pelo mapa — escolha a métrica e passe o mouse nos estados."),
        uiOutput("kpis_geo"),
        div(class = "geo-metrica-bar",
            span(class = "geo-metrica-lbl", icon("sliders"), "Métrica do mapa e do ranking:"),
            div(class = "geo-metrica",
                radioButtons("geo_metrica", NULL, inline = TRUE,
                  choices = c("Receita" = "receita", "Pedidos" = "pedidos", "Ticket médio" = "ticket",
                              "Nota" = "nota", "Prazo" = "prazo"), selected = "receita"))),
        fluidRow(
          box(title = titulo_info("Mapa do Brasil", "Coroplético por estado. Passe o mouse para ver os valores; use a roda do mouse para dar zoom."),
              width = 6, collapsible = FALSE, plotlyOutput("g_mapa", height = 500)),
          box(title = titulo_info("Ranking de estados", "Top 12 estados pela métrica selecionada acima."),
              width = 6, collapsible = FALSE, plotlyOutput("g_rank_uf", height = 500))
        ),
        fluidRow(
          box(title = titulo_info("Receita por região", "Participação de cada macrorregião na receita."),
              width = 4, collapsible = FALSE, plotlyOutput("g_regiao_donut", height = 340)),
          box(title = titulo_info("Fluxo vendedor → cliente", "Para os clientes de cada região (coluna), de qual região vêm os pedidos (linha). Explica os prazos: quase tudo sai do Sudeste."),
              width = 8, collapsible = FALSE, plotlyOutput("g_fluxo", height = 340))
        ),
        fluidRow(
          box(title = titulo_info("Volume x Valor por estado", "Eixo X = pedidos (log), Y = ticket médio, tamanho = receita, cor = região."),
              width = 8, collapsible = FALSE, plotlyOutput("g_bubble_uf", height = 340)),
          box(title = titulo_info("Resumo por estado", "Todos os estados, ordenável — role para ver mais."),
              width = 4, collapsible = FALSE, DTOutput("tabela_uf"))
        ),
        guia(
          "Escolha a <b>métrica</b> acima: o <b>mapa</b> e o <b>ranking</b> se atualizam juntos (receita, pedidos, ticket, nota ou prazo).",
          "O <b>fluxo vendedor → cliente</b> é a chave da logística: quase tudo sai do <b>Sudeste</b> — por isso Norte/Nordeste têm os maiores prazos. Aproximar vendedores desses mercados encurta a entrega.",
          "Em <b>Volume × Valor</b>, priorize por quadrante: muito volume + ticket baixo pede upsell; ticket alto + pouco volume pede expansão.",
          "A <b>receita por região</b> mostra a concentração no Sudeste — insumo para decisões de expansão e malha logística."
        )
      ),
      tabItem("pgto",
        pagina("Meios de Pagamento", "Mix, parcelamento e financiamento — como o pagamento molda o ticket e a receita."),
        uiOutput("kpis_pgto"),
        fluidRow(
          box(title = titulo_info("Valor do pedido por meio de pagamento", "Distribuição do valor por meio (mediana, quartis e amplitude) — o cartão realmente habilita tickets maiores?"),
              width = 5, collapsible = FALSE, plotlyOutput("g_valor_meio", height = 330)),
          box(title = titulo_info("Evolução do mix de pagamento", "Participação (%) de cada meio ao longo do tempo — o cartão de crédito está ganhando espaço?"),
              width = 7, collapsible = FALSE, plotlyOutput("g_mix_evol", height = 330))
        ),
        fluidRow(
          box(title = titulo_info("Ticket médio por nº de parcelas", "Quanto maior o parcelamento, maior o ticket? O financiamento habilita compras maiores."),
              width = 6, collapsible = FALSE, plotlyOutput("g_ticket_parcelas", height = 320)),
          box(title = titulo_info("Parcelamento por faixa de valor", "Dado o valor do pedido, como ele é parcelado — pedidos caros tendem a financiar mais."),
              width = 6, collapsible = FALSE, plotlyOutput("g_heat_parc", height = 320))
        ),
        fluidRow(
          box(title = titulo_info("Pagamento → parcelamento", "Anel interno = meio de pagamento; anel externo = faixa de parcelas."),
              width = 6, collapsible = FALSE, plotlyOutput("g_sunburst_pag", height = 340)),
          box(title = titulo_info("Distribuição do nº de parcelas", "Quantos pedidos em cada número de parcelas (1 a 24)."),
              width = 6, collapsible = FALSE, plotlyOutput("g_parcelas", height = 340))
        ),
        guia(
          "<b>Mix e evolução:</b> o cartão de crédito domina e o parcelamento é a norma — a <b>evolução</b> mostra se essa dependência cresce ao longo do tempo.",
          "<b>Financiamento habilita ticket:</b> em <b>ticket × parcelas</b>, o valor médio sobe com o número de parcelas — parcelar não é só conveniência, é alavanca de venda.",
          "<b>Onde se financia:</b> o <b>heatmap</b> mostra que pedidos de maior valor concentram os parcelamentos longos — insumo para políticas de crédito e promoções.",
          "<b>Risco e caixa:</b> mais receita parcelada = mais recebíveis a prazo — relevante para fluxo de caixa e negociação com adquirentes."
        )
      ),
      tabItem("satisf",
        pagina("Satisfação do Cliente", "O que move a nota — e onde agir. Da distribuição aos drivers e às categorias críticas."),
        uiOutput("kpis_sat"),
        fluidRow(
          box(title = titulo_info("Distribuição das notas", "Quantidade de avaliações por nota (1 a 5)."),
              width = 5, collapsible = FALSE, plotlyOutput("g_notas", height = 320)),
          box(title = titulo_info("Evolução da satisfação", "Nota média (linha) e participação de avaliações negativas (área) ao longo do tempo."),
              width = 7, collapsible = FALSE, plotlyOutput("g_evol_sat", height = 320))
        ),
        fluidRow(
          box(title = titulo_info("Impacto do prazo na nota", "Nota média conforme a entrega foi adiantada, no prazo ou atrasada — o principal driver de insatisfação."),
              width = 5, collapsible = FALSE, plotlyOutput("g_prazo_nota", height = 320)),
          box(title = titulo_info("Nota × Volume por categoria", "Cada bolha é uma categoria: X = pedidos (log), Y = nota média. Alvo prioritário: alto volume + nota baixa."),
              width = 7, collapsible = FALSE, plotlyOutput("g_nota_vol_cat", height = 320))
        ),
        fluidRow(
          box(title = titulo_info("Categorias acima e abaixo da média", "Diferença da nota da categoria frente à média geral — verde acima, vermelho abaixo (mín. 100 pedidos)."),
              width = 12, collapsible = FALSE, plotlyOutput("g_cat_dif", height = 420))
        ),
        guia(
          "<b>Prazo é o driver nº 1:</b> em <b>Impacto do prazo na nota</b>, a nota despenca quando a entrega atrasa — melhorar logística é melhorar satisfação.",
          "<b>Onde agir primeiro:</b> em <b>Nota × Volume</b>, priorize categorias no canto inferior direito (muito volume + nota baixa) — maior retorno por correção.",
          "<b>Saúde da base:</b> o <b>índice NPS-like</b> (promotores − detratores) resume a satisfação; acompanhe a <b>evolução</b> para pegar quedas cedo.",
          "<b>Curadoria de portfólio:</b> categorias <b>abaixo da média</b> pedem ação (vendedores, expectativa de prazo); as <b>acima</b> são candidatas a destaque."
        )
      ),
      tabItem("dados",
        pagina("Amostra dos Dados", "Base de pedidos enriquecida (até 1.000 linhas do recorte atual)."),
        box(width = 12, collapsible = FALSE, DTOutput("tabela")),
        guia(
          "Esta tabela é a <b>base por trás dos gráficos</b> — cada linha é um pedido, já com receita, prazo, pagamento e nota.",
          "Use a <b>busca</b> e a ordenação das colunas para inspecionar casos específicos (ex.: pedidos com prazo alto e nota baixa).",
          "Todos os números do painel derivam desta base; os <b>filtros do topo</b> também a recortam."
        )
      )
    )
  ),
  footer = dashboardFooter(left = "Fonte: Olist / Kaggle", right = "Elton Jose da Silva")
)

# ---------------------------------------------------------------------
# SERVER
# ---------------------------------------------------------------------
server <- function(input, output, session) {

  dados <- reactive({
    df <- DADOS %>% filter(as.Date(data_compra) >= input$periodo[1],
                           as.Date(data_compra) <= input$periodo[2])
    if (length(input$estado) > 0)    df <- df %>% filter(estado %in% input$estado)
    if (length(input$categoria) > 0) df <- df %>% filter(categoria %in% input$categoria)
    df
  })
  entregues <- reactive(dados() %>% filter(entregue))

  # meses com dados suficientes (omite tails incompletos do Olist)
  meses_validos <- reactive({
    s <- dados() %>% count(mes, name = "n") %>% filter(!is.na(mes))
    if (nrow(s) < 3) return(s$mes)
    s$mes[s$n >= 0.25 * median(s$n)]
  })

  # botão "Limpar filtros"
  observeEvent(input$limpar, {
    updateDateRangeInput(session, "periodo", start = PMIN, end = PMAX)
    updateSelectizeInput(session, "estado", selected = character(0))
    updateSelectizeInput(session, "categoria", selected = character(0))
  })

  # série mensal auxiliar para sparklines
  serie <- function(df, col_expr) {
    df %>% group_by(m = mes) %>% summarise(v = {{ col_expr }}, .groups = "drop") %>% arrange(m) %>% pull(v)
  }

  # navegação ao clicar num KPI
  observeEvent(input$kpi_nav, {
    updateTabItems(session, "menu", input$kpi_nav)
  })

  # ---- KPIs ----
  output$kpis_geral <- renderUI({
    d <- dados(); e <- entregues()
    s_rec <- serie(e, sum(receita, na.rm = TRUE))
    s_ped <- d %>% count(mes) %>% arrange(mes) %>% pull(n)
    s_nota <- serie(filter(d, !is.na(nota)), mean(nota, na.rm = TRUE))
    s_prz <- serie(filter(e, !is.na(dias_entrega)), mean(dias_entrega, na.rm = TRUE))
    recompra <- d %>% group_by(customer_unique_id) %>% summarise(k = n(), .groups = "drop") %>%
      summarise(r = mean(k > 1, na.rm = TRUE)) %>% pull(r)
    tagList(
      fluidRow(class = "linha-kpi",
        column(3, kpi_card("sack-dollar", IDPC_AZUL, brl(sum(e$receita, na.rm = TRUE)), "Receita (entregues)",
                           sparkline_svg(s_rec, IDPC_AZUL), destino = "geo", dica = "Receita dos pedidos entregues no recorte")),
        column(3, kpi_card("box-open", AZUL_MED, num(nrow(d)), "Pedidos",
                           sparkline_svg(s_ped, AZUL_MED), destino = "geo")),
        column(3, kpi_card("receipt", IDPC_AZUL, brl2(mean(e$receita, na.rm = TRUE)), "Ticket médio",
                           sparkline_svg(serie(e, mean(receita, na.rm = TRUE)), IDPC_AZUL), destino = "pgto")),
        column(3, kpi_card("star", AMBAR, sprintf("%.2f", mean(d$nota, na.rm = TRUE)), "Nota média",
                           sparkline_svg(s_nota, AMBAR), destino = "satisf"))
      ),
      fluidRow(class = "linha-kpi",
        column(3, kpi_card("truck-fast", AZUL_MED, sprintf("%.1f dias", mean(e$dias_entrega, na.rm = TRUE)), "Prazo médio",
                           sparkline_svg(s_prz, AZUL_MED), destino = "logistica")),
        column(3, kpi_card("circle-check", VERDE, percent(mean(e$no_prazo, na.rm = TRUE), accuracy = 0.1), "Entregas no prazo",
                           destino = "logistica")),
        column(3, kpi_card("repeat", IDPC_AZUL, percent(recompra, accuracy = 0.1), "Taxa de recompra", destino = "geral",
                           dica = "Clientes únicos com mais de um pedido")),
        column(3, kpi_card("map", AZUL_MED, num(n_distinct(d$estado)), "Estados atendidos", destino = "geo"))
      )
    )
  })

  output$kpis_log <- renderUI({
    e <- entregues()
    fluidRow(class = "linha-kpi",
      column(3, kpi_card("truck-fast", AZUL_MED, sprintf("%.1f dias", mean(e$dias_entrega, na.rm = TRUE)), "Prazo médio de entrega")),
      column(3, kpi_card("circle-check", VERDE, percent(mean(e$no_prazo, na.rm = TRUE), accuracy = 0.1), "Entregas no prazo")),
      column(3, kpi_card("triangle-exclamation", VERMELHO, percent(mean(!e$no_prazo, na.rm = TRUE), accuracy = 0.1), "Entregas atrasadas")),
      column(3, kpi_card("clock-rotate-left", IDPC_AZUL, sprintf("%.1f dias", mean(e$dias_vs_prev, na.rm = TRUE)), "Antes do previsto",
                         dica = "Média de dias que a entrega chega antes da data estimada"))
    )
  })

  output$kpis_sat <- renderUI({
    d <- dados() %>% filter(!is.na(nota)); r <- round(d$nota)
    prom <- mean(r == 5); detr <- mean(r <= 2); nps <- (prom - detr) * 100
    fluidRow(class = "linha-kpi",
      column(3, kpi_card("star", AMBAR, sprintf("%.2f", mean(d$nota, na.rm = TRUE)), "Nota média")),
      column(3, kpi_card("thumbs-up", VERDE, percent(prom, accuracy = 0.1), "Promotores (5 estrelas)")),
      column(3, kpi_card("thumbs-down", VERMELHO, percent(detr, accuracy = 0.1), "Detratores (1–2 estrelas)")),
      column(3, kpi_card("gauge-high", IDPC_AZUL, sprintf("%+.0f", nps), "Índice de satisfação (NPS-like)",
                         dica = "% de promotores (5★) menos % de detratores (1–2★)"))
    )
  })

  # ---- Visão Geral ----
  output$g_receita_mes <- renderPlotly({
    d <- entregues() %>% filter(mes %in% meses_validos()) %>%
      group_by(x = mes) %>% summarise(v = sum(receita, na.rm = TRUE), .groups = "drop") %>% arrange(x)
    d$mm <- as.numeric(stats::filter(d$v, rep(1/3, 3), sides = 1))
    plot_ly(d, x = ~x) %>%
      add_trace(y = ~v, type = "scatter", mode = "lines", name = "Receita",
                line = list(color = IDPC_AZUL, width = 2.5, shape = "spline"),
                fill = "tozeroy", fillcolor = "rgba(11,79,138,0.08)",
                hovertemplate = "%{x|%b/%Y}<br>R$ %{y:,.0f}<extra></extra>") %>%
      add_trace(y = ~mm, type = "scatter", mode = "lines", name = "Média móvel 3m",
                line = list(color = AMBAR, width = 2, dash = "dot"),
                hovertemplate = "MM 3m: R$ %{y:,.0f}<extra></extra>") %>%
      theme_dashboard() %>%
      layout(showlegend = TRUE, legend = list(orientation = "h", x = 0, y = 1.14))
  })

  output$g_cresc_mom <- renderPlotly({
    d <- entregues() %>% filter(mes %in% meses_validos()) %>%
      group_by(x = mes) %>% summarise(v = sum(receita, na.rm = TRUE), .groups = "drop") %>%
      arrange(x) %>% mutate(g = (v / lag(v) - 1) * 100) %>% filter(!is.na(g))
    plot_ly(d, x = ~x, y = ~g, type = "bar",
            marker = list(color = ifelse(d$g >= 0, VERDE, VERMELHO)),
            hovertemplate = "%{x|%b/%Y}<br>%{y:.1f}%<extra></extra>") %>%
      theme_dashboard() %>% layout(yaxis = list(ticksuffix = "%", gridcolor = GRID))
  })

  output$g_pareto_cat <- renderPlotly({
    all <- entregues() %>% group_by(rotulo = categoria) %>% summarise(v = sum(receita, na.rm = TRUE), .groups = "drop") %>% arrange(desc(v))
    tot <- sum(all$v); req(tot > 0)
    top <- all %>% slice_head(n = 12) %>% mutate(cum = cumsum(v) / tot * 100)
    top$rotulo <- factor(top$rotulo, levels = top$rotulo)
    plot_ly(top, x = ~rotulo) %>%
      add_bars(y = ~v, name = "Receita", marker = list(color = IDPC_AZUL),
               hovertemplate = "%{x}<br>R$ %{y:,.0f}<extra></extra>") %>%
      add_trace(y = ~cum, yaxis = "y2", type = "scatter", mode = "lines+markers", name = "% acumulado",
                line = list(color = AMBAR, width = 2), marker = list(color = AMBAR, size = 5),
                hovertemplate = "%{y:.0f}% acumulado<extra></extra>") %>%
      theme_dashboard() %>%
      layout(xaxis = list(tickangle = -35, tickfont = list(size = 9)),
             yaxis2 = list(overlaying = "y", side = "right", range = c(0, 105), ticksuffix = "%",
                           showgrid = FALSE, tickfont = list(size = 9, color = INK2)),
             legend = list(orientation = "h", x = 0, y = 1.16), margin = list(r = 46, b = 96))
  })

  output$g_novos_recorr <- renderPlotly({
    d <- dados() %>% filter(mes %in% meses_validos(), !is.na(tipo_cliente)) %>% count(mes, tipo_cliente, name = "n")
    plot_ly(d, x = ~mes, y = ~n, color = ~tipo_cliente,
            colors = c("Novo" = AZUL_MED, "Recorrente" = AMBAR), type = "bar",
            hovertemplate = "%{x|%b/%Y}<br>%{fullData.name}: %{y:,}<extra></extra>") %>%
      theme_dashboard() %>%
      layout(barmode = "stack", legend = list(orientation = "h", x = 0, y = 1.14))
  })

  output$g_ticket_volume <- renderPlotly({
    d <- entregues() %>% filter(mes %in% meses_validos()) %>%
      group_by(x = mes) %>% summarise(pedidos = n(), ticket = mean(receita, na.rm = TRUE), .groups = "drop") %>% arrange(x)
    plot_ly(d, x = ~x) %>%
      add_bars(y = ~pedidos, name = "Pedidos", marker = list(color = "rgba(42,120,214,0.55)"),
               hovertemplate = "%{x|%b/%Y}<br>%{y:,} pedidos<extra></extra>") %>%
      add_trace(y = ~ticket, yaxis = "y2", type = "scatter", mode = "lines+markers", name = "Ticket médio",
                line = list(color = AMBAR, width = 2.5), marker = list(color = AMBAR, size = 5),
                hovertemplate = "Ticket R$ %{y:,.2f}<extra></extra>") %>%
      theme_dashboard() %>%
      layout(yaxis2 = list(overlaying = "y", side = "right", showgrid = FALSE, tickprefix = "R$ ",
                           tickfont = list(size = 9, color = INK2)),
             legend = list(orientation = "h", x = 0, y = 1.14), margin = list(r = 54))
  })
  output$g_treemap_cat <- renderPlotly({
    d <- entregues() %>% group_by(rotulo = categoria) %>% summarise(v = sum(receita, na.rm = TRUE), .groups = "drop") %>%
      arrange(desc(v)) %>% slice_head(n = 12)
    treemap_v(d, hover = "%{label}<br>R$ %{value:,.0f} (%{percentRoot})<extra></extra>")
  })
  output$g_saz <- renderPlotly({
    d <- dados() %>% mutate(mn = month(data_compra), dw = wday(data_compra, week_start = 1)) %>%
      filter(!is.na(mn), !is.na(dw)) %>% count(mn, dw)
    z <- matrix(0, 7, 12)
    for (i in seq_len(nrow(d))) z[d$dw[i], d$mn[i]] <- d$n[i]
    plot_ly(x = MESES, y = DIAS, z = z, type = "heatmap", colorscale = ESCALA_AZUL,
            xgap = 3, ygap = 3, hovertemplate = "%{y}, %{x}<br>%{z:,} pedidos<extra></extra>",
            colorbar = list(title = "", thickness = 10, len = 0.9, tickfont = list(size = 9))) %>%
      theme_dashboard() %>% layout(yaxis = list(autorange = "reversed", gridcolor = "rgba(0,0,0,0)"),
                                   xaxis = list(gridcolor = "rgba(0,0,0,0)"))
  })

  # ---- Logística ----
  output$g_gauge_prazo <- renderPlotly({
    e <- entregues(); gauge_pct(100 * mean(e$no_prazo, na.rm = TRUE), VERDE)
  })

  output$g_sla_mes <- renderPlotly({
    d <- entregues() %>% filter(mes %in% meses_validos(), !is.na(no_prazo)) %>%
      group_by(x = mes) %>% summarise(v = mean(no_prazo, na.rm = TRUE) * 100, .groups = "drop") %>% arrange(x)
    plot_ly(d, x = ~x, y = ~v, type = "scatter", mode = "lines+markers",
            line = list(color = VERDE, width = 2.5, shape = "spline"), marker = list(color = VERDE, size = 5),
            hovertemplate = "%{x|%b/%Y}<br>%{y:.1f}% no prazo<extra></extra>") %>%
      theme_dashboard() %>% layout(yaxis = list(ticksuffix = "%", range = c(60, 100), gridcolor = GRID))
  })

  output$g_lead_comp <- renderPlotly({
    e <- entregues() %>% filter(t_aprovacao >= 0, t_despacho >= 0, t_transporte >= 0)
    req(nrow(e) > 0)
    est <- data.frame(
      etapa = c("Aprovação do pagamento", "Manuseio / Despacho", "Transporte"),
      v = c(mean(e$t_aprovacao, na.rm = TRUE), mean(e$t_despacho, na.rm = TRUE), mean(e$t_transporte, na.rm = TRUE)),
      cor = c("#8fb4e0", AMBAR, IDPC_AZUL), stringsAsFactors = FALSE)
    est$etapa <- factor(est$etapa, levels = est$etapa)   # Transporte no topo
    plot_ly(est, x = ~v, y = ~etapa, type = "bar", orientation = "h",
            marker = list(color = est$cor),
            text = ~sprintf("%.1f dias", v), textposition = "outside",
            textfont = list(color = INK2, size = 11), cliponaxis = FALSE,
            hovertemplate = "%{y}: %{x:.1f} dias<extra></extra>") %>%
      theme_dashboard() %>%
      layout(showlegend = FALSE, margin = list(l = 10, r = 46),
             xaxis = list(title = list(text = "dias (média)"), gridcolor = GRID,
                          range = c(0, max(est$v) * 1.18)),
             yaxis = list(title = list(text = "")))
  })

  output$g_prazo_regiao <- renderPlotly({
    d <- entregues() %>% filter(!is.na(dias_entrega), dias_entrega >= 0, dias_entrega <= 60) %>%
      mutate(regiao = unname(REGIAO[estado])) %>% filter(!is.na(regiao))
    req(nrow(d) > 0)
    ordem <- d %>% group_by(regiao) %>% summarise(m = median(dias_entrega), .groups = "drop") %>%
      arrange(m) %>% pull(regiao)
    d$regiao <- factor(d$regiao, levels = ordem)
    plot_ly(d, x = ~dias_entrega, y = ~regiao, type = "box", color = ~regiao, colors = PAL,
            boxpoints = FALSE, line = list(width = 1.5), fillcolor = "rgba(42,120,214,0.12)",
            hovertemplate = "%{y}<br>%{x} dias<extra></extra>") %>%
      theme_dashboard() %>%
      layout(showlegend = FALSE, xaxis = list(title = list(text = "dias até a entrega"), gridcolor = GRID),
             yaxis = list(title = list(text = "")))
  })

  output$g_dist_prometido <- renderPlotly({
    e <- entregues() %>% filter(!is.na(dias_vs_prev), dias_vs_prev >= -30, dias_vs_prev <= 45)
    early <- e %>% filter(dias_vs_prev >= 0); late <- e %>% filter(dias_vs_prev < 0)
    plot_ly() %>%
      add_histogram(x = early$dias_vs_prev, name = "Antes do previsto", marker = list(color = VERDE),
                    xbins = list(size = 2), hovertemplate = "%{x} dias antes<br>%{y} pedidos<extra></extra>") %>%
      add_histogram(x = late$dias_vs_prev, name = "Atrasado", marker = list(color = VERMELHO),
                    xbins = list(size = 2), hovertemplate = "%{x} dias<br>%{y} pedidos<extra></extra>") %>%
      theme_dashboard() %>%
      layout(barmode = "overlay",
             xaxis = list(title = list(text = "dias antes (+) / depois (−) do previsto"), gridcolor = GRID),
             legend = list(orientation = "h", x = 0, y = 1.14))
  })

  output$g_dumbbell_uf <- renderPlotly({
    d <- entregues() %>% filter(!is.na(dias_entrega), !is.na(lead_previsto)) %>%
      group_by(uf = estado) %>%
      summarise(real = mean(dias_entrega, na.rm = TRUE), prev = mean(lead_previsto, na.rm = TRUE), .groups = "drop") %>%
      arrange(desc(real)) %>% slice_head(n = 15)
    d$uf <- factor(d$uf, levels = rev(d$uf))
    plot_ly(d) %>%
      add_segments(x = ~real, xend = ~prev, y = ~uf, yend = ~uf,
                   line = list(color = "#c2cfdd", width = 2), showlegend = FALSE, hoverinfo = "skip") %>%
      add_markers(x = ~real, y = ~uf, name = "Realizado", marker = list(color = IDPC_AZUL, size = 9),
                  hovertemplate = "%{y} — realizado: %{x:.1f} d<extra></extra>") %>%
      add_markers(x = ~prev, y = ~uf, name = "Prometido", marker = list(color = AMBAR, size = 9),
                  hovertemplate = "%{y} — prometido: %{x:.1f} d<extra></extra>") %>%
      theme_dashboard() %>%
      layout(xaxis = list(title = list(text = "dias"), gridcolor = GRID),
             legend = list(orientation = "h", x = 0, y = 1.08))
  })

  output$g_prazo_uf <- renderPlotly({
    d <- entregues() %>% filter(!is.na(dias_entrega)) %>% group_by(rotulo = estado) %>%
      summarise(v = mean(dias_entrega, na.rm = TRUE), .groups = "drop") %>% arrange(desc(v)) %>% slice_head(n = 15)
    lolli(d, cor = AMBAR, hover = "%{y}<br>%{x:.1f} dias<extra></extra>")
  })
  output$g_nota_prazo <- renderPlotly({
    d <- entregues() %>% filter(!is.na(dias_entrega), !is.na(nota)) %>% group_by(estado) %>%
      summarise(prazo = mean(dias_entrega, na.rm = TRUE), nota = mean(nota, na.rm = TRUE), pedidos = n(), .groups = "drop")
    plot_ly(d, x = ~prazo, y = ~nota, type = "scatter", mode = "markers+text",
            text = ~estado, textposition = "top center", textfont = list(size = 9, color = INK2),
            marker = list(size = ~pedidos, sizemode = "area", sizeref = 2 * max(d$pedidos) / (34^2), sizemin = 4,
                          color = IDPC_AZUL, opacity = 0.5, line = list(color = "white", width = 1)),
            hovertemplate = "%{text}<br>Prazo: %{x:.1f} dias<br>Nota: %{y:.2f}<extra></extra>") %>% theme_dashboard()
  })

  # ---- Geografia ----
  uf_stats <- reactive({
    entregues() %>% group_by(uf = estado) %>%
      summarise(pedidos = n(),
                ticket  = mean(receita, na.rm = TRUE),   # ANTES de somar receita
                nota    = mean(nota, na.rm = TRUE),
                prazo   = mean(dias_entrega, na.rm = TRUE),
                receita = sum(receita, na.rm = TRUE),     # soma por último
                .groups = "drop") %>%
      filter(!is.na(uf)) %>% mutate(regiao = unname(REGIAO[uf]))
  })

  output$kpis_geo <- renderUI({
    st <- uf_stats(); req(nrow(st) > 0)
    tot <- sum(st$receita)
    lider <- st %>% arrange(desc(receita)) %>% slice(1)
    top5 <- st %>% arrange(desc(receita)) %>% slice_head(n = 5) %>% summarise(s = sum(receita)) %>% pull(s)
    reg <- st %>% group_by(regiao) %>% summarise(r = sum(receita), .groups = "drop") %>% arrange(desc(r)) %>% slice(1)
    fluidRow(class = "linha-kpi",
      column(3, kpi_card("trophy", IDPC_AZUL, lider$uf, paste0("Estado líder · ", brl(lider$receita)))),
      column(3, kpi_card("layer-group", AZUL_MED, percent(top5 / tot, accuracy = 0.1), "Concentração Top 5 (receita)")),
      column(3, kpi_card("compass", VERDE, reg$regiao, paste0("Região líder · ", percent(reg$r / tot, accuracy = 0.1)))),
      column(3, kpi_card("earth-americas", IDPC_AZUL, num(nrow(st)), "Estados com vendas"))
    )
  })

  output$g_mapa <- renderPlotly({
    st <- uf_stats(); req(nrow(st) > 0); m <- input$geo_metrica %||% "receita"
    z <- st[[m]]
    if (is.null(GEO)) {
      return(plotly_empty(type = "scatter", mode = "markers") %>%
               layout(title = list(text = "Mapa indisponível (br_mapa.geojson não encontrado)", font = list(size = 12))))
    }
    plot_ly() %>%
      add_trace(type = "choropleth", geojson = GEO, featureidkey = "properties.sigla",
                locations = st$uf, z = z, colorscale = ESCALA_AZUL, reversescale = (m == "prazo"),
                marker = list(line = list(color = "white", width = 1)),
                colorbar = list(title = "", thickness = 10, len = 0.85, tickfont = list(size = 9)),
                hovertemplate = hov_mapa(m)) %>%
      layout(geo = list(fitbounds = "locations", visible = FALSE, bgcolor = "rgba(0,0,0,0)"),
             margin = list(l = 0, r = 0, t = 0, b = 0), paper_bgcolor = "rgba(0,0,0,0)",
             font = list(family = FONTE_BASE), separators = ",.") %>%
      config(displayModeBar = FALSE, responsive = TRUE, scrollZoom = TRUE)
  })

  output$g_rank_uf <- renderPlotly({
    st <- uf_stats(); req(nrow(st) > 0); m <- input$geo_metrica %||% "receita"
    d <- st %>% transmute(rotulo = uf, v = .data[[m]]) %>% arrange(desc(v)) %>% slice_head(n = 12)
    cor <- if (m %in% c("nota")) VERDE else if (m == "prazo") AMBAR else IDPC_AZUL
    lolli(d, cor = cor, hover = hov_rank(m))
  })

  output$g_regiao_donut <- renderPlotly({
    d <- uf_stats() %>% group_by(regiao) %>% summarise(v = sum(receita, na.rm = TRUE), .groups = "drop") %>% arrange(desc(v))
    plot_ly(d, labels = ~regiao, values = ~v, type = "pie", hole = 0.55, sort = FALSE,
            marker = list(colors = PAL[seq_len(nrow(d))], line = list(color = "#fff", width = 2)),
            textinfo = "label+percent", textposition = "inside", insidetextorientation = "horizontal",
            hovertemplate = "%{label}<br>R$ %{value:,.0f} (%{percent})<extra></extra>") %>%
      layout(showlegend = FALSE, margin = list(l = 6, r = 6, t = 6, b = 6),
             paper_bgcolor = "rgba(0,0,0,0)", font = list(family = FONTE_BASE), separators = ",.") %>%
      config(displayModeBar = FALSE, responsive = TRUE)
  })

  output$g_fluxo <- renderPlotly({
    reg_ord <- c("Norte", "Nordeste", "Centro-Oeste", "Sudeste", "Sul")
    d <- entregues() %>% filter(!is.na(seller_uf), !is.na(estado)) %>%
      mutate(rv = unname(REGIAO[seller_uf]), rc = unname(REGIAO[estado])) %>%
      filter(!is.na(rv), !is.na(rc)) %>% count(rv, rc) %>%
      group_by(rc) %>% mutate(pct = n / sum(n) * 100) %>% ungroup()
    req(nrow(d) > 0)
    z <- matrix(NA_real_, length(reg_ord), length(reg_ord), dimnames = list(reg_ord, reg_ord))
    for (i in seq_len(nrow(d))) z[d$rv[i], d$rc[i]] <- d$pct[i]
    plot_ly(x = reg_ord, y = reg_ord, z = z, type = "heatmap", colorscale = ESCALA_AZUL, xgap = 3, ygap = 3, zmin = 0,
            hovertemplate = "Origem: %{y}<br>Destino: %{x}<br>%{z:.0f}% dos pedidos<extra></extra>",
            colorbar = list(title = "%", thickness = 10, len = 0.9, tickfont = list(size = 9))) %>%
      theme_dashboard() %>%
      layout(xaxis = list(title = list(text = "cliente (destino)"), gridcolor = "rgba(0,0,0,0)"),
             yaxis = list(title = list(text = "vendedor (origem)"), gridcolor = "rgba(0,0,0,0)"))
  })

  output$g_bubble_uf <- renderPlotly({
    st <- uf_stats() %>% filter(pedidos >= 20)
    plot_ly(st, x = ~pedidos, y = ~ticket, type = "scatter", mode = "markers+text",
            color = ~regiao, colors = PAL, size = ~receita, sizes = c(80, 1600),
            text = ~uf, textposition = "middle center", textfont = list(size = 8, color = "#fff"),
            marker = list(sizemode = "area", opacity = 0.75, line = list(color = "white", width = 1)),
            hovertemplate = "<b>%{text}</b><br>Pedidos: %{x:,}<br>Ticket: R$ %{y:,.2f}<extra></extra>") %>%
      theme_dashboard() %>%
      layout(xaxis = list(title = list(text = "Pedidos (escala log)"), type = "log"),
             yaxis = list(title = list(text = "Ticket médio (R$)")),
             legend = list(orientation = "h", x = 0, y = 1.12))
  })

  output$tabela_uf <- renderDT({
    st <- uf_stats() %>% arrange(desc(receita)) %>%
      transmute(UF = uf, Região = regiao, `Receita (R$)` = round(receita, 0),
                Pedidos = pedidos, `Ticket (R$)` = round(ticket, 2),
                Nota = round(nota, 2), `Prazo (d)` = round(prazo, 1))
    DT::datatable(st, options = modifyList(DT_PT, list(dom = "t", paging = FALSE, scrollY = "292px", scrollCollapse = TRUE)),
                  rownames = FALSE, class = "compact stripe hover")
  })

  # ---- Pagamentos ----
  output$g_sunburst_pag <- renderPlotly({
    d <- dados() %>% filter(!is.na(tipo_pgto), !is.na(parcelas)) %>%
      mutate(faixa = case_when(parcelas <= 1 ~ "1x", parcelas <= 3 ~ "2–3x",
                               parcelas <= 6 ~ "4–6x", parcelas <= 12 ~ "7–12x", TRUE ~ "12x+"))
    agg <- d %>% count(tipo_pgto, faixa, name = "n")
    tp  <- agg %>% group_by(tipo_pgto) %>% summarise(v = sum(n), .groups = "drop")
    ids <- c(tp$tipo_pgto, paste(agg$tipo_pgto, agg$faixa))
    labels <- c(tp$tipo_pgto, agg$faixa)
    parents <- c(rep("", nrow(tp)), agg$tipo_pgto)
    values <- c(tp$v, agg$n)
    cor_tipo <- setNames(PAL[(seq_len(nrow(tp)) - 1) %% length(PAL) + 1], tp$tipo_pgto)
    cores <- unname(c(cor_tipo[tp$tipo_pgto], cor_tipo[agg$tipo_pgto]))
    plot_ly(type = "sunburst", ids = ids, labels = labels, parents = parents, values = values,
            branchvalues = "total", insidetextorientation = "radial",
            hovertemplate = "%{label}<br>%{value:,} pedidos<extra></extra>",
            marker = list(colors = cores, line = list(color = "#fff", width = 1.5))) %>%
      layout(margin = list(l = 4, r = 4, t = 4, b = 4), paper_bgcolor = "rgba(0,0,0,0)",
             font = list(family = FONTE_BASE), separators = ",.") %>%
      config(displayModeBar = FALSE, responsive = TRUE)
  })
  output$kpis_pgto <- renderUI({
    d <- dados() %>% filter(!is.na(tipo_pgto))
    e <- entregues() %>% filter(!is.na(parcelas), parcelas >= 1)
    cred <- mean(d$tipo_pgto == "Cartão de Crédito", na.rm = TRUE)
    parc_med <- mean(e$parcelas, na.rm = TRUE)
    pct_parc <- mean(e$parcelas > 1, na.rm = TRUE)
    rev_parc <- sum(e$receita[e$parcelas > 1], na.rm = TRUE) / sum(e$receita, na.rm = TRUE)
    fluidRow(class = "linha-kpi",
      column(3, kpi_card("credit-card", IDPC_AZUL, percent(cred, accuracy = 0.1), "Pedidos no cartão de crédito")),
      column(3, kpi_card("layer-group", AZUL_MED, sprintf("%.1fx", parc_med), "Parcelas médias")),
      column(3, kpi_card("calendar-days", AMBAR, percent(pct_parc, accuracy = 0.1), "Pedidos parcelados (>1x)")),
      column(3, kpi_card("sack-dollar", VERDE, percent(rev_parc, accuracy = 0.1), "Receita parcelada",
                         dica = "Parcela dos pedidos financiados no total da receita (recebíveis a prazo)"))
    )
  })

  output$g_valor_meio <- renderPlotly({
    d <- entregues() %>% filter(!is.na(tipo_pgto), !is.na(receita), receita > 0)
    req(nrow(d) > 0)
    ordem <- d %>% group_by(tipo_pgto) %>% summarise(m = median(receita), .groups = "drop") %>%
      arrange(m) %>% pull(tipo_pgto)
    d$tipo_pgto <- factor(d$tipo_pgto, levels = ordem)
    plot_ly(d, x = ~receita, y = ~tipo_pgto, type = "box", color = ~tipo_pgto, colors = PAL,
            boxpoints = FALSE, line = list(width = 1.5), fillcolor = "rgba(42,120,214,0.12)",
            hovertemplate = "%{y}<br>R$ %{x}<extra></extra>") %>%
      theme_dashboard() %>%
      layout(showlegend = FALSE, xaxis = list(title = list(text = "valor do pedido (R$)"), gridcolor = GRID),
             yaxis = list(title = list(text = "")))
  })

  output$g_mix_evol <- renderPlotly({
    d <- dados() %>% filter(mes %in% meses_validos(), !is.na(tipo_pgto)) %>% count(mes, tipo_pgto, name = "n")
    plot_ly(d, x = ~mes, y = ~n, color = ~tipo_pgto, colors = PAL,
            type = "scatter", mode = "none", stackgroup = "one", groupnorm = "percent",
            hovertemplate = "%{x|%b/%Y}<br>%{fullData.name}: %{y:.1f}%<extra></extra>") %>%
      theme_dashboard() %>%
      layout(yaxis = list(ticksuffix = "%", range = c(0, 100)),
             legend = list(orientation = "h", x = 0, y = 1.14))
  })

  output$g_ticket_parcelas <- renderPlotly({
    d <- entregues() %>% filter(!is.na(parcelas), parcelas >= 1, parcelas <= 24) %>%
      group_by(parcelas) %>% summarise(ticket = mean(receita, na.rm = TRUE), n = n(), .groups = "drop") %>%
      filter(n >= 30)
    plot_ly(d, x = ~parcelas, y = ~ticket, type = "scatter", mode = "lines+markers",
            line = list(color = IDPC_AZUL, width = 2.5, shape = "spline"), marker = list(color = IDPC_AZUL, size = 6),
            hovertemplate = "%{x}x<br>Ticket médio: R$ %{y:,.2f}<extra></extra>") %>%
      theme_dashboard() %>%
      layout(xaxis = list(title = list(text = "nº de parcelas"), dtick = 2, gridcolor = GRID),
             yaxis = list(title = list(text = "ticket médio (R$)")))
  })

  output$g_heat_parc <- renderPlotly({
    lev_val <- c("≤ 50", "50–100", "100–200", "200–500", "500+")
    d <- entregues() %>% filter(!is.na(parcelas), !is.na(receita)) %>%
      mutate(fv = cut(receita, breaks = c(-Inf, 50, 100, 200, 500, Inf), labels = lev_val),
             fp = case_when(parcelas <= 1 ~ "1x", parcelas <= 3 ~ "2–3x", parcelas <= 6 ~ "4–6x",
                            parcelas <= 12 ~ "7–12x", TRUE ~ "12x+")) %>%
      count(fv, fp) %>% group_by(fv) %>% mutate(pct = n / sum(n) * 100) %>% ungroup()
    lev_par <- c("1x", "2–3x", "4–6x", "7–12x", "12x+")
    z <- matrix(0, length(lev_val), length(lev_par), dimnames = list(lev_val, lev_par))
    for (i in seq_len(nrow(d))) z[as.character(d$fv[i]), d$fp[i]] <- d$pct[i]
    plot_ly(x = lev_par, y = lev_val, z = z, type = "heatmap", colorscale = ESCALA_AZUL, xgap = 3, ygap = 3, zmin = 0,
            hovertemplate = "Valor %{y}<br>%{x}: %{z:.0f}% dos pedidos<extra></extra>",
            colorbar = list(title = "%", thickness = 10, len = 0.9, tickfont = list(size = 9))) %>%
      theme_dashboard() %>%
      layout(xaxis = list(title = list(text = "parcelas"), gridcolor = "rgba(0,0,0,0)"),
             yaxis = list(title = list(text = "valor do pedido (R$)"), gridcolor = "rgba(0,0,0,0)"))
  })

  output$g_parcelas <- renderPlotly({
    d <- dados() %>% filter(!is.na(parcelas), parcelas >= 1, parcelas <= 24) %>% count(parcelas, name = "v")
    plot_ly(d, x = ~parcelas, y = ~v, type = "bar", marker = list(color = AZUL_MED),
            hovertemplate = "%{x}x<br>%{y:,} pedidos<extra></extra>") %>%
      theme_dashboard() %>% layout(xaxis = list(dtick = 1, gridcolor = GRID))
  })

  # ---- Satisfação ----
  output$g_notas <- renderPlotly({
    d <- dados() %>% filter(!is.na(nota)) %>% mutate(n5 = round(nota)) %>% count(n5, name = "v")
    plot_ly(d, x = ~factor(n5), y = ~v, type = "bar",
            marker = list(color = ifelse(d$n5 >= 4, VERDE, AZUL_MED)),
            hovertemplate = "%{x} estrelas<br>%{y:,} avaliações<extra></extra>") %>% theme_dashboard()
  })
  output$g_evol_sat <- renderPlotly({
    d <- dados() %>% filter(mes %in% meses_validos(), !is.na(nota)) %>%
      group_by(x = mes) %>% summarise(nota = mean(nota, na.rm = TRUE), neg = mean(round(nota) <= 2) * 100, .groups = "drop") %>% arrange(x)
    plot_ly(d, x = ~x) %>%
      add_trace(y = ~neg, yaxis = "y2", name = "% negativas", type = "scatter", mode = "lines",
                line = list(color = VERMELHO, width = 2, dash = "dot"), fill = "tozeroy",
                fillcolor = "rgba(192,57,43,0.08)",
                hovertemplate = "%{x|%b/%Y}<br>%{y:.1f}% negativas<extra></extra>") %>%
      add_trace(y = ~nota, name = "Nota média", type = "scatter", mode = "lines+markers",
                line = list(color = IDPC_AZUL, width = 2.5, shape = "spline"), marker = list(color = IDPC_AZUL, size = 5),
                hovertemplate = "%{x|%b/%Y}<br>Nota %{y:.2f}<extra></extra>") %>%
      theme_dashboard() %>%
      layout(yaxis = list(title = list(text = ""), range = c(3, 5), gridcolor = GRID),
             yaxis2 = list(overlaying = "y", side = "right", ticksuffix = "%", showgrid = FALSE,
                           range = c(0, 40), tickfont = list(size = 9, color = INK2)),
             legend = list(orientation = "h", x = 0, y = 1.14), margin = list(r = 46))
  })

  output$g_prazo_nota <- renderPlotly({
    lv <- c("Adiantado<br>(3+ dias)", "No prazo<br>(0–2 dias)", "Atraso<br>1–5 dias", "Atraso<br>6–15 dias", "Atraso<br>>15 dias")
    d <- entregues() %>% filter(!is.na(nota), !is.na(dias_vs_prev)) %>%
      mutate(faixa = case_when(dias_vs_prev >= 3 ~ lv[1], dias_vs_prev >= 0 ~ lv[2],
                               dias_vs_prev >= -5 ~ lv[3], dias_vs_prev >= -15 ~ lv[4], TRUE ~ lv[5])) %>%
      group_by(faixa) %>% summarise(nota = mean(nota, na.rm = TRUE), n = n(), .groups = "drop")
    d$faixa <- factor(d$faixa, levels = lv); d <- d %>% arrange(faixa)
    plot_ly(d, x = ~faixa, y = ~nota, type = "scatter", mode = "lines+markers",
            line = list(color = "#c2cfdd", width = 2),
            marker = list(size = 13, line = list(color = "#fff", width = 1),
                          color = ifelse(d$nota >= 4, VERDE, ifelse(d$nota >= 3, AMBAR, VERMELHO))),
            text = ~scales::comma(n),
            hovertemplate = "%{x}<br>Nota média %{y:.2f}<br>%{text} pedidos<extra></extra>") %>%
      theme_dashboard() %>%
      layout(yaxis = list(range = c(1, 5), title = list(text = "nota média"), gridcolor = GRID),
             xaxis = list(tickfont = list(size = 9)))
  })

  output$g_nota_vol_cat <- renderPlotly({
    med <- mean(dados()$nota, na.rm = TRUE)
    d <- dados() %>% filter(!is.na(nota), !is.na(categoria)) %>% group_by(categoria) %>%
      summarise(nota = mean(nota, na.rm = TRUE), n = n(), .groups = "drop") %>% filter(n >= 100)
    plot_ly(d, x = ~n, y = ~nota, type = "scatter", mode = "markers", text = ~categoria,
            marker = list(size = ~n, sizemode = "area", sizeref = 2 * max(d$n) / (34^2), sizemin = 4,
                          color = ifelse(d$nota >= med, VERDE, VERMELHO),
                          opacity = 0.5, line = list(color = "#fff", width = 1)),
            hovertemplate = "<b>%{text}</b><br>%{x:,} pedidos<br>Nota %{y:.2f}<extra></extra>") %>%
      theme_dashboard() %>%
      layout(xaxis = list(title = list(text = "pedidos (log)"), type = "log", gridcolor = GRID),
             yaxis = list(title = list(text = "nota média"), gridcolor = GRID),
             shapes = list(list(type = "line", x0 = 0, x1 = 1, xref = "paper", y0 = med, y1 = med,
                                line = list(color = INK2, width = 1, dash = "dot"))))
  })

  output$g_cat_dif <- renderPlotly({
    med <- mean(dados()$nota, na.rm = TRUE)
    d <- dados() %>% filter(!is.na(nota), !is.na(categoria)) %>% group_by(categoria) %>%
      summarise(nota = mean(nota, na.rm = TRUE), n = n(), .groups = "drop") %>% filter(n >= 100) %>%
      mutate(dif = nota - med)
    d <- bind_rows(slice_max(d, dif, n = 8), slice_min(d, dif, n = 8)) %>% distinct() %>% arrange(dif)
    d$categoria <- factor(d$categoria, levels = d$categoria)
    plot_ly(d, x = ~dif, y = ~categoria, type = "bar", orientation = "h", customdata = ~nota,
            marker = list(color = ifelse(d$dif >= 0, VERDE, VERMELHO)),
            hovertemplate = "%{y}<br>Nota %{customdata:.2f} (%{x:+.2f} vs média)<extra></extra>") %>%
      theme_dashboard() %>%
      layout(xaxis = list(title = list(text = sprintf("diferença da nota vs média geral (%.2f)", med)),
                          gridcolor = GRID, zeroline = TRUE, zerolinecolor = "#c2cfdd"),
             yaxis = list(title = list(text = "")))
  })

  # ---- Tabela ----
  output$tabela <- renderDT({
    df <- dados() %>% transmute(Pedido = substr(order_id, 1, 8), Data = as.Date(data_compra), UF = estado,
      Categoria = categoria, Itens = itens, `Receita (R$)` = round(receita, 2), Pagamento = tipo_pgto,
      Parcelas = parcelas, `Prazo (dias)` = round(dias_entrega, 1), Nota = round(nota, 1), Status = order_status) %>% head(1000)
    dt <- DT::datatable(df, options = DT_PT, rownames = FALSE, class = "compact stripe hover")
    DT::formatDate(dt, "Data", method = "toLocaleDateString", params = list("pt-BR"))
  })
}

shinyApp(ui, server)
