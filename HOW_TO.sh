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


###################################################################################################################################
################## EMPEZAR A ORGANIZAR EL TORNEO



##### 1/6 - Configurar ficheros iniciales

# -- copiar index de la web al home
cp Example/index.html

# -- copiar de los de ejemplo
cp Example/infoTorneo.cfg .    # datos del torneo
cp Example/pistas.txt .        # informacion sobre las pistas disponibles
cp Example/parejas.txt .       # informacion sobre las personas y las parejas que forman
cp Example/restricciones.txt . # restricciones de las personsa

# -- editar
vim infoTorneo.cfg
vim pistas.txt
vim parejas.txt
vim restricciones.txt

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
# ranking.txt
# ranking.html

# -- comprueba que el fichero de salida es valido y coherente
bash Script/checkRanking.sh
# -- ficheros de salida
# no tiene, solo hace un check





##### 3/6 - Generar los primeros partidos
# -- Se generan a partir del fichero de ranking
# -- Se divide el ranking en divisiones. Dentro de cada division es un todos contra todos

# -- ejecuta script
NUMERO_PAREJAS_POR_DIVISION=4
bash Script/getPartidos.sh -m 1 -n "${NUMERO_PAREJAS_POR_DIVISION}"
# -- ficheros de salida
# partidos.txt

# -- comprueba que los ficheros de salida son validos y coherentes
bash Script/checkPartidos.sh
# -- ficheros de salida
# no tiene, solo hace un check

# -- genera el html de los partidos (o esperar a tener los partidos)
bash Script/updatePartidos.sh -w
# -- ficheros de salida
# partidos.html





##### 4/6 - Generar calendario de cuando se juega cada partido
# -- Se genera a partir del fichero de partidos
# -- Genera los ficheros de calendario, pero tambien actualiza el fichero de partidos anterior

# -- inicializa variables
FECHA_INI_MES=20190603
FECHA_FIN_MES=20190628

# -- ejecuta el script
bash Script/getCalendario.sh -m 1 -i "${FECHA_INI_MES}" -f "${FECHA_FIN_MES}"
# -- ficheros de salida
# calendario.txt
# calendario.html

# -- comprueba que los ficheros de salida son validos y coherentes
bash Script/checkCalendario.sh
# -- ficheros de salida
# no tiene, solo hace un check

# -- actualiza partidos con fechas del calendario + genera el html de los partidos
bash Script/updatePartidos.sh -f -w
# -- ficheros de salida
# partidos.txt
# partidos.html
bash Script/checkPartidos.sh
# -- ficheros de salida
# no tiene, solo hace un check

# -- enviar email con la informacion de los partidos de cada persona
**************bash Script/sendMails.sh -m 1




##### 5/6 - Hacer backup de todos los ficheros generados
# -- Sirve para tener constancia de todos los ficheros que se van generando

mkdir -p Historico
for f in infoTorneo.cfg pistas.txt parejas.txt restricciones.txt ranking.txt ranking.html partidos.txt partidos.html calendario.txt calendario.html
do
    cp ${f} Historico/versionInicial-${f}
done






##### 6/6 - Subir los html para que sean visibles para todo el mundo
# -- Los unicos ficheros html que se van a publicar son ranking, partidos y calendario
# -- En el directorio Calendario esta la configuracion necesaria para mostrar correctamente el Calendario
cp Example/index.html .
bash Script/creaPaquete.sh
# --ablar con Daniel Duran para que lo suba a la web





###################################################################################################################################
################## GRABAR RESULTADOS Y ACTUALIZAR RANKING

# Se puede ejecutar en cualquier momento, no hace falta haber jugado todos los partidos, ya que
# internamente se lleva el control de que partidos se han tenido ya en cuenta para actualizar el ranking


##### 1/3 - Grabar los resultados y hacerlos publicos

