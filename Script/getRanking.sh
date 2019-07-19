#!/bin/bash

#================================================================================
#
# Script que genera/actualiza un ranking = clasificacion del torneo
#  - Puede generar de manera inicial, donde se conserva el orden que haya en parejas.txt
#  - Puede actualizar el fichero ranking.txt ya existente, dados los resultados del mes anterior (partidos.txt)
#
# Entrada
#  -i --> Indica que es un ranking inicial (por defecto, toma el fichero de partidos y actualiza ranking.txt)
#  -o --> Tiene en cuenta el 'Goal Averae Particular'
#
# Salida
#   0 --> ejecucion correcta
#   1 --> ejecucion con errores
#
#================================================================================


shopt -s nullglob
shopt -s expand_aliases

# Definicion de parametros de colores
export R="\\033[1;31m"  # red
export Y="\\033[1;33m"  # yellow
export G="\\033[1;32m"  # green
export B="\\033[1;34m"  # blue
export NC="\\033[0m"    # no color
export N="\\033[1m"     # negrita
export I="\\033[7m"     # invertido

# Variables basicas
PID=$$
SCRIPT=$( basename "${BASH_SOURCE[0]}" )

# Impresion de script + timestamp
function aTS { local _ln=$1; local _ts; _ts=$( date +"%Y/%m/%d %H:%M:%S" ); printf "EX|%-25s|%s|%06d|%04d|---------------------|00" "$SCRIPT" "${_ts}" "$PID" "${_ln}"; }

# Funciones de impresion de mensajes
function prt_error {                                      local _s; _s=$(aTS "${BASH_LINENO[0]}"); printf "${R}%s|$*|${NC}\\n" "${_s}";    }
function prt_warn  {                                      local _s; _s=$(aTS "${BASH_LINENO[0]}"); printf "${Y}%s|$*|${NC}\\n" "${_s}";    }
function prt_info  {                                      local _s; _s=$(aTS "${BASH_LINENO[0]}"); printf     "%s|$*|${NC}\\n" "${_s}";    }
function prt_debug { if [ "${1}" == "true" ]; then shift; local _s; _s=$(aTS "${BASH_LINENO[0]}"); printf "${B}%s|$*|${NC}\\n" "${_s}"; fi }



###############################################
###
### Control de errores inicial
###
###############################################

# Debe estar en el directorio correcto
if [ "$( basename ${PWD} )" != "Padel" ]; then prt_error "ERROR: se debe ejecutar desde el directorio Padel"; exit 1; fi

# Deben existir los siguientes ficheros
if [ ! -f parejas.txt ]; then prt_error "ERROR: no existe el fichero [parejas.txt] en el directorio actual"; exit 1; fi

# Carga la informacion del torneo, por si se necesita
if [ ! -f infoTorneo.cfg ];                     then prt_error "ERROR: no existe el fichero [infoTorneo.cfg] en el directorio actual"; exit 1; fi
. infoTorneo.cfg; rv=$?; if [ "${rv}" != "0" ]; then prt_error "ERROR: cargando la configuracion del fichero [infoTorneo.cfg]";        exit 1; fi

# Carga las funciones generales, por si se quieren usar
if [ ! -f Script/functions.sh ];                     then prt_error "ERROR: no existe el fichero [Script/functions.sh] en el directorio actual"; exit 1; fi
. Script/functions.sh; rv=$?; if [ "${rv}" != "0" ]; then prt_error "ERROR: cargando la configuracion las funciones [Script/functions.sh]";      exit 1; fi



###############################################
###
### Argumentos
###
###############################################

AYUDA="
 ${SCRIPT}

 Script que genera/actualiza un ranking = clasificacion del torneo
  - Puede generar de manera inicial, donde se conserva el orden que haya en parejas.txt
  - Puede actualizar el fichero ranking.txt ya existente, dados los resultados del mes anterior (partidos.txt)

 Entrada
  -i --> Indica que es un ranking inicial (por defecto, toma el fichero de partidos y actualiza ranking.txt)
  -o --> Tiene en cuenta el 'Goal Averae Particular'

 Salida:
  0 --> ejecucion correcta
  1 --> ejecucion con errores
"

ARG_INICIAL=false      # por defecto, no se trata de generar el ranking inicial
ARG_GOAL_AVERAGE=false # por defecto, no se tiene en cuenta

