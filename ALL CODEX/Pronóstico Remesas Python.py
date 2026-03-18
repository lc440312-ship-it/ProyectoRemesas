#############################################
# 1. BLOQUE: Instalación y carga de paquetes
#############################################
import os
import sys
import subprocess
import importlib
import warnings

print("--- INICIANDO VERIFICACIÓN DE LIBRERÍAS ---")


def verificar_e_instalar(package, import_name=None):
    if import_name is None:
        import_name = package
    try:
        importlib.import_module(import_name)
        print(f"[OK] {package} está instalada.")
    except (ImportError, ValueError) as e:
        # Detectar conflicto de versiones (NumPy 2.0 vs pmdarima)
        if "numpy.dtype size changed" in str(e) or "binary incompatibility" in str(e):
            print(
                f"\n[ALERTA CRÍTICA] Incompatibilidad detectada en '{package}' con NumPy 2.0.")
            print("--- SOLUCIONANDO: Instalando versión compatible de NumPy (1.x) ---")
            subprocess.check_call(
                [sys.executable, "-m", "pip", "install", "numpy<2.0"])
            print("\n[ÉXITO] NumPy ha sido corregido.")
            print(
                ">>> POR FAVOR, CIERRA Y VUELVE A EJECUTAR ESTE SCRIPT PARA APLICAR LOS CAMBIOS. <<<")
            sys.exit(0)

        print(
            f"[ALERTA] No se encontró '{package}' o tiene errores. Instalando/Actualizando...")
        try:
            subprocess.check_call(
                [sys.executable, "-m", "pip", "install", package])
            print(f"[EXITO] '{package}' se instaló correctamente.")
        except subprocess.CalledProcessError:
            print(
                f"[ERROR CRITICO] No se pudo instalar '{package}'. Verifica tu internet.")


# Lista de librerías requeridas (nombre en pip)
libs_requeridas = [
    "pandas", "numpy", "statsmodels", "matplotlib",
    "seaborn", "arch", "pmdarima", "openpyxl"
]

for lib in libs_requeridas:
    verificar_e_instalar(lib)

# Importaciones principales movidas DESPUÉS de la verificación
try:
    import pandas as pd
    import numpy as np
    import statsmodels.api as sm
    import matplotlib.pyplot as plt
    import seaborn as sns
    import pmdarima as pm
    from statsmodels.stats.stattools import durbin_watson
    from pmdarima.arima import ndiffs
    from statsmodels.stats.diagnostic import acorr_ljungbox
    from statsmodels.tsa.arima.model import ARIMA
    from statsmodels.graphics.tsaplots import plot_acf, plot_pacf
    from arch.unitroot import PhillipsPerron
    from statsmodels.tsa.stattools import adfuller
except ValueError as e:
    if "numpy.dtype size changed" in str(e):
        print("\n[ERROR CRITICO] Incompatibilidad detectada entre NumPy y pmdarima.")
        print(
            "SOLUCION: Ejecuta en tu terminal: pip install \"numpy<2.0\" --force-reinstall")
        sys.exit(1)
    raise e

print("--- TODAS LAS LIBRERÍAS ESTÁN LISTAS ---\n")

# pmdarima es el equivalente a auto.arima de R

# Silenciar advertencias de convergencia de statsmodels
warnings.filterwarnings("ignore", category=UserWarning)

print("Librerías cargadas correctamente.")

#############################################
# 2. IMPORTACIÓN Y PREPARACIÓN DE DATOS
#############################################

# Asegurarse de que el archivo Excel está en el mismo directorio que el script
ruta_excel = r"C:\Users\Usuario\Desktop\PsetRemesas\ExcelREMESAS.xlsx"
try:
    raw = pd.read_excel(ruta_excel, sheet_name="DATOS")
except FileNotFoundError:
    print(f"ERROR: No se encontró el archivo en: {ruta_excel}")
    print("Verifica que la ruta y el nombre del archivo sean correctos.")
    sys.exit(1)

# Convertir a formato largo (melt es el equivalente a pivot_longer)
meses_es = [
    "enero", "febrero", "marzo", "abril", "mayo", "junio",
    "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"
]

# --- CORRECCIÓN: Autodetección de la estructura de la tabla ---
# A veces los Excel tienen títulos en las primeras filas. Buscamos dónde están los encabezados.
raw.columns = raw.columns.astype(str).str.strip()  # Limpiar espacios

# Si no vemos 'enero' o 'años' en las columnas actuales, buscamos más abajo
claves_esperadas = ['enero', 'febrero', 'años', 'año']
columnas_lower = raw.columns.str.lower().tolist()

if not any(k in columnas_lower for k in claves_esperadas):
    print("[AVISO] Encabezados no detectados en la primera fila. Escaneando filas inferiores...")
    for i in range(1, 10):  # Probar hasta la fila 10
        try:
            temp = pd.read_excel(ruta_excel, sheet_name="DATOS", header=i)
            temp.columns = temp.columns.astype(str).str.strip()
            if any(k in temp.columns.str.lower() for k in claves_esperadas):
                raw = temp
                print(f"[ÉXITO] Tabla de datos encontrada en la fila {i+1}.")
                break
        except Exception:
            continue

