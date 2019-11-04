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
################## EMPEZAR A ORGANIZAR EL TORNEO



##### 1/6 - Configurar ficheros iniciales

# -- copiar de los de ejemplo
cp Example/infoTorneo.cfg .    # datos del torneo
cp Example/pistas.txt .        # informacion sobre las pistas disponibles
cp Example/parejas.txt .       # informacion sobre las personas y las parejas que forman

# -- editar
vim infoTorneo.cfg
vim pistas.txt
vim parejas.txt

# -- crear directorio de backup
mkdir -p Historico

# -- obtener restricciones
bash Script/getRestricciones.sh

# -- dar formato a las tablas (sobreescribe las tablas)
bash Script/formateaTabla.sh -f pistas.txt
bash Script/formateaTabla.sh -f parejas.txt
bash Script/formateaTabla.sh -f restricciones.txt

# -- comprueba que el formato de los ficheros es bueno (no salida, solo ok o error)
bash Script/checkPistas.sh
bash Script/checkParejas.sh
bash Script/checkRestricciones.sh





##### 2/6 - Generar el primer ranking
# -- Mismo orden de las parejas
# -- Puntos iniciales para conservar el ranking

# -- ejecuta con opcion inicial
bash Script/getRanking.sh -i
# -- ficheros de salida
# ranking.html
# ranking.txt
# rankingIndividual.txt
# rankingReferencia.txt



##### 3/6 - Generar los primeros partidos
# -- Se generan a partir del fichero de ranking
# -- Se divide el ranking en divisiones. Dentro de cada division es un todos contra todos

# -- ejecuta script
NUMERO_PAREJAS_POR_DIVISION=3 # numero de partidos que se quieran jugar + 1
bash Script/getPartidos.sh -n "${NUMERO_PAREJAS_POR_DIVISION}"
# -- ficheros de salida
# partidos.txt
# partidos.html





##### 4/6 - Generar calendario de cuando se juega cada partido
# -- Se genera a partir del fichero de partidos
# -- Genera los ficheros de calendario, pero tambien actualiza el fichero de partidos anterior

# -- ejecuta el script
bash Script/getCalendario.sh
bash Script/getCalendario.sh.sinChecks
# -- ficheros de salida
# calendario.txt
# calendario.html
# partidos.txt
# partidos.html

# -- enviar email con la informacion de los partidos de cada persona
**************bash Script/sendMail.sh





##### 5/6 - Hacer backup de todos los ficheros generados
# -- Sirve para tener constancia de todos los ficheros que se van generando
. infoTorneo.cfg
for f in infoTorneo.cfg pistas.txt parejas.txt restricciones.txt rankingIndividual.txt rankingReferencia.txt ranking.txt ranking.html partidos.txt partidos.html calendario.txt calendario.html
do
    cp ${f} Historico/jornada${CFG_JORNADA}-versionInicial-${f}
done





##### 6/6 - Subir los html para que sean visibles para todo el mundo
bash Script/creaPaquete.sh
# -- hablar con Daniel Duran para que lo suba a la web
