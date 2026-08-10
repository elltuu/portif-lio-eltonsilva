# =====================================================================
# prep_data.R — Prepara os dados do Olist para o dashboard Shiny
# Lê os 9 CSVs, junta as tabelas e salva um objeto pronto (olist_prepared.rds)
# Fonte dos dados: Olist / Kaggle
# =====================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(stringr)
})

# Pasta com os CSVs (relativa a este script)
data_dir <- file.path("olist_data")

msg <- function(...) cat(format(Sys.time(), "%H:%M:%S"), "-", ..., "\n")

msg("Lendo CSVs...")
orders      <- read_csv(file.path(data_dir, "olist_orders_dataset.csv"), show_col_types = FALSE)
items       <- read_csv(file.path(data_dir, "olist_order_items_dataset.csv"), show_col_types = FALSE)
payments    <- read_csv(file.path(data_dir, "olist_order_payments_dataset.csv"), show_col_types = FALSE)
reviews     <- read_csv(file.path(data_dir, "olist_order_reviews_dataset.csv"), show_col_types = FALSE)
products    <- read_csv(file.path(data_dir, "olist_products_dataset.csv"), show_col_types = FALSE)
customers   <- read_csv(file.path(data_dir, "olist_customers_dataset.csv"), show_col_types = FALSE)
sellers     <- read_csv(file.path(data_dir, "olist_sellers_dataset.csv"), show_col_types = FALSE)
cat_transl  <- read_csv(file.path(data_dir, "product_category_name_translation.csv"), show_col_types = FALSE)

# ---------------------------------------------------------------------
# 1) Produtos + tradução da categoria (PT -> EN, e um nome amigável)
# ---------------------------------------------------------------------
products <- products %>%
  left_join(cat_transl, by = "product_category_name") %>%
  mutate(
    categoria = coalesce(product_category_name_english, product_category_name, "sem_categoria"),
    categoria = str_replace_all(categoria, "_", " "),
    categoria = str_to_title(categoria)
  ) %>%
  select(product_id, categoria)

# ---------------------------------------------------------------------
# 2) Itens: receita e frete por PEDIDO + categoria principal do pedido
# ---------------------------------------------------------------------
items_cat <- items %>%
  left_join(products, by = "product_id") %>%
  mutate(categoria = coalesce(categoria, "Sem Categoria"))

# Agregado por pedido
order_items_agg <- items_cat %>%
  group_by(order_id) %>%
  summarise(
    receita = sum(price, na.rm = TRUE),
    frete   = sum(freight_value, na.rm = TRUE),
    itens   = n(),
    .groups = "drop"
  )