# Normalizar nombres de columnas (Enero -> enero, Años -> Año)
mapa_cols = {}
for col in raw.columns:
    c_low = col.lower()
    if 'año' in c_low:  # Atrapa "Años", "Año", "Year"
        mapa_cols[col] = 'Año'
    elif c_low in meses_es:
        mapa_cols[col] = c_low  # Asegura minúsculas

df = raw.rename(columns=mapa_cols)

# Verificar existencia de columna Año antes de continuar
if 'Año' not in df.columns:
    print(f"\n[ERROR CRÍTICO] No se encontró la columna 'Año' o 'Años'.")
    print(f"Columnas detectadas: {list(raw.columns)}")
    print("Revisa que el Excel tenga una columna llamada 'Años' y columnas para los meses.")
    sys.exit(1)

df = df.melt(
    id_vars='Año',
    value_vars=meses_es,
    var_name='Mes',
    value_name='Remesas'
)

# Limpiar y ordenar datos
df.dropna(subset=['Remesas'], inplace=True)
df['Mes_num'] = df['Mes'].apply(lambda x: meses_es.index(x) + 1)
df['Fecha_str'] = df['Año'].astype(int).astype(
    str) + '-' + df['Mes_num'].astype(str).str.zfill(2)
# as.yearmon en R es equivalente a to_period('M') en pandas
df['Fecha'] = pd.to_datetime(df['Fecha_str']).dt.to_period('M')
df = df.sort_values('Fecha').reset_index(drop=True)
df = df[['Fecha', 'Remesas']]

# Crear un índice de tiempo (t = 1, 2, 3, ...)
df['t'] = np.arange(1, len(df) + 1)

# Establecer Fecha como índice para facilitar el trabajo con series de tiempo
df.set_index('Fecha', inplace=True)

print("Datos procesados:")
print(f"Rango histórico detectado: {df.index.min()} hasta {df.index.max()}")
print(f"Total de meses históricos: {len(df)}")
print(df.head())

#############################################
# 3. ANÁLISIS DE LA SERIE: TENDENCIA Y CICLO
#############################################

# Crear directorio para guardar los gráficos en Descargas
path_descargas = os.path.join(os.path.expanduser(
    '~'), 'Downloads', 'graficos_remesas_python')
os.makedirs(path_descargas, exist_ok=True)
print(f"\nGuardando gráficos en: {path_descargas}")

# 3.0 Gráfico de la serie original
plt.figure(figsize=(10, 5))
plt.plot(df.index.to_timestamp(), df['Remesas'], color='steelblue')
plt.title("Remesas a Nicaragua (serie mensual)")
plt.xlabel("Fecha")
plt.ylabel("Millones de USD")
plt.grid(True, linestyle='--', alpha=0.6)
plt.savefig(os.path.join(path_descargas, "01_remesas_serie_original.png"))
plt.close()

# 3.1 Estimación de la tendencia determinista con modelo cuadrático
# Usamos statsmodels que es muy similar a lm() de R
X = df[['t']]
X['t2'] = X['t']**2
X = sm.add_constant(X)  # Añadir intercepto
y = df['Remesas']

tendencia_lm = sm.OLS(y, X).fit()
print("\nResumen de la regresión de tendencia cuadrática:")
print(tendencia_lm.summary())

df['trend'] = tendencia_lm.predict(X)
df['cycle'] = df['Remesas'] - df['trend']

# Gráfico comparativo: Remesas vs. Tendencia
plt.figure(figsize=(10, 5))
plt.plot(df.index.to_timestamp(),
         df['Remesas'], color='steelblue', label='Remesas')
plt.plot(df.index.to_timestamp(),
         df['trend'], color='red', linewidth=2, label='Tendencia Cuadrática')
plt.title("Remesas vs. Tendencia Cuadrática Estimada")
plt.ylabel("Millones de USD")
plt.legend()
plt.grid(True, linestyle='--', alpha=0.6)
plt.savefig(os.path.join(path_descargas, "02_remesas_vs_tendencia.png"))
plt.close()

# Gráfico del componente cíclico
plt.figure(figsize=(10, 5))
plt.plot(df.index.to_timestamp(), df['cycle'], color='darkgreen')
plt.title("Componente Cíclico de las Remesas")
plt.xlabel("Fecha")
plt.ylabel("Residuales")
plt.grid(True, linestyle='--', alpha=0.6)
plt.savefig(os.path.join(path_descargas, "03_componente_ciclico.png"))
plt.close()

#############################################
# 4. PRUEBAS DE ESTACIONARIEDAD Y DIAGNÓSTICO DEL CICLO
#############################################

# Prueba Phillips-Perron
pp_test = PhillipsPerron(df['cycle'])
print("\nResultados de la prueba Phillips-Perron:")
print(pp_test.summary())

# Prueba Dickey-Fuller Aumentada
adf_test = adfuller(df['cycle'])
print("\nResultados de la prueba ADF:")
print(f'ADF Statistic: {adf_test[0]}')
print(f'p-value: {adf_test[1]}')

