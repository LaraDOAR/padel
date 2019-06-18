#!/bin/bash

#================================================================================
#
# Script que genera los partidos que deben jugarse en un mes/jornada dado. Se generan
# a partir del ranking:
# - Opcion 1: emparejando Pareja1 vs Pareja2, Pareja3 vs Pareja4, ...
#             En caso de que haya parejas impares, se eliminara una aleatoriamente del ranking
#             y se procedera igual. Recomendado si el torneo se hace por jornadas.
# - Opcion 2: el ranking se divide en divisiones, habiendo N parejas en cada division, y se hace
#             un todos contra todos.
#
# Entrada
#  -m [n] --> Numero del mes (1,2,3...)
#  -n [n] --> Numero de parejas en cada division
#  -o [n] --> (opcional) Opcion 1 o 2 (por defecto, 2)
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
if [ ! -f ranking.txt ]; then prt_error "ERROR: no existe el fichero [ranking.txt] en el directorio actual"; exit 1; fi

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

 Script que genera los partidos que deben jugarse en un mes/jornada dado. Se generan
 a partir del ranking:
 - Opcion 1: emparejando Pareja1 vs Pareja2, Pareja3 vs Pareja4, ...
             En caso de que haya parejas impares, se eliminara una aleatoriamente del ranking
             y se procedera igual. Recomendado si el torneo se hace por jornadas.
 - Opcion 2: el ranking se divide en divisiones, habiendo N parejas en cada division, y se hace
             un todos contra todos.

 Entrada
  -m [n] --> Numero del mes (1,2,3...)
  -n [n] --> Numero de parejas en cada division
  -o [n] --> (opcional) Opcion 1 o 2 (por defecto, 2)

 Salida:
  0 --> ejecucion correcta
  1 --> ejecucion con errores
"

ARG_MES=""          # parametro obligatorio
ARG_NUM_PAREJAS=""  # parametro obligatorio
ARG_OPCION=2        # por defecto, la opcion 2

# Procesamos los argumentos de entrada
while getopts m:n:o:h opt
do
    case "${opt}" in
        m) ARG_MES=$OPTARG;;
        n) ARG_NUM_PAREJAS=$OPTARG;;
        o) ARG_OPCION=$OPTARG;;
        h) echo -e "${AYUDA}"; exit 0;;
        *) prt_error "Parametro [${opt}] invalido"; echo -e "${AYUDA}"; exit 1;;
    esac
done

if [ "${ARG_MES}" == "" ];                                   then prt_error "ERROR: ARG_MES vacio (param -m)";                                                     exit 1; fi
if ! [[ ${ARG_MES} =~ ^[0-9]+$ ]];                           then prt_error "ERROR: ARG_MES=${ARG_MES}, no es un numero entero valido (param -m)";                 exit 1; fi
if [ "${ARG_NUM_PAREJAS}" == "" ];                           then prt_error "ERROR: ARG_NUM_PAREJAS vacio (param -n)";                                             exit 1; fi
if ! [[ ${ARG_NUM_PAREJAS} =~ ^[1-9]+$ ]];                   then prt_error "ERROR: ARG_NUM_PAREJAS=${ARG_NUM_PAREJAS}, no es un numero entero valido (param -n)"; exit 1; fi
if [ "${ARG_OPCION}" == "" ];                                then prt_error "ERROR: ARG_OPCION vacio (param -o)";                                                  exit 1; fi
if [ "${ARG_OPCION}" != "1" ] && [ "${ARG_OPCION}" != "2" ]; then prt_error "ERROR: ARG_OPCION=${ARG_OPCION}, no es ni 1 ni 2 (param -o)";                         exit 1; fi




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

### CABECERA DEL FICHERO DE PARTIDOS ---> Mes | Division |                     Local |            Visitante |    Fecha | Hora_ini | Hora_fin |   Lugar | Set1 | Set2 | Set3
###                                         1 |        1 | AlbertoMateos-IsraelAlonso| EricPerez-DanielRamos| 20190507 |    18:00 |    19:30 | Pista 7 |  7/6 |  6/4 |    -


############# INICIALIZACION

prt_info "Inicializacion..."

# Resetea un directorio temporal solo para este script, dentro de tmp/
mkdir -p tmp; DIR_TMP="tmp/tmp.${SCRIPT}.${PID}"; rm -rf "${DIR_TMP}"; mkdir "${DIR_TMP}"

# Limpia los diferentes ficheros
out=$( FGRL_limpiaTabla ranking.txt "${DIR_TMP}/ranking" false )

