#!/bin/bash

#================================================================================
#
# Script que genera el fichero calendario.html a partir de calendario.txt
#
# Entrada
#  -- no tiene
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
if [ ! -f pistas.txt ];     then prt_error "ERROR: no existe el fichero [pistas.txt] en el directorio actual";     exit 1; fi
if [ ! -f calendario.txt ]; then prt_error "ERROR: no existe el fichero [calendario.txt] en el directorio actual";  exit 1; fi

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

 Script que genera el fichero calendario.html a partir de calendario.txt

 Entrada
  -- no tiene

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

function interrumpir {
    exit 1
}
trap "interrumpir;" INT

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

### CABECERA DEL FICHERO DE PARTIDOS ---> Mes | Division |                     Local |            Visitante |    Fecha | Hora_ini | Hora_fin |   Lugar | Set1 | Set2 | Set3
###                                         1 |        1 | AlbertoMateos-IsraelAlonso| EricPerez-DanielRamos| 20190507 |    18:00 |    19:30 | Pista 7 |  7/5 |  6/5 |    -


############# INICIALIZACION

prt_info "Inicializacion..."

# Resetea un directorio temporal solo para este script, dentro de tmp/
mkdir -p tmp; DIR_TMP="tmp/tmp.${SCRIPT}.${PID}"; rm -rf "${DIR_TMP}"; mkdir "${DIR_TMP}"

# Limpia los diferentes ficheros
out=$( FGRL_limpiaTabla pistas.txt     "${DIR_TMP}/pistas"     false )
out=$( FGRL_limpiaTabla calendario.txt "${DIR_TMP}/calendario" false )

# Se hace backup de los ficheros de salida, para no sobreescribir
FGRL_backupFile calendario html; rv=$?; if [ "${rv}" != "0" ]; then exit 1; fi
FGRL_backupFile partidos   txt;  rv=$?; if [ "${rv}" != "0" ]; then exit 1; fi
FGRL_backupFile partidos   html; rv=$?; if [ "${rv}" != "0" ]; then exit 1; fi



############# EJECUCION

prt_info "Ejecucion..."

# Actualiza los ficheros de partidos
bash Script/updatePartidos.sh -w -f; rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi

