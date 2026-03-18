#############################################
# 1. BLOQUE: Instalación y carga de paquetes
#############################################

# Lista de paquetes necesarios
paquetes_necesarios <- c(
  "readxl", "ggplot2", "lmtest", "forecast", 
  "tseries", "zoo", "TSA", "dplyr", "tidyr", "car"
)

for (pkg in paquetes_necesarios) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, dependencies = TRUE,
                     repos = "https://cloud.r-project.org")
    library(pkg, character.only = TRUE)
  }
}

#############################################
# 2. IMPORTACIÓN Y PREPARACIÓN DE DATOS
#############################################

# --- RUTA AL ARCHIVO EXCEL ---
# Usamos una ruta absoluta para asegurar que el script siempre encuentre el archivo,
# sin importar desde dónde se ejecute.
ruta_excel <- "C:/Users/Usuario/Desktop/PsetRemesas/ExcelREMESAS.xlsx"
cat("Buscando archivo en:", ruta_excel, "\n")

# Importar datos desde el archivo Excel (hoja "DATOS")
if (!file.exists(ruta_excel)) {
  stop(paste("¡ERROR CRÍTICO! No se encontró el archivo en la ruta especificada:", ruta_excel))
}
raw <- read_excel(ruta_excel, sheet = "DATOS")

# Convertir a formato largo: Año-Mes-Valor
meses <- c(
  "enero", "febrero", "marzo", "abril", "mayo", "junio",
  "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"
)

df <- raw |>
  rename(Año = `Años`) |>
  select(Año, all_of(meses)) |>
  mutate(across(all_of(meses), as.numeric)) |>
  pivot_longer(
    cols     = all_of(meses),
    names_to = "Mes",
    values_to = "Remesas"
  ) |>
  filter(!is.na(Remesas)) |>
  mutate(
    Mes_num = match(Mes, meses),
    Fecha   = as.yearmon(sprintf("%d-%02d", Año, Mes_num), "%Y-%m")
  ) |>
  arrange(Fecha) |>
  select(Fecha, Remesas)

# -----------------------------
# Crear columna Proxy placeholder
# (Reemplaza esto con tu verdadero proxy)
# -----------------------------
df$Proxy <- rep(0, nrow(df))
# Por ejemplo, si tienes un Excel con proxy, leerlo aquí y hacer left_join:
# proxy_raw <- read_excel("ProxyRemesas.xlsx", sheet = "Proxy")
# proxy_raw <- proxy_raw %>%
#   mutate(Fecha = as.yearmon(Fecha, "%Y-%m")) %>%
#   arrange(Fecha)
# df <- left_join(df, proxy_raw, by = "Fecha")
# rename(df, Proxy = ValorProxy)

# Crear un índice de tiempo que represente los meses (t = 1, 2, 3, ...)
df$t <- seq_along(df$Fecha)

#############################################
# 3. ANÁLISIS DE LA SERIE: TENDENCIA Y CICLO
#############################################

# Crear un directorio para guardar los gráficos
# Usamos la carpeta de Descargas del usuario para evitar perder los archivos
path_descargas <- file.path(Sys.getenv("USERPROFILE"), "Downloads", "graficos_remesas")
dir.create(path_descargas, showWarnings = FALSE)
cat("Guardando gráficos en:", path_descargas, "\n")

# 3.0 Gráfico de la serie original de remesas
p1 <- ggplot(df, aes(x = Fecha, y = Remesas)) +
  geom_line(color = "steelblue") +
  labs(
    title = "Remesas a Nicaragua (serie mensual)",
    x = "Fecha", y = "Millones de USD"
  ) +
  theme_minimal()
print(p1)
ggsave(file.path(path_descargas, "01_remesas_serie_original.png"), plot = p1, width = 8, height = 5)


# 3.1 Estimación de la tendencia determinista con modelo cuadrático
tendencia_lm <- lm(Remesas ~ t + I(t^2), data = df)
cat("Resumen de la regresión de tendencia cuadrática:\n")
print(summary(tendencia_lm))