# Se hace backup de los ficheros de salida, para no sobreescribir
FGRL_backupFile partidos txt; rv=$?; if [ "${rv}" != "0" ]; then exit 1; fi


############# EJECUCION

prt_info "Ejecucion..."

# -- cabecera: solo la primera vez
if [ ! -f partidos.txt ]; then echo "MES|DIVISION|LOCAL|VISITANTE|FECHA|HORA_INI|HORA_FIN|LUGAR|SET1|SET2|SET3|RANKING" > partidos.txt
else                           prt_warn "-- Como ya existe partidos.txt, se anadiran a este fichero los nuevos partidos, no se empieza de cero"
fi

##########################################################################
### POR JORNADA: pareja1 vs pareja2, pareja3 vs pareja4...
###
if [ "${ARG_OPCION}" == "1" ]
then

    prt_error "Codigo no actualizado"
    exit 1

    # prt_info "OPCION: ${ARG_OPCION}"
    
    # # 1/2 - Revisa si hay parejas impares
    # prt_info "1/2 - Revisa si hay parejas impares"
    # nParejas=$( wc -l "${DIR_TMP}/ranking" | gawk '{print $1}' )
    # if [ "$(( nParejas % 2))" != "0" ]
    # then
    #     prt_warn "-- Hay parejas impares"
        
    #     # -- se hace backup de los ficheros de salida, para no sobreescribir
    #     FGRL_backupFile parejasSinJugar txt; rv=$?; if [ "${rv}" != "0" ]; then exit 1; fi

    #     # -- comprueba si existe el fichero
    #     if [ ! -f parejasSinJugar.txt ]
    #     then
    #         prt_error "---- No existe el fichero parejasSinJugar.txt"
    #         prt_warn "---- Para generarlo ejecuta los siguientes comandos"
    #         prt_warn "----   echo \"PAREJA|MES\" > parejasSinJugar.txt"
    #         prt_warn "----   bash Script/formateaTabla.sh -f parejasSinJugar.txt"
    #         prt_warn "----   bash Script/getPartidos.sh -j${ARG_MES}"
    #         exit 1
    #     fi

    #     # -- se limpia
    #     cp parejasSinJugar.txt parejasSinJugar-mes${ARG_MES}.txt
    #     out=$( FGRL_limpiaTabla parejasSinJugar.txt "${DIR_TMP}/sinJugar" false )

    #     # -- comprueba si hay que resetear el fichero, porque ya han no jugado todas las parejas
    #     reset=true
    #     while IFS="|" read -r _ PAREJA _ _ _ _ _
    #     do
    #         if [ "$( grep -e "${PAREJA}" "${DIR_TMP}/sinJugar" )" == "" ]; then reset=false; fi
    #     done < "${DIR_TMP}/ranking"
    #     if [ "${reset}" == "true" ]
    #     then
    #         prt_warn "---- Ya han 'no jugado' todas las parejas, asi que se resetea el fichero"
    #         cat /dev/null > parejasSinJugar-mes${ARG_MES}.txt
    #     fi

    #     # -- elige aleatoriamente
    #     eliminadaPareja=false
    #     while [ "${eliminadaPareja}" == "false" ]
    #     do
    #         n=$( shuf -i 1-${nParejas} -n 1 )
    #         parejaElegida=$( head -${n} "${DIR_TMP}/ranking" | tail -1 | gawk -F"|" '{print $2}' )
    #         if [ "$( grep -e "${parejaElegida}" "${DIR_TMP}/sinJugar" )" == "" ]
    #         then
    #             prt_warn "---- Se descarta a la pareja ${parejaElegida}, que no jugara en el mes ${ARG_MES}"
    #             grep -v "|${parejaElegida}|" "${DIR_TMP}/ranking" > "${DIR_TMP}/ranking.tmp"; mv "${DIR_TMP}/ranking.tmp" "${DIR_TMP}/ranking"
    #             echo "${parejaElegida}|${ARG_MES}" >> parejasSinJugar-mes${ARG_MES}.txt
    #             eliminadaPareja=true
    #         fi
    #     done

    #     # -- se da formato
    #     out=$( bash Script/formateaTabla.sh -f parejasSinJugar-mes${ARG_MES}.txt ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi
    #     prt_info "---- Generado ${G}parejasSinJugar-mes${ARG_MES}.txt${NC}"
    # fi


    # # 2/2 - Se generan los emparejamientos
    # prt_info "2/2 - Se generan los emparejamientos"
    # gawk 'BEGIN{OFS=FS="|";}{if (NR%2==0) print J,"0",ant,$2,"-","-","-","-","-","-","-"; ant=$2}' J="${ARG_MES}" "${DIR_TMP}/ranking" >> partidos-mes${ARG_MES}.txt
    
