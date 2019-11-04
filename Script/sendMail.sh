#!/bin/bash

#================================================================================
#
# Script que envia un email a las personas que participan indicandoles la fecha
# de los partidos que tienen programas y que aun no han jugado.
#
# Entrada
#  -v --> Verboso (no envia los emails, pero indica paso a paso lo que haria)
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
 de los partidos que tienen programas y que aun no han jugado.

 Entrada
  -v --> Verboso (no envia los emails, pero indica paso a paso lo que haria)

 Salida:
  0 --> ejecucion correcta
  1 --> ejecucion con errores
"

ARG_VERBOSO=false

# Procesamos los argumentos de entrada
while getopts vh opt
do
    case "${opt}" in
        v) ARG_VERBOSO=true;;
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

###                                        1       2                     3                        4              5          6          7          8       9      10    11      12       13
### CABECERA DEL FICHERO DE PARTIDOS ---> Mes | Division |                     Local |            Visitante |    Fecha | Hora_ini | Hora_fin |   Lugar | Set1 | Set2 | Set3 | Puntos | Ranking
###                                         1 |        1 | AlbertoMateos-IsraelAlonso| EricPerez-DanielRamos| 20190507 |    18:00 |    19:30 | Pista 7 |  7/5 |  6/5 |    - |      - | false

### CABECERA DEL FICHERO DE PAREJAS ---> PAREJA|       NOMBRE|  APELLIDO|                      CORREO
###                                           1|  JoseAntonio|   Cordoba|     jose.cordoba@iic.uam.es


############# INICIALIZACION

prt_info "Inicializacion..."

# Resetea un directorio temporal solo para este script, dentro de tmp/
mkdir -p tmp; DIR_TMP="tmp/tmp.${SCRIPT}.${PID}"; rm -rf "${DIR_TMP}"; mkdir "${DIR_TMP}"

# Limpia los diferentes ficheros
out=$( FGRL_limpiaTabla parejas.txt  "${DIR_TMP}/parejas"  false )
out=$( FGRL_limpiaTabla partidos.txt "${DIR_TMP}/partidos" false )

# Crea directorio donde ira almacenando todos los emails, para evitar enviar emails repetidos
mkdir -p emails


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
    persona1=$( head -"${l1}" "${DIR_TMP}/parejas" | tail -1 | gawk -F"|" '{print $2 " " $3}' )
    persona2=$( head -"${l2}" "${DIR_TMP}/parejas" | tail -1 | gawk -F"|" '{print $2 " " $3}' )
    if [ "${persona2:0:1}" == "I" ]; then aux=e
    else                                  aux=y
    fi

    # averigua la columna de los resultados
    if   [ "${CFG_MODO_PUNTUACION}" == "SETS" ];   then COL_PUNTOS=9
    elif [ "${CFG_MODO_PUNTUACION}" == "PUNTOS" ]; then COL_PUNTOS=12
    else                                           prt_error "CFG_MODO_PUNTUACION=${CFG_MODO_PUNTUACION} es invalido, solo puede ser SETS o PUNTOS"; exit 1
    fi

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
        echo "Hola <B style='color:blue'>${persona1}</B> ${aux} <B style='color:blue'>${persona2}</B> !"
        echo "<BR><BR>"
        echo "Este email se env&iacute;a porque ha habido modificaciones en el calendario que os pueden afectar."
        echo "<BR>"
        echo "<B>Ignorad emails anteriores.</B>"
        echo "</P>"
        echo "<P>"
        echo "Por favor, comprobad que no teneis restricciones y est&aacute;is libres en esas fechas."
        echo "<BR>"
        echo "Para informar de cualquier problema escribid al email <A HREF="padel@iic.uam.es">padel@iic.uam.es</A>"
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
        grep "|${n1}-${n2}|" "${DIR_TMP}/partidos" | gawk -F"|" '{if ($COL=="-") print}' COL="${COL_PUNTOS}" | sort -t"|" -k5,5 | gawk -F"|" '
        BEGIN{ vacio=1; }
        {
            if ($5=="-") { next; }
            print "<TR>";
            print "<TD>" substr($5,7,2) "/" substr($5,5,2) "/" substr($5,1,4) "</TD>";
            print "<TD>" $6 "</TD>";
            print "<TD>" $8 "</TD>";
            if ($3==PAREJA) { print "<TD>" $4 "</TD>"; }
            else            { print "<TD>" $3 "</TD>"; }
            print "</TR>";
            vacio = 0;
        }
        END{
            if (vacio==1) {
                print "<TD colspan=\"4\">No tienes partidos pendientes</TD>"
            }
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
        touch "${DIR_TMP}/vacio.txt"
        grep "|${n1}-${n2}|" "${DIR_TMP}/partidos" | gawk -F"|" '{if ($COL=="-") print}' COL="${COL_PUNTOS}" | sort -t"|" -k5,5 |
            while IFS="|" read -r _ _ LOC VIS FECHA _ _ _ _ _ _ _ CONFIRMADA
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
                if [ "${out}" != "" ]
                then
                    echo "<TD>"
                    echo "<B>Elegid un hueco de entre los siguientes:</B>"
                    echo "<BR>"
                    echo "${out}"
                    echo "</TD>"
                else
                    echo "<TD>"
                    echo "No hay ning&uacute;n hueco disponible seg&uacute;n vuestras restricciones."
                    echo "<BR>"
                    echo "Opciones disponibles:<BR>"
                    echo "<UL>"
                    echo "<LI>Jugar un viernes</LI>"
                    echo "<LI>Jugar un d&iacute;a entre semana antes de las 18:00</LI>"
                    echo "<LI>Algun jugador debe cambiar sus restricciones</LI>"
                    echo "</TD>"
                fi
                echo "</TR>"
                rm -f "${DIR_TMP}/vacio.txt"
            done
        if [ -f "${DIR_TMP}/vacio.txt" ]; then rm "${DIR_TMP}/vacio.txt"; echo "<TD colspan=\"2\">No tienes partidos pendientes</TD>"; fi
        echo "</TABLE>"
        echo "</DIV>"

        # -- texto
        echo "<P>"
        echo "Nota: <B>Tened en cuenta que la informaci&oacute;n de este email es la oficial (la web del calendario tarda algo m&aacute;s en actualizarse)</B>"
        echo "</P>"

        # -- fin html
        echo "</BODY>"
        echo "</HTML>"

    } > "${DIR_TMP}/mail"

    # Solo se envia el email, si el email generado es diferente al ultimo que se envio
    fileEmail="emails/mail-${n1}-${n2}.html"
    if [ -f "${fileEmail}" ] && [ "$( diff "${DIR_TMP}/mail" "${fileEmail}" )" == "" ]; then continue; fi

    if [ "${ARG_VERBOSO}" == "true" ]
    then
        base=$( basename "${fileEmail}" )
        prt_debug "${ARG_VERBOSO}" "Envia el mail [${base}] porque es diferente a lo que habia"
        cp "${DIR_TMP}/mail" "${base}"
        continue
    fi

    # hace copia del email nuevo que va a enviar
    cp "${DIR_TMP}/mail" "${fileEmail}"
    
    # envia el email
    sendmail ${e1}, ${e2} < "${DIR_TMP}/mail"

done



############# FIN
prt_info "-- FIN"
exit 0

