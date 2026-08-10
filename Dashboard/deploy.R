# =====================================================================
# deploy.R — Publica o dashboard no shinyapps.io (link público)
#
# COMO USAR (uma vez):
#   1) Crie uma conta grátis em https://www.shinyapps.io  (entre com Google/GitHub)
#   2) No shinyapps.io: avatar (canto superior direito) -> Tokens -> Show ->
#      copie a linha rsconnect::setAccountInfo(name=..., token=..., secret=...)
#   3) No RStudio, com este projeto aberto, COLE e RODE essa linha uma vez.
#   4) Rode:  source("deploy.R")
#      (o 1º envio demora alguns minutos — instala os pacotes no servidor)
#   5) Ao terminar, abre o link público. Copie e me mande para eu colocar no site.
# =====================================================================
library(rsconnect)

# Só os arquivos que o app precisa em produção (o .rds já vem pronto;
# os CSVs em olist_data/ e os scripts de preparo NÃO são enviados).
rsconnect::deployApp(
  appDir        = ".",
  appPrimaryDoc = "app.R",
  appFiles      = c("app.R", "tema.R", "olist_prepared.rds", "br_mapa.geojson"),
  appName       = "olist-dashboard",
  appTitle      = "Olist — Painel Executivo de E-commerce",
  forceUpdate   = TRUE
)
