# Gera um GeoJSON LEVE dos estados (br_mapa.geojson) para o mapa do dashboard.
# Baixa o contorno, mantém só 'sigla'/'name', ARREDONDA e SIMPLIFICA (decima
# vértices) — o mapa fica ~10x menor sem diferença visível, deixando a aba
# Geografia rápida. Fonte: codeforamerica/click_that_hood (domínio público).
suppressPackageStartupMessages(library(jsonlite))

fonte <- "br_alt.geojson"
if (!file.exists(fonte)) {
  cat("Baixando contorno dos estados...\n")
  utils::download.file(
    "https://raw.githubusercontent.com/codeforamerica/click_that_hood/master/public/data/brazil-states.geojson",
    fonte, quiet = TRUE, mode = "wb")
}
g <- jsonlite::fromJSON(fonte, simplifyVector = FALSE)

# ponto = list(lon, lat); anel = lista de pontos
eh_ponto <- function(p) is.list(p) && length(p) == 2 && is.numeric(p[[1]]) && length(p[[1]]) == 1

# arredonda (2 casas ~1km) e decima: mantém 1 a cada KEEP pontos (+ primeiro/último)
KEEP <- 8
simplifica <- function(x) {
  if (is.list(x) && length(x) > 0 && eh_ponto(x[[1]])) {          # x é um anel
    n <- length(x)
    idx <- if (n <= 6) seq_len(n) else unique(c(seq(1, n, by = KEEP), n))
    return(lapply(x[idx], function(p) list(round(p[[1]], 2), round(p[[2]], 2))))
  }
  if (is.list(x)) return(lapply(x, simplifica))
  x
}

conta <- function(x) if (eh_ponto(x)) 1 else if (is.list(x)) sum(vapply(x, conta, 0)) else 0

v0 <- sum(vapply(g$features, function(f) conta(f$geometry$coordinates), 0))
for (i in seq_along(g$features)) {
  f <- g$features[[i]]
  sig <- f$properties$sigla %||% f$properties$PK_sigla
  nom <- f$properties$name  %||% f$properties$Estado
  g$features[[i]]$properties <- list(sigla = sig, name = nom)
  g$features[[i]]$geometry$coordinates <- simplifica(f$geometry$coordinates)
}
v1 <- sum(vapply(g$features, function(f) conta(f$geometry$coordinates), 0))

jsonlite::write_json(g, "br_mapa.geojson", auto_unbox = TRUE, digits = 4)
if (file.exists(fonte)) file.remove(fonte)
cat(sprintf("br_mapa.geojson: %d KB | vertices %d -> %d (%.0f%% menor) | %d estados\n",
            round(file.info("br_mapa.geojson")$size / 1024), v0, v1, 100 * (1 - v1 / v0), length(g$features)))
