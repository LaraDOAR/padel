#!/bin/bash

#================================================================================
#
# Script que comprueba que el fichero partidos.txt sea valido y coherente.
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
if [ ! -f partidos.txt ]; then prt_error "ERROR: no existe el fichero [partidos.txt] en el directorio actual"; exit 1; fi
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

 Script que comprueba que el fichero partidos.txt sea valido y coherente.

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
out=$( FGRL_limpiaTabla partidos.txt "${DIR_TMP}/partidos" false )
out=$( FGRL_limpiaTabla parejas.txt  "${DIR_TMP}/parejas"  false )




############# EJECUCION

prt_info "Ejecucion..."

# 1/5 - No hay celdas vacias
prt_info "-- 1/5 - No hay celdas vacias"
out=$( gawk -F"|" '{for (i=1;i<=NF;i++) { if ($i=="") print "Hay celda vacia en la fila " NR ", columna " i}}' "${DIR_TMP}/partidos" )
if [ "${out}" !=  "" ]; then echo -e "${out}"; exit 1; fi

# 2/5 - Registros (lineas) unicos
prt_info "-- 2/5 - Registros (lineas) unicos"
out=$( sort "${DIR_TMP}/partidos" | uniq -c | gawk '{if ($1>1) print "El registro " $2 " no es unico, aparece " $1 " veces"}' )
if [ "${out}" !=  "" ]; then echo -e "${out}"; exit 1; fi

# 3/5 - Formato de las columnas
prt_info "-- 3/5 - Formato de las columnas"
while IFS="|" read -r MES DIVISION LOCAL VISITANTE FECHA HINI HFIN LUGAR SET1 SET2 SET3
do
    if ! [[ ${MES}       =~ ^[0-9]+$                                         ]]; then echo "El campo MES=${MES} no es un numero entero";                       exit 1; fi
    if ! [[ ${DIVISION}  =~ ^[0-9]+$                                         ]]; then echo "El campo DIVISION=${DIVISION} no es un numero entero";             exit 1; fi
    if ! [[ ${LOCAL}     =~ ^[A-Z][a-z]+[A-Z][a-z]+\-[A-Z][a-z]+[A-Z][a-z]+$ ]]; then echo "El campo LOCAL=${LOCAL} no tiene el formato de la pareja";         exit 1; fi
    if ! [[ ${VISITANTE} =~ ^[A-Z][a-z]+[A-Z][a-z]+\-[A-Z][a-z]+[A-Z][a-z]+$ ]]; then echo "El campo VISITANTE=${VISITANTE} no tiene el formato de la pareja"; exit 1; fi
    if [ "${FECHA}" == "-" ]
    then
        if [ "${HINI}" != "-" ]; then echo "El campo HORA_INI=${HINI} debe ser '-' porque la fecha es '-'"; exit 1; fi
        if [ "${HFIN}" != "-" ]; then echo "El campo HORA_FIN=${HFIN} debe ser '-' porque la fecha es '-'"; exit 1; fi
        if [ "${SET1}" != "-" ]; then echo "El campo SET1=${SET1} debe ser '-' porque la fecha es '-'";     exit 1; fi
        if [ "${SET2}" != "-" ]; then echo "El campo SET2=${SET2} debe ser '-' porque la fecha es '-'";     exit 1; fi
        if [ "${SET3}" != "-" ]; then echo "El campo SET3=${SET3} debe ser '-' porque la fecha es '-'";     exit 1; fi
    else
        if ! [[ ${FECHA}     =~ ^[0-9]{8}$                                       ]]; then echo "El campo FECHA=${FECHA} no es de la forma YYYYMMDD";               exit 1; fi
        if ! [[ ${HINI}      =~ ^([0-1][0-9]|2[0-3]):[0-5][0-9]$                 ]]; then echo "El campo HORA_INI=${HINI} no es de la forma HH:MM";                exit 1; fi
        if ! [[ ${HFIN}      =~ ^([0-1][0-9]|2[0-3]):[0-5][0-9]$                 ]]; then echo "El campo HORA_FIN=${HFIN} no es de la forma HH:MM";                exit 1; fi
        # el lugar se deja libre, no se obliga a cumplir ningun formato
        if ! [[ ${SET1}      =~ ^[0-7]+/[0-7]$ ]] && [ "${SET1}" != "-"           ]; then echo "El campo SET1=${SET1} no es de la forma '-' ni [0-7]/[0-7]";       exit 1; fi
        if ! [[ ${SET2}      =~ ^[0-7]+/[0-7]$ ]] && [ "${SET2}" != "-"           ]; then echo "El campo SET2=${SET2} no es de la forma '-' ni [0-7]/[0-7]";       exit 1; fi
        if ! [[ ${SET3}      =~ ^[0-7]+/[0-7]$ ]] && [ "${SET3}" != "-"           ]; then echo "El campo SET3=${SET3} no es de la forma '-' ni [0-7]/[0-7]";       exit 1; fi
        date +"%Y%m%d"     -d "${FECHA}         +5 days"  > /dev/null 2>&1; rv=$?; if [ "${rv}" != "0" ]; then echo "La fecha ${FECHA} no es una fecha valida";                   exit 1; fi
        date +"%Y%m%d%H%M" -d "${FECHA} ${HINI} +2 hours" > /dev/null 2>&1; rv=$?; if [ "${rv}" != "0" ]; then echo "La hora ${HINI} no es una hora valida para el dia ${FECHA}"; exit 1; fi
        date +"%Y%m%d%H%M" -d "${FECHA} ${HFIN} +2 hours" > /dev/null 2>&1; rv=$?; if [ "${rv}" != "0" ]; then echo "La hora ${HFIN} no es una hora valida para el dia ${FECHA}"; exit 1; fi
    fi