# Gráficos ACF y PACF
fig, axes = plt.subplots(1, 2, figsize=(16, 5))
plot_acf(df['cycle'], lags=36, ax=axes[0], title="ACF del Componente Cíclico")
plot_pacf(df['cycle'], lags=36, ax=axes[1],
          title="PACF del Componente Cíclico")
plt.savefig(os.path.join(path_descargas, "04_acf_pacf_ciclo.png"))
plt.close()

#############################################
# 5. SELECCIÓN Y ESTIMACIÓN DEL MODELO ARMA
#############################################

# Bucle para encontrar el mejor modelo ARMA (p,q)
y_ts = df['cycle']
model_results = []

for p in range(5):
    for q in range(5):
        try:
            model = ARIMA(y_ts, order=(p, 0, q)).fit()
            model_results.append(
                {'AR': p, 'MA': q, 'AIC': model.aic, 'BIC': model.bic})
        except Exception as e:
            continue

results_df = pd.DataFrame(model_results)
print("\nResultados de los modelos ARMA (p, q, AIC, BIC):")
print(results_df)

best_model_aic = results_df.loc[results_df['AIC'].idxmin()]
best_model_bic = results_df.loc[results_df['BIC'].idxmin()]

print(
    f"\nMejor modelo según AIC: ARIMA({int(best_model_aic['AR'])}, 0, {int(best_model_aic['MA'])})")
print(
    f"Mejor modelo según BIC: ARIMA({int(best_model_bic['AR'])}, 0, {int(best_model_bic['MA'])})")

# Ajustar el modelo final (usando el de AIC como en el script de R)
p_opt, q_opt = int(best_model_aic['AR']), int(best_model_aic['MA'])
fit_final = ARIMA(y_ts, order=(p_opt, 0, q_opt)).fit()
print("\nResumen del modelo ARMA final:")
print(fit_final.summary())

# Diagnóstico de residuos (equivalente a checkresiduals)
fig = fit_final.plot_diagnostics(figsize=(10, 8))
fig.suptitle("Diagnóstico de Residuos del Modelo Final", fontsize=16, y=1.02)
plt.tight_layout()
plt.savefig(os.path.join(path_descargas, "05_residuos_modelo_final.png"))
plt.close()

#############################################
# 6. PRONÓSTICO Y RECONSTRUCCIÓN
#############################################
forecast_horizon = 12

# Pronóstico del ciclo
cycle_forecast = fit_final.get_forecast(steps=forecast_horizon)
cycle_fc_mean = cycle_forecast.predicted_mean
conf_int = cycle_forecast.conf_int(
    alpha=0.05)  # Intervalos de confianza al 95%

# Pronóstico de la tendencia
t_future = np.arange(df['t'].max() + 1, df['t'].max() + 1 + forecast_horizon)
X_future = pd.DataFrame({'const': 1, 't': t_future, 't2': t_future**2})
# Aseguramos el mismo orden de columnas que en el entrenamiento para evitar errores
X_future = X_future[['const', 't', 't2']]
trend_fc = tendencia_lm.predict(X_future)

# Reconstruir el pronóstico
# --- CORRECCIÓN CLAVE: Usamos .values para sumar solo los números y evitar conflictos de índice ---
remesas_fc = trend_fc.values + cycle_fc_mean.values

# Crear DataFrame de pronóstico
future_dates = pd.period_range(
    start=df.index.max() + 1, periods=forecast_horizon, freq='M')

print(
    f"\nGenerando pronóstico para el periodo: {future_dates[0]} al {future_dates[-1]}")

pronostico = pd.DataFrame({
    'Fecha': future_dates,
    'Tendencia': trend_fc.values,  # Forzamos array
    'Ciclo': cycle_fc_mean.values,
    'Remesas_fc': remesas_fc,
    'Lo95': trend_fc.values + conf_int.iloc[:, 0].values,
    'Hi95': trend_fc.values + conf_int.iloc[:, 1].values
}).set_index('Fecha')

print("\nPronóstico de remesas (12 meses):")
print(pronostico)

# Gráfico del pronóstico
plt.figure(figsize=(12, 6))
plt.plot(df.index.to_timestamp(), df['Remesas'],
         color='steelblue', label='Histórico')
plt.plot(pronostico.index.to_timestamp(),
         pronostico['Remesas_fc'], color='red', linewidth=2, label='Pronóstico')
plt.fill_between(pronostico.index.to_timestamp(
), pronostico['Lo95'], pronostico['Hi95'], color='red', alpha=0.15, label='IC 95%')
plt.title("Pronóstico de Remesas (12 Meses) con Intervalos de Confianza al 95%")
plt.ylabel("Millones de USD")
plt.legend()
plt.grid(True, linestyle='--', alpha=0.6)
plt.savefig(os.path.join(path_descargas, "07_pronostico_remesas.png"))
plt.close()

print(
    f"\n¡Proceso completado! Revisa la carpeta '{os.path.basename(path_descargas)}' en tus Descargas.")
