#!/bin/bash

#================================================================================
#
# Script que genera/actualiza un ranking = clasificacion del torneo
#  - Puede generar de manera inicial, donde se conserva el orden que haya en parejas.txt
#  - Puede actualizar el fichero ranking.txt ya existente, dados los resultados del mes anterior (partidos.txt)
#
# Entrada
#  -i --> Indica que es un ranking inicial (por defecto, toma el fichero de partidos y actualiza ranking.txt)
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
  - Puede actualizar el fichero ranking.txt ya existente, dados los resultados del mes anterior (partidos.txt)

 Entrada
  -i --> Indica que es un ranking inicial (por defecto, toma el fichero de partidos y actualiza ranking.txt)

 Salida:
  0 --> ejecucion correcta
  1 --> ejecucion con errores
"

ARG_INICIAL=false  # por defecto no se trata de generar el ranking inicial

# Procesamos los argumentos de entrada
while getopts ih opt
do
    case "${opt}" in
        i) ARG_INICIAL=true;;
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

### CABECERA DEL FICHERO DE RANKING ---> POSICION |       PAREJA  |  PUNTOS | PARTIDOS_JUGADOS | PARTIDOS_GANADOS | JUEGOS_FAVOR | JUEGOS_CONTRA
###                                             1 | AlbertoMateos |      10 |                3 |                2 |           12 |             6


############# INICIALIZACION

prt_info "Inicializacion..."

# Resetea un directorio temporal solo para este script, dentro de tmp/
mkdir -p tmp; DIR_TMP="tmp/tmp.${SCRIPT}.${PID}"; rm -rf "${DIR_TMP}"; mkdir "${DIR_TMP}"

# Existencia de ficheros
if [ "${ARG_INICIAL}" == "false" ]
then
    if [ ! -f rankingReferencia.txt ]; then prt_error "ERROR: no existe el fichero [rankingReferencia.txt] en el directorio actual"; exit 1; fi
    if [ ! -f partidos.txt ];          then prt_error "ERROR: no existe el fichero [partidos.txt] en el directorio actual";          exit 1; fi
    out=$( FGRL_limpiaTabla rankingReferencia.txt "${DIR_TMP}/ranking"  false )
    out=$( FGRL_limpiaTabla partidos.txt          "${DIR_TMP}/partidos" false )
fi

# Limpia los diferentes ficheros
out=$( FGRL_limpiaTabla parejas.txt "${DIR_TMP}/parejas" false )

# Se hace backup de los ficheros de salida, para no sobreescribir
FGRL_backupFile ranking txt
FGRL_backupFile ranking html

# Puntos por partidos ganados / perdidos
PUNTOS_GANA_ARRIBA=1     # puntos que gana la pareja ganadora, si la pareja ganadora estaba situada en el ranking mas arriba que la otra pareja
PUNTOS_GANA_ABAJO=1      # puntos que gana la pareja ganadora, si la pareja ganadora estaba situada en el ranking mas abajo que la otra pareja
PUNTOS_PIERDE_ARRIBA=0   # puntos que gana la pareja perdedora, si la pareja ganadora estaba situada en el ranking mas arriba que la otra pareja
PUNTOR_PIERDE_ABAJO=0    # puntos que gana la pareja perdedora, si la pareja ganadora estaba situada en el ranking mas abajo que la otra pareja


############# EJECUCION

prt_info "Ejecucion..."


if [ "${ARG_INICIAL}" == "true" ]
then
    prt_info "-- GENERACION de un ranking inicial"

    nParejas=$( wc -l "${DIR_TMP}/parejas" | gawk '{printf("%d",($1+1)/2)}' )
    gawk 'BEGIN{OFS=FS="|";}{if (NR%2==0) {pos=NR/2; punt=1+N-NR/2; print pos,ant"-"$2$3,punt,"0","0","0","0";} ant=$2$3;}' N="${nParejas}" "${DIR_TMP}/parejas" > "${DIR_TMP}/new_ranking"
    
