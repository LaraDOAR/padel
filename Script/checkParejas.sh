#!/bin/bash

#================================================================================
#
# Script que comprueba que el fichero parejas.txt sea valido y coherente.
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
if [ ! -f parejas.txt ]; then prt_error "ERROR: no existe el fichero [parejas.txt] en el directorio actual"; exit 1; fi

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

 Script que comprueba que el fichero parejas.txt sea valido y coherente.

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


############# INICIALIZACION

prt_info "Inicializacion..."

# Resetea un directorio temporal solo para este script, dentro de tmp/
mkdir -p tmp; DIR_TMP="tmp/tmp.${SCRIPT}.${PID}"; rm -rf "${DIR_TMP}"; mkdir "${DIR_TMP}"

# Limpia los diferentes ficheros
out=$( limpiaTabla parejas.txt "${DIR_TMP}/parejas" false )




############# EJECUCION

prt_info "Ejecucion..."

# 1/4 - No hay celdas vacias
prt_info "-- 1/5 - No hay celdas vacias"
out=$( gawk -F"|" '{for (i=1;i<=NF;i++) { if ($i=="") print "Hay celda vacia en la fila " NR ", columna " i}}' "${DIR_TMP}/parejas" )
if [ "${out}" !=  "" ]; then echo -e "${out}"; exit 1; fi

# 2/5 - Registros (lineas) unicos
prt_info "-- 2/5 - Registros (lineas) unicos"
out=$( sort "${DIR_TMP}/parejas" | uniq -c | gawk '{if ($1>1) print "El registro " $2 " no es unico, aparece " $1 " veces"}' )
if [ "${out}" !=  "" ]; then echo -e "${out}"; exit 1; fi

# 3/5 - Formato de las columnas
prt_info "-- 3/5 - Formato de las columnas"
while IFS="|" read -r PAREJA NOMBRE APELLIDO EMAIL
do
    if ! [[ ${PAREJA}   =~ ^[0-9]+$                      ]]; then echo "El campo PAREJA=${PAREJA} no es un numero entero";                         exit 1; fi
    if ! [[ ${NOMBRE}   =~ ^[A-Z][a-z]+$                 ]]; then echo "El campo NOMBRE=${NOMBRE} no es un string que empieza por mayusculas";     exit 1; fi
    if ! [[ ${APELLIDO} =~ ^[A-Z][a-z]+$                 ]]; then echo "El campo APELLIDO=${APELLIDO} no es un string que empieza por mayusculas"; exit 1; fi
    if ! [[ ${EMAIL}    =~ ^[a-z]+\.[a-z]+@iic\.uam\.es$ ]]; then echo "El campo EMAIL=${EMAIL} no es de la forma [nombre].[apellido]@iic.uam.es"; exit 1; fi
done < "${DIR_TMP}/parejas"

# 4/5 - Las parejas tienen 2 componentes
prt_info "-- 4/5 - Las parejas tienen 2 componentes"
out=$( gawk -F"|" '{print $1}' "${DIR_TMP}/parejas" | sort | uniq -c | gawk '{if ($1!=2) print "La pareja " $2 " la componen " $1 " personas, cuando solo pueden ser 2"}' )
if [ "${out}" !=  "" ]; then echo -e "${out}"; exit 1; fi

# 5/5 - Las parejas estan ordenadas, y van seguidas
prt_info "-- 5/5 - Las parejas estan ordenadas, y van seguidas"
out=$( gawk -F"|" '{ if (NR%2==0 && $1!=NR/2) print "La pareja " ant " de la linea " NR " deberia ser la numero " NR/2 " no la " NR; ant=$1 }' "${DIR_TMP}/parejas" )
if [ "${out}" !=  "" ]; then echo -e "${out}"; exit 1; fi




############# FIN
exit 0