# Procesamos los argumentos de entrada
while getopts ioh opt
do
    case "${opt}" in
        i) ARG_INICIAL=true;;
        o) ARG_GOAL_AVERAGE=true;;
        h) echo -e "${AYUDA}"; exit 0;;
        *) prt_error "Parametro [${opt}] invalido"; echo -e "${AYUDA}"; exit 1;;
    esac
done

if [ "${ARG_INICIAL}" == "true" ] && [ "${ARG_GOAL_AVERAGE}" == "true" ]
then
    prt_error "No puede usarse la opcion de Goal Average (param -o) en el ranking inicial"
    exit 1
fi



###############################################
###
### Funciones
###
###############################################

# No hay funciones especificas en este script





###############################################
###
### Captura de senal
###
###############################################

function salir {
    _rv=$?

    if [ "${_rv}" == "0" ]; then prt_info  "**** Ejecucion correcta"
    else                         prt_error "**** Ejecucion fallida"
    fi

    # Si todo va bien, borra ficheros temporales, sino, guarda una copia
    if [ "${DIR_TMP}" != "" ] && [ -d "${DIR_TMP}" ]
    then
        if [ "${_rv}" == "0" ] || [ "$( find "${DIR_TMP}/" -mindepth 1 | wc -l )" == "0" ]
        then rm -r "${DIR_TMP}"
        else mv "${DIR_TMP}" "error-${SCRIPT}-$( date +"%Y%m%d_%H%M%S" )"
        fi
    fi

    exit ${_rv}
}
trap "salir;" EXIT





###############################################
###
### Script
###
###############################################

### CABECERA DEL FICHERO DE RANKING ---> POSICION |       PAREJA  |  PUNTOS | PARTIDOS_JUGADOS | PARTIDOS_GANADOS | JUEGOS_FAVOR | JUEGOS_CONTRA
###                                             1 | AlbertoMateos |      10 |                3 |                2 |           12 |             6


############# INICIALIZACION

prt_info "Inicializacion..."

# Resetea un directorio temporal solo para este script, dentro de tmp/
mkdir -p tmp; DIR_TMP="tmp/tmp.${SCRIPT}.${PID}"; rm -rf "${DIR_TMP}"; mkdir "${DIR_TMP}"

# Existencia de ficheros
if [ "${ARG_INICIAL}" == "false" ]
then
    if [ ! -f rankingReferencia.txt ]; then prt_error "ERROR: no existe el fichero [rankingReferencia.txt] en el directorio actual"; exit 1; fi
    if [ ! -f ranking.txt ];           then prt_error "ERROR: no existe el fichero [ranking.txt] en el directorio actual";           exit 1; fi
    if [ ! -f partidos.txt ];          then prt_error "ERROR: no existe el fichero [partidos.txt] en el directorio actual";          exit 1; fi
    out=$( FGRL_limpiaTabla rankingReferencia.txt "${DIR_TMP}/rankingRef" false )
    out=$( FGRL_limpiaTabla rankingIndividual.txt "${DIR_TMP}/rankingInd" false )
    out=$( FGRL_limpiaTabla ranking.txt           "${DIR_TMP}/ranking"    false )
    out=$( FGRL_limpiaTabla partidos.txt          "${DIR_TMP}/partidos"   false )
    FGRL_backupFile partidos txt;  rv=$?; if [ "${rv}" != "0" ]; then exit 1; fi
    FGRL_backupFile partidos html; rv=$?; if [ "${rv}" != "0" ]; then exit 1; fi
fi

# Limpia los diferentes ficheros
out=$( FGRL_limpiaTabla parejas.txt "${DIR_TMP}/parejas" false )

# Se hace backup de los ficheros de salida, para no sobreescribir
FGRL_backupFile rankingIndividual txt;  rv=$?; if [ "${rv}" != "0" ]; then exit 1; fi
FGRL_backupFile ranking           txt;  rv=$?; if [ "${rv}" != "0" ]; then exit 1; fi
FGRL_backupFile ranking           html; rv=$?; if [ "${rv}" != "0" ]; then exit 1; fi

# Puntos por partidos ganados / perdidos
PUNTOS_GANA_ARRIBA=1     # puntos que gana la pareja ganadora, si la pareja ganadora estaba situada en el ranking mas arriba que la otra pareja
PUNTOS_GANA_ABAJO=1      # puntos que gana la pareja ganadora, si la pareja ganadora estaba situada en el ranking mas abajo que la otra pareja
PUNTOS_PIERDE_ARRIBA=0   # puntos que gana la pareja perdedora, si la pareja ganadora estaba situada en el ranking mas arriba que la otra pareja
PUNTOR_PIERDE_ABAJO=0    # puntos que gana la pareja perdedora, si la pareja ganadora estaba situada en el ranking mas abajo que la otra pareja


