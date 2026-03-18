# ProyectoRemesas
Este es un pronóstico a un año de las Remesas de Nicaragua

# INTRODUCCIÓN
Este proyecto busca la aplicación de técnicas de pronóstico por medio de un modelo ARMA. La variable a pronosticar son las Remesas de Nicaragua, datos obtenidos de las bases de datos del Banco Central de Nicaragua (BCN). El pronóstico toma toda la serie de datos disponibles en el BCN desde enero de 2010, hasta el último año abril 2025; por lo cual el pronóstico a 1 año, llegaría hasta abril 2026, como último año de pronóstico. En general los resultado de este pronóstico muestran un crecimiento sostenido a lo largo de un año de las remesas en Nicaragua, lo cual es un panorama positivo si consideramos que las remesas son una fuente importante de ingresos para las familias nicaraguenses y un gran factor dinamizador del consumo interno, inversión por vía sector bancario (al disponer ese ingreso como fondos nuevos a bancos) y fortalecimientos de reservas del BCN.

<img width="891" height="470" alt="image" src="https://github.com/user-attachments/assets/df0d3897-c530-4be5-8ddd-e769f5367262" />

# METODOLOGÍA
Se utilizó tanto R como Python en la realización del Modelo, para l explicación metodológica las gráficas y los tests que se mostraran serán del lenguaje de programación R. El modelo que se utilizó fue un ARMA (4,0,2), que según los criterios de información y pruebas en los TEST es el modelo óptimo y que cumple el supuesto de "estacionariedad", es decir, que su media, varianza y covarianza son independientes en el tiempo, lo cual podemos asegurar que esos componentes estadísticos se mantienen estables en el tiempo. 

## Test Phillips-Perron (Prueba de estacionariedad)
<img width="679" height="201" alt="image" src="https://github.com/user-attachments/assets/6aa8d80d-1aa6-4666-a76a-2d755ea974af" />

El p-value dió 0.2232, lo cuál según el TEST se rechaza la hipótesis nula de que el modelo NO ES ESTACIONARIO, por lo tanto, el modelo si es estacionario.

## Test Ljung-Box (Q-test)
Este Test busca identificar autocorrelación serial entre los errores del modelo. Lo ideal es que los errores del modelo sean estacionarios o que se comporten como "ruido blanco", es decir, se comporten de forma aleatoria y no estén correlacionados.
<img width="555" height="118" alt="image" src="https://github.com/user-attachments/assets/a00f6bc3-f8cd-452a-ac1c-68dac7ca1ff4" />

El p-value fue menor a 0.05, por lo tanto no rechazamos la hipótesis nula que plantea que los errores NO ESTÁN CORRELACIONADOS.

## Test de Diebold-Mariano (DM)
Este Test buca comparar nuestro modelo "óptimo" contra un modelo parsimonioso (más sencillo) como un AR(1) y comparar su capacidad de pronóstico.
<img width="662" height="383" alt="image" src="https://github.com/user-attachments/assets/31583a59-3950-4193-8272-8d961891b62d" />

Según los resultados del TEST cualquier de los dos modelos son igual de bueno para pronósticos.

## Test Mincer-zarnowits y Test Wald
Ambos Test buscan verificar si nuestro modelo está estructuralmente sesgado, es decir, si nuestro modelo no está captando la información completa a partir de los datos reales para pronosticar en el futuro, lo cuál provocaría que nuestro pronostico esté sesgado. El test de wald apunta a que nuestro modelo está sesgado.
<img width="577" height="361" alt="image" src="https://github.com/user-attachments/assets/2262c30d-73f9-4753-92be-726ecc7f9dc8" />

La conclusión es que este modelo, está sistemáticamente sesgado, por lo cuál para fines científicos, no es un modelo recomendable, inclusi si pasó satisfactoriamente los otros TEST.

# Resultados y conclusión
Este fue un ejercicio práctico donde para fines de negocios es muy útil para predecir el comportamiento futuro de variables que podrían ser de nuestro interés como **crédito**, **inflación** etc. Respecto a nuestro modelo podríamos decir que no es recomendable debido a sus sesgo, sin embargo vale la pena ver qué nos dice resecto a las remesas; en teoría a una año el crecimiento interanual de las remesas en Nicaragua (Abril 2025 a abril 2026) será de 10.7%.
<img width="1042" height="534" alt="image" src="https://github.com/user-attachments/assets/1e88a4e4-a4b1-48ca-acec-322835dd5f22" />











