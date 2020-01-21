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

# Se supone ya actualizado el ranking con los resultados de la ultima jornada/mes

# 1/5 - ORGANIZAR DIRECTORIO HISTORICO

# -- guardar una copia de todos los ficheros en el historico
. infoTorneo.cfg
JORNADA=$( printf "%02d" "${CFG_JORNADA}" )
for f in infoTorneo.cfg pistas.txt parejas.txt restricciones.txt rankingIndividual.txt rankingReferencia.txt ranking.txt ranking.html partidos.txt partidos.html calendario.txt calendario.html
do
    cp ${f} Historico/jornada${JORNADA}-versionFinal-${f}
done

# -- eliminar eliminar los ficheros que sobren de Historico
rm Historico/[...]




# 2/5 - CONFIGURACION DE FICHEROS DE CONFIGURACION

# -- editar el fichero infoTorneo.cfg, para cambiar las fechas de inicio y de fin, y el numero de jornada
vim infoTorneo.cfg

# -- editar el fichero de pistas para anyadir las nuevas
vim pistas.txt
bash Script/checkPistas.sh

# -- hacer cambios, si es que hay que hacerlos, en el fichero de parejas (sobre todo que parejas juegan esta jornada y cuales no)
vim parejas.txt
bash Script/checkParejas.sh

# -- actualizar restricciones
bash Script/getRestricciones.sh -z
bash Script/checkRestricciones.sh
rm Restricciones/restricciones.zip

# -- guardar como los ficheros de referencia
bash Script/getRanking.sh  # no deberia cambiar nada
bash Script/checkRanking.sh
cp ranking.txt rankingReferencia.txt

# -- editar en el fichero partidos.txt los partidos del mes pasado que no se han jugado
# ---- Si se han pospuesto para este mes, borrar los datos de FECHA, HORA y LUGAR
# ---- Si no se van a jugar, cambiar la columna RANKING de false a true
vim partidos.txt
bash Script/checkPartidos.sh

# -- comprobar tambien el buen formato del calendario
bash Script/checkCalendario.sh



# 3/5 - GENERAR PARTIDOS Y CALENDARIO

# -- generar nuevos partidos
NUMERO_PAREJAS_POR_DIVISION=3   # numero de partidos que se quieran jugar + 1
bash Script/getPartidos.sh -n "${NUMERO_PAREJAS_POR_DIVISION}"
# -- ficheros de salida
# partidos.txt
# partidos.html

# -- generar calendario de cuando se juega cada partido
bash Script/getCalendario.sh
bash Script/getCalendario.sh.sinChecks
# -- ficheros de salida
# calendario.txt
# calendario.html
# partidos.txt
# partidos.html

# -- editar en el calendario:
# ---- segun restricciones de hora
# ---- para que los mejores usen las mejores pistas
vim calendario.txt
bash Script/updateCalendario.sh

# -- enviar email con la informacion de los partidos de cada persona
bash Script/sendMail.sh -v  # para ver lo que se va a mandar
bash Script/sendMail.sh     # para mandarlo




# 4/5 - HACER BACKUP DE TODOS LOS FICHERO GENERADOS
. infoTorneo.cfg
JORNADA=$( printf "%02d" "${CFG_JORNADA}" )
for f in infoTorneo.cfg pistas.txt parejas.txt restricciones.txt rankingIndividual.txt rankingReferencia.txt ranking.txt ranking.html partidos.txt partidos.html calendario.txt calendario.html
do
    cp ${f} Historico/jornada${JORNADA}-versionInicial-${f}
done




# 5/5 - CREAR PAQUETE PARA LA WEB
bash Script/creaPaquete.sh