# Categoria "principal" do pedido = a de maior valor
order_main_cat <- items_cat %>%
  group_by(order_id, categoria) %>%
  summarise(valor = sum(price, na.rm = TRUE), .groups = "drop") %>%
  group_by(order_id) %>%
  slice_max(valor, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  select(order_id, categoria)

# ---------------------------------------------------------------------
# 3) Pagamentos por pedido: valor total, tipo principal, parcelas
# ---------------------------------------------------------------------
tipo_pt <- c(
  credit_card = "Cartão de Crédito",
  boleto      = "Boleto",
  voucher     = "Voucher",
  debit_card  = "Cartão de Débito",
  not_defined = "Não Definido"
)

pay_agg <- payments %>%
  group_by(order_id) %>%
  summarise(
    valor_pago  = sum(payment_value, na.rm = TRUE),
    parcelas    = max(payment_installments, na.rm = TRUE),
    tipo_pgto   = payment_type[which.max(payment_value)],
    .groups = "drop"
  ) %>%
  mutate(tipo_pgto = coalesce(unname(tipo_pt[tipo_pgto]), "Outro"))

# ---------------------------------------------------------------------
# 4) Avaliações por pedido (média, caso haja mais de uma)
# ---------------------------------------------------------------------
rev_agg <- reviews %>%
  group_by(order_id) %>%
  summarise(nota = mean(review_score, na.rm = TRUE), .groups = "drop")

# Estado do vendedor por pedido (vendedor principal = 1º item)
order_seller <- items %>%
  left_join(sellers %>% select(seller_id, seller_state), by = "seller_id") %>%
  group_by(order_id) %>%
  summarise(seller_uf = dplyr::first(na.omit(seller_state)), .groups = "drop")

# ---------------------------------------------------------------------
# 5) Tabela principal: um pedido por linha, enriquecido
# ---------------------------------------------------------------------
orders_enriched <- orders %>%
  left_join(customers %>% select(customer_id, customer_unique_id, estado = customer_state), by = "customer_id") %>%
  left_join(order_items_agg, by = "order_id") %>%
  left_join(order_main_cat,  by = "order_id") %>%
  left_join(order_seller,    by = "order_id") %>%
  left_join(pay_agg,         by = "order_id") %>%
  left_join(rev_agg,         by = "order_id") %>%
  mutate(
    data_compra   = as_datetime(order_purchase_timestamp),
    mes           = floor_date(as_date(data_compra), "month"),
    entregue_em   = as_datetime(order_delivered_customer_date),
    estimada_em   = as_datetime(order_estimated_delivery_date),
    aprovado_em   = as_datetime(order_approved_at),
    despacho_em   = as_datetime(order_delivered_carrier_date),
    dias_entrega  = as.numeric(difftime(entregue_em, data_compra, units = "days")),
    dias_vs_prev  = as.numeric(difftime(estimada_em, entregue_em, units = "days")), # >0 = adiantado
    lead_previsto = as.numeric(difftime(estimada_em, data_compra, units = "days")),
    t_aprovacao   = as.numeric(difftime(aprovado_em, data_compra, units = "days")),   # compra -> aprovação
    t_despacho    = as.numeric(difftime(despacho_em, aprovado_em, units = "days")),   # aprovação -> despacho
    t_transporte  = as.numeric(difftime(entregue_em, despacho_em, units = "days")),   # despacho -> entrega
    no_prazo      = entregue_em <= estimada_em,
    entregue      = order_status == "delivered",
    categoria     = coalesce(categoria, "Sem Categoria"),
    tipo_pgto     = coalesce(tipo_pgto, "Outro")
  )

# ---------------------------------------------------------------------
# 5b) Novos x Recorrentes: ordem de compra por cliente único
# ---------------------------------------------------------------------
orders_enriched <- orders_enriched %>%
  arrange(customer_unique_id, data_compra) %>%
  group_by(customer_unique_id) %>%
  mutate(compra_rank = row_number(),
         recorrente  = compra_rank > 1,
         tipo_cliente = if_else(recorrente, "Recorrente", "Novo")) %>%
  ungroup()

# ---------------------------------------------------------------------
# 6) Salva objeto pronto
# ---------------------------------------------------------------------
prepared <- list(
  orders   = orders_enriched,
  gerado_em = Sys.time()
)
saveRDS(prepared, "olist_prepared.rds")

# ---------------------------------------------------------------------
# Resumo rápido (sanity check)
# ---------------------------------------------------------------------
d <- orders_enriched
del <- d %>% filter(entregue)
msg("Pedidos totais:", nrow(d))
msg("Pedidos entregues:", nrow(del))
msg("Receita total (entregues): R$", format(round(sum(del$receita, na.rm = TRUE), 2), big.mark = ".", decimal.mark = ","))
msg("Ticket médio (entregues): R$", round(mean(del$receita, na.rm = TRUE), 2))
msg("Nota média:", round(mean(d$nota, na.rm = TRUE), 2))
msg("Prazo médio de entrega (dias):", round(mean(del$dias_entrega, na.rm = TRUE), 1))
msg("% no prazo:", round(100 * mean(del$no_prazo, na.rm = TRUE), 1), "%")
msg("Período:", as.character(min(d$mes, na.rm = TRUE)), "a", as.character(max(d$mes, na.rm = TRUE)))
msg("Estados:", n_distinct(d$estado, na.rm = TRUE))
msg("OK - olist_prepared.rds salvo.")
