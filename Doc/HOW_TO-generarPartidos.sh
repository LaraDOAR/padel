#!/bin/bash

####################################################
#
# MANUAL DE COMO EJECUTAR SCRIPTS PARA ORGANIZAR TORNEO DE PADEL
#
####################################################


echo ""
echo " Aunque este script fichero contine comandos de bash, no se puede ejecutar. Solo es una guia"
echo ""
exit 1


################################################################################################################################
################## GENERAR PARTIDOS PARA EL RESTO DE JORNADAS

MES=2
FECHA_INI_JORNADA=20190701
FECHA_FIN_JORNADA=20190726
NUMERO_PAREJAS_POR_DIVISION=5   # numero de partidos que se quieran jugar + 1

# Se supone ya actualizado el ranking con los resultados de la ultima jornada/mes

# -- guardar como los ficheros de referencia
cp ranking.txt  rankingReferencia.txt
cp ranking.html rankingReferencia.html


# 1/3 - Averiguar que partidos hay que jugar segun el ranking actual

# NOTA: si hay partidos del mes pasado que no se han jugado y se han pospuesto a esta jornada
#  - Editar el fichero partidos.txt, dejando el MES que esta y borrando datos de FECHA, HORA y LUGAR
#  - La nueva ejecucion de getPartidos.sh, anyadira partidos nuevos

# -- ejecuta script
bash Script/getPartidos.sh -m "${MES}" -n "${NUMERO_PAREJAS_POR_DIVISION}"
# -- ficheros de salida
# partidos.txt
# partidos.html


# 2/3 - Generar calendario de cuando se juega cada partido

# -- ejecuta el script
bash Script/getCalendario.sh -m "${MES}" -i "${FECHA_INI_JORNADA}" -f "${FECHA_FIN_JORNADA}"
# -- ficheros de salida
# calendario.txt
# calendario.html
# partidos.txt
# partidos.html


# 3/3 - Subir el nuevo calendario a la web
bash Script/creaPaquete.sh
# -- hablar con Daniel Duran para que lo suba a la web




