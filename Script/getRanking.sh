#!/bin/bash

#================================================================================
#
# Script que genera/actualiza un ranking = clasificacion del torneo
#  - Puede generar de manera inicial, donde se conserva el orden que haya en parejas.txt
#  - Puede actualizar el fichero ranking.txt ya existente, dados los resultados del mes anterior
#
# Entrada
#  -i     --> Indica que es un ranking inicial
#  -m [n] --> Numero del mes (1,2,3...)
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

 Script que genera/actualiza un ranking = clasificacion del torneo
  - Puede generar de manera inicial, donde se conserva el orden que haya en parejas.txt
  - Puede actualizar el fichero ranking.txt ya existente, dados los resultados del mes anterior

 Entrada:
  -i     --> Indica que es un ranking inicial
  -m [n] --> Numero del mes (1,2,3...)

 Salida:
  0 --> ejecucion correcta
  1 --> ejecucion con errores
"

ARG_INICIAL=false  # por defecto no se trata de generar el ranking inicial
ARG_MES=""         # parametro obligatorio

# Procesamos los argumentos de entrada
while getopts im:h opt
do
    case "${opt}" in
        i) ARG_INICIAL=true;;
        m) ARG_MES=$OPTARG;;
        h) echo -e "${AYUDA}"; exit 0;;
        *) prt_error "Parametro [${opt}] invalido"; echo -e "${AYUDA}"; exit 1;;
    esac
done

if [ "${ARG_MES}" == "" ];         then prt_error "ERROR: ARG_MES vacio (param -m)";                                     exit 1; fi
if ! [[ ${ARG_MES} =~ ^[0-9]+$ ]]; then prt_error "ERROR: ARG_MES=${ARG_MES}, no es un numero entero valido (param -m)"; exit 1; fi




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

### CABECERA DEL FICHERO DE RANKING ---> POSICION |       PAREJA  |  PUNTOS | PARTIDOS_JUGADOS | PARTIDOS_GANADOS | JUEGOS_FAVOR | JUEGOS_CONTRA
###                                             1 | AlbertoMateos |      10 |                3 |                2 |           12 |             6


############# INICIALIZACION

prt_info "Inicializacion..."

# Resetea un directorio temporal solo para este script, dentro de tmp/
mkdir -p tmp; DIR_TMP="tmp/tmp.${SCRIPT}.${PID}"; rm -rf "${DIR_TMP}"; mkdir "${DIR_TMP}"

# Existencia de ficheros
if [ "${ARG_INICIAL}" == "false" ]
then
    if [ ! -f ranking.txt ];                then prt_error "ERROR: no existe el fichero [ranking.txt] en el directorio actual";                exit 1; fi
    if [ ! -f partidos-mes${ARG_MES}.txt ]; then prt_error "ERROR: no existe el fichero [partidos-mes${ARG_MES}.txt] en el directorio actual"; exit 1; fi
    out=$( FGRL_limpiaTabla ranking.txt                "${DIR_TMP}/ranking"  false )
    out=$( FGRL_limpiaTabla partidos-mes${ARG_MES}.txt "${DIR_TMP}/partidos" false )
fi

# Limpia los diferentes ficheros
out=$( FGRL_limpiaTabla parejas.txt "${DIR_TMP}/parejas" false )




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
    echo "POSICION|PAREJA|PUNTOS|PARTIDOS_JUGADOS|PARTIDOS_GANADOS|JUEGOS_FAVOR|JUEGOS_CONTRA" > ranking-mes${ARG_MES}.txt
    
    # -- inicializa todo a 0
    nParejas=$( wc -l "${DIR_TMP}/parejas" | gawk '{printf("%d",($1+1)/2)}' )
    gawk 'BEGIN{OFS=FS="|";}{if (NR%2==0) print NR/2,ant"-"$2$3,1+N-NR/2,"0","0","0","0"; ant=$2$3;}' N="${nParejas}" "${DIR_TMP}/parejas" >> ranking-mes${ARG_MES}.txt
    
fi
prt_info "---- Generado ranking-mes${ARG_MES}.txt"

# Da forma y comprueba que esta bien generado
prt_info "-- Se formatea ranking-mes${ARG_MES}.txt y se valida su contenido"
out=$( bash Script/formateaTabla.sh -f ranking-mes${ARG_MES}.txt ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi

# Se genera el html
prt_info "-- Se genera el html a partir de ese fichero"

# -- limpia la tabla
out=$( FGRL_limpiaTabla ranking-mes${ARG_MES}.txt "${DIR_TMP}/ranking" true ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi

# -- genera el html
cat <<EOM >ranking-mes${ARG_MES}.html
<!DOCTYPE html>
<html>
  <head>
<style>
      #customers {
        font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
        border-collapse: collapse;
        margin-left: 5%;
        margin-right: 5%;
        width: 90%;
      }
      #customers td, #customers th {
        border: 1px solid #ddd;
        padding: 8px;
      }
      #customers tr:nth-child(even){background-color: #f2f2f2;}
      #customers tr:hover {background-color: #ddd;}
      #customers th {
        text-align: left;
        background-color: #4CAF50;
        color: white;
      }
      h1 {
      	color: #343434;
      	font-weight: normal;
      	font-family: 'Ultra', sans-serif;   
      	font-size: 36px;
      	line-height: 42px;
      	text-transform: uppercase;
      	text-shadow: 0 2px white, 0 3px #777;
        text-align: center;
      }
      h2 {
      	color: #859085;
      	font-weight: normal;
      	font-family: 'Ultra', sans-serif;   
      	font-size: 36px;
      	line-height: 42px;
        text-align: center;
      }
    </style>
  </head>
  <body>
EOM
echo "<h1>TORNEO DE PADEL - ${CFG_NOMBRE}</h1>" >> ranking-mes${ARG_MES}.html
echo "<h2>Ranking</h2>" >> ranking-mes${ARG_MES}.html
cat <<EOM >>ranking-mes${ARG_MES}.html
    <br>
    <table id="customers">
EOM
head -1   "${DIR_TMP}/ranking" | gawk -F"|" '{print "<tr>";for(i=1;i<=NF;i++)print "<th>" $i"</th>";print "</tr>"}' >> ranking-mes${ARG_MES}.html
tail -n+2 "${DIR_TMP}/ranking" | gawk -F"|" '{print "<tr>";for(i=1;i<=NF;i++)print "<td>" $i"</td>";print "</tr>"}' >> ranking-mes${ARG_MES}.html
cat <<EOM >>ranking-mes${ARG_MES}.html
    </table>
  </body>
</html>
EOM

prt_info "---- Generado ranking-mes${ARG_MES}.html"


############# FIN
exit 0

