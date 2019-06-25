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
################## GRABAR RESULTADOS Y ACTUALIZAR RANKING

# Se puede ejecutar en cualquier momento, no hace falta haber jugado todos los partidos, ya que
# internamente se lleva el control de que partidos se han tenido ya en cuenta para actualizar el ranking

# 1/2 - Editar el fichero partidos.txt y actualizar las columnas de los sets
# ---- set jugado: 6/4, por ejemplo, donde 6 es local y 4 visitante
# ---- set no jugado: -
# ---- partido no jugado: 6/0, 6/0, -   ---> para la pareja ganadora
# ---- partido no jugado: 0/0, 0/0, 0/0 ---> si se ha cancelado y se ha dado por perdido, y ninguna de las partes gana
vim partidos.txt

# 2/3 - Ejecuta script
bash Script/getRanking.sh
# -- ficheros de salida
# ranking.txt
# ranking.html
# partidos.txt
# partidos.html

# 3/3 - Subir el nuevo ranking a la web y la lista de partidos con los resultados actualizados
bash Script/creaPaquete.sh
# -- hablar con Daniel Duran para que lo suba a la web