############# EJECUCION

prt_info "Ejecucion..."


if [ "${ARG_INICIAL}" == "true" ]
then
    prt_info "-- GENERACION de un ranking inicial"

    nParejas=$( wc -l "${DIR_TMP}/parejas" | gawk '{printf("%d",($1+1)/2)}' )
    gawk 'BEGIN{OFS=FS="|";}{if (NR%2==0) {pos=NR/2; punt=1+N-NR/2; print pos,ant"-"$2$3,punt,"0","0","0","0";} ant=$2$3;}' N="${nParejas}" "${DIR_TMP}/parejas" > "${DIR_TMP}/new_ranking"
    
else
    prt_info "-- ACTUALIZACION de ranking anterior"

    # se copian ya que se van a ir modificando
    cp "${DIR_TMP}/ranking" "${DIR_TMP}/new_ranking"
    cp "${DIR_TMP}/partidos" "${DIR_TMP}/new_partidos"

    # Se comprueban errores de formato
    out=$( bash Script/checkPartidos.sh ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi
    
    # Se recorre la lista de partidos
    while IFS="|" read -r MES DIVISION LOCAL VISITANTE FECHA HINI HFIN LUGAR SET1 SET2 SET3 RANKING
    do

        # Se ignora si es un resultado que ya se ha metido en el ranking
        if [ "${RANKING}" == "true" ]; then continue; fi

        # Se ignora si es un partido que no tiene fecha+hora+lugar
        if [ "${FECHA}" == "-" ] && [ "${HINI}" == "-" ] && [ "${HFIN}" == "-" ] && [ "${LUGAR}" == "-" ]; then continue; fi

        # Se ignora si es un partido que no tiene inicializados los sets
        if [ "${SET1}" == "-" ] && [ "${SET2}" == "-" ] && [ "${SET3}" == "-" ]; then continue; fi

        jueL1=$( echo -e "${SET1}" | gawk -F"/" '{print $1}' ); jueV1=$( echo -e "${SET1}" | gawk -F"/" '{print $2}' )
        jueL2=$( echo -e "${SET2}" | gawk -F"/" '{print $1}' ); jueV2=$( echo -e "${SET2}" | gawk -F"/" '{print $2}' )
        jueL3=$( echo -e "${SET3}" | gawk -F"/" '{print $1}' ); jueV3=$( echo -e "${SET3}" | gawk -F"/" '{print $2}' )
        posRankLoc=$( gawk -F"|" '{if ($2==PAREJA) print $1+0}' PAREJA="${LOCAL}"     "${DIR_TMP}/rankingRef" )
        posRankVis=$( gawk -F"|" '{if ($2==PAREJA) print $1+0}' PAREJA="${VISITANTE}" "${DIR_TMP}/rankingRef" )
        difPos=$(( posRankLoc - posRankVis )); if [ "${difPos}" -lt "1" ]; then difPos=$(( difPos * (-1) )); fi

        # Se averigua el ganador
        ganador="visitante"
        if [ "${jueL1}" -gt "${jueV1}" ] && [ "${jueL2}" -gt "${jueV2}" ];                                  then ganador="local"; fi
        if [ "${jueL1}" -gt "${jueV1}" ] && [ "${jueL2}" -lt "${jueV2}" ] && [ "${jueL3}" -gt "${jueV3}" ]; then ganador="local"; fi
        if [ "${jueL1}" -lt "${jueV1}" ] && [ "${jueL2}" -gt "${jueV2}" ] && [ "${jueL3}" -gt "${jueV3}" ]; then ganador="local"; fi

        # *** PUNTOS (puntosLoc / puntosVis)
        if [ "${ganador}" == "local" ]     && [ "${posRankLoc}" -gt "${posRankVis}" ]; then puntosLoc=$(( PUNTOS_GANA_ABAJO + difPos ));  puntosVis=${PUNTOS_PIERDE_ARRIBA}; fi
        if [ "${ganador}" == "local" ]     && [ "${posRankLoc}" -lt "${posRankVis}" ]; then puntosLoc=${PUNTOS_GANA_ARRIBA}; puntosVis=${PUNTOS_PIERDE_ABAJO};  fi
        if [ "${ganador}" == "visitante" ] && [ "${posRankVis}" -gt "${posRankLoc}" ]; then puntosVis=$(( PUNTOS_GANA_ABAJO + difPos ));  puntosLoc=${PUNTOS_PIERDE_ARRIBA}; fi
        if [ "${ganador}" == "visitante" ] && [ "${posRankVis}" -lt "${posRankLoc}" ]; then puntosVis=${PUNTOS_GANA_ARRIBA}; puntosLoc=${PUNTOS_PIERDE_ABAJO};  fi

        # *** PARTIDOS_JUGADOS
        # no se hacen cuentas: a lo que habia se le suma 1, tanto en local como en visitante)

        # *** PARTIDOS_GANADOS (partGanaLoc / partGanaVis)
        if [ "${ganador}" == "local" ];     then partGanaLoc=1; partGanaVis=0; fi
        if [ "${ganador}" == "visitante" ]; then partGanaLoc=0; partGanaVis=1; fi

        # *** JUEGOS_FAVOR (jueFavorLoc / jueFavorVis)
        jueFavorLoc=$(( jueL1 + jueL2 )); if [ "${SET3}" != "-" ]; then jueFavorLoc=$(( jueFavorLoc + jueL3 )); fi
        jueFavorVis=$(( jueV1 + jueV2 )); if [ "${SET3}" != "-" ]; then jueFavorVis=$(( jueFavorVis + jueV3 )); fi
                                                                        
        # *** JUEGOS_CONTRA (jueContraLoc / jueContraVis)
        jueContraLoc=${jueFavorVis}
        jueContraVis=${jueFavorLoc}

        # Actualiza el nuevo ranking: POSICION | PAREJA | PUNTOS | PARTIDOS_JUGADOS | PARTIDOS_GANADOS | JUEGOS_FAVOR | JUEGOS_CONTRA
        # -- local
        gawk 'BEGIN{FS=OFS="|"}{if ($2==PAREJA) {$3=$3+PTS; $4=$4+1; $5=$5+GAN; $6=$6+FAV; $7=$7+CON;} print;}' \
             PAREJA="${LOCAL}" PTS="${puntosLoc}" GAN="${partGanaLoc}" FAV="${jueFavorLoc}" CON="${jueContraLoc}" "${DIR_TMP}/new_ranking" > "${DIR_TMP}/new_ranking.tmp"
        mv "${DIR_TMP}/new_ranking.tmp" "${DIR_TMP}/new_ranking"
        # -- visitante
        gawk 'BEGIN{FS=OFS="|"}{if ($2==PAREJA) {$3=$3+PTS; $4=$4+1; $5=$5+GAN; $6=$6+FAV; $7=$7+CON;} print;}' \
             PAREJA="${VISITANTE}" PTS="${puntosVis}" GAN="${partGanaVis}" FAV="${jueFavorVis}" CON="${jueContraVis}" "${DIR_TMP}/new_ranking" > "${DIR_TMP}/new_ranking.tmp"
        mv "${DIR_TMP}/new_ranking.tmp" "${DIR_TMP}/new_ranking"

        # Actualiza el fichero partidos.txt para cambiar a RANKING=true
        gawk 'BEGIN{OFS=FS="|";}{if ($1==M && $2==D && $3==LO && $4==V && $5==F && $6==HI && $7==HF && $8==LU && $9==SA && $10==SB && $11==SC) {$12="true";} print;}' \
             M="${MES}" D="${DIVISION}" LO="${LOCAL}" V="${VISITANTE}" F="${FECHA}" HI="${HINI}" HF="${HFIN}" LU="${LUGAR}" SA="${SET1}" SB="${SET2}" SC="${SET3}" "${DIR_TMP}/new_partidos" > "${DIR_TMP}/new_partidos.new"
        mv "${DIR_TMP}/new_partidos.new"  "${DIR_TMP}/new_partidos"
        
    done < "${DIR_TMP}/partidos"

    {
        head -1 partidos.txt
        cat "${DIR_TMP}/new_partidos"
    } > partidos.txt.new; mv partidos.txt.new partidos.txt
    prt_info "---- Actualizado ${G}partidos.txt${NC}"

    out=$( bash Script/formateaTabla.sh -f partidos.txt ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi

    # Actualiza el html de partidos
    out=$( bash Script/updatePartidos.sh -w ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi
fi

# Se ordena por puntos + partidos ganados + juegos_favor + juego_contra
sort -t"|" -s -r -g -k3,3 -k5,5 -k6,6 -k7,7 "${DIR_TMP}/new_ranking" > "${DIR_TMP}/new_ranking.tmp"
mv "${DIR_TMP}/new_ranking.tmp" "${DIR_TMP}/new_ranking"

# Si hay empate a puntos, se analiza el 'goal average' entre las 2: estara por encima la pareja que mas veces haya ganado las veces que se hayan enfrentado
if [ "${ARG_GOAL_AVERAGE}" == "true" ]
then
    prt_info "-- Se analiza el 'goal average particular'"
    cp "${DIR_TMP}/new_ranking" "${DIR_TMP}/ranking"
    PUNTOS_EMPATE_ANTERIORES=""
    while read -r line
    do   
        # Se averiguan los puntos de esa pareja
        puntos=$( echo -e "${line}" | gawk -F"|" '{print $3}' )
        if [ "${puntos}" == "${PUNTOS_EMPATE_ANTERIORES}" ]; then continue; fi  # Si este empate ya se ha resuelto, se pasa a la siguiente linea

        # Se averigua cuantas parejas tienen esos puntos
        empates=$( gawk -F"|" '{if ($3==PTS) print NR}' PTS="${puntos}" "${DIR_TMP}/new_ranking" )
        nEmpates=$( echo -e "${empates}" | wc -l )

        # Si es la unica pareja con esos puntos, no se hace nada
        if [ "${nEmpates}" == "1" ]; then continue; fi

        # Hay empate, asi que se analiza. Ya se marca como que el empate con esta cantidad de puntos ya esta analizado
        PUNTOS_EMPATE_ANTERIORES=${puntos}

        # Si son 3 parejas empatadas:
        # -- p1_2.partidos = partidos en los que han jugado 1 y 2, da igual si de local o de visitante
        # -- p1_3.partidos = partidos en los que han jugado 1 y 3, da igual si de local o de visitante
        # -- p2_3.partidos = partidos en los que han jugado 2 y 3, da igual si de local o de visitante
        for i in ${empates}
        do
            pA=$( head -"${i}" "${DIR_TMP}/new_ranking" | tail -1 | gawk -F"|" '{print $2}' )
            for j in ${empates}
            do
                if [ "${j}" -le "${i}" ]; then continue; fi
                pB=$( head -"${j}" "${DIR_TMP}/new_ranking" | tail -1 | gawk -F"|" '{print $2}' )
                grep -e "|${pA}|" "${DIR_TMP}/partidos" | grep -e "|${pB}|" | gawk -F"|" '{if ($NF==true) print}' > "${DIR_TMP}/p${i}_${j}.partidos"
            done
        done

        # El 'Goal Average Particular' es contar cuantos sets ha ganado uno y cuantos ha ganado otro
        # En el caso de las 3 parejas, tendriamos 6 valores:
        # -- p1_2.sets = numero de sets que 1 ha ganado a 2 - numero de sets que 1 ha perdido contra 2
        # -- p2_1.sets = -p1_2.sets
        # -- p1_3.sets = numero de sets que 1 ha ganado a 3 - numero de sets que 1 ha perdido contra 3
        # -- p3_1.sets = -p1_3.sets
        # -- p2_3.sets = numero de sets que 2 ha ganado a 3 - numero de sets que 2 ha perdido contra 3
        # -- p3_2.sets = -p2_3.sets

        # Se inicializan todos con 0
        for f in "${DIR_TMP}/p"*"_"*".partidos"; do i=$( basename "${f}" | gawk -F"[p_.]" '{print $2}' ); j=$( basename "${f}" | gawk -F"[p_.]" '{print $3}' ); echo "0" > "${DIR_TMP}/p${i}_${j}.sets"; echo "0" > "${DIR_TMP}/p${j}_${i}.sets"; done   

        # Se va partido a partido actualizando la lista
        for f in "${DIR_TMP}/p"*"_"*".partidos"
        do
            #echo $f; cat $f
            i=$( basename "${f}" | gawk -F"[p_.]" '{print $2}' ); pA=$( head -"${i}" "${DIR_TMP}/new_ranking" | tail -1 | gawk -F"|" '{print $2}' )
            j=$( basename "${f}" | gawk -F"[p_.]" '{print $3}' ); pB=$( head -"${j}" "${DIR_TMP}/new_ranking" | tail -1 | gawk -F"|" '{print $2}' )

            # Por cada linea = cada partido, se cuentan los sets
            while IFS="|" read -r MES DIVISION LOCAL VISITANTE FECHA HINI HFIN LUGAR SET1 SET2 SET3 RANKING
            do
                # Se averiguan los juegos de cada set
                jueL1=$( echo -e "${SET1}" | gawk -F"/" '{print $1}' ); jueV1=$( echo -e "${SET1}" | gawk -F"/" '{print $2}' )
                jueL2=$( echo -e "${SET2}" | gawk -F"/" '{print $1}' ); jueV2=$( echo -e "${SET2}" | gawk -F"/" '{print $2}' )
                jueL3=$( echo -e "${SET3}" | gawk -F"/" '{print $1}' ); jueV3=$( echo -e "${SET3}" | gawk -F"/" '{print $2}' )

                # Se averigua:
                # -- el ganador
                # -- los sets a favor y los sets en contra (del ganador)
                ganador="visitante"
                if [ "${jueL1}" -gt "${jueV1}" ] && [ "${jueL2}" -gt "${jueV2}" ];                                  then ganador="local"; setFavor=2; setContra=0; fi
                if [ "${jueL1}" -gt "${jueV1}" ] && [ "${jueL2}" -lt "${jueV2}" ] && [ "${jueL3}" -gt "${jueV3}" ]; then ganador="local"; setFavor=2; setContra=1; fi
                if [ "${jueL1}" -lt "${jueV1}" ] && [ "${jueL2}" -gt "${jueV2}" ] && [ "${jueL3}" -gt "${jueV3}" ]; then ganador="local"; setFavor=2; setContra=1; fi

                if   ( [ "${pA}" == "${LOCAL}" ] && [ "${ganador}" == "local"     ] ) || ( [ "${pA}" == "${VISITANTE}" ] && [ "${ganador}" == "visitante" ] ); then new=$((   setFavor - setContra ))
                elif ( [ "${pA}" == "${LOCAL}" ] && [ "${ganador}" == "visitante" ] ) || ( [ "${pA}" == "${VISITANTE}" ] && [ "${ganador}" == "local"     ] ); then new=$(( - setFavor + setContra ))
                fi

                old=$( cat "${DIR_TMP}/p${i}_${j}.sets" ); echo "$(( old + new ))" > "${DIR_TMP}/p${i}_${j}.sets"
                old=$( cat "${DIR_TMP}/p${j}_${i}.sets" ); echo "$(( old - new ))" > "${DIR_TMP}/p${j}_${i}.sets"
            done < "${f}"

            rm "${f}"
        done

        # Se crea un fichero con las columnas:          GoalAverage | Posicion Actual | Orden Nuevo | Posicion Nueva
        for f in "${DIR_TMP}/p"*"_"*".sets"; do printf "%d|%d\n" "$( cat "${f}" )" "$( basename "${f}" | gawk -F"[p_.]" '{print $2}' )"; rm "${f}"; done |
            gawk '{print $0"|"NR}' |                      # se pone la posicion actual
            sort -s -t"|" -k1,1 -g > "${DIR_TMP}/sorted" # se ordena
        # -- se calcula la nueva posicion
        while read -r line
        do
            pos=$( echo -e "${line}" | gawk -F"|" '{print $3}' )
            newPos=$( head -"${pos}" "${DIR_TMP}/sorted" | tail -1 | gawk -F"|" '{print $2}' )
            echo -e "${line}" | gawk '{ print $0"|"NEW}' NEW="${newPos}"
        done < "${DIR_TMP}/sorted" > "${DIR_TMP}/sorted.tmp"; mv "${DIR_TMP}/sorted.tmp" "${DIR_TMP}/sorted"

        # Se modifica el ranking segun se hayan ordenado las parejas
        while IFS="|" read -r _ ACTUAL _ NUEVA
        do
            actual=$( head -"${ACTUAL}" "${DIR_TMP}/ranking" | tail -1 )
            nueva=$(  head -"${NUEVA}"  "${DIR_TMP}/ranking" | tail -1 )
            gawk '{if (NR==POS) {print LINEA;} else {print;} }' POS="${ACTUAL}" LINEA="${nueva}"  "${DIR_TMP}/ranking" > "${DIR_TMP}/ranking.tmp"; mv "${DIR_TMP}/ranking.tmp" "${DIR_TMP}/ranking"
            gawk '{if (NR==POS) {print LINEA;} else {print;} }' POS="${NUEVA}"  LINEA="${actual}" "${DIR_TMP}/ranking" > "${DIR_TMP}/ranking.tmp"; mv "${DIR_TMP}/ranking.tmp" "${DIR_TMP}/ranking"
        done < "${DIR_TMP}/sorted"
        
    done < "${DIR_TMP}/new_ranking"
    mv "${DIR_TMP}/ranking" "${DIR_TMP}/new_ranking"
fi

# Se actualizan las posiciones
gawk 'BEGIN{OFS=FS="|";}{$1=NR; print}' "${DIR_TMP}/new_ranking" > "${DIR_TMP}/new_ranking.tmp"
mv "${DIR_TMP}/new_ranking.tmp" "${DIR_TMP}/new_ranking"

# Se construye el fichero final
{
    # -- cabecera
    echo "POSICION|PAREJA|PUNTOS|PARTIDOS_JUGADOS|PARTIDOS_GANADOS|JUEGOS_FAVOR|JUEGOS_CONTRA"
    # -- cuerpo
    cat "${DIR_TMP}/new_ranking"
} > ranking.txt
prt_info "---- Generado ${G}ranking.txt${NC}"

# Da forma y comprueba que esta bien generado
prt_info "-- Se formatea ranking.txt y se valida su contenido"
out=$( bash Script/formateaTabla.sh -f ranking.txt ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi
out=$( bash Script/checkRanking.sh );                 rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi

# Se genera el html
prt_info "-- Se genera el html a partir de ese fichero"

# -- limpia la tabla
out=$( FGRL_limpiaTabla ranking.txt           "${DIR_TMP}/ranking"    true ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi
out=$( FGRL_limpiaTabla rankingReferencia.txt "${DIR_TMP}/rankingRef" true ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi
out=$( FGRL_limpiaTabla rankingIndividual.txt "${DIR_TMP}/rankingInd" true ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi

# -- genera el html
cat <<EOM >ranking.html
<!DOCTYPE html>
<html>
  <head>
    <title>RANKING - Torneo de padel IIC</title>
    <link href='Librerias/other/padel.css' rel='stylesheet' />
  </head>
  <body>
EOM
echo "    <h1>TORNEO DE PADEL - ${CFG_NOMBRE}</h1>" >> ranking.html
cat <<EOM >>ranking.html
    <h2>Ranking</h2>
    <br>

    <div class="tab">
      <button class="tablinks" onclick="openRank(event, 'Actual')" id="defaultOpen">Ranking actualizado</button>
      <button class="tablinks" onclick="openRank(event, 'Referencia')">Ranking de referencia</button>
      <button class="tablinks" onclick="openRank(event, 'Individual')">Ranking individual</button>
    </div>

    <div id="Actual" class="tabcontent">
      <p>Este es el ranking más actualizado, el que tiene en cuenta todos los partidos que se han jugado hasta el momento</p>
      <input type="text" class="myInput" id="inputActual" onkeyup='myFunction("inputActual","tableActual");' placeholder="Busca..." title="Busca en cualquier columna">
      <br>
      <table class="myTable" id="tableActual">
EOM
head -1   "${DIR_TMP}/ranking" | gawk -F"|" '{printf("        <tr>\n");for(i=1;i<=NF;i++) {print "          <th onclick=\"sortTable("i-1")\">" $i"</th>";} print "        </tr>";}' >> ranking.html
tail -n+2 "${DIR_TMP}/ranking" | gawk -F"|" '{printf("        <tr>");  for(i=1;i<=NF;i++) {printf("<td>"$i"</td>");} print "</tr>";}' >> ranking.html
cat <<EOM >>ranking.html
      </table>
      <br>
      <br>
    </div>

    <div id="Referencia" class="tabcontent">
      <p>Este es el ranking que se tomó de referencia para generar los partidos y es el que se usa para saber cuantos puntos suma la pareja ganadora en cada partido</p>
      <input type="text" class="myInput" id="inputReferencia" onkeyup='myFunction("inputReferencia","tableReferencia");' placeholder="Busca..." title="Busca en cualquier columna">
      <br>
      <table class="myTable" id="tableReferencia">
EOM
head -1   "${DIR_TMP}/rankingRef" | gawk -F"|" '{printf("        <tr>\n");for(i=1;i<=NF;i++) {print "          <th onclick=\"sortTable("i-1")\">" $i"</th>";} print "        </tr>";}' >> ranking.html
tail -n+2 "${DIR_TMP}/rankingRef" | gawk -F"|" '{printf("        <tr>");  for(i=1;i<=NF;i++) {printf("<td>"$i"</td>");} print "</tr>";}' >> ranking.html
cat <<EOM >>ranking.html
      </table>
      <br>
      <br>
    </div>

    <div id="Individual" class="tabcontent">
      <p>Este es el ranking individual, ya que no todas las personas juegan siempre con la misma pareja</p>
      <input type="text" class="myInput" id="inputIndividual" onkeyup='myFunction("inputIndividual","tableIndividual");' placeholder="Busca..." title="Busca en cualquier columna">
      <br>
      <table class="myTable" id="tableIndividual">
EOM
head -1   "${DIR_TMP}/rankingInd" | gawk -F"|" '{printf("        <tr>\n");for(i=1;i<=NF;i++) {print "          <th onclick=\"sortTable("i-1")\">" $i"</th>";} print "        </tr>";}' >> ranking.html
tail -n+2 "${DIR_TMP}/rankingInd" | gawk -F"|" '{printf("        <tr>");  for(i=1;i<=NF;i++) {printf("<td>"$i"</td>");} print "</tr>";}' >> ranking.html
cat <<EOM >>ranking.html
      </table>
      <br>
      <br>
    </div>

    <br>
    <br>

    <script>
      function myFunction(nameInput, nameTable) {
        var input, filter, table, tr, td, i, txtValue;
        input = document.getElementById(nameInput);
        filter = input.value.toUpperCase();
        table = document.getElementById(nameTable);
        tr = table.getElementsByTagName("tr");
        th = table.getElementsByTagName("th");
        for (i = 0; i < tr.length; i++) {
          for(var j=0; j<th.length; j++){
            td = tr[i].getElementsByTagName("td")[j];
            if (td) {
              txtValue = td.textContent || td.innerText;
              if (txtValue.toUpperCase().indexOf(filter) > -1) {
                tr[i].style.display = "";
                break;
              } else {
                tr[i].style.display = "none";
              }
            }       
          }
        }
      }
      function sortTable(n) {
        var table, rows, switching, i, x, y, shouldSwitch, dir, switchcount = 0;
        table = document.getElementById("customers");
        switching = true;
        //Set the sorting direction to ascending:
        dir = "asc"; 
        /*Make a loop that will continue until
        no switching has been done:*/
        while (switching) {
          //start by saying: no switching is done:
          switching = false;
          rows = table.rows;
          /*Loop through all table rows (except the
          first, which contains table headers):*/
          for (i = 1; i < (rows.length - 1); i++) {
            //start by saying there should be no switching:
            shouldSwitch = false;
            /*Get the two elements you want to compare,
            one from current row and one from the next:*/
            x = rows[i].getElementsByTagName("TD")[n];
            y = rows[i + 1].getElementsByTagName("TD")[n];
            /*check if the two rows should switch place,
            based on the direction, asc or desc:*/
            if (dir == "asc") {
              if ((isNaN(x.innerHTML) && x.innerHTML.toLowerCase() > y.innerHTML.toLowerCase()) || (!isNaN(x.innerHTML) && parseFloat(x.innerHTML) > parseFloat(y.innerHTML))) {
                //if so, mark as a switch and break the loop:
                shouldSwitch= true;
                break;
              }
            } else if (dir == "desc") {
              if ((isNaN(x.innerHTML) && x.innerHTML.toLowerCase() < y.innerHTML.toLowerCase()) || (!isNaN(x.innerHTML) && parseFloat(x.innerHTML) < parseFloat(y.innerHTML))) {
                //if so, mark as a switch and break the loop:
                shouldSwitch = true;
                break;
              }
            }
          }
          if (shouldSwitch) {
            /*If a switch has been marked, make the switch
            and mark that a switch has been done:*/
            rows[i].parentNode.insertBefore(rows[i + 1], rows[i]);
            switching = true;
            //Each time a switch is done, increase this count by 1:
            switchcount ++;      
          } else {
            /*If no switching has been done AND the direction is "asc",
            set the direction to "desc" and run the while loop again.*/
            if (switchcount == 0 && dir == "asc") {
              dir = "desc";
              switching = true;
            }
          }
        }
      }
    </script>

    <script>
      function openRank(evt, name) {
        var i, tabcontent, tablinks;
        tabcontent = document.getElementsByClassName("tabcontent");
        for (i = 0; i < tabcontent.length; i++) {
          tabcontent[i].style.display = "none";
        }
        tablinks = document.getElementsByClassName("tablinks");
        for (i = 0; i < tablinks.length; i++) {
          tablinks[i].className = tablinks[i].className.replace(" active", "");
        }
        document.getElementById(name).style.display = "block";
        evt.currentTarget.className += " active";
      }
    </script>

    <script>
      document.getElementById("defaultOpen").click();
    </script>

  </body>
</html>
EOM

prt_info "---- Generado ${G}ranking.html${NC}"


############# FIN
exit 0