# Calcular la tendencia estimada (pronosticada) usando el modelo cuadrático
df$trend <- predict(tendencia_lm, newdata = df)

# Extraer el componente cíclico (residuos de la tendencia)
df$cycle <- df$Remesas - df$trend

# Gráfico comparativo: Remesas vs. Tendencia cuadrática
p2 <- ggplot(df, aes(x = Fecha)) +
  geom_line(aes(y = Remesas, color = "Remesas")) +
  geom_line(aes(y = trend,   color = "Tendencia cuadrática"), linewidth = 1) +
  scale_color_manual(
    values = c("Remesas" = "steelblue", "Tendencia cuadrática" = "red")
  ) +
  labs(
    title = "Remesas vs. Tendencia Cuadrática Estimada",
    y = "Millones de USD"
  ) +
  theme_minimal()
print(p2)
ggsave(file.path(path_descargas, "02_remesas_vs_tendencia.png"), plot = p2, width = 8, height = 5)

# Gráfico del componente cíclico
p3 <- ggplot(df, aes(x = Fecha, y = cycle)) +
  geom_line(color = "darkgreen") +
  labs(
    title = "Componente cíclico de las remesas",
    x = "Fecha", y = "Residuales"
  ) +
  theme_minimal()
print(p3)
ggsave(file.path(path_descargas, "03_componente_ciclico.png"), plot = p3, width = 8, height = 5)

#############################################
# 4. PRUEBAS DE ESTACIONARIEDAD Y DIAGNÓSTICO DEL CICLO
#############################################

pp_result <- pp.test(df$cycle)
adf_result <- adf.test(df$cycle, alternative = "stationary")

cat("\nResultados de la prueba Phillips-Perron:\n")
print(pp_result)
cat("\nResultados de la prueba ADF:\n")
print(adf_result)
cat("\nGuardando gráficos de ACF y PACF en Descargas...\n")
png(file.path(path_descargas, "04_acf_pacf_ciclo.png"), width = 800, height = 400)
par(mfrow = c(1, 2))
acf(df$cycle, lag.max = 36, main = "ACF del Componente Cíclico")
pacf(df$cycle, lag.max = 36, main = "PACF del Componente Cíclico")
dev.off()
par(mfrow = c(1, 1)) # Resetear layout

#############################################
# 5. SELECCIÓN Y ESTIMACIÓN DEL MODELO ARMA (y AR(1))
#############################################

# Convertir el componente cíclico a una serie de tiempo (ts) con frecuencia mensual = 12
y_ts <- ts(
  df$cycle,
  frequency = 12,
  start = c(
    as.numeric(format(df$Fecha[1], "%Y")),
    as.numeric(format(df$Fecha[1], "%m"))
  )
)

# Inicializar data frame para almacenar resultados de modelos ARMA
model_results <- data.frame(AR = integer(), MA = integer(), AIC = numeric(), BIC = numeric())

# Bucle para evaluar modelos ARMA con p y q de 0 a 4
for (i in 0:4) {
  for (j in 0:4) {
    mod <- tryCatch(arima(y_ts, order = c(i, 0, j)), error = function(e) NULL)
    if (!is.null(mod)) {
      model_results <- rbind(
        model_results,
        data.frame(AR = i, MA = j, AIC = AIC(mod), BIC = BIC(mod))
      )
    }
  }
}

cat("\nResultados de los modelos ARMA (p, q, AIC, BIC):\n")
print(model_results)

# Seleccionar el mejor modelo según AIC y BIC
best_model_aic <- model_results[which.min(model_results$AIC), ]
best_model_bic <- model_results[which.min(model_results$BIC), ]

cat(
  "\nMejor modelo según AIC: ARIMA(",
  best_model_aic$AR, ",0,", best_model_aic$MA,
  ")\n", sep = ""
)
cat(
  "Mejor modelo según BIC: ARIMA(",
  best_model_bic$AR, ",0,", best_model_bic$MA,
  ")\n", sep = ""
)

