#!/bin/bash

#================================================================================
#
# Script que actualiza el fichero partidos.txt de diferentes maneras segun
# parametros de entrada.
#
# Entrada
#  -f --> Actualiza fechas+horas+lugar en partidos.txt dado calendario.txt
#  -w --> Genera partidos.html a partir de partidos.txt
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

 Script que actualiza el fichero partidos.txt de diferentes maneras segun
 parametros de entrada.

 Entrada
  -f --> Actualiza fechas+horas+lugar en partidos.txt dado calendario.txt
  -w --> Genera partidos.html a partir de partidos.txt

 Salida:
  0 --> ejecucion correcta
  1 --> ejecucion con errores
"

ARG_CALENDARIO=false # por defecto, no se actualizan fechas+horas+lugar
ARG_HTML=false       # por defecto, no se genera el html

# Procesamos los argumentos de entrada
while getopts fwh opt
do
    case "${opt}" in
        f) ARG_CALENDARIO=true;;
        w) ARG_HTML=true;;
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

### CABECERA DEL FICHERO DE PARTIDOS ---> Mes | Division |                     Local |            Visitante |    Fecha | Hora_ini | Hora_fin |   Lugar | Set1 | Set2 | Set3
###                                         1 |        1 | AlbertoMateos-IsraelAlonso| EricPerez-DanielRamos| 20190507 |    18:00 |    19:30 | Pista 7 |  7/6 |  6/4 |    -


############# INICIALIZACION

prt_info "Inicializacion..."

# Resetea un directorio temporal solo para este script, dentro de tmp/
mkdir -p tmp; DIR_TMP="tmp/tmp.${SCRIPT}.${PID}"; rm -rf "${DIR_TMP}"; mkdir "${DIR_TMP}"

# Se hace backup de los ficheros de salida, para no sobreescribir
FGRL_backupFile partidos txt;  rv=$?; if [ "${rv}" != "0" ]; then exit 1; fi
FGRL_backupFile partidos html; rv=$?; if [ "${rv}" != "0" ]; then exit 1; fi


############# EJECUCION

prt_info "Ejecucion..."

# Lo primero es formatear la tabla
out=$( bash Script/formateaTabla.sh -f partidos.txt ); rv=$?
if [ "${rv}" != "0" ]; then prt_error "Error ejeuctando <bash Script/formateaTabla.sh -f partidos.txt>"; echo -e "${out}"; exit 1; fi

# Y comprobar que el formato esta bien
out=$( bash Script/checkPartidos.sh ); rv=$?
if [ "${rv}" != "0" ]; then prt_error "Error ejeuctando <bash Script/checkPartidos.sh>"; echo -e "${out}"; exit 1; fi


