#!/bin/bash

#================================================================================
#
# Script que comprueba que el fichero ranking.txt sea valido y coherente.
#
# Entrada
#  (no tiene)
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

 Script que comprueba que el fichero ranking.txt sea valido y coherente.

 Entrada:
  (no tiene)

 Salida:
  0 --> ejecucion correcta
  1 --> ejecucion con errores
"

# Procesamos los argumentos de entrada
while getopts h opt
do
    case "${opt}" in
        h) echo -e "${AYUDA}"; exit 0;;
        *) prt_error "Parametro [${opt}] invalido"; echo -e "${AYUDA}"; exit 1;;
    esac
done





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


############# INICIALIZACION

prt_info "Inicializacion..."

# Resetea un directorio temporal solo para este script, dentro de tmp/
mkdir -p tmp; DIR_TMP="tmp/tmp.${SCRIPT}.${PID}"; rm -rf "${DIR_TMP}"; mkdir "${DIR_TMP}"

# Limpia los diferentes ficheros
out=$( FGRL_limpiaTabla ranking.txt "${DIR_TMP}/ranking" false )
out=$( FGRL_limpiaTabla parejas.txt "${DIR_TMP}/parejas" false )




############# EJECUCION

prt_info "Ejecucion..."

# 1/4 - No hay celdas vacias
prt_info "-- 1/6 - No hay celdas vacias"
out=$( gawk -F"|" '{for (i=1;i<=NF;i++) { if ($i=="") print "Hay celda vacia en la fila " NR ", columna " i}}' "${DIR_TMP}/ranking" )
if [ "${out}" !=  "" ]; then echo -e "${out}"; exit 1; fi

# 2/6 - Registros (lineas) unicos
prt_info "-- 2/6 - Registros (lineas) unicos"
out=$( sort "${DIR_TMP}/ranking" | uniq -c | gawk '{if ($1>1) print "El registro " $2 " no es unico, aparece " $1 " veces"}' )
if [ "${out}" !=  "" ]; then echo -e "${out}"; exit 1; fi

# 3/6 - Formato de las columnas
prt_info "-- 3/6 - Formato de las columnas"
while IFS="|" read -r POSICION PAREJA PUNTOS JUGADOS GANADOS FAVOR CONTRA
do
    if ! [[ ${POSICION} =~ ^[0-9]+$                                         ]]; then echo "El campo POSICION=${PAREJA} no es un numero entero";         exit 1; fi
    if ! [[ ${PAREJA}   =~ ^[A-Z][a-z]+[A-Z][a-z]+\-[A-Z][a-z]+[A-Z][a-z]+$ ]]; then echo "El campo PAREJA=${PAREJA} no tiene el formato de la pareja"; exit 1; fi
    if ! [[ ${PUNTOS}   =~ ^[0-9]+$                                         ]]; then echo "El campo PUNTOS=${PUNTOS} no es un numero entero";           exit 1; fi
    if ! [[ ${JUGADOS}  =~ ^[0-9]+$                                         ]]; then echo "El campo JUGADOS=${JUGADOS} no es un numero entero";         exit 1; fi
    if ! [[ ${GANADOS}  =~ ^[0-9]+$                                         ]]; then echo "El campo GANADOS=${GANADOS} no es un numero entero";         exit 1; fi
    if ! [[ ${FAVOR}    =~ ^[0-9]+$                                         ]]; then echo "El campo FAVOR=${FAVOR} no es un numero entero";             exit 1; fi
    if ! [[ ${CONTRA}   =~ ^[0-9]+$                                         ]]; then echo "El campo CONTRA=${CONTRA} no es un numero entero";           exit 1; fi
done < "${DIR_TMP}/ranking"

# 4/6 - Las posiciones estan seguidas y estan ordenadas
prt_info "-- 4/6 - Las posiciones estan seguidas y estan ordenadas"
out=$( gawk -F"|" '{if ($1!=NR) print "La posicion de la linea " NR " deberia ser " NR ", pero es " $1}' "${DIR_TMP}/ranking" )
if [ "${out}" !=  "" ]; then echo -e "${out}"; exit 1; fi

# 5/6 - Los puntos estan ordenados
prt_info "-- 5/6 - Las ranking estan ordenadas, y van seguidas"
out=$( gawk -F"|" '{if (NR>1 && $3>ant) print "La columna de los puntos no esta bien ordenada. La linea " NR " tiene " $3 " puntos y la anterior " ant; ant=$3;}' "${DIR_TMP}/ranking" )
if [ "${out}" !=  "" ]; then echo -e "${out}"; exit 1; fi

# 6/6 - La clave nombre+apellido esta en la lista de parejas
prt_info "-- 6/6 - La clave nombre+apellido esta en la lista de parejas"
while IFS="|" read -r POSICION PAREJA PUNTOS JUGADOS GANADOS FAVOR CONTRA
do
    persona=$( echo "${PAREJA}" | gawk -F"-" '{print $1}' )
    if [ "$( gawk -F"|" '{print FS $2$3 FS}' "${DIR_TMP}/parejas" | grep "|${persona}|" )" == "" ]; then echo "La persona [${persona}] no aparece en el fichero parejas.txt"; exit 1; fi
    persona=$( echo "${PAREJA}" | gawk -F"-" '{print $2}' )
    if [ "$( gawk -F"|" '{print FS $2$3 FS}' "${DIR_TMP}/parejas" | grep "|${persona}|" )" == "" ]; then echo "La persona [${persona}] no aparece en el fichero parejas.txt"; exit 1; fi
done < "${DIR_TMP}/ranking"



############# FIN
exit 0