# -- editar el fichero partidos.txt y actualizar las columnas de los sets
# ---- set jugado: 6/4, por ejemplo, donde 6 es local y 4 visitante
# ---- set no jugado: -
# ---- partido no jugado: 6/0, 6/0, -   ---> para la pareja ganadora
# ---- partido no jugado: 0/0, 0/0, 0/0 ---> si se ha cancelado y se ha dado por perdido, y ninguna de las partes gana
vim partidos.txt
bash Script/formateaTabla.sh -f partidos.txt

# -- comprueba que el fichero es coherente
bash Script/checkPartidos.sh
# -- ficheros de salida
# no tiene, solo hace un check

# -- genera el html de los partidos (o esperar a tener los partidos)
bash Script/updatePartidos.sh -w
# -- ficheros de salida
# partidos.html

# -- se mueven al Historico los ficheros que no son necesarios
mv partidos-*.txt partidos-*.html Historico/


##### 2/3 - Actualizar ranking con los resultados

# -- ejecuta script
bash Script/getRanking.sh
# -- ficheros de salida
# ranking.txt
# ranking.html

# -- comprueba que el fichero de salida es valido y coherente
bash Script/checkRanking.sh
# -- ficheros de salida
# no tiene, solo hace un check

# -- se mueven al Historico los ficheros que no son necesarios
mv ranking-*.txt ranking-*.html Historico/


##### 3/3 - Subir el nuevo ranking a la web y la lista de partidos con los resultados actualizados
bash Script/creaPaquete.sh
# -- hablar con Daniel Duran para que lo suba a la web






###################################################################################################################################
################## GENERAR PARTIDOS PARA EL RESTO DE JORNADAS

MES=2
FECHA_INI_JORNADA=20190701
FECHA_FIN_JORNADA=20190726
NUMERO_PAREJAS_POR_DIVISION=5

# Se supone ya actualizado el ranking con los resultados de la ultima jornada/mes


##### 1/3 - Averiguar que partidos hay que jugar segun el ranking actual

# NOTA: si hay partidos del mes pasado que no se han jugado y se han pospuesto a esta jornada
#  - Editar el fichero partidos.txt, dejando el MES que esta y borrando datos de FECHA, HORA y LUGAR
#  - La nueva ejecucion de getPartidos.sh, anyadira partidos nuevos

# -- ejecuta script
bash Script/getPartidos.sh -m "${MES}" -n "${NUMERO_PAREJAS_POR_DIVISION}"
# -- ficheros de salida
# partidos.txt

# -- comprueba que los ficheros de salida son validos y coherentes
bash Script/checkPartidos.sh
# -- ficheros de salida
# no tiene, solo hace un check

# -- genera el html de los partidos (o esperar a tener los partidos)
bash Script/updatePartidos.sh -w
# -- ficheros de salida
# partidos.html

# -- se mueven al Historico los ficheros que no son necesarios
mv partidos-*.txt partidos-*.html Historico/


##### 2/3 - Generar calendario de cuando se juega cada partido

# -- ejecuta el script
bash Script/getCalendario.sh -m "${MES}" -i "${FECHA_INI_JORNADA}" -f "${FECHA_FIN_JORNADA}"
# -- ficheros de salida
# calendario.txt
# calendario.html

# -- comprueba que los ficheros de salida son validos y coherentes
bash Script/checkCalendario.sh
# -- ficheros de salida
# no tiene, solo hace un check

# -- actualiza partidos con fechas del calendario + genera el html de los partidos
bash Script/updatePartidos.sh -f -w
# -- ficheros de salida
# partidos.txt
# partidos.html
bash Script/checkPartidos.sh
# -- ficheros de salida
# no tiene, solo hace un check

# -- se mueven al Historico los ficheros que no son necesarios
mv partidos-*.txt   partidos-*.html   Historico/
mv calendario-*.txt calendario-*.html Historico/


##### 3/3 - Subir el nuevo calendario a la web
bash Script/creaPaquete.sh
# -- hablar con Daniel Duran para que lo suba a la web




