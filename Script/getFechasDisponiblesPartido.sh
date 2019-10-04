#!/bin/bash

#================================================================================
#
# Script que dado un partido [Pareja1+Pareja2], enumera los huecos disponibles para
# jugar dicho partido, donde hueco=Pista+fecha+hora. Para ello tiene en cuenta los
# partidos ya programados, las pistas disponibles y las restricciones de los jugadores.
#
# Entrada
#  -q --------------------> La salida tiene el formato para incluir en sendMail.sh
#  -p [Pareja1+Pareja2] --> Partido a analizar
#  -i YYYYMMDD -----------> Fecha de inicio (incluida)
#  -f YYYYMMDD -----------> Fecha final (incluida)
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
if [ ! -f pistas.txt ];        then prt_error "ERROR: no existe el fichero [pistas.txt] en el directorio actual";        exit 1; fi
if [ ! -f parejas.txt ];       then prt_error "ERROR: no existe el fichero [parejas.txt] en el directorio actual";       exit 1; fi
if [ ! -f calendario.txt ];    then prt_error "ERROR: no existe el fichero [calendario.txt] en el directorio actual";    exit 1; fi
if [ ! -f restricciones.txt ]; then prt_error "ERROR: no existe el fichero [restricciones.txt] en el directorio actual"; exit 1; fi

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

 Script que dado un partido [Pareja1+Pareja2], enumera los huecos disponibles para
 jugar dicho partido, donde hueco=Pista+fecha+hora. Para ello tiene en cuenta los
 partidos ya programados, las pistas disponibles y las restricciones de los jugadores.

 Entrada
  -q --------------------> La salida tiene el formato para incluir en sendMail.sh
  -p [Pareja1+Pareja2] --> Partido a analizar
  -i YYYYMMDD -----------> Fecha de inicio (incluida)
  -f YYYYMMDD -----------> Fecha final (incluida)

 Salida:
  0 --> ejecucion correcta
  1 --> ejecucion con errores
"

ARG_SENDMAIL=false # por defecto, no es para sendMail
ARG_PARTIDO=""     # param obligatorio
ARG_FINI=""        # param obligatorio
ARG_FFIN=""        # param obligatorio

# Procesamos los argumentos de entrada
while getopts qp:i:f:oh opt
do
    case "${opt}" in
        q) ARG_SENDMAIL=true;;
        p) ARG_PARTIDO=$OPTARG;;
        i) ARG_FINI=$OPTARG;;
        f) ARG_FFIN=$OPTARG;;
        h) echo -e "${AYUDA}"; exit 0;;
        *) prt_error "Parametro [${opt}] invalido"; echo -e "${AYUDA}"; exit 1;;
    esac
done

if [ "${ARG_PARTIDO}" == "" ]; then prt_error "ERROR: El partido es un parametro obligarorio (param -p)";       exit 1; fi
if [ "${ARG_FINI}"    == "" ]; then prt_error "ERROR: La fecha inicial es un parametro obligarorio (param -i)"; exit 1; fi
if [ "${ARG_FFIN}"    == "" ]; then prt_error "ERROR: La fecha final es un parametro obligarorio (param -f)";   exit 1; fi
date +"%Y%m%d" -d "${ARG_FINI} +5 days" > /dev/null 2>&1; rv=$?; if [ "${rv}" != "0" ]; then prt_error "ERROR: ARG_FINI=${ARG_FINI} no es una fecha valida (param -i)"; exit 1; fi
date +"%Y%m%d" -d "${ARG_FFIN} +5 days" > /dev/null 2>&1; rv=$?; if [ "${rv}" != "0" ]; then prt_error "ERROR: ARG_FFIN=${ARG_FFIN} no es una fecha valida (param -f)"; exit 1; fi



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


# Si la llamada es desde sendMail, se cambia la forma de imprimir los mensajes
if [ "${ARG_SENDMAIL}" == "true" ]
then
    function prt_error { echo "" > /dev/null; }
    function prt_warn  { echo "" > /dev/null; }
    function prt_info  { echo "" > /dev/null; }
    function prt_debug { echo "" > /dev/null; }
fi


############# INICIALIZACION

prt_info "Inicializacion..."

# Resetea un directorio temporal solo para este script, dentro de tmp/
mkdir -p tmp; DIR_TMP="tmp/tmp.${SCRIPT}.${PID}"; rm -rf "${DIR_TMP}"; mkdir "${DIR_TMP}"

