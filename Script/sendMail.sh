#!/bin/bash

#================================================================================
#
# Script que envia un email a las personas que participan indicandoles la fecha
# de los partidos que tienen programas y que aun no han jugado.
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
if [ ! -f parejas.txt ];  then prt_error "ERROR: no existe el fichero [parejas.txt] en el directorio actual";  exit 1; fi
if [ ! -f partidos.txt ]; then prt_error "ERROR: no existe el fichero [partidos.txt] en el directorio actual"; exit 1; fi

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

 Script que envia un email a las personas que participan indicandoles la fecha
 # de los partidos que tienen programas y que aun no han jugado.

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

### CABECERA DEL FICHERO DE PARTIDOS ---> Mes | Division |                     Local |            Visitante |    Fecha | Hora_ini | Hora_fin |   Lugar | Set1 | Set2 | Set3 | Ranking
###                                         1 |        1 | AlbertoMateos-IsraelAlonso| EricPerez-DanielRamos| 20190507 |    18:00 |    19:30 | Pista 7 |  7/5 |  6/5 |    - |  false

### CABECERA DEL FICHERO DE PAREJAS ---> PAREJA|       NOMBRE|  APELLIDO|                      CORREO
###                                           1|         Jose|   Cordoba|     jose.cordoba@iic.uam.es


############# INICIALIZACION

prt_info "Inicializacion..."

# Resetea un directorio temporal solo para este script, dentro de tmp/
mkdir -p tmp; DIR_TMP="tmp/tmp.${SCRIPT}.${PID}"; rm -rf "${DIR_TMP}"; mkdir "${DIR_TMP}"

# Limpia los diferentes ficheros
out=$( FGRL_limpiaTabla parejas.txt  "${DIR_TMP}/parejas"  false )
out=$( FGRL_limpiaTabla partidos.txt "${DIR_TMP}/partidos" false )



############# EJECUCION

prt_info "Ejecucion..."

# Averigua el numero de parejas
nParejas=$( gawk -F"|" '{print $1}' "${DIR_TMP}/parejas" | sort -g | tail -1 )