done < "${DIR_TMP}/partidos"

# 4/5 - La clave nombre+apellido esta en la lista de parejas
prt_info "-- 4/5 - La clave nombre+apellido esta en la lista de parejas"
while IFS="|" read -r _ _ LOCAL VISITANTE _ _ _ _ _ _ _
do
    persona=$( echo "${LOCAL}" | gawk -F"-" '{print $1}' )
    if [ "$( gawk -F"|" '{print FS $2$3 FS}' "${DIR_TMP}/parejas" | grep "|${persona}|" )" == "" ]; then echo "La persona [${persona}] no aparece en el fichero parejas.txt"; exit 1; fi
    persona=$( echo "${LOCAL}" | gawk -F"-" '{print $2}' )
    if [ "$( gawk -F"|" '{print FS $2$3 FS}' "${DIR_TMP}/parejas" | grep "|${persona}|" )" == "" ]; then echo "La persona [${persona}] no aparece en el fichero parejas.txt"; exit 1; fi
    persona=$( echo "${VISITANTE}" | gawk -F"-" '{print $1}' )
    if [ "$( gawk -F"|" '{print FS $2$3 FS}' "${DIR_TMP}/parejas" | grep "|${persona}|" )" == "" ]; then echo "La persona [${persona}] no aparece en el fichero parejas.txt"; exit 1; fi
    persona=$( echo "${VISITANTE}" | gawk -F"-" '{print $2}' )
    if [ "$( gawk -F"|" '{print FS $2$3 FS}' "${DIR_TMP}/parejas" | grep "|${persona}|" )" == "" ]; then echo "La persona [${persona}] no aparece en el fichero parejas.txt"; exit 1; fi
done < "${DIR_TMP}/partidos"

