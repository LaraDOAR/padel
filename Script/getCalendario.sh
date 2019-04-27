#!/bin/bash

#================================================================================
#
# Script que calcula cuando se deben jugar los partidos de una jornada dada.
#  - Actualiza el fichero partidos-jornadaN.txt, con los datos de: fecha, hora, lugar
#  - Genera el fichero calendario.html donde aparecen todos los partidos programados
#
# Entrada
#  -j [n]        --> Numero de la jornada (1,2,3...)
#  -i [YYYYMMDD] --> Fecha de inicio de la jornada
#  -f [YYYYMMDD] --> Fecha fin de la jornada
#  -v            --> Verboso (para ver las iteraciones del algoritmo)
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
if [ ! -f restricciones.txt ]; then prt_error "ERROR: no existe el fichero [restricciones.txt] en el directorio actual"; exit 1; fi

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

 Script que calcula cuando se deben jugar los partidos de una jornada dada.
  - Actualiza el fichero partidos-jornadaN.txt, con los datos de: fecha, hora, lugar
  - Genera el fichero calendario.html donde aparecen todos los partidos programados

 Entrada:
  -j [n]        --> Numero de la jornada (1,2,3...)
  -i [YYYYMMDD] --> Fecha de inicio de la jornada
  -f [YYYYMMDD] --> Fecha fin de la jornada
  -v            --> Verboso (para ver las iteraciones del algoritmo)

 Salida:
  0 --> ejecucion correcta
  1 --> ejecucion con errores
"

ARG_JORNADA=""     # parametro obligatorio
ARG_FECHA_INI=""   # parametro obligatorio
ARG_FECHA_FIN=""   # parametro obligatorio
ARG_VERBOSO=false  # por defecto, no es verboso

# Procesamos los argumentos de entrada
while getopts j:i:f:vh opt
do
    case "${opt}" in
        j) ARG_JORNADA=$OPTARG;;
        i) ARG_FECHA_INI=$OPTARG;;
        f) ARG_FECHA_FIN=$OPTARG;;
        v) ARG_VERBOSO=true;;
        h) echo -e "${AYUDA}"; exit 0;;
        *) prt_error "Parametro [${opt}] invalido"; echo -e "${AYUDA}"; exit 1;;
    esac
done

if [ "${ARG_JORNADA}" == "" ];         then prt_error "ERROR: ARG_JORNADA vacio, necesario el parametro -j";                                                                           exit 1; fi
if [ "${ARG_FECHA_INI}" == "" ];       then prt_error "ERROR: ARG_FECHA_INI vacio, necesario el parametro -i";                                                                         exit 1; fi
if [ "${ARG_FECHA_FIN}" == "" ];       then prt_error "ERROR: ARG_FECHA_FIN vacio, necesario el parametro -f";                                                                         exit 1; fi
if ! [[ ${ARG_JORNADA} =~ ^[0-9]+$ ]]; then prt_error "ERROR: ARG_JORNADA=${ARG_JORNADA}, no es un numero entero valido (param -j)";                                                   exit 1; fi
date +"%Y%m%d" -d "${ARG_FECHA_INI} +5 days" > /dev/null 2>&1; rv=$?; if [ "${rv}" != "0" ]; then prt_error "ERROR: ARG_FECHA_INI=${ARG_FECHA_INI} no es una fecha valida (param -i)"; exit 1; fi
date +"%Y%m%d" -d "${ARG_FECHA_FIN} +5 days" > /dev/null 2>&1; rv=$?; if [ "${rv}" != "0" ]; then prt_error "ERROR: ARG_FECHA_INI=${ARG_FECHA_INI} no es una fecha valida (param -f)"; exit 1; fi




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


