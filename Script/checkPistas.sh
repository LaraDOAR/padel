#!/bin/bash

#================================================================================
#
# Script que comprueba que el fichero pistas.txt sea valido y coherente.
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
if [ ! -f pistas.txt ]; then prt_error "ERROR: no existe el fichero [pistas.txt] en el directorio actual"; exit 1; fi

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

 Script que comprueba que el fichero pistas.txt sea valido y coherente.

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
out=$( FGRL_limpiaTabla pistas.txt "${DIR_TMP}/pistas" false )




############# EJECUCION

prt_info "Ejecucion..."

# 1/4 - No hay celdas vacias
prt_info "-- 1/4 - No hay celdas vacias"
out=$( gawk -F"|" '{for (i=1;i<=NF;i++) { if ($i=="") print "Hay celda vacia en la fila " NR ", columna " i}}' "${DIR_TMP}/pistas" )
if [ "${out}" !=  "" ]; then echo -e "${out}"; exit 1; fi

# 2/4 - Registros (lineas) unicos
prt_info "-- 2/4 - Registros (lineas) unicos"
out=$( sort "${DIR_TMP}/pistas" | uniq -c | gawk '{if ($1>1) print "El registro " $2 " no es unico, aparece " $1 " veces"}' )
if [ "${out}" !=  "" ]; then echo -e "${out}"; exit 1; fi

# 3/4 - Formato de las columnas
prt_info "-- 3/4 - Formato de las columnas"
while IFS="|" read -r PISTA FECHA HINI HFIN
do
    if ! [[ ${PISTA} =~ ^Pista[0-9]$                     ]]; then echo "El campo PISTA=${PISTA} no es de la forma PistaN"; exit 1; fi
    if ! [[ ${FECHA} =~ ^[0-9]{8}$                       ]]; then echo "La fecha ${FECHA} no es de la forma YYYYMMDD";     exit 1; fi
    if ! [[ ${HINI}  =~ ^([0-1][0-9]|2[0-3]):[0-5][0-9]$ ]]; then echo "La hora ${HINI} no es de la forma HH:MM";          exit 1; fi
    if ! [[ ${HFIN}  =~ ^([0-1][0-9]|2[0-3]):[0-5][0-9]$ ]]; then echo "La hora ${HFIN} no es de la forma HH:MM";          exit 1; fi
    date +"%Y%m%d"     -d "${FECHA}         +5 days"  > /dev/null 2>&1; rv=$?; if [ "${rv}" != "0" ]; then echo "La fecha ${FECHA} no es una fecha valida";                   exit 1; fi
    date +"%Y%m%d%H%M" -d "${FECHA} ${HINI} +2 hours" > /dev/null 2>&1; rv=$?; if [ "${rv}" != "0" ]; then echo "La hora ${HINI} no es una hora valida para el dia ${FECHA}"; exit 1; fi
    date +"%Y%m%d%H%M" -d "${FECHA} ${HFIN} +2 hours" > /dev/null 2>&1; rv=$?; if [ "${rv}" != "0" ]; then echo "La hora ${HFIN} no es una hora valida para el dia ${FECHA}"; exit 1; fi
done < "${DIR_TMP}/pistas"

# 4/4 - No se pisan
prt_info "-- 4/4 - No se pisan"
while IFS="|" read -r PISTA FECHA HINI HFIN
do
    while read -r line
    do
        horaI=$( echo -e "${line}" | gawk -F"|" '{print $3}' )
        horaF=$( echo -e "${line}" | gawk -F"|" '{print $4}' )
        if [ "${HINI:0:2}"  -le "${horaI:0:2}" ] && [ "${HFIN:0:2}"  -le "${horaI:0:2}" ]; then continue; fi
        if [ "${horaI:0:2}" -le "${HINI:0:2}"  ] && [ "${horaF:0:2}" -le "${HINI:0:2}"  ]; then continue; fi
        echo "El registro [${PISTA}|${FECHA}|${HINI}|${HFIN}] entra en conflicto con [${line}]"
        exit 1
    done < <( grep "^${PISTA}|${FECHA}" "${DIR_TMP}/pistas" | grep -v "${PISTA}|${FECHA}|${HINI}|${HFIN}" )
done < "${DIR_TMP}/pistas"




############# FIN
exit 0