# 5/5 - Los sets son coherentes
prt_info "-- 5/5 - Formato de las columnas"
while read -r line
do
    set1=$( echo -e "${line}" | gawk -F"|" '{print $(NF-2)}' ); jueL1=$( echo -e "${set1}" | gawk -F"/" '{print $1}' ); jueV1=$( echo -e "${set1}" | gawk -F"/" '{print $2}' )
    set2=$( echo -e "${line}" | gawk -F"|" '{print $(NF-1)}' ); jueL2=$( echo -e "${set2}" | gawk -F"/" '{print $1}' ); jueV2=$( echo -e "${set2}" | gawk -F"/" '{print $2}' )
    set3=$( echo -e "${line}" | gawk -F"|" '{print $(NF)}'   ); jueL3=$( echo -e "${set3}" | gawk -F"/" '{print $1}' ); jueV3=$( echo -e "${set3}" | gawk -F"/" '{print $2}' )

    # Si son todo lineas aun no se ha inicializado, es correcto
    if [ "${set1}" == "-" ] && [ "${set2}" == "-" ] && [ "${set3}" == "-" ]; then continue; fi

    # Si set1 == -, set2 != -            : error
    # Si set1 == -, set2 == -, set3 != - : error
    # Si set1 != -, set2 == -            : error
    if [ "${set1}" == "-" ] && [ "${set2}" != "-" ];                         then echo "-- En la linea ${line}, no puede ser que set1='-' y set2!='-'";            exit 1; fi
    if [ "${set1}" == "-" ] && [ "${set2}" == "-" ] && [ "${set3}" != "-" ]; then echo "-- En la linea ${line}, no puede ser que set1='-', set2='-' y set3!='-'";  exit 1; fi
    if [ "${set1}" != "-" ] && [ "${set2}" == "-" ];                         then echo "-- En la linea ${line}, no puede ser que set1!='-' y set2=='-'";           exit 1; fi

    # Partido cancelado; si un set vale 0/0, todos valen 0/0. Sino es error
    if [ "${set1}" == "0/0" ] && [ "${set2}" == "0/0" ] && [ "${set3}" == "0/0" ]; then continue; fi
    if [ "${set1}" == "0/0" ] && ( [ "${set2}" != "0/0" ] || [ "${set3}" != "0/0" ] ); then echo "-- En la linea ${line}, no puede ser que set1=='0/0' y el resto no. '0/0' soo con partidos cancelados y los 3 sets iguales"; exit 1; fi
    if [ "${set2}" == "0/0" ] && ( [ "${set1}" != "0/0" ] || [ "${set3}" != "0/0" ] ); then echo "-- En la linea ${line}, no puede ser que set2=='0/0' y el resto no. '0/0' soo con partidos cancelados y los 3 sets iguales"; exit 1; fi
    if [ "${set3}" == "0/0" ] && ( [ "${set1}" != "0/0" ] || [ "${set2}" != "0/0" ] ); then echo "-- En la linea ${line}, no puede ser que set3=='0/0' y el resto no. '0/0' soo con partidos cancelados y los 3 sets iguales"; exit 1; fi
    
    # - set 1
    # --- si es <6 --> error (si se ha interrumpido, se pondra 6/n 6/0 -)
    # --- si es 6 --> al otro lado <=4
    # --- si es 7 --> al otro lado 5 o 6
    if [ "${jueL1}" -gt "${jueV1}" ]; then maxJuego=${jueL1}; minJuego=${jueV1}; else maxJuego=${jueV1}; minJuego=${jueL1}; fi
    if [ "${maxJuego}" -lt "6" ]; then echo "-- En la linea ${line}, no puede ser que ninguno de los juegos del set1 llegue a 6. Si se ha cancelado, se pondra '6/n 6/0 -' para la pareja ganadora";       exit 1; fi
    if [ "${maxJuego}" == "6" ] && [ "${minJuego}" -gt "4" ];                                then echo "-- En la linea ${line}, no puede ser que en el set1, juego ganador = 6 y juego perdedor > 4";      exit 1; fi
    if [ "${maxJuego}" == "7" ] && ( [ "${minJuego}" != "5" ] && [ "${minJuego}" != "6" ] ); then echo "-- En la linea ${line}, no puede ser que en el set1, juego ganador = 7 y juego perdedor != 5 o 6"; exit 1; fi
    
    # Si el set 1 tiene unos valores validos (en este punto los tiene), entonces es necesario que set 2 este inicializado y tambien tenga valores validos
    if [ "${set2}" == "-" ]; then echo "-- En la linea ${line}, el set1 tiene valores validos, pero el partido no esta terminado. Es necesario que el set2!='-'"; exit 1; fi

    # - set 2
    # --- si es <6 --> error (si se ha interrumpido, se pondra set1 6/n -)
    # --- si es 6 --> al otro lado <=4
    # --- si es 7 --> al otro lado 5 o 6
    if [ "${jueL2}" -gt "${jueV2}" ]; then maxJuego=${jueL2}; minJuego=${jueV2}; else maxJuego=${jueV2}; minJuego=${jueL2}; fi
    if [ "${maxJuego}" -lt "6" ]; then echo "-- En la linea ${line}, no puede ser que ninguno de los juegos del set2 llegue a 6. Si se ha cancelado, se pondra '6/n 6/0 -' para la pareja ganadora";       exit 1; fi
    if [ "${maxJuego}" == "6" ] && [ "${minJuego}" -gt "4" ];                                then echo "-- En la linea ${line}, no puede ser que en el set2, juego ganador = 6 y juego perdedor > 4";      exit 1; fi
    if [ "${maxJuego}" == "7" ] && ( [ "${minJuego}" != "5" ] && [ "${minJuego}" != "6" ] ); then echo "-- En la linea ${line}, no puede ser que en el set2, juego ganador = 7 y juego perdedor != 5 o 6"; exit 1; fi
    
    # Si el set 1 y el set 2 tienen valores validos (en este punto los tiene), entonces set3=='-' si ya hay ganador o set!='-' si hay empate
    hayGanador=false
    if [ "${jueL1}" -gt "${jueV1}" ] && [ "${jueL2}" -gt "${jueV2}" ]; then hayGanador=true; fi
    if [ "${jueV1}" -gt "${jueL1}" ] && [ "${jueV2}" -gt "${jueL2}" ]; then hayGanador=true; fi
    if [ "${hayGanador}" == "true" ] && [ "${set3}" == "-" ]; then continue; fi
    if [ "${hayGanador}" == "true" ] && [ "${set3}" != "-" ]; then echo "-- En la linea ${line}, no puede ser que haya un ganador mirando set1 y set2, y que el set3!='-'"; exit 1; fi

    # - set 3
    # --- no puede ser > 7
    # (se permite todo porque por limitaciones de hora es posible que no de tiempo a terminar algun partido)
    if [ "${jueL3}" -gt "${jueV3}" ]; then maxJuego=${jueL3}; minJuego=${jueV3}; else maxJuego=${jueV3}; minJuego=${jueL3}; fi
    if [ "${maxJuego}" -gt "7" ]; then echo "-- En la linea ${line}, no puede ser que los juegos del set3 sea mas de 7"; exit 1; fi
    
done < "${DIR_TMP}/partidos"


############# FIN
exit 0

