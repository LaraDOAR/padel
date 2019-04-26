#!/bin/bash

#================================================================================
#
# Script que genera los partidos que deben jugarse en una jornada dada. Se generan
# a partir del ranking, emparejando: Pareja1 vs Pareja2, Pareja3 vs Pareja4, ...
# En caso de que haya parejas impares, se eliminara una aleatoriamente del ranking
# y se procedera igual.
#
# Entrada
#  -j [n] --> Numero de la jornada (1,2,3...)
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



###############################################
###
### Argumentos
###
###############################################

AYUDA="
 ${SCRIPT}

 Script que genera los partidos que deben jugarse en una jornada dada. Se generan
 a partir del ranking, emparejando: Pareja1 vs Pareja2, Pareja3 vs Pareja4, ...
 En caso de que haya parejas impares, se eliminara una aleatoriamente del ranking
 y se procedera igual.

 Entrada:
  -j [n] --> Numero de la jornada (1,2,3...)

 Salida:
  0 --> ejecucion correcta
  1 --> ejecucion con errores
"

ARG_JORNADA=""  # parametro obligatorio

# Procesamos los argumentos de entrada
while getopts j:h opt
do
    case "${opt}" in
        j) ARG_JORNADA=$OPTARG;;
        h) echo -e "${AYUDA}"; exit 0;;
        *) prt_error "Parametro [${opt}] invalido"; echo -e "${AYUDA}"; exit 1;;
    esac
done

if [ "${ARG_JORNADA}" == "" ];         then prt_error "ERROR: ARG_JORNADA vacio (param -j)";                                         exit 1; fi
if ! [[ ${ARG_JORNADA} =~ ^[0-9]+$ ]]; then prt_error "ERROR: ARG_JORNADA=${ARG_JORNADA}, no es un numero entero valido (param -j)"; exit 1; fi




###############################################
###
### Funciones
###
###############################################

##########
# - limpiaTabla
#     Funcion   --->  dado un fichero (que contiene una tabla) elimina cabecera y blancos
#     Entrada   --->  $1 = fichero entrada
#                     $2 = fichero salida
#                     $3 = true/false para indicar si se mantiene la cabecera o no
#     Salida    --->  0 = ok
#                     1 = error
#                ECHO lineaFinCabecera por si hiciera falta restaurarla despues
#
function limpiaTabla {

    # Argumentos
    local _fIn="$1"
    local _fOut="$2"
    local _conservarCabecera="$3"

    # Variables internas
    local _lineaFinCabecera
    local _line

    # Copia el fichero original para no corromperlo
    cp "${_fIn}" "${_fOut}"

    # Calcula en que linea termina la cabecera del fichero
    _lineaFinCabecera=0
    while read -r _line
    do
        if [ "$( echo -e "${_line}" | grep -e ^# -e '^[[:space:]]*$' )" == "${_line}" ]; then _lineaFinCabecera=$(( _lineaFinCabecera + 1 ))
        else break
        fi
    done < "${_fOut}"

    # Segun se quiera mantener la cabecera o no
    if [ "${_conservarCabecera}" == "false" ]; then _lineaFinCabecera=$(( _lineaFinCabecera + 1 )); fi

    # Quita la cabecera
    if [ "${_lineaFinCabecera}" != "0" ]; then sed -i -e "1,${_lineaFinCabecera}d" "${_fOut}"; fi

    # Quita todos los espacios
    sed -i 's/ //g' "${_fOut}"

    # Fin
    echo "${_lineaFinCabecera}"
    return 0
}






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

### CABECERA DEL FICHERO DE PARTIDOS ---> Jornada |                     Local |            Visitante |    Fecha | Hora_ini | Hora_fin |   Lugar | Set1 | Set2 | Set3
###                                             1 | AlbertoMateos-IsraelAlonso| EricPerez-DanielRamos| 20190507 |    18:00 |    19:30 | Pista 7 |  7/6 |  6/4 |    -


############# INICIALIZACION

prt_info "Inicializacion..."

# Resetea un directorio temporal solo para este script, dentro de tmp/
mkdir -p tmp; DIR_TMP="tmp/tmp.${SCRIPT}.${PID}"; rm -rf "${DIR_TMP}"; mkdir "${DIR_TMP}"