##########
# - factorial
#     Funcion   --->  calcula el factorial de un numero
#     Entrada   --->  $1 = numero
#     Salida    --->  0 = ok
#                     1 = error
#                ECHO resultados
#
function factorial {

    # Argumentos
    local _n=$1

    # Variables internas
    local _res

    # Inicializacion
    _res=1
    while [ "${_n}" -gt "0" ]
    do
        _res=$(( _res * _n ))
        _n=$(( _n - 1 ))
    done
    
    # Fin
    echo "${_res}"
    return 0
}


##########
# - getPermutacion
#     Funcion   --->  genera n ficheros nuevos con las diferentes permutaciones de sus linea posibles
#     Entrada   --->  $1 = fichero
#     Entrada   --->  $2 = iteracion: numero de la iteracion
#     Salida    --->  0 = ok
#                     1 = error
#                   $1.perm1
#                   $1.perm2
#                   $1.perm(...)
#
function getPermutacion {

    # Argumentos
    local _file=$1
    local _iteracion=$2

    # Variables internas
    local _dir
    local _base
    local _f
    local _files
    local _nPosiciones
    local _i
    
    # Condicion de parada: cuando solo queda un elemento
    if [ "$( wc -l "${_file}" | gawk '{print $1}' )" == "1" ]
    then
        cat "${_file}" > "${_file}.perm${_iteracion}"
        return 0
    fi

    # Se genera un fichero que no tiene la primer linea
    tail -n+2 "${_file}" > "${_file}.${_iteracion}"

    # Se calculan las permutaciones del fichero restante
    getPermutacion "${_file}.${_iteracion}" "${_iteracion}"
    rm "${_file}.${_iteracion}"

    # Se calculan las combinaciones: se pone la primera linea de _file
    # delante de todos los ficheros resultado
    _dir=$(  dirname  "${_file}" )
    _base=$( basename "${_file}" )
    _files=$( find "${_dir}/" -type f -name "${_base}.${_iteracion}.perm*" )
    _newLine=$( head -1 "${_file}" )
    for _f in ${_files}
    do
        # En el fichero _f tengo "2 er" y "3 tq", y newLine es "1 ab"
        # Lo que quiero es meter "1 ab" en todas las posiciones posibles
        # En este caso: en la 1 (antes de "2 er"), en la 2 (entre "2 er" y "3 tq"), y en la 3 (despues de "3 tq")
        _nPosiciones=$( wc -l "${_f}" | gawk '{print $1}' )
        for _i in $( seq 1 "${_nPosiciones}" )
        do
            gawk '{if (NR==POSICION) print NEW; print;}' POSICION="${_i}" NEW="${_newLine}" "${_f}" > "${_file}.perm${_iteracion}"
            _iteracion=$(( _iteracion + 1 ))
        done
        cat "${_f}" > "${_file}.perm${_iteracion}"; echo "${_newLine}" >> "${_file}.perm${_iteracion}"
        _iteracion=$(( _iteracion + 1 ))
        rm "${_f}"
    done

    # Fin
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

### CABECERA DEL FICHERO DE PARTIDOS ---> Jornada |                     Local |            Visitante |    Fecha | Hora_ini | Hora_fin |   Lugar | Set1 | Set2 | Set3
###                                             1 | AlbertoMateos-IsraelAlonso| EricPerez-DanielRamos| 20190507 |    18:00 |    19:30 | Pista 7 |  7/6 |  6/4 |    -


############# INICIALIZACION

prt_info "Inicializacion..."

# Resetea un directorio temporal solo para este script, dentro de tmp/
mkdir -p tmp; DIR_TMP="tmp/tmp.${SCRIPT}.${PID}"; rm -rf "${DIR_TMP}"; mkdir "${DIR_TMP}"

# Debe existir el fichero de partidos de la jornadas
if [ ! -f partidos-jornada${ARG_JORNADA}.txt ]; then prt_error "ERROR: no existe el fichero [partidos-jornada${ARG_JORNADA}.txt] en el directorio actual"; exit 1; fi

# Limpia los diferentes ficheros
out=$( limpiaTabla pistas.txt                         "${DIR_TMP}/pistas"        false )
out=$( limpiaTabla restricciones.txt                  "${DIR_TMP}/restricciones" false )
out=$( limpiaTabla partidos-jornada${ARG_JORNADA}.txt "${DIR_TMP}/partidos"      false )



############# EJECUCION

prt_info "Ejecucion..."

# 1/9 - Se comprueba que hay suficientes huecos para poder colocar todos los partidos
prt_info "-- 1/9 - Se comprueba que hay suficientes huecos para poder colocar todos los partidos"
gawk -F"|" '{if ($2>=FINI && $2<=FFIN) print}' FINI="${ARG_FECHA_INI}" FFIN="${ARG_FECHA_FIN}" "${DIR_TMP}/pistas" | sed 's/|/-/g' > "${DIR_TMP}/huecos"
nHuecos=$(   wc -l "${DIR_TMP}/huecos"   | gawk '{print $1}' )
nPartidos=$( wc -l "${DIR_TMP}/partidos" | gawk '{print $1}' )
if [ "${nPartidos}" -gt "${nHuecos}" ]; then prt_error "---- Hay mas partidos [${nPartidos}] que huecos disponibles [${nHuecos}]"; exit 1; fi

# 2/9 - Se une partido=Pareja1+Pareja2 con todos los huecos posibles
prt_info "-- 2/9 - Se une partido=Pareja1+Pareja2 con todos los huecos posibles"
gawk -F"|" '{print $2"-"$3}' "${DIR_TMP}/partidos" |
    while read -r linea
    do
        gawk '{print "-"L"-"$0}' L="${linea}" "${DIR_TMP}/huecos"
    done > "${DIR_TMP}/combinaciones_todas"

# 3/9 - Se elimina de la lista anterior, los partidos que no se pueden jugar por tener alguna restriccion
prt_info "-- 3/9 - Se elimina de la lista anterior, los partidos que no se pueden jugar por tener alguna restriccion"
while IFS="|" read -r NOMBRE APELLIDO FECHA
do
    sed -i "/-${NOMBRE}${APELLIDO}-.*-${FECHA}-/d"  "${DIR_TMP}/combinaciones_todas"
done < "${DIR_TMP}/restricciones"

# 4/9 - Se ordenan los partidos por numero de veces que si se pueden jugar
prt_info "-- 4/9 - Se ordenan los partidos por numero de veces que si se pueden jugar"
gawk -F"-" '{print $2"-"$3 " vs " $4"-"$5}' "${DIR_TMP}/combinaciones_todas" | sort | uniq -c > "${DIR_TMP}/combinaciones_ordenadas"

# 5/9 - Se comprueba que todas las parejas tienen algun hueco
prt_info "-- 5/9 - Se comprueba que todas las parejas tienen algun hueco"
while IFS="|" read -r _ LOCAL VISITANTE _ _ _ _ _ _ _
do
    out=$( grep -e " ${LOCAL} vs ${VISITANTE}" "${DIR_TMP}/combinaciones_ordenadas" )
    if [ "${out}" == "" ]; then prt_error "---- El partido [${LOCAL} vs ${VISITANTE}] no se puede jugar, no esta en las opciones disponibles ordenadas"; exit 1; fi
done < "${DIR_TMP}/partidos"

# 6/9 - Se calculan todas las permutaciones posibles
# line 1 --> line 1 --> line 2 --> line 2 --> line 3 --> line 3
# line 2 --> line 3 --> line 1 --> line 3 --> line 1 --> line 2
# line 3 --> line 2 --> line 3 --> line 1 --> line 2 --> line 1
prt_info "-- 6/9 - Se calculan todas las permutaciones posibles"
getPermutacion "${DIR_TMP}/combinaciones_ordenadas" 1 # genera los ficheros DIR_TMP/combinaciones_ordenadas.permX donde X=numero de la permutacion
nLineas=$( wc -l "${DIR_TMP}/combinaciones_ordenadas" | gawk '{print $1}' )
nPermutaciones=$( factorial ${nLineas} )
prt_info "---- Hay ${nPermutaciones} posibles a probar"

# 7/9 - Se ordenan las permutaciones para probar primero los partidos que tienen menos opciones
prt_info "-- 7/9 - Se ordenan las permutaciones para probar primero los partidos que tienen menos opciones"
contador=1
for i in $( seq 1 "${nLineas}" )
do
    # Se cogen las "i" primeras lineas de todos los ficheros disponibles
    files=$( find "${DIR_TMP}/" -type f -name "combinaciones_ordenadas.perm*" )
    for f in ${files}; do head -"${i}" ${f} > ${f}.processing; done

    # Se suman los pesos y se ordenan
    files=$( find "${DIR_TMP}/" -type f -name "combinaciones_ordenadas.*.processing" )
    out=$(
        for f in ${files}; do gawk '{sum+=$1}END{printf("%d|",sum)}' "${f}"; echo "${f}"; done |  # se calcula <peso total>|<nombre_fichero>
            sort |    # se ordenan por peso
            head -2 | # nos quedamos con las 2 primeras
            tac |     # imprimimos primero la 2da y despues la 1ra
            gawk -F"|" '{if (NR==1) ant=$1; if (NR==2 && $1<ant) print $2;}' | # solo nos quedamos con la permutacion (la primera) si el peso de la primera es < la segunda (no <=)
            sed 's/.processing//g'
       )
    if [ "${out}" != "" ]; then mv "${out}" "${DIR_TMP}/combinaciones_ordenadas.done.perm${contador}"; contador=$(( contador + 1 )); fi
    rm "${DIR_TMP}/combinaciones_ordenadas."*".processing"
done
# -- cuando ya son todas iguales, se dejan tal y como estan
files=$( find "${DIR_TMP}/" -type f -name "combinaciones_ordenadas.perm*" )
for f in ${files}; do mv "${f}" "${DIR_TMP}/combinaciones_ordenadas.done.perm${contador}"; contador=$(( contador + 1 )); done

# 8/9 - Se prueban cada una de las permutaciones
prt_info "-- 8/9 - Se prueban cada una de las permutaciones"
for f in "${DIR_TMP}/combinaciones_ordenadas.done.perm"*
do
    
    prt_info "*** Probando iteracion ${f} (de ${nPermutaciones} posibles)"

    # Inicializacion = reset
    rm -f "${DIR_TMP}/calendario-jornada${ARG_JORNADA}.txt"; touch "${DIR_TMP}/calendario-jornada${ARG_JORNADA}.txt"
    cp "${DIR_TMP}/combinaciones_todas" "${DIR_TMP}/comb_todas"
    cp "${f}"                           "${DIR_TMP}/comb_ordenadas"

    # Se ejecuta hasta conseguir encajar todos los partidos
    vuelveAEmpezar=false
    primerPartido=true
    while [ "$( cat "${DIR_TMP}/comb_ordenadas" )" != "" ] && [ "${vuelveAEmpezar}" == "false" ]
    do

        # Se coge el primer registro
        pLocal=$(     head -1 "${DIR_TMP}/comb_ordenadas" | gawk '{print $2}' )
        pVisitante=$( head -1 "${DIR_TMP}/comb_ordenadas" | gawk '{print $4}' )
        prt_debug "${ARG_VERBOSO}" "-- Se intenta colocar el partido [${pLocal} vs ${pVisitante}]"

        # Se comprueba que esa pareja tiene huecos libres
        if [ "$( grep -e "-${pLocal}-${pVisitante}" "${DIR_TMP}/comb_todas" )" == "" ]
        then
            prt_debug "${ARG_VERBOSO}" "---- El partido [${pLocal} vs ${pVisitante}] no puede ir en ninguna de las posiciones posibles. Asi que se tira la iteracion"
            if [ "${primerPartido}" == "true" ]
            then
                prt_error "---- El partido [${pLocal} vs ${pVisitante}] no puede ir en ninguna de las posiciones posibles. No va a ser posible encajarlo. Fin"
                exit 1
            fi
            vuelveAEmpezar=true
            continue
        fi

        # Se coge el primer hueco en el que puede ir
        hueco=$( grep -e "-${pLocal}-${pVisitante}" "${DIR_TMP}/comb_todas" | head -1 | cut -d"-" -f 6- )
        prt_debug "${ARG_VERBOSO}" "---- en el hueco [${hueco}]"

        # Se comprueba si ese hueco esta disponible
        if [ "$( grep -e "${hueco}" "${DIR_TMP}/calendario-jornada${ARG_JORNADA}.txt" )" != "" ]
        then
            prt_debug "${ARG_VERBOSO}" "---- El partido [${pLocal} vs ${pVisitante}] no puede ir en el hueco [${hueco}] porque esta ocupado. Pasa a probar otro hueco"
            sed -i "/-${pLocal}-${pVisitante}-${hueco}/d" "${DIR_TMP}/comb_todas"  # Elimina ese hueco de los posibles para ese partido
            continue                                                               # Vuelve a probar
        fi

        # Si esta disponible
        prt_debug "${ARG_VERBOSO}" "---- El partido [${pLocal} vs ${pVisitante}] SI se puede jugar en [${hueco}]. Se registra"
        primerPartido=false  # el primer partido ya ha sido colocado
        grep -e "-${pLocal}-${pVisitante}-${hueco}" "${DIR_TMP}/comb_todas" >> "${DIR_TMP}/calendario-jornada${ARG_JORNADA}.txt"  # Se anade ese partido en ese huecos al calendario
        sed -i "/-${pLocal}-${pVisitante}-/d" "${DIR_TMP}/comb_todas"  # Dada la pareja, se eliminan todos los huecos de esa pareja
        sed -i "/-${hueco}/d" "${DIR_TMP}/comb_todas"                  # Dado el hueco, se eliminan todas las parejas que tenian posibilidad de jugar en ese hueco

        # Se recalculan las combinaciones ordenadas
        gawk -F"-" '{print $2"-"$3 " vs " $4"-"$5}' "${DIR_TMP}/comb_todas" | sort | uniq -c > "${DIR_TMP}/comb_ordenadas"
        
    done

    # Se comprueba si esa permutacion es valida y estan todos los partidos colocados
    if  [ "$( cat "${DIR_TMP}/comb_ordenadas" )" == "" ] && [ "${vuelveAEmpezar}" == "false" ]
    then
        prt_info "-- Esta iteracion es buena y se han podido colocar todos los partidos. Se termina"
        break
    fi
    
done

# 9/9 - Se actualiza el fichero de partidos de la jornada
prt_info "-- 9/9 - Se actualiza el fichero de partidos de la jornada: partidos-jornada${ARG_JORNADA}.txt"
while IFS="-" read -r _ L1 L2 V1 V2 L F HI HF
do
    gawk 'BEGIN{FS=OFS="|";}{j=$1; l=$2; v=$3; gsub(" ","",j); gsub(" ","",l); gsub(" ","",v); if (j==JO && l==LO && v==VI) {$4=FE; $5=HI; $6=HF; $7=LU}; print;}' \
         JO="${ARG_JORNADA}" LO="${L1}-${L2}" VI="${V1}-${V2}" FE="${F}" HI="${HI}" HF="${HF}" LU="${L}" "partidos-jornada${ARG_JORNADA}.txt" > "partidos-jornada${ARG_JORNADA}.txt.tmp"
    mv "partidos-jornada${ARG_JORNADA}.txt.tmp" "partidos-jornada${ARG_JORNADA}.txt"
done < "${DIR_TMP}/calendario-jornada${ARG_JORNADA}.txt"
out=$( bash Script/formateaTabla.sh -f "partidos-jornada${ARG_JORNADA}.txt" ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi



############# FIN
exit 0

