#!/bin/bash

#================================================================================
#
# Script que da formato a una tabla de texto.
#
# Entrada
#  -f [path] --> Ruta al fichero al que dar formato
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

 Script que da formato a una tabla de texto.

 Entrada:
  -f [path] --> Ruta al fichero al que dar formato

 Salida:
  0 --> ejecucion correcta
  1 --> ejecucion con errores
"

ARG_TABLA="" # parametro obligatorio

# Procesamos los argumentos de entrada
while getopts f:h opt
do
    case "${opt}" in
        f) ARG_TABLA=$OPTARG;;
        h) echo -e "${AYUDA}"; exit 0;;
        *) prt_error "Parametro [${opt}] invalido"; echo -e "${AYUDA}"; exit 1;;
    esac
done

if [ "${ARG_TABLA}" == "" ]; then prt_error "ERROR: ARG_TABLA vacio (param -f)";                  exit 1; fi
if [ ! -f "${ARG_TABLA}" ];  then prt_error "ERROR: ARG_TABLA=${ARG_TABLA} no existe (param -f)"; exit 1; fi





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
lineaFinCabecera=$( FGRL_limpiaTabla "${ARG_TABLA}" "${DIR_TMP}/tabla" true )



############# EJECUCION

prt_info "Ejecucion..."

# Calcula numero de columnas
nCols=$( gawk -F"|" '{print NF}' "${DIR_TMP}/tabla" | sort -u )

# Comprueba que hay columnas
if [ "${nCols}" == "0" ]; then prt_error "-- No hay columnas"; exit 1; fi

# Comprueba que todas las filas tienen el mismo numero de columnas
if [ "$( echo -e "${nCols}" | wc -l )" -gt "1" ]; then prt_error "-- Hay filas con diferentes numeros de columnas"; exit 1; fi

# Por cada columna, imprime en una celda de tamano el maximo que haya
for i in $( seq 1 "${nCols}" )
do
    tam=$( gawk -F"|" '{print length($COL)}' COL="${i}" "${DIR_TMP}/tabla" | sort -g -u | tail -1 )

    gawk -F"|" '{
      for (j=1;j<NCOLS;j++) {
          if (j==COL) { printf("%" TAM "s|",$COL); }
          else        { printf("%s|",$j);         }
      }
      if (NCOLS==COL) { printf("%" TAM "s\n",$COL); }
      else            { printf("%s\n",$NCOLS);     }
    }' COL="${i}" TAM="${tam}" NCOLS="${nCols}" "${DIR_TMP}/tabla" > "${DIR_TMP}/tabla.tmp"

    mv "${DIR_TMP}/tabla.tmp" "${DIR_TMP}/tabla"
done

# Anade al fichero la cabecera
if [ "${lineaFinCabecera}" != "0" ]
then
    head -"${lineaFinCabecera}" "${ARG_TABLA}"  > "${DIR_TMP}/tabla.tmp"
    cat "${DIR_TMP}/tabla"                     >> "${DIR_TMP}/tabla.tmp"
    mv "${DIR_TMP}/tabla.tmp" "${DIR_TMP}/tabla"
fi

mv "${DIR_TMP}/tabla" "${ARG_TABLA}"




############# FIN
exit 0

