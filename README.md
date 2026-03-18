# ProyectoRemesas
Este es un pronóstico a un año de las Remesas de Nicaragua

# INTRODUCCIÓN
Este proyecto busca la aplicación de técnicas de pronóstico por medio de un modelo ARMA. La variable a pronosticar son las Remesas de Nicaragua, datos obtenidos de las bases de datos del Banco Central de Nicaragua (BCN). El pronóstico toma toda la serie de datos disponibles en el BCN desde enero de 2010, hasta el último año abril 2025; por lo cual el pronóstico a 1 año, llegaría hasta abril 2026, como último año de pronóstico. En general los resultado de este pronóstico muestran un crecimiento sostenido a lo largo de un año de las remesas en Nicaragua, lo cual es un panorama positivo si consideramos que las remesas son una fuente importante de ingresos para las familias nicaraguenses y un gran factor dinamizador del consumo interno, inversión por vía sector bancario (al disponer ese ingreso como fondos nuevos a bancos) y fortalecimientos de reservas del BCN.

<img width="891" height="470" alt="image" src="https://github.com/user-attachments/assets/df0d3897-c530-4be5-8ddd-e769f5367262" />

# METODOLOGÍA
Se utilizó tanto R como Python en la realización del Modelo, para l explicación metodológica las gráficas y los tests que se mostraran serán del lenguaje de programación R. El modelo que se utilizó fue un ARMA (4,0,2), que según los criterios de información y pruebas en los TEST es el modelo óptimo y que cumple el supuesto de "estacionariedad", es decir, que su media, varianza y covarianza son independientes en el tiempo, lo cual podemos asegurar que esos componentes estadísticos se mantienen estables en el tiempo. 

## Test Phillips-Perron (Prueba de estacionariedad)
<img width="679" height="201" alt="image" src="https://github.com/user-attachments/assets/6aa8d80d-1aa6-4666-a76a-2d755ea974af" />






