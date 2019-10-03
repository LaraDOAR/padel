#!/bin/bash

#================================================================================
#
# Script que genera el fichero de restricciones, como union de todos los ficheros
# de restricciones que hay en el directorio Restricciones
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

 Script que genera el fichero de restricciones, como union de todos los ficheros
 de restricciones que hay en el directorio Restricciones.

 Entrada
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

### CABECERA DEL FICHERO DE RESTRICCIONES --->  NOMBRE | APELLIDO |    FECHA
###                                            Alberto |   Mateos | 20190605


############# INICIALIZACION

prt_info "Inicializacion..."

# Resetea un directorio temporal solo para este script, dentro de tmp/
mkdir -p tmp; DIR_TMP="tmp/tmp.${SCRIPT}.${PID}"; rm -rf "${DIR_TMP}"; mkdir "${DIR_TMP}"

# Limpia los diferentes ficheros
out=$( FGRL_limpiaTabla parejas.txt "${DIR_TMP}/parejas" false )

# Existencia de ficheros / directorios
if [ ! -d Restricciones ]; then prt_error "ERROR: no existe el directorio [Restricciones] en el directorio actual"; exit 1; fi
for f in Restricciones/restricciones-*.txt
do
    nombre=$(   basename "${f}" | sed 's/restricciones-//g; s/.txt//g' | gawk -F"_" '{print $1}' )
    apellido=$( basename "${f}" | sed 's/restricciones-//g; s/.txt//g' | gawk -F"_" '{print $2}' )
    if [ "$( grep "|${nombre}|${apellido}|" "${DIR_TMP}/parejas" )" == "" ]; then prt_error "ERROR: La persona [${nombre}|${apellido}] no aparece en el fichero parejas.txt"; exit 1; fi
done

# Se asegura que estan en ascii los ficheros
for f in Restricciones/restricciones-*.txt
do
    cat "${f}" | tr -c '[:print:]\n' ' ' > "${DIR_TMP}/aaa"
    mv "${DIR_TMP}/aaa" "${f}"
done

# Revisa que los ficheros solo contienen fechas
for f in Restricciones/restricciones-*.txt
do
    while read -r line
    do
        if ! [[ ${line} =~ ^[0-9]{8}$ ]]; then prt_error "ERROR: El fichero [${f}] contiene la linea [${line}] que no es una fecha"; exit 1; fi
    done < "${f}"
done

# Se hace backup de los ficheros de salida, para no sobreescribir
FGRL_backupFile restricciones txt;  rv=$?; if [ "${rv}" != "0" ]; then exit 1; fi



############# EJECUCION

prt_info "Ejecucion..."

# Resetea el fichero
rm -f restricciones.txt
touch restricciones.txt

# Cabecera
{
    echo "####################################################"
    echo "#"
    echo "# INFORMACION SOBRE LAS RESTRICCIONES QUE TIENE CADA PERSONA"
    echo "#"
    echo "####################################################"
    echo "" 
    echo " NOMBRE|  APELLIDO|   FECHA"
} > restricciones.txt

# Se vuelca la informacion de las parejas
for f in Restricciones/restricciones-*.txt
do
    nombre=$(   basename "${f}" | sed 's/restricciones-//g; s/.txt//g' | gawk -F"_" '{print $1}' )
    apellido=$( basename "${f}" | sed 's/restricciones-//g; s/.txt//g' | gawk -F"_" '{print $2}' )
    while read -r fecha
    do
        echo "${nombre}|${apellido}|${fecha}" >> restricciones.txt
    done < "${f}"
done

# Se le da formato
out=$( bash Script/formateaTabla.sh -f restricciones.txt ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi

# Se comprueba el formato
out=$( bash Script/checkRestricciones.sh ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi


prt_info "---- Generado ${G}restricciones.txt${NC}"


############# FIN
exit 0