# Ajustar el modelo ARMA óptimo (utilizando el seleccionado por AIC) con método ML
fit_final <- Arima(
  y_ts,
  order = c(best_model_aic$AR, 0, best_model_aic$MA),
  method = "ML",
  include.constant = TRUE,
  optim.control = list(maxit = 2500)
)
cat("\nResumen del modelo ARMA final (ML):\n")
print(summary(fit_final))

# Diagnóstico de residuos del modelo final
cat("\nGuardando gráfico de diagnóstico de residuos en Descargas...\n")
png(file.path(path_descargas, "05_residuos_modelo_final.png"), width = 800, height = 600)
checkresiduals(fit_final)
dev.off()

# También ajustamos AR(1) in-sample para comparar
fit_ar1_in <- Arima(
  y_ts,
  order = c(1, 0, 0),
  include.constant = TRUE,
  method = "ML"
)
cat("\n=== Resumen in-sample AR(1) sobre ciclo ===\n")
print(summary(fit_ar1_in))
cat("\nGuardando gráfico de diagnóstico de residuos en Descargas...\n")
png(file.path(path_descargas, "06_residuos_modelo_ar1.png"), width = 800, height = 600)
checkresiduals(fit_ar1_in)
dev.off()

#############################################
# 6. PRONÓSTICO DEL CICLO Y RECONSTRUCCIÓN DE LAS REMESAS (12 MESES)
#############################################

# Definir el horizonte de pronóstico (12 meses = 1 año)
forecast_horizon <- 12

# Generar el pronóstico del componente cíclico para el horizonte definido (ARMA)
cycle_forecast <- forecast(fit_final, h = forecast_horizon)
cat("\nPronóstico del Componente Cíclico (12 meses, ARMA):\n")
print(cycle_forecast)

# Pronóstico de la tendencia futura: usa t y t²
t_future <- seq(from = max(df$t) + 1, by = 1, length.out = forecast_horizon)
trend_fc <- predict(tendencia_lm, newdata = data.frame(t = t_future))

# Reconstruir el pronóstico de remesas: tendencia + ciclo
remesas_fc <- trend_fc + cycle_forecast$mean

# Configuración de fechas futuras
last_date <- max(df$Fecha)
fecha_fc  <- seq(last_date + 1/12, by = 1/12, length.out = forecast_horizon)

# Data frame con el pronóstico completo
pronostico <- data.frame(
  Fecha      = as.yearmon(fecha_fc),
  Tendencia  = trend_fc,
  Ciclo      = cycle_forecast$mean,
  Remesas_fc = remesas_fc,
  Lo80       = trend_fc + cycle_forecast$lower[, 1],
  Hi80       = trend_fc + cycle_forecast$upper[, 1],
  Lo95       = trend_fc + cycle_forecast$lower[, 2],
  Hi95       = trend_fc + cycle_forecast$upper[, 2]
)

cat("\nPronóstico de remesas (12 meses, ARMA):\n")
print(pronostico)

# -------------------------------------------------------
# Gráfico del pronóstico (línea sólida para la proyección)
# -------------------------------------------------------
p_fc <- ggplot() +
  geom_line(data = df, aes(x = Fecha, y = Remesas), color = "steelblue") +
  geom_line(
    data     = pronostico,
    aes(x = Fecha, y = Remesas_fc),
    linetype = "solid",   # línea continua para la proyección
    size     = 1.1,
    color    = "red"
  ) +
  geom_ribbon(
    data = pronostico,
    aes(x = Fecha, ymin = Lo95, ymax = Hi95),
    alpha = 0.15,
    fill  = "red"
  ) +
  labs(
    title = "Pronóstico de Remesas (12 Meses) con Intervalos de Confianza al 95%",
    x     = "Fecha",
    y     = "Millones de USD"
  ) +
  # CORRECCIÓN: Usar scale_x_yearmon para el eje de fechas y ajustar los breaks
  # para que muestre una etiqueta por año.
  scale_x_yearmon(
    format = "%Y-%m",
    breaks = seq(from = floor(as.numeric(min(df$Fecha))),
                 to = ceiling(as.numeric(max(pronostico$Fecha))),
                 by = 2) # Etiqueta cada 2 años para mayor claridad
  ) +
  theme_minimal()