# Deben existir los ficheros
if [ ! -f pistas.txt ];        then prt_error "ERROR: no existe el fichero [pistas.txt] en el directorio actual";        exit 1; fi
if [ ! -f parejas.txt ];       then prt_error "ERROR: no existe el fichero [parejas.txt] en el directorio actual";       exit 1; fi
if [ ! -f calendario.txt ];    then prt_error "ERROR: no existe el fichero [calendario.txt] en el directorio actual";    exit 1; fi
if [ ! -f restricciones.txt ]; then prt_error "ERROR: no existe el fichero [restricciones.txt] en el directorio actual"; exit 1; fi

# Limpia los diferentes ficheros
out=$( FGRL_limpiaTabla pistas.txt        "${DIR_TMP}/pistas"        false )
out=$( FGRL_limpiaTabla parejas.txt       "${DIR_TMP}/parejas"       false )
out=$( FGRL_limpiaTabla calendario.txt    "${DIR_TMP}/calendario"    false )
out=$( FGRL_limpiaTabla restricciones.txt "${DIR_TMP}/restricciones" false )


############# EJECUCION

prt_info "Ejecucion..."

# Comprueba que el formato de todos los ficheros es bueno
out=$( bash Script/checkPistas.sh        ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi
out=$( bash Script/checkParejas.sh       ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi
out=$( bash Script/checkCalendario.sh    ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi
out=$( bash Script/checkRestricciones.sh ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi

# Extrae las 2 parejas del partido
loc=$( echo -e "${ARG_PARTIDO}" | gawk -F"+" '{print $1}' )
vis=$( echo -e "${ARG_PARTIDO}" | gawk -F"+" '{print $2}' )

# Comprueba si el partido dado existe de verdad
out=$( grep "|${loc}|${vis}|" "${DIR_TMP}/calendario" )
if [ "${out}" == "" ]; then prt_error "ERROR: el partido local=${loc} vs visitante=${vis} no existe en el fichero calendario.txt"; exit 1; fi

# Prepara el fichero de huecos disponibles
gawk -F"|" '{if ($2>=FINI && $2<=FFIN) print}' FINI="${ARG_FINI}" FFIN="${ARG_FFIN}" "${DIR_TMP}/pistas" | sed 's/|/-/g' | sort -t"-" -k2,2 -k3,3 -k1,1r  > "${DIR_TMP}/huecos"

# Calcula todas las posible combinaciones
gawk '{print "-"LOC"-"VIS"-"$0}' LOC="${loc}" VIS="${vis}" "${DIR_TMP}/huecos" > "${DIR_TMP}/combinaciones_todas"

# Se eliminan los partidos que no se pueden jugar por tener alguna restriccion
while IFS="|" read -r NOMBRE APELLIDO FECHA
do
    sed -i "/-${NOMBRE}${APELLIDO}-.*-${FECHA}-/d" "${DIR_TMP}/combinaciones_todas"
done < "${DIR_TMP}/restricciones"

# Se eliminan las fechas en las que ya hay partido
while IFS="|" read -r _ _ _ PISTA FECHA HINI HFIN _
do
    sed -i "/-${PISTA}-${FECHA}-${HINI}-${HFIN}/d" "${DIR_TMP}/combinaciones_todas"
done < "${DIR_TMP}/calendario"

# Se cambia el formato de las fechas (formato: -DanielRamos-AlvaroRomero-EricPerez-IsraelAlonso-Pista3-20191021-19:00-20:00)
while read -r line
do
    fecha=$( echo -e "${line}" | gawk -F"-" '{print $7}' )
    fecha=$( date +"%d/%m/%Y" -d "${fecha}" )
    echo -e "${line}" | gawk 'BEGIN{FS=OFS="-"}{$7=FECHA; print}' FECHA="${fecha}" >> "${DIR_TMP}/combinaciones_todas.tmp"
done < "${DIR_TMP}/combinaciones_todas"
mv "${DIR_TMP}/combinaciones_todas.tmp" "${DIR_TMP}/combinaciones_todas"

# Se imprimen las fechas disponibles
num=$( wc -l "${DIR_TMP}/combinaciones_todas" | gawk '{print $1}' )
prt_info "Hay [${num}] huecos disponibles para jugar el partido ${loc} vs ${vis} entre las fechas ${ARG_FINI} - ${ARG_FFIN}, que son:"
gawk -F"-" '{print "- Dia "$7" en "$6" de "$8" a "$9; if (FLAG=="true") {print "<BR>";} }' FLAG="${ARG_SENDMAIL}" "${DIR_TMP}/combinaciones_todas"



############# FIN
exit 0

