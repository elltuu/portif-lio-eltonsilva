# ─────────────────────────────────────────────
# Identidade visual do dashboard Olist (padrão IDPC/Hyperon)
#   - tema_olist / css_olist / theme_dashboard()
#   - KPI cards interativos (sparkline + clique), guia, treemap, gauge...
# ─────────────────────────────────────────────
library(fresh)

# ── Cores (paleta suave e uniforme) ──
IDPC_AZUL  <- "#0b4f8a"
AZUL_MED   <- "#2a78d6"
AZUL_CLARO <- "#e8f1fa"
VERDE      <- "#1baf7a"
AMBAR      <- "#eda100"
VERMELHO   <- "#c0392b"
INK        <- "#1f2937"
INK2       <- "#52606d"
GRID       <- "#e4e8ee"
BORDA      <- "#e2e8f0"
FUNDO      <- "#f4f6fa"
FONTE_BASE <- 'system-ui, "Segoe UI", sans-serif'
ESCALA_AZUL <- list(c(0, AZUL_CLARO), c(0.5, AZUL_MED), c(1, IDPC_AZUL))
PAL <- c("#2a78d6", "#1baf7a", "#eda100", "#0b4f8a", "#6c8ebf", "#7a9e9f", "#b08a3e", "#4d9dff")

# ── Tema bs4Dash ──
tema_olist <- create_theme(
  bs4dash_status(primary = IDPC_AZUL, info = AZUL_MED, success = "#188a5e",
                 warning = "#d29500", danger = VERMELHO),
  bs4dash_layout(main_bg = FUNDO),
  bs4dash_sidebar_light(bg = "#ffffff", color = "#3b4a5a",
                        hover_color = IDPC_AZUL, active_color = IDPC_AZUL)
)

