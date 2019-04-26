#!/bin/bash

#================================================================================
#
# Script que genera/actualiza un ranking = clasificacion del torneo
#  - Puede generar de manera inicial, donde se conserva el orden que haya en parejas.txt
#  - Puede actualizar el fichero ranking.txt ya existente, dados los resultados de la jornada anterior
#
# Entrada
#  -i     --> Indica que es un ranking inicial
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

 Script que genera/actualiza un ranking = clasificacion del torneo
  - Puede generar de manera inicial, donde se conserva el orden que haya en parejas.txt
  - Puede actualizar el fichero ranking.txt ya existente, dados los resultados de la jornada anterior

 Entrada:
  -i     --> Indica que es un ranking inicial
  -j [n] --> Numero de la jornada (1,2,3...)

 Salida:
  0 --> ejecucion correcta
  1 --> ejecucion con errores
"

ARG_INICIAL=false  # por defecto no se trata de generar el ranking inicial
ARG_JORNADA=""     # parametro obligatorio

# Procesamos los argumentos de entrada
while getopts ij:h opt
do
    case "${opt}" in
        i) ARG_INICIAL=true;;
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

### CABECERA DEL FICHERO DE RANKING ---> POSICION |       PAREJA  |  PUNTOS | PARTIDOS_JUGADOS | PARTIDOS_GANADOS | JUEGOS_FAVOR | JUEGOS_CONTRA
###                                             1 | AlbertoMateos |      10 |                3 |                2 |           12 |             6


############# INICIALIZACION

prt_info "Inicializacion..."

# Resetea un directorio temporal solo para este script, dentro de tmp/
mkdir -p tmp; DIR_TMP="tmp/tmp.${SCRIPT}.${PID}"; rm -rf "${DIR_TMP}"; mkdir "${DIR_TMP}"

# Existencia de ficheros
if [ "${ARG_INICIAL}" == "false" ]
then
    if [ ! -f ranking.txt ];                        then prt_error "ERROR: no existe el fichero [ranking.txt] en el directorio actual";                        exit 1; fi
    if [ ! -f partidos-jornada${ARG_JORNADA}.txt ]; then prt_error "ERROR: no existe el fichero [partidos-jornada${ARG_JORNADA}.txt] en el directorio actual"; exit 1; fi
    out=$( limpiaTabla ranking.txt                        "${DIR_TMP}/ranking"  false )
    out=$( limpiaTabla partidos-jornada${ARG_JORNADA}.txt "${DIR_TMP}/partidos" false )
fi

# Limpia los diferentes ficheros
out=$( limpiaTabla parejas.txt "${DIR_TMP}/parejas" false )




############# EJECUCION

prt_info "Ejecucion..."


if [ "${ARG_INICIAL}" == "false" ]
then
    prt_info "-- ACTUALIZACION de ranking anterior"
    prt_error "---- No implementado todavia"
    exit 1
else
    prt_info "-- GENERACION de un ranking inicial"

    # -- cabecera
    echo "POSICION|PAREJA|PUNTOS|PARTIDOS_JUGADOS|PARTIDOS_GANADOS|JUEGOS_FAVOR|JUEGOS_CONTRA" > ranking-jornada${ARG_JORNADA}.txt
    
    # -- inicializa todo a 0
    nParejas=$( wc -l "${DIR_TMP}/parejas" | gawk '{printf("%d",($1+1)/2)}' )
    gawk 'BEGIN{OFS=FS="|";}{if (NR%2==0) print NR/2,ant"-"$2$3,1+N-NR/2,"0","0","0","0"; ant=$2$3;}' N="${nParejas}" "${DIR_TMP}/parejas" >> ranking-jornada${ARG_JORNADA}.txt
    
fi
prt_info "---- Generado ranking-jornada${ARG_JORNADA}.txt"

# Da forma y comprueba que esta bien generado
prt_info "-- Se formatea ranking-jornada${ARG_JORNADA}.txt y se valida su contenido"
out=$( bash Script/formateaTabla.sh -f ranking-jornada${ARG_JORNADA}.txt ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi
#out=$( bash Script/checkRanking.sh );                                       rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi

# Se genera el html
prt_info "-- Se genera el html a partir de ese fichero"

# -- limpia la tabla
out=$( limpiaTabla ranking-jornada${ARG_JORNADA}.txt "${DIR_TMP}/ranking" true ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi

# -- genera el html
cat <<EOM >ranking-jornada${ARG_JORNADA}.html
<!DOCTYPE html>
<html>
  <head>
    <style>
      table {
        font-family: arial, sans-serif;
        border-collapse: collapse;
        width: 100%;
      }
      td, th {
          border: 1px solid #dddddd;
          text-align: left;
          padding: 8px;
      }
      tr:nth-child(even) {
          background-color: #dddddd;
      }
    </style>
  </head>
  <body>
    <table>
EOM
gawk -F"|" '{print "<tr>";for(i=1;i<=NF;i++)print "<td>" $i"</td>";print "</tr>"}' "${DIR_TMP}/ranking" >> ranking-jornada${ARG_JORNADA}.html
cat <<EOM >>ranking-jornada${ARG_JORNADA}.html
    </table>
  </body>
</html>
EOM

prt_info "---- Generado ranking-jornada${ARG_JORNADA}.html"


############# FIN
exit 0