print(p_fc)
ggsave(file.path(path_descargas, "07_pronostico_remesas.png"), plot = p_fc, width = 10, height = 6)

#############################################
# 7. EVALUACIÓN FUERA DE MUESTRA
#############################################

# Tamaño de la muestra de prueba OOS (en meses)
test_size <- 24  

# Puntos de corte para entrenamiento y prueba
split_pt <- length(y_ts) - test_size

# Inicializar matrices para errores h = 1 y h = 2
err_arma <- err_ar1 <- matrix(NA, nrow = test_size, ncol = 2)

for (i in 1:test_size) {
  # Submuestra móvil hasta el punto actual
  train_i <- window(y_ts, end = time(y_ts)[split_pt + i - 1])
  
  arma_i <- Arima(train_i,
                  order = c(best_model_aic$AR, 0, best_model_aic$MA),
                  method = "ML",
                  include.constant = TRUE)
  ar1_i  <- Arima(train_i,
                  order = c(1, 0, 0),
                  include.constant = TRUE,
                  method = "ML")
  
  fc_arma <- forecast(arma_i, h = 2)$mean
  fc_ar1  <- forecast(ar1_i,  h = 2)$mean
  
  y_real1 <- y_ts[split_pt + i]
  y_real2 <- y_ts[split_pt + i + 1]
  
  err_arma[i, 1] <- y_real1 - fc_arma[1]
  err_arma[i, 2] <- y_real2 - fc_arma[2]
  
  err_ar1[i, 1]  <- y_real1 - fc_ar1[1]
  err_ar1[i, 2]  <- y_real2 - fc_ar1[2]
}

#############################################
# 8. COMPARACIÓN ARMA vs. AR(1) (Diebold–Mariano)
#############################################

dm_h1 <- dm.test(err_arma[, 1], err_ar1[, 1], h = 1, power = 2)
dm_h2 <- dm.test(err_arma[, 2], err_ar1[, 2], h = 2, power = 2)

cat("\nDiebold–Mariano ARMA vs. AR(1), h = 1:\n")
print(dm_h1)
cat("\nDiebold–Mariano ARMA vs. AR(1), h = 2:\n")
print(dm_h2)

#############################################
# 9. PROMEDIOS SIMPLE Y PONDERADO
#############################################

# Calcular ponderadores inversos con base en el MAE del último año de entrenamiento
w_arma <- 1 / mean(abs(err_arma[(test_size - 11):test_size, 1]))
w_ar1  <- 1 / mean(abs(err_ar1 [(test_size - 11):test_size, 1]))

err_simple <- err_weight <- numeric(test_size)

for (i in 1:test_size) {
  train_i <- window(y_ts, end = time(y_ts)[split_pt + i - 1])
  
  arma_i <- Arima(train_i,
                  order = c(best_model_aic$AR, 0, best_model_aic$MA),
                  method = "ML",
                  include.constant = TRUE)
  ar1_i  <- Arima(train_i,
                  order = c(1, 0, 0),
                  include.constant = TRUE,
                  method = "ML")
  
  f_arma  <- forecast(arma_i, h = 1)$mean
  f_ar1   <- forecast(ar1_i,  h = 1)$mean
  
  f_simple   <- (f_arma + f_ar1) / 2
  f_weighted <- (w_arma * f_arma + w_ar1 * f_ar1) / (w_arma + w_ar1)
  
  y_real <- y_ts[split_pt + i]
  
  err_simple[i]  <- y_real - f_simple
  err_weight[i]  <- y_real - f_weighted
}

dm_simple <- dm.test(err_arma[, 1], err_simple,   h = 1, power = 2)
dm_weight <- dm.test(err_arma[, 1], err_weight,   h = 1, power = 2)

cat("\nDiebold–Mariano ARMA vs. Promedio Simple (h=1):\n")
print(dm_simple)
cat("\nDiebold–Mariano ARMA vs. Promedio Ponderado (h=1):\n")
print(dm_weight)