# Genera el html de calendario
cat <<EOM >calendario.html
<!DOCTYPE html>
<html>
  <head>
    <title>CALENDARIO - Torneo de pádel IIC</title>
    <link href='https://use.fontawesome.com/releases/v5.0.6/css/all.css' rel='stylesheet'>
    <link href='Librerias/fullcalendar/core/main.css' rel='stylesheet' />
    <link href='Librerias/fullcalendar/bootstrap/main.css' rel='stylesheet' />
    <link href='Librerias/fullcalendar/timegrid/main.css' rel='stylesheet' />
    <link href='Librerias/fullcalendar/daygrid/main.css' rel='stylesheet' />
    <link href='Librerias/fullcalendar/list/main.css' rel='stylesheet' />
    <link href='Librerias/fullcalendar/bootstrap/main.css' rel='stylesheet' />
    <script src='Librerias/fullcalendar/core/main.js'></script>
    <script src='Librerias/fullcalendar/interaction/main.js'></script>
    <script src='Librerias/fullcalendar/bootstrap/main.js'></script>
    <script src='Librerias/fullcalendar/daygrid/main.js'></script>
    <script src='Librerias/fullcalendar/timegrid/main.js'></script>
    <script src='Librerias/fullcalendar/list/main.js'></script>
    <script src='Librerias/fullcalendar/bootstrap/main.js'></script>
    <script src='Librerias/fullcalendar/resource-common/main.js'></script>
    <script src='Librerias/fullcalendar/resource-daygrid/main.js'></script>
    <script src='Librerias/fullcalendar/resource-timegrid/main.js'></script>
    <script src='Librerias/other/jquery.min.js'></script>
    <script src='Librerias/other/popper.min.js'></script>
    <script src='Librerias/other/tooltip.min.js'></script>
    <script>
      document.addEventListener('DOMContentLoaded', function() {
        var calendarEl = document.getElementById('calendar');
        var calendar = new FullCalendar.Calendar(calendarEl, {
          plugins: [ 'bootstrap', 'interaction', 'dayGrid', 'timeGrid', 'list', 'resourceDayGrid', 'resourceTimeGrid' ],
          themeSystem: 'bootstrap4',
          header: {
            left: 'prevYear,prev,next,nextYear today',
            center: 'title',
            right: 'dayGridMonth,listMonth,resourceTimeGridDay'
          },
          aspectRatio: 2.5,
          firstDay: 1,
          navLinks: true,
          businessHours: true,
          minTime: "13:00",
          maxTime: "23:00",
          navLinks: true, 
          selectable: true,
          selectMirror: true,
          editable: false,
          resources: [
EOM
gawk -F"|" '{print $1}' "${DIR_TMP}/pistas" | sort -u |
    gawk '
{
    print "            {";
    print "              id: \x27" $1 "\x27,";
    print "              title: \x27" $1 "\x27";
    print "            },";
}' >> calendario.html
sed -i '$ s/.$//' calendario.html
cat <<EOM >>calendario.html
          ],
          eventRender: function(info) {
            var tooltip = new Tooltip(info.el, {
              title: info.event.extendedProps.description,
              html: true,
              placement: 'top',
              trigger: 'hover',
              container: 'body'
            });
          },
          events: [
EOM
gawk -F"|" '
{
    print "            {";
    print "              id: " NR",";
    print "              title: \x27"$2" vs "$3"\x27,";
    print "              description: \x27Mes "$1"<br>"$2"<br>vs<br>"$3"\x27,";
    print "              start: \x27" substr($5,1,4)"-"substr($5,5,2)"-"substr($5,7,2)"T"$6":00\x27,";
    print "              end:   \x27" substr($5,1,4)"-"substr($5,5,2)"-"substr($5,7,2)"T"$7":00\x27,";
    print "              resourceId: \x27" $4 "\x27";
    print "            },";
}' "${DIR_TMP}/calendario" >> calendario.html
sed -i '$ s/.$//' calendario.html
cat <<EOM >>calendario.html
          ]
        });
        calendar.render();
      });
    </script>
    <style>
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
      #calendar {
        width: 90%;
        margin: 0 auto;
      }
      .popper,
      .tooltip {
        position: absolute;
        z-index: 9999;
        background: #668a99;
        color: white;
        border-radius: 3px;
        box-shadow: 0 0 2px rgba(0,0,0,0.5);
        padding: 10px;
          text-align: center;
          font-size: 10pt;
      }
      .style5 .tooltip {
        background: #1E252B;
        color: #FFFFFF;
        max-width: 200px;
        width: auto;
        font-size: .8rem;
        padding: .5em 1em;
      }
      .popper .popper__arrow,
      .tooltip .tooltip-arrow {
        width: 0;
        height: 0;
        border-style: solid;
        position: absolute;
        margin: 5px;
      }
    
      .tooltip .tooltip-arrow,
      .popper .popper__arrow {
        border-color: #668a99;
      }
      .style5 .tooltip .tooltip-arrow {
        border-color: #1E252B;
      }
      .popper[x-placement^="top"],
      .tooltip[x-placement^="top"] {
        margin-bottom: 5px;
      }
      .popper[x-placement^="top"] .popper__arrow,
      .tooltip[x-placement^="top"] .tooltip-arrow {
        border-width: 5px 5px 0 5px;
        border-left-color: transparent;
        border-right-color: transparent;
        border-bottom-color: transparent;
        bottom: -5px;
        left: calc(50% - 5px);
        margin-top: 0;
        margin-bottom: 0;
      }
      .popper[x-placement^="bottom"],
      .tooltip[x-placement^="bottom"] {
        margin-top: 5px;
      }
      .tooltip[x-placement^="bottom"] .tooltip-arrow,
      .popper[x-placement^="bottom"] .popper__arrow {
        border-width: 0 5px 5px 5px;
        border-left-color: transparent;
        border-right-color: transparent;
        border-top-color: transparent;
        top: -5px;
        left: calc(50% - 5px);
        margin-top: 0;
        margin-bottom: 0;
      }
      .tooltip[x-placement^="right"],
      .popper[x-placement^="right"] {
        margin-left: 5px;
      }
      .popper[x-placement^="right"] .popper__arrow,
      .tooltip[x-placement^="right"] .tooltip-arrow {
        border-width: 5px 5px 5px 0;
        border-left-color: transparent;
        border-top-color: transparent;
        border-bottom-color: transparent;
        left: -5px;
        top: calc(50% - 5px);
        margin-left: 0;
        margin-right: 0;
      }
      .popper[x-placement^="left"],
      .tooltip[x-placement^="left"] {
        margin-right: 5px;
      }
      .popper[x-placement^="left"] .popper__arrow,
      .tooltip[x-placement^="left"] .tooltip-arrow {
        border-width: 5px 0 5px 5px;
        border-top-color: transparent;
        border-right-color: transparent;
        border-bottom-color: transparent;
        right: -5px;
        top: calc(50% - 5px);
        margin-left: 0;
        margin-right: 0;
      }
    </style>
  </head>
  <body>
EOM
echo "    <h1>TORNEO DE PADEL - ${CFG_NOMBRE}</h1>" >> calendario.html
cat <<EOM >>calendario.html
    <div id='calendar'></div>
  </body>
</html>
EOM

prt_info "---- Generado ${G}calendario.html${NC}"


############# FIN
exit 0