else
    prt_info "-- ACTUALIZACION de ranking anterior"

    # se copian ya que se van a ir modificando
    cp "${DIR_TMP}/ranking" "${DIR_TMP}/new_ranking"
    cp "${DIR_TMP}/partidos" "${DIR_TMP}/new_partidos"

    # Se comprueban errores de formato
    out=$( bash Script/checkPartidos.sh ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi
    
    # Se recorre la lista de partidos
    while IFS="|" read -r MES DIVISION LOCAL VISITANTE FECHA HINI HFIN LUGAR SET1 SET2 SET3 RANKING
    do

        # Se ignora si es un resultado que ya se ha metido en el ranking
        if [ "${RANKING}" == "true" ]; then continue; fi

        # Se ignora si es un partido que no tiene fecha+hora+lugar
        if [ "${FECHA}" == "-" ] && [ "${HINI}" == "-" ] && [ "${HFIN}" == "-" ] && [ "${LUGAR}" == "-" ]; then continue; fi

        # Se ignora si es un partido que no tiene inicializados los sets
        if [ "${SET1}" == "-" ] && [ "${SET2}" == "-" ] && [ "${SET3}" == "-" ]; then continue; fi

        jueL1=$( echo -e "${SET1}" | gawk -F"/" '{print $1}' ); jueV1=$( echo -e "${SET1}" | gawk -F"/" '{print $2}' )
        jueL2=$( echo -e "${SET2}" | gawk -F"/" '{print $1}' ); jueV2=$( echo -e "${SET2}" | gawk -F"/" '{print $2}' )
        jueL3=$( echo -e "${SET3}" | gawk -F"/" '{print $1}' ); jueV3=$( echo -e "${SET3}" | gawk -F"/" '{print $2}' )
        posRankLoc=$( gawk -F"|" '{if ($2==PAREJA) print $1+0}' PAREJA="${LOCAL}"     "${DIR_TMP}/ranking" )
        posRankVis=$( gawk -F"|" '{if ($2==PAREJA) print $1+0}' PAREJA="${VISITANTE}" "${DIR_TMP}/ranking" )
        difPos=$(( posRankLoc - posRankVis )); if [ "${difPos}" -lt "1" ]; then difPos=$(( difPos * (-1) )); fi

        # Se averigua el ganador
        ganador="visitante"
        if [ "${jueL1}" -gt "${jueV1}" ] && [ "${jueL2}" -gt "${jueV2}" ];                                  then ganador="local"; fi
        if [ "${jueL1}" -gt "${jueV1}" ] && [ "${jueL2}" -lt "${jueV2}" ] && [ "${jueL3}" -gt "${jueV3}" ]; then ganador="local"; fi
        if [ "${jueL1}" -lt "${jueV1}" ] && [ "${jueL2}" -gt "${jueV2}" ] && [ "${jueL3}" -gt "${jueV3}" ]; then ganador="local"; fi

        # *** PUNTOS (puntosLoc / puntosVis)
        if [ "${ganador}" == "local" ]     && [ "${posRankLoc}" -gt "${posRankVis}" ]; then puntosLoc=$(( PUNTOS_GANA_ABAJO + difPos ));  puntosVis=${PUNTOS_PIERDE_ARRIBA}; fi
        if [ "${ganador}" == "local" ]     && [ "${posRankLoc}" -lt "${posRankVis}" ]; then puntosLoc=${PUNTOS_GANA_ARRIBA}; puntosVis=${PUNTOS_PIERDE_ABAJO};  fi
        if [ "${ganador}" == "visitante" ] && [ "${posRankVis}" -gt "${posRankLoc}" ]; then puntosVis=$(( PUNTOS_GANA_ABAJO + difPos ));  puntosLoc=${PUNTOS_PIERDE_ARRIBA}; fi
        if [ "${ganador}" == "visitante" ] && [ "${posRankVis}" -lt "${posRankLoc}" ]; then puntosVis=${PUNTOS_GANA_ARRIBA}; puntosLoc=${PUNTOS_PIERDE_ABAJO};  fi

        # *** PARTIDOS_JUGADOS
        # no se hacen cuentas: a lo que habia se le suma 1, tanto en local como en visitante)

        # *** PARTIDOS_GANADOS (partGanaLoc / partGanaVis)
        if [ "${ganador}" == "local" ];     then partGanaLoc=1; partGanaVis=0; fi
        if [ "${ganador}" == "visitante" ]; then partGanaLoc=0; partGanaVis=1; fi

        # *** JUEGOS_FAVOR (jueFavorLoc / jueFavorVis)
        jueFavorLoc=$(( jueL1 + jueL2 )); if [ "${SET3}" != "-" ]; then jueFavorLoc=$(( jueFavorLoc + jueL3 )); fi
        jueFavorVis=$(( jueV1 + jueV2 )); if [ "${SET3}" != "-" ]; then jueFavorVis=$(( jueFavorVis + jueV3 )); fi
                                                                        
        # *** JUEGOS_CONTRA (jueContraLoc / jueContraVis)
        jueContraLoc=${jueFavorVis}
        jueContraVis=${jueFavorLoc}

        # Actualiza el nuevo ranking: POSICION | PAREJA | PUNTOS | PARTIDOS_JUGADOS | PARTIDOS_GANADOS | JUEGOS_FAVOR | JUEGOS_CONTRA
        # -- local
        gawk 'BEGIN{FS=OFS="|"}{if ($2==PAREJA) {$3=$3+PTS; $4=$4+1; $5=$5+GAN; $6=$6+FAV; $7=$7+CON;} print;}' \
             PAREJA="${LOCAL}" PTS="${puntosLoc}" GAN="${partGanaLoc}" FAV="${jueFavorLoc}" CON="${jueContraLoc}" "${DIR_TMP}/new_ranking" > "${DIR_TMP}/new_ranking.tmp"
        mv "${DIR_TMP}/new_ranking.tmp" "${DIR_TMP}/new_ranking"
        # -- visitante
        gawk 'BEGIN{FS=OFS="|"}{if ($2==PAREJA) {$3=$3+PTS; $4=$4+1; $5=$5+GAN; $6=$6+FAV; $7=$7+CON;} print;}' \
             PAREJA="${VISITANTE}" PTS="${puntosVis}" GAN="${partGanaVis}" FAV="${jueFavorVis}" CON="${jueContraVis}" "${DIR_TMP}/new_ranking" > "${DIR_TMP}/new_ranking.tmp"
        mv "${DIR_TMP}/new_ranking.tmp" "${DIR_TMP}/new_ranking"

        # Actualiza el fichero partidos.txt para cambiar a RANKING=true
        gawk 'BEGIN{OFS=FS="|";}{if ($1==M && $2==D && $3==LO && $4==V && $5==F && $6==HI && $7==HF && $8==LU && $9==SA && $10==SB && $11==SC) {$12="true";} print;}' \
             M="${MES}" D="${DIVISION}" LO="${LOCAL}" V="${VISITANTE}" F="${FECHA}" HI="${HINI}" HF="${HFIN}" LU="${LUGAR}" SA="${SET1}" SB="${SET2}" SC="${SET3}" "${DIR_TMP}/new_partidos" > "${DIR_TMP}/new_partidos.new"
        mv "${DIR_TMP}/new_partidos.new"  "${DIR_TMP}/new_partidos"
        
    done < "${DIR_TMP}/partidos"

    {
        head -1 partidos.txt
        cat "${DIR_TMP}/new_partidos"
    } > partidos.txt.new; mv partidos.txt.new partidos.txt
    prt_info "---- Actualizado ${G}partidos.txt${NC}"

    out=$( bash Script/formateaTabla.sh -f partidos.txt ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi
fi

# Se ordena por puntos + juegos_favor + juego_contra
sort -t"|" -s -r -g -k3,3 -k6,6 -k7,7 "${DIR_TMP}/new_ranking" > "${DIR_TMP}/new_ranking.tmp"
mv "${DIR_TMP}/new_ranking.tmp" "${DIR_TMP}/new_ranking"

# Se actualizan las posiciones
gawk 'BEGIN{OFS=FS="|";}{$1=NR; print}' "${DIR_TMP}/new_ranking" > "${DIR_TMP}/new_ranking.tmp"
mv "${DIR_TMP}/new_ranking.tmp" "${DIR_TMP}/new_ranking"

# Se construye el fichero final
{
    # -- cabecera
    echo "POSICION|PAREJA|PUNTOS|PARTIDOS_JUGADOS|PARTIDOS_GANADOS|JUEGOS_FAVOR|JUEGOS_CONTRA"
    # -- cuerpo
    cat "${DIR_TMP}/new_ranking"
} > ranking.txt
prt_info "---- Generado ${G}ranking.txt${NC}"

# Da forma y comprueba que esta bien generado
prt_info "-- Se formatea ranking.txt y se valida su contenido"
out=$( bash Script/formateaTabla.sh -f ranking.txt ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi

# Se genera el html
prt_info "-- Se genera el html a partir de ese fichero"

# -- limpia la tabla
out=$( FGRL_limpiaTabla ranking.txt "${DIR_TMP}/ranking" true ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi

# -- genera el html
cat <<EOM >ranking.html
<!DOCTYPE html>
<html>
  <head>
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
echo "<h1>TORNEO DE PADEL - ${CFG_NOMBRE}</h1>" >> ranking.html
echo "<h2>Ranking</h2>" >> ranking.html
cat <<EOM >>ranking.html
    <br>

    <input type="text" id="myInput" onkeyup="myFunction()" placeholder="Busca..." title="Busca en cualquier columna">
    <br>

    <table id="customers">
EOM
head -1   "${DIR_TMP}/ranking" | gawk -F"|" '{print "<tr>";for(i=1;i<=NF;i++)print "<th onclick=\"sortTable("i-1")\">" $i"</th>";print "</tr>"}' >> ranking.html
tail -n+2 "${DIR_TMP}/ranking" | gawk -F"|" '{print "<tr>";for(i=1;i<=NF;i++)print "<td>"                              $i"</td>";print "</tr>"}' >> ranking.html
cat <<EOM >>ranking.html
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

prt_info "---- Generado ${G}ranking.html${NC}"


############# FIN
exit 0