# ── CSS ──
css_olist <- shiny::HTML('
  body, .wrapper, .content-wrapper, .main-header, .main-sidebar, .main-footer {
    font-family: system-ui, "Segoe UI", sans-serif;
  }
  .content-wrapper { background: #f4f6fa !important; }
  .content { padding: 16px 22px 6px; }

  .card { border: 1px solid #e2e8f0; border-radius: 10px;
    box-shadow: 0 1px 2px rgba(15,23,42,.06), 0 2px 6px rgba(15,23,42,.05) !important; margin-bottom: 18px; }
  .card-header { background: transparent; border-bottom: 1px solid #eef1f5; padding: .7rem 1rem; }
  .card-title { font-size: .93rem !important; font-weight: 600; color: #1f2937; }

  .main-header.navbar { background: #fff !important; border-bottom: 1px solid #e2e8f0; box-shadow: none; }
  .brand-link { border-bottom: 1px solid #e2e8f0 !important; background: #fff !important; }
  .brand-text { font-weight: 700 !important; color: #0b4f8a !important; letter-spacing: .01em; }
  .main-sidebar { box-shadow: none; border-right: 1px solid #e2e8f0; }
  .nav-sidebar .nav-link.active { background: #eaf1f9 !important; color: #0b4f8a !important; font-weight: 600; }
  .nav-sidebar .nav-link p { font-size: .92rem; }

  label { font-weight: 600; font-size: .8rem; color: #52606d; }
  .selectize-input, .form-control { border-color: #d7dee8 !important; border-radius: 8px !important;
    box-shadow: none !important; font-size: .85rem; }
  .selectize-dropdown { z-index: 4000 !important; }
  table.dataTable { font-size: .875rem; }
  .main-footer { background: #fff; border-top: 1px solid #e2e8f0; color: #64748b; font-size: .85rem; }

  h2.page-title { font-weight: 700; color: #1f2937; font-size: 1.3rem; margin: 2px 0 2px; }
  p.page-sub { color: #64748b; font-size: .9rem; margin: 0 0 14px; }

  /* barra de filtros no topo */
  .topbar-filtros { background: #fff; border: 1px solid #e2e8f0; border-radius: 10px;
    box-shadow: 0 1px 2px rgba(15,23,42,.06), 0 2px 6px rgba(15,23,42,.05);
    padding: 12px 16px 2px; margin-bottom: 16px; }
  .topbar-filtros .filtros-cab { font-size: .72rem; font-weight: 700; letter-spacing: .08em;
    text-transform: uppercase; color: #64748b; margin-bottom: 8px; display:flex; align-items:center; gap:6px; }
  .btn-limpar { background:#fff; border:1px solid #d7dee8; color:#52606d; border-radius:8px;
    padding:4px 12px; font-size:.75rem; font-weight:600; letter-spacing:0; text-transform:none; }
  .btn-limpar:hover { border-color:#0b4f8a; color:#0b4f8a; background:#f6f9fc; }

  /* KPI cards */
  .kpi-card { background: #fff; border: 1px solid #e2e8f0; border-radius: 10px;
    box-shadow: 0 1px 2px rgba(15,23,42,.06), 0 2px 6px rgba(15,23,42,.05);
    padding: 14px 16px; display: flex; gap: 13px; align-items: flex-start;
    margin-bottom: 18px; min-height: 110px; transition: transform .12s, box-shadow .12s; }
  .kpi-click { cursor: pointer; }
  .kpi-click:hover { transform: translateY(-3px);
    box-shadow: 0 6px 18px rgba(11,79,138,.14) !important; }
  .kpi-icone { width: 42px; height: 42px; border-radius: 10px; flex: none;
    display: flex; align-items: center; justify-content: center; font-size: 18px; }
  .kpi-corpo { flex: 1; min-width: 0; }
  .kpi-valor { font-size: 1.5rem; font-weight: 700; color: #1f2937; line-height: 1.1; white-space: nowrap; }
  .kpi-rotulo { font-size: .8rem; color: #64748b; font-weight: 600; margin-top: 2px; }
  .kpi-spark { margin-top: 8px; opacity: .9; }
  .kpi-seta { float: right; color: #cbd5e1; font-size: .8rem; margin-top: 2px; }

  /* guia "como analisar" */
  .guia-box { border: 1px solid #dbe6f1; border-left: 4px solid #0b4f8a; border-radius: 10px;
    background: #f6f9fc; padding: 14px 18px; margin: 6px 2px 8px; }
  .guia-titulo { font-weight: 700; color: #0b4f8a; font-size: .95rem; margin-bottom: 8px;
    display: flex; align-items: center; gap: 8px; }
  .guia-lista { margin: 0 0 6px; padding-left: 20px; }
  .guia-lista li { color: #45535f; font-size: .86rem; line-height: 1.6; margin-bottom: 3px; }
  .guia-lista li b { color: #2f4256; }
  .guia-fonte { color: #8090a0; font-size: 12px; border-top: 1px dashed #cdd9e5; padding-top: 8px; margin-top: 4px; }

  /* seletor de métrica do mapa (radios como pílulas) */
  .geo-metrica { margin-bottom: 10px; }
  .geo-metrica .shiny-options-group { display: flex; flex-wrap: wrap; gap: 6px; }
  .geo-metrica .radio-inline { margin: 0 !important; padding: 5px 12px; border: 1px solid #d7dee8;
    border-radius: 999px; font-size: .82rem; font-weight: 600; color: #52606d; background: #fff; }
  .geo-metrica .radio-inline input { margin-right: 5px; }
  .geo-metrica-bar { display:flex; align-items:center; gap:14px; flex-wrap:wrap; margin-bottom:10px; }
  .geo-metrica-bar .geo-metrica, .geo-metrica-bar .form-group { margin-bottom:0; }
  .geo-metrica-lbl { font-size:.8rem; font-weight:600; color:#52606d; }
  .geo-metrica-lbl i { color:#0b4f8a; margin-right:4px; }

  @media (max-width: 991.98px) {
    .content .row > [class*="col-"] { flex: 0 0 100%; max-width: 100%; }
    .card-body .js-plotly-plot { height: 280px !important; }
  }
  @media (min-width: 576px) and (max-width: 1199.98px) {
    .content .row.linha-kpi > [class*="col-"] { flex: 0 0 50%; max-width: 50%; }
  }
')

# ── Tema único dos gráficos plotly ──
theme_dashboard <- function(p) {
  plotly::layout(p,
    paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)", separators = ",.",
    font   = list(family = FONTE_BASE, color = INK2, size = 12),
    xaxis  = list(title = list(text = ""), gridcolor = GRID, zeroline = FALSE),
    yaxis  = list(title = list(text = ""), gridcolor = GRID, zeroline = FALSE),
    legend = list(orientation = "h", x = 0, y = 1.12, font = list(size = 11, color = INK2)),
    margin = list(l = 10, r = 14, t = 12, b = 10),
    hoverlabel = list(font = list(family = FONTE_BASE, size = 12))
  ) |> plotly::config(displayModeBar = FALSE, responsive = TRUE)
}

# ── Helpers de UI ──
titulo_info <- function(texto, dica)
  shiny::span(texto, shiny::span(class = "info-dica", title = dica, style = "color:#94a3b8;margin-left:6px;font-size:.8rem;cursor:help;", shiny::icon("circle-info")))

# sparkline em SVG puro (leve, sem dependência)
sparkline_svg <- function(v, cor = IDPC_AZUL, w = 130, h = 30) {
  v <- v[is.finite(v)]
  if (length(v) < 2) return(NULL)
  x <- seq(2, w - 2, length.out = length(v))
  rng <- range(v); span <- diff(rng); if (span == 0) span <- 1
  y <- (h - 3) - (v - rng[1]) / span * (h - 8)
  pts <- paste(sprintf("%.1f,%.1f", x, y), collapse = " ")
  n <- length(v)
  shiny::HTML(sprintf(
    '<svg width="%d" height="%d" viewBox="0 0 %d %d" preserveAspectRatio="none" style="display:block">
       <polyline points="%s" fill="none" stroke="%s" stroke-width="1.8" stroke-linejoin="round" stroke-linecap="round"/>
       <circle cx="%.1f" cy="%.1f" r="2.6" fill="%s"/></svg>',
    w, h, w, h, pts, cor, x[n], y[n], cor))
}

# KPI card: ícone + valor + rótulo + sparkline; clicável leva à aba `destino`
kpi_card <- function(icone, cor, valor, rotulo, spark = NULL, destino = NULL, dica = "") {
  card <- shiny::div(
    class = paste("kpi-card", if (!is.null(destino)) "kpi-click"),
    title = dica, style = paste0("border-left:4px solid ", cor, ";"),
    shiny::div(class = "kpi-icone", style = paste0("background:", cor, "1a; color:", cor, ";"), shiny::icon(icone)),
    shiny::div(class = "kpi-corpo",
      if (!is.null(destino)) shiny::span(class = "kpi-seta", shiny::icon("arrow-right")),
      shiny::div(class = "kpi-valor", valor),
      shiny::div(class = "kpi-rotulo", rotulo),
      if (!is.null(spark)) shiny::div(class = "kpi-spark", spark))
  )
  if (!is.null(destino)) card <- shiny::tagAppendAttributes(card, `data-destino` = destino)
  card
}

# guia "como analisar" ao fim de cada página
guia <- function(...) {
  itens <- list(...)
  shiny::div(class = "guia-box",
    shiny::div(class = "guia-titulo", shiny::icon("compass"), "Como analisar esta página"),
    shiny::tags$ul(class = "guia-lista", lapply(itens, function(t) shiny::tags$li(shiny::HTML(t)))),
    shiny::div(class = "guia-fonte", shiny::HTML("<b>Fonte:</b> Olist / Kaggle — dados públicos de e-commerce brasileiro (2016–2018). Painel por Elton Jose da Silva.")))
}

# JS: clique no KPI navega para a aba
js_kpi_nav <- shiny::tags$script(shiny::HTML(
  "$(document).on('click','.kpi-click',function(){var d=$(this).attr('data-destino');
   if(d){Shiny.setInputValue('kpi_nav', d, {priority:'event'});}});"))

# JS: redesenha os gráficos plotly ao trocar de aba, recolher a sidebar ou
# redimensionar a janela — garante que o painel se ajusta a qualquer tela
js_resize <- shiny::tags$script(shiny::HTML("
  function dispararResize(){ setTimeout(function(){ window.dispatchEvent(new Event('resize')); }, 250); }
  $(document).on('shown.bs.tab', dispararResize);
  $(document).on('click', '[data-widget=\"pushmenu\"]', function(){ setTimeout(dispararResize, 350); });
  $(document).on('collapsed.lte.pushmenu expanded.lte.pushmenu', dispararResize);
"))

# ── Gráficos reutilizáveis ──
hbar <- function(df, cor = AZUL_MED, hover = "%{y}: %{x}<extra></extra>")
  plotly::plot_ly(df, x = ~v, y = ~stats::reorder(rotulo, v), type = "bar", orientation = "h",
                  marker = list(color = cor), hovertemplate = hover) |> theme_dashboard()

lolli <- function(df, cor = IDPC_AZUL, hover = "%{y}: %{x}<extra></extra>") {
  df$rotulo <- stats::reorder(df$rotulo, df$v)
  plotly::plot_ly(df) |>
    plotly::add_segments(x = 0, xend = ~v, y = ~rotulo, yend = ~rotulo,
                         line = list(color = "#c2cfdd", width = 2), hoverinfo = "skip", showlegend = FALSE) |>
    plotly::add_markers(x = ~v, y = ~rotulo, marker = list(color = cor, size = 10,
                        line = list(color = "#fff", width = 1)), hovertemplate = hover, showlegend = FALSE) |>
    theme_dashboard()
}

linha_tempo <- function(df, cor = IDPC_AZUL, hover = "%{x}<br>%{y}<extra></extra>", yrange = NULL) {
  p <- plotly::plot_ly(df, x = ~x, y = ~v, type = "scatter", mode = "lines+markers",
                       line = list(color = cor, width = 2.5, shape = "spline"),
                       marker = list(color = cor, size = 5), fill = "tozeroy",
                       fillcolor = "rgba(11,79,138,0.08)", hovertemplate = hover) |>
    theme_dashboard() |> plotly::layout(showlegend = FALSE)
  if (!is.null(yrange)) p <- plotly::layout(p, yaxis = list(range = yrange, gridcolor = GRID))
  p
}

# treemap (df com rotulo/v), colorido por valor (escala azul)
treemap_v <- function(df, hover = "%{label}<br>%{value}<extra></extra>") {
  plotly::plot_ly(type = "treemap", labels = df$rotulo, parents = rep("", nrow(df)),
                  values = df$v, branchvalues = "total", sort = TRUE,
                  marker = list(colors = df$v, colorscale = ESCALA_AZUL, showscale = FALSE,
                                line = list(color = "#fff", width = 2)),
                  textinfo = "label+value+percent root",
                  textfont = list(family = FONTE_BASE, size = 13, color = "#fff"),
                  hovertemplate = hover) |>
    plotly::layout(margin = list(l = 4, r = 4, t = 4, b = 4), paper_bgcolor = "rgba(0,0,0,0)",
                   font = list(family = FONTE_BASE), separators = ",.") |>
    plotly::config(displayModeBar = FALSE, responsive = TRUE)
}

# medidor (gauge) de percentual
gauge_pct <- function(valor, cor = VERDE) {
  valor <- round(valor, 1)
  plotly::plot_ly(type = "indicator", mode = "gauge+number", value = valor,
                  number = list(suffix = "%", font = list(size = 40, color = INK, family = FONTE_BASE)),
                  gauge = list(
                    axis = list(range = list(0, 100), tickcolor = INK2, tickfont = list(size = 10)),
                    bar = list(color = cor, thickness = 0.28), bgcolor = "white", borderwidth = 0,
                    steps = list(list(range = c(0, 80), color = "#f7dcd8"),
                                 list(range = c(80, 95), color = "#fdeecb"),
                                 list(range = c(95, 100), color = "#d9f0e5")),
                    threshold = list(line = list(color = INK, width = 3), thickness = 0.8, value = valor))) |>
    plotly::layout(margin = list(l = 24, r = 24, t = 26, b = 6), paper_bgcolor = "rgba(0,0,0,0)",
                   font = list(family = FONTE_BASE)) |>
    plotly::config(displayModeBar = FALSE, responsive = TRUE)
}

# ── Configuração padrão das tabelas DT ──
DT_PT <- list(
  pageLength = 12, scrollX = TRUE,
  language = list(search = "Buscar:", lengthMenu = "Mostrar _MENU_",
                  info = "_START_–_END_ de _TOTAL_", zeroRecords = "Nenhum registro",
                  paginate = list(previous = "Anterior", "next" = "Próxima"))
)
