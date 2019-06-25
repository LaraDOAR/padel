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
################## CAMBIOS DE PISTAS O DE HORARIO EN EL CALENDARIO

# Una vez que se tenga claro el cambio, basta con hacer lo siguiente

# 1/3 - Editar el fichero de calendario con la configuracion definitiva
vim calendario.txt

# 2/3 - Actualizar el html del calendario
bash Script/updateCalendario.sh
# calendario.html
# partidos.txt
# partidos.html

# 3/3 - Subir el nuevo ranking a la web y la lista de partidos con los resultados actualizados
bash Script/creaPaquete.sh
# -- hablar con Daniel Duran para que lo suba a la web