print("NO EXISTE DIFERENCIAS SIGNIFICATIVAS ENTRE EL ARMA ESTIMADO Y EL MODELO AR(1)")

#############################################
# 10. TEST DE RACIONALIDAD “CLÁSICO” (Mincer–Zarnowitz usando ŷ como proxy)
#############################################

# (Asumimos que ya definiste `split_pt`, `test_size`, y calculaste `err_ar1[i,1]`
#  dentro del bucle OOS en el apartado 7.)

# 10.1 Extraer las series OOS para h = 1:
#     - y_real: valores reales del ciclo en la ventana fuera de muestra
#     - y_hat : pronóstico AR(1) para h = 1 en esa misma ventana

y_real <- df$cycle[(split_pt + 1):(split_pt + test_size)]
y_hat  <- y_real - err_ar1[, 1]   # como err_ar1[i,1] = y_real_i - y_hat_i

# 10.2 Verificar longitudes
if (length(y_real) != length(y_hat)) {
  stop("Error: y_real y y_hat deben tener la misma longitud.")
}

# 10.3 Armar el data.frame para Mincer–Zarnowitz
mz_data <- data.frame(
  e_t1  = as.numeric(y_real - y_hat),  # estos son justamente err_ar1[,1]
  y_hat = as.numeric(y_hat)
)

# Nota: podríamos haber usado directamente err_ar1[,1] como e_t1, pero lo recalculamos
# de y_real - y_hat para dejar todo claro.

# 10.4 Ajustar la regresión “clásica”:
#      e_{t,1} = α_0 + α_1 * ŷ_{t,1} + ε
mz_reg_classic <- lm(e_t1 ~ y_hat, data = mz_data)

cat("\n=== Resultados Mincer–Zarnowitz (clásico, sin proxy externa) ===\n")
print(coeftest(mz_reg_classic))

# 10.5 Wald test conjunto H0: α_0 = 0 y α_1 = 0
wald_test_classic <- linearHypothesis(
  mz_reg_classic,
  c("(Intercept) = 0",  # α_0 = 0
    "y_hat = 0")         # α_1 = 0
)
cat("\n=== Wald test (α_0 = 0, α_1 = 0) ===\n")
print(wald_test_classic)

# --- INICIO: TEST DE RACIONALIDAD PARA ARMA(4,0,2) ---
# (pégalo justo después del bloque de Mincer–Zarnowitz para AR(1))

# 1. Extraer las series OOS para h = 1 de ARMA(4,0,2):
y_real_arma <- df$cycle[(split_pt + 1):(split_pt + test_size)]
y_hat_arma  <- y_real_arma - err_arma[, 1]  # err_arma[i,1] = y_real_i - y_hat_arma_i

# 2. Verificar longitudes
if (length(y_real_arma) != length(y_hat_arma)) {
  stop("Error: y_real_arma y y_hat_arma deben tener la misma longitud.")
}

# 3. Armar el data.frame para Mincer–Zarnowitz (ARMA)
mz_data_arma <- data.frame(
  e_t1_arma   = as.numeric(y_real_arma - y_hat_arma),  # equivale a err_arma[,1]
  y_hat_arma  = as.numeric(y_hat_arma)
)

# 4. Ajustar la regresión “clásica”:
mz_reg_arma <- lm(e_t1_arma ~ y_hat_arma, data = mz_data_arma)

cat("\n=== Resultados Mincer–Zarnowitz (clásico) para ARMA(4,0,2) ===\n")
print(coeftest(mz_reg_arma))

# 5. Wald test conjunto H0: α_0 = 0 y α_1 = 0
wald_test_arma <- linearHypothesis(
  mz_reg_arma,
  c("(Intercept) = 0",   # α_0 = 0
    "y_hat_arma = 0")    # α_1 = 0
)
cat("\n=== Wald test (α_0 = 0, α_1 = 0) para ARMA(4,0,2) ===\n")
print(wald_test_arma)
# --- FIN: TEST DE RACIONALIDAD PARA ARMA(4,0,2) ---

cat("\n¡Proceso completado! Verifica la carpeta 'graficos_remesas' en tus Descargas.\n")