# Genera un email por cada pareja
for i in $( seq 1 "${nParejas}" )
do
    # averigua las lineas donde esta la informacion de la pareja
    l1=$(( (i-1)*2 + 1))
    l2=$(( l1 + 1 ))

    # obtiene la informacion necesaria
    n1=$( head -"${l1}" "${DIR_TMP}/parejas" | tail -1 | gawk -F"|" '{print $2$3}' )
    n2=$( head -"${l2}" "${DIR_TMP}/parejas" | tail -1 | gawk -F"|" '{print $2$3}' )
    e1=$( head -"${l1}" "${DIR_TMP}/parejas" | tail -1 | gawk -F"|" '{print $4}' )
    e2=$( head -"${l2}" "${DIR_TMP}/parejas" | tail -1 | gawk -F"|" '{print $4}' )

    {
        # -- cabecera email
        echo "To: ${e1}, ${e2}"
        echo "From: padel@iic.uam.es"
        echo "Subject: [PADEL] Partidos programados"
        echo "MIME-Version: 1.0"
        echo "Content-Type: text/html; charset=\"iso-8859-1\""
        echo ""

        # -- cabecera html
        echo "<HTML>"
        echo "<HEAD>"
        echo "   <STYLE>"
        echo "      body {"
        echo "        font-family: \"Trebuchet MS\", Arial, Helvetica, sans-serif;"
        echo "        margin-left: 30px;"
        echo "      }"
        echo "      #customers {"
        echo "        border-collapse: collapse;"
        echo "        margin-left: -100px;"
        echo "        width: 700px;"
        echo "        align: left;"
        echo "      }"
        echo "      #customers td, #customers th {"
        echo "        border: 1px solid #ddd;"
        echo "        padding: 8px;"
        echo "      }"
        echo "      #customers tr:nth-child(even){background-color: #f2f2f2;}"
        echo "      #customers th {"
        echo "        text-align: left;"
        echo "        background-color: #4CAF50;"
        echo "        color: white;"
        echo "      }"
        echo "      h1 {"
        echo "        align: left;"
        echo "        font-size: 12pt;"
        echo "      }"
        echo "   </STYLE>"
        echo "</HEAD>"
        echo "<BODY>"

        # -- titulo
        echo "<BR>"
        echo "<H1> PARTIDOS DE PADEL PROGRAMADOS </H1>"

        # -- texto
        echo "<P>"
        echo "Este email se env&iacute;a porque bien hay nuevos partidos en el calendario o bien porque"
        echo "ha habido modificaciones en el calendario que te pueden afectar."
        echo "</P>"
        echo "<P>"
        echo "<B>Ignora emails anteriores.</B>"
        echo "</P>"
        echo "<P>"
        echo "Por favor, comprueba que no tienes restricciones y est&aacute;s libre en esas fechas."
        echo "</P>"
        echo "<P>"
        echo "Para informar de cualquier problema escribe al email <A HREF="padel@iic.uam.es">padel@iic.uam.es</A>"
        echo "</P>"

        # -- tabla partidos pendientes con fecha
        echo "<DIV STYLE='margin-left: 100px; margin-top: 10px;'>"
        echo "<TABLE id=\"customers\">"
        echo "<CAPTION>Partidos pendientes con pista asignada</CAPTION>"
        echo "<TR>"
        echo "<TH>Fecha</TH>"
        echo "<TH>Hora</TH>"
        echo "<TH>Lugar</TH>"
        echo "<TH>Rival</TH>"
        echo "</TR >"
        grep "|${n1}-${n2}|" "${DIR_TMP}/partidos" | gawk -F"|" '{if ($9=="-") print}' | sort -t"|" -k5,5 | gawk -F"|" '{
            if ($5=="-") { next; }
            print "<TR>";
            print "<TD>" substr($5,7,2) "/" substr($5,5,2) "/" substr($5,1,4) "</TD>";
            print "<TD>" $6 "</TD>";
            print "<TD>" $8 "</TD>";
            if ($3==PAREJA) { print "<TD>" $4 "</TD>"; }
            else            { print "<TD>" $3 "</TD>"; }
            print "</TR>";
        }' PAREJA="${n1}-${n2}"
        echo "</TABLE>"
        echo "</DIV>"

        echo "<br>"

        # -- tabla partidos pendientes sin fecha
        echo "<DIV STYLE='margin-left: 100px; margin-top: 10px;'>"
        echo "<TABLE id=\"customers\">"
        echo "<CAPTION>Partidos pendientes, sin pista asignada</CAPTION>"
        echo "<TR>"
        echo "<TH>Rival</TH>"
        echo "<TH>Huecos disponibles</TH>"
        echo "</TR >"
        grep "|${n1}-${n2}|" "${DIR_TMP}/partidos" | gawk -F"|" '{if ($9=="-") print}' | sort -t"|" -k5,5 |
            while IFS="|" read -r _ _ LOC VIS FECHA _ _ _ _ _ _ CONFIRMADA
            do
                if [ "${FECHA}" != "-" ]; then continue; fi
                if [ "${FECHA}" == "-" ] && [ "${CONFIRMADA}" == "true" ]; then continue; fi
                echo "<TR>"
                # -- rival
                if [ "${LOC}" == "${n1}-${n2}" ]; then echo "<TD>${VIS}</TD>"
                else                                   echo "<TD>${LOC}</TD>"
                fi
                # -- huecos disponibles
                out=$( bash Script/getFechasDisponiblesPartido.sh -q -p "${LOC}+${VIS}" -i "$( date +"%Y%m%d" )" -f "${CFG_FECHA_FIN}" )
                echo "<TD>${out}</TD>"
                echo "</TR>"
            done
        echo "</TABLE>"
        echo "</DIV>"

        # -- texto
        echo "<P>"
        echo "<B>Ante cualquier incoherencia entre la informaci&oacute;n de este email y la informaci&oacute;n"
        echo "de la web, deb&eacute;is tener en cuenta que lo dicho en este email siempre estar&aacute;"
        echo "m&aacute;s actualizado</B>"
        echo "</P>"

        # -- fin html
        echo "</BODY>"
        echo "</HTML>"

    } > "${DIR_TMP}/mail"

    # envia el email
    sendmail ${e1}, ${e2} < "${DIR_TMP}/mail"

done



############# FIN
prt_info "-- FIN"
exit 0