# Limpia los diferentes ficheros
out=$( limpiaTabla ranking.txt "${DIR_TMP}/ranking" false )



############# EJECUCION

prt_info "Ejecucion..."

# 1/9 - Revisa si hay parejas impares
prt_info "1/9 - Revisa si hay parejas impares"
nParejas=$( wc -l "${DIR_TMP}/ranking" | gawk '{print $1}' )
if [ "$(( nParejas % 2))" != "0" ]
then
    prt_warn "-- Hay parejas impares"

    # -- comprueba si existe el fichero
    if [ ! -f parejasSinJugar.txt ]
    then
        prt_error "---- No existe el fichero parejasSinJugar.txt"
        prt_warn "---- Para generarlo ejecuta los siguientes comandos"
        prt_warn "----   echo \"PAREJA|JORNADA\" > parejasSinJugar.txt"
        prt_warn "----   bash Script/formateaTabla.sh -f parejasSinJugar.txt"
        prt_warn "----   bash Script/getPartidos.sh -j${ARG_JORNADA}"
        exit 1
    fi

    # -- se limpia
    cp parejasSinJugar.txt parejasSinJugar-jornada${ARG_JORNADA}.txt
    out=$( limpiaTabla parejasSinJugar.txt "${DIR_TMP}/sinJugar" false )

    # -- comprueba si hay que resetear el fichero, porque ya han no jugado todas las parejas
    reset=true
    while IFS="|" read -r _ PAREJA _ _ _ _ _
    do
        if [ "$( grep -e "${PAREJA}" "${DIR_TMP}/sinJugar" )" == "" ]; then reset=false; fi
    done < "${DIR_TMP}/ranking"
    if [ "${reset}" == "true" ]
    then
        prt_warn "---- Ya han 'no jugado' todas las parejas, asi que se resetea el fichero"
        cat /dev/null > parejasSinJugar-jornada${ARG_JORNADA}.txt
    fi

    # -- elige aleatoriamente
    eliminadaPareja=false
    while [ "${eliminadaPareja}" == "false" ]
    do
        n=$( shuf -i 1-${nParejas} -n 1 )
        parejaElegida=$( head -${n} "${DIR_TMP}/ranking" | tail -1 | gawk -F"|" '{print $2}' )
        if [ "$( grep -e "${parejaElegida}" "${DIR_TMP}/sinJugar" )" == "" ]
        then
            prt_warn "---- Se descarta a la pareja ${parejaElegida}, que no jugara en la jornada ${ARG_JORNADA}"
            grep -v "|${parejaElegida}|" "${DIR_TMP}/ranking" > "${DIR_TMP}/ranking.tmp"; mv "${DIR_TMP}/ranking.tmp" "${DIR_TMP}/ranking"
            echo "${parejaElegida}|${ARG_JORNADA}" >> parejasSinJugar-jornada${ARG_JORNADA}.txt
            eliminadaPareja=true
        fi
    done

    # -- se da formato
    out=$( bash Script/formateaTabla.sh -f parejasSinJugar-jornada${ARG_JORNADA}.txt ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi
    prt_info "---- Generado parejasSinJugar-jornada${ARG_JORNADA}.txt"
fi


# 2/9 - Se generan los emparejamientos
prt_info "2/9 - Se generan los emparejamientos"
echo "JORNADA|LOCAL|VISITANTE|FECHA|HORA_INI|HORA_FIN|LUGAR|SET1|SET2|SET3"                                                         > partidos-jornada${ARG_JORNADA}.txt
gawk 'BEGIN{OFS=FS="|";}{if (NR%2==0) print J,ant,$2,"-","-","-","-","-","-","-"; ant=$2}' J="${ARG_JORNADA}" "${DIR_TMP}/ranking" >> partidos-jornada${ARG_JORNADA}.txt

# -- se da formato
out=$( bash Script/formateaTabla.sh -f partidos-jornada${ARG_JORNADA}.txt ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi
prt_info "---- Generado partidos-jornada${ARG_JORNADA}.txt"


############# FIN
exit 0