fi


##########################################################################
### POR MES: se generan divisiones, y despues ligas dentro de esas divisiones
###
if [ "${ARG_OPCION}" == "2" ]
then

    prt_info "OPCION: ${ARG_OPCION}"

    # 1/2 - Se calculan las divisiones que va a haber
    prt_info "1/2 - Se calculan las divisiones que va a haber"
    nParejas=$( wc -l "${DIR_TMP}/ranking" | gawk '{print $1}' )
    nDivisiones=$( echo "" | gawk '{printf("%d",A/B+0.5)}' A="${nParejas}" B="${ARG_NUM_PAREJAS}" )
    nPartidos=$(( nParejas -1 ))
    prt_info "---- Habra ${nDivisiones} divisiones con ${ARG_NUM_PAREJAS} parejas en cada una, que jugaran ${nPartidos} partidos"

    # 2/2 - Se generan los emparejamientos
    prt_info "2/2 - Se generan los emparejamientos"
    nLineas=0
    for i in $( seq 1 "${nDivisiones}" )
    do
        prt_info "---- Division ${i}"
        nLineas=$(( ARG_NUM_PAREJAS*(i-1) + 1 ))
        # -- se agrupan las parejas por divisiones
        tail -n+${nLineas} "${DIR_TMP}/ranking" | head -"${ARG_NUM_PAREJAS}" > "${DIR_TMP}/division"
        # -- se calculan todas las permutaciones
        FGRL_getPermutacion "${DIR_TMP}/division" 1 # genera los ficheros DIR_TMP/division.permX donde X=numero de la permutacion
        # -- se van anadiendo los partidos
        for f in "${DIR_TMP}/division.perm"*
        do
            gawk 'BEGIN{OFS=FS="|";}{if (NR%2==0) {J=sprintf("%03d",J); print J,DIV,ant,$2,"-","-","-","-","-","-","-","false";} ant=$2}' J="${ARG_MES}" DIV="${i}" "${f}" >> "${DIR_TMP}/division.partidos"
        done
        sort -u "${DIR_TMP}/division.partidos" > "${DIR_TMP}/division.partidos.tmp"; mv "${DIR_TMP}/division.partidos.tmp" "${DIR_TMP}/division.partidos"
        # -- local y visitante son lo mismo, asi que se eliminan las repetidas
        while read -r line
        do
            pLocal=$(     echo -e "${line}" | gawk -F"|" '{print $3}' )
            pVisitante=$( echo -e "${line}" | gawk -F"|" '{print $4}' )
            out1=$( grep "|${pLocal}|${pVisitante}" partidos.txt )
            out2=$( grep "|${pVisitante}|${pLocal}" partidos.txt )
            if [ "${out1}" == "" ] && [ "${out2}" == "" ]
            then
                echo -e "${line}" >> partidos.txt
            fi
        done < "${DIR_TMP}/division.partidos"
        rm "${DIR_TMP}/division"*
    done

fi

# Se ordenan por partidos por mes, para tener arriba los mas nuevos
head -1 partidos.txt > partidos.sorted.txt
tail -n+2 partidos.txt | sort -t"|" -s -r -k1,1 >> partidos.sorted.txt
mv partidos.sorted.txt partidos.txt

# Se da formato
out=$( bash Script/formateaTabla.sh -f partidos.txt ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi
prt_info "---- Generado ${G}partidos.txt${NC}"

# Se comprueba el formato
bash Script/checkPartidos.sh; rv=$?
if [ "${rv}" != "0" ]
then
    prt_error "Error ejecutando <bash Script/checkPartidos.sh>"
    prt_error "---- Soluciona el problema y ejecutalo a mano"
    prt_warn "*** Despues quedaria ejecutar <bash Script/updatePartidos.sh -w> para actualizar el fichero html"
    exit 1
fi

# Se crea el fichero web
bash Script/updatePartidos.sh -w; rv=$?
if [ "${rv}" != "0" ]
then
    prt_error "Error ejecutando <bash Script/updatePartidos.sh -w>"
    prt_error "---- Soluciona el problema y ejecutalo a mano"
    exit 1
fi


############# FIN
exit 0