if [ "${ARG_CALENDARIO}" == "false" ]; then prt_warn "-- Se indica no actualizar con los datos de calendario.txt"
else
    prt_warn "-- Se indica SI actualizar con los datos de calendario.txt"

    # Deben existir los siguientes ficheros
    if [ ! -f calendario.txt ]; then prt_error "ERROR: no existe el fichero [calendario.txt] en el directorio actual"; exit 1; fi

    # Limpiar tabla
    out=$( FGRL_limpiaTabla partidos.txt "${DIR_TMP}/partidos" true )
    out=$( FGRL_limpiaTabla "calendario.txt" "${DIR_TMP}/calendario" false ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi
    
    while IFS="|" read -r MES LO VI LU FE HI HF
    do
        gawk 'BEGIN{FS=OFS="|";}{m=$1; l=$3; v=$4; gsub(" ","",m); gsub(" ","",l); gsub(" ","",v); if (m==MES && l==LO && v==VI) {$5=FE; $6=HI; $7=HF; $8=LU}; print;}' \
             MES="${MES}" LO="${LO}" VI="${VI}" FE="${FE}" HI="${HI}" HF="${HF}" LU="${LU}" "partidos.txt" > "${DIR_TMP}/partidos.txt.tmp"
        mv "${DIR_TMP}/partidos.txt.tmp" "partidos.txt"
    done < "${DIR_TMP}/calendario"
    
    out=$( bash Script/formateaTabla.sh -f "partidos.txt" ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi

    prt_info "---- Generado ${G}partidos.txt${N}"
fi


if [ "${ARG_HTML}" == "false" ]; then prt_warn "-- Se indica no generar el fichero partidos.html"
else
    prt_info "-- Se indica SI generar el fichero partidos.html"

    # Limpia los diferentes ficheros
    out=$( FGRL_limpiaTabla partidos.txt "${DIR_TMP}/partidos" true )   

    # Se transforman las fechas a un formato mas legible
    head -1 "${DIR_TMP}/partidos" > "${DIR_TMP}/partidos.tmp"
    tail -n+2 "${DIR_TMP}/partidos" | gawk 'BEGIN{OFS=FS="|";}{if ($5!="-") {$5=sprintf("%02d/%02d/%04d",substr($5,7,2),substr($5,5,2),substr($5,1,4));} print;}' >> "${DIR_TMP}/partidos.tmp"
    mv "${DIR_TMP}/partidos.tmp" "${DIR_TMP}/partidos"
    
    cat <<EOM >partidos.html
<!DOCTYPE html>
<html>
  <head>
   <title>PARTIDOS - Torneo de padel IIC</title>
   <style>
      #myInput {
        margin-left: 5%;
        margin-right: 5%;
        margin-bottom: 1%;
        width: 50%;
      }
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
        cursor: pointer;
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
    echo "    <h1>TORNEO DE PADEL - ${CFG_NOMBRE}</h1>" >> partidos.html
    echo "    <h2>Partidos</h2>" >> partidos.html
    cat <<EOM >>partidos.html

    <br>
    <input type="text" id="myInput" onkeyup="myFunction()" placeholder="Busca..." title="Busca en cualquier columna">
    <br>

    <table id="customers">
EOM
    head -1   "${DIR_TMP}/partidos" | gawk -F"|" '{print "<tr>";for(i=1;i<=NF;i++)print "<th onclick=\"sortTable("i-1")\">" $i"</th>";print "</tr>"}' >> partidos.html
    tail -n+2 "${DIR_TMP}/partidos" | gawk -F"|" '{print "<tr>";for(i=1;i<=NF;i++)print "<td>"                              $i"</td>";print "</tr>"}' >> partidos.html
    cat <<EOM >>partidos.html
    </table>

    <script>
      function myFunction() {
        var input, filter, table, tr, td, i, txtValue;
        input = document.getElementById("myInput");
        filter = input.value.toUpperCase();
        table = document.getElementById("customers");
        tr = table.getElementsByTagName("tr");
        th = table.getElementsByTagName("th");
        for (i = 0; i < tr.length; i++) {
          for(var j=0; j<th.length; j++){
            td = tr[i].getElementsByTagName("td")[j];
            if (td) {
              txtValue = td.textContent || td.innerText;
              if (txtValue.toUpperCase().indexOf(filter) > -1) {
                tr[i].style.display = "";
                break;
              } else {
                tr[i].style.display = "none";
              }
            }       
          }
        }
      }
      function sortTable(n) {
        var table, rows, switching, i, x, y, shouldSwitch, dir, switchcount = 0;
        table = document.getElementById("customers");
        switching = true;
        //Set the sorting direction to ascending:
        dir = "asc"; 
        /*Make a loop that will continue until
        no switching has been done:*/
        while (switching) {
          //start by saying: no switching is done:
          switching = false;
          rows = table.rows;
          /*Loop through all table rows (except the
          first, which contains table headers):*/
          for (i = 1; i < (rows.length - 1); i++) {
            //start by saying there should be no switching:
            shouldSwitch = false;
            /*Get the two elements you want to compare,
            one from current row and one from the next:*/
            x = rows[i].getElementsByTagName("TD")[n];
            y = rows[i + 1].getElementsByTagName("TD")[n];
            /*check if the two rows should switch place,
            based on the direction, asc or desc:*/
            if (dir == "asc") {
              if ((isNaN(x.innerHTML) && x.innerHTML.toLowerCase() > y.innerHTML.toLowerCase()) || (!isNaN(x.innerHTML) && parseFloat(x.innerHTML) > parseFloat(y.innerHTML))) {
                //if so, mark as a switch and break the loop:
                shouldSwitch= true;
                break;
              }
            } else if (dir == "desc") {
              if ((isNaN(x.innerHTML) && x.innerHTML.toLowerCase() < y.innerHTML.toLowerCase()) || (!isNaN(x.innerHTML) && parseFloat(x.innerHTML) < parseFloat(y.innerHTML))) {
                //if so, mark as a switch and break the loop:
                shouldSwitch = true;
                break;
              }
            }
          }
          if (shouldSwitch) {
            /*If a switch has been marked, make the switch
            and mark that a switch has been done:*/
            rows[i].parentNode.insertBefore(rows[i + 1], rows[i]);
            switching = true;
            //Each time a switch is done, increase this count by 1:
            switchcount ++;      
          } else {
            /*If no switching has been done AND the direction is "asc",
            set the direction to "desc" and run the while loop again.*/
            if (switchcount == 0 && dir == "asc") {
              dir = "desc";
              switching = true;
            }
          }
        }
      }
    </script>

  </body>
</html>
EOM

    prt_info "---- Generado ${G}partidos.html${N}"
fi




############# FIN
exit 0

