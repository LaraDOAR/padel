#!/bin/bash

#================================================================================
#
# Script averigua cuando se juegan los partidos de partidos.txt, que aun no tienen fecha y que son del mes dado
#  - Genera el fichero calendario.txt con la fecha de los partidos que hay pendiente por jugar
#  - Genera el fichero calendario.html para poder visualizar la tabla anterior
#
# Entrada
#  -m [n]        --> Numero del mes (1,2,3...)
#  -i [YYYYMMDD] --> Fecha de inicio del mes
#  -f [YYYYMMDD] --> Fecha fin del mes (fecha en la que se dan por jugados todos los partidos)
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
if [ ! -f partidos.txt ];      then prt_error "ERROR: no existe el fichero [partidos.txt] en el directorio actual";      exit 1; fi
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

 Script averigua cuando se juegan los partidos de partidos.txt, que aun no tienen fecha y que son del mes dado
  - Genera el fichero calendario.txt con la fecha de los partidos que hay pendiente por jugar
  - Genera el fichero calendario.html para poder visualizar la tabla anterior

 Entrada
  -m [n]        --> Numero del mes (1,2,3...)
  -i [YYYYMMDD] --> Fecha de inicio del mes
  -f [YYYYMMDD] --> Fecha fin del mes (fecha en la que se dan por jugados todos los partidos)
  -v            --> Verboso (para ver las iteraciones del algoritmo)

 Salida:
  0 --> ejecucion correcta
  1 --> ejecucion con errores
"

ARG_MES=""         # parametro obligatorio
ARG_FECHA_INI=""   # parametro obligatorio
ARG_FECHA_FIN=""   # parametro obligatorio
ARG_VERBOSO=false  # por defecto, no es verboso

# Procesamos los argumentos de entrada
while getopts m:i:f:vh opt
do
    case "${opt}" in
        m) ARG_MES=$OPTARG;;
        i) ARG_FECHA_INI=$OPTARG;;
        f) ARG_FECHA_FIN=$OPTARG;;
        v) ARG_VERBOSO=true;;
        h) echo -e "${AYUDA}"; exit 0;;
        *) prt_error "Parametro [${opt}] invalido"; echo -e "${AYUDA}"; exit 1;;
    esac
done

if [ "${ARG_MES}" == "" ];         then prt_error "ERROR: ARG_MES vacio, necesario el parametro -m";                     exit 1; fi
if [ "${ARG_FECHA_INI}" == "" ];   then prt_error "ERROR: ARG_FECHA_INI vacio, necesario el parametro -i";               exit 1; fi
if [ "${ARG_FECHA_FIN}" == "" ];   then prt_error "ERROR: ARG_FECHA_FIN vacio, necesario el parametro -f";               exit 1; fi
if ! [[ ${ARG_MES} =~ ^[0-9]+$ ]]; then prt_error "ERROR: ARG_MES=${ARG_MES}, no es un numero entero valido (param -m)"; exit 1; fi
date +"%Y%m%d" -d "${ARG_FECHA_INI} +5 days" > /dev/null 2>&1; rv=$?; if [ "${rv}" != "0" ]; then prt_error "ERROR: ARG_FECHA_INI=${ARG_FECHA_INI} no es una fecha valida (param -i)"; exit 1; fi
date +"%Y%m%d" -d "${ARG_FECHA_FIN} +5 days" > /dev/null 2>&1; rv=$?; if [ "${rv}" != "0" ]; then prt_error "ERROR: ARG_FECHA_INI=${ARG_FECHA_INI} no es una fecha valida (param -f)"; exit 1; fi




###############################################
###
### Funciones
###
###############################################

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
###                                         1 |        1 | AlbertoMateos-IsraelAlonso| EricPerez-DanielRamos| 20190507 |    18:00 |    19:30 | Pista 7 |  7/5 |  6/5 |    -


############# INICIALIZACION

prt_info "Inicializacion..."

# Resetea un directorio temporal solo para este script, dentro de tmp/
mkdir -p tmp; DIR_TMP="tmp/tmp.${SCRIPT}.${PID}"; rm -rf "${DIR_TMP}"; mkdir "${DIR_TMP}"

# Limpia los diferentes ficheros
out=$( FGRL_limpiaTabla pistas.txt        "${DIR_TMP}/pistas"        false )
out=$( FGRL_limpiaTabla restricciones.txt "${DIR_TMP}/restricciones" false )
out=$( FGRL_limpiaTabla partidos.txt      "${DIR_TMP}/partidos"      false )

# Se hace backup de los ficheros de salida, para no sobreescribir
FGRL_backupFile calendario txt
FGRL_backupFile calendario html



############# EJECUCION

prt_info "Ejecucion..."

# 1/5 - Se hace por semanas para evitar que una pareja juegue mas de 1 partido la misma semana
prt_info "-- 1/5 - Se hace por semanas para evitar que una pareja juegue mas de 1 partido la misma semana"
dIni=$( date -d "${ARG_FECHA_INI}" +%s )
dFin=$( date -d "${ARG_FECHA_FIN}" +%s )
nSemanas=$( echo "" | gawk '{printf("%d",((FIN-INI)/(86400*7))+0.5)}' INI="${dIni}" FIN="${dFin}" )
prt_info "---- Hay ${nSemanas}"


# 2/5 - Se coloca un partido en cada semana, que sera la configuracion por defecto
prt_info "-- 2/5 - Se coloca un partido en cada semana, que sera la configuracion por defecto"
gawk -F"|" '{if ($1==MES && $5=="-") print}' MES="${ARG_MES}" "${DIR_TMP}/partidos" | # solo partidos que no tienen fecha asignada todavia y que son del mes dado
while read line
do
    pLocal=$(     echo -e "${line}" | gawk -F"|" '{print $3}' )
    pVisitante=$( echo -e "${line}" | gawk -F"|" '{print $4}' )
    
    fDest=-1
    for semana in $( seq 1 "${nSemanas}" )
    do
        touch "${DIR_TMP}/partidos.semana${semana}"
        if [ "$( grep "|${pLocal}|" "${DIR_TMP}/partidos.semana${semana}" )" == "" ] && [ "$( grep "|${pVisitante}|" "${DIR_TMP}/partidos.semana${semana}" )" == "" ]; then fDest=${semana}; break; fi
    done
    if [ "${fDest}" == "-1" ]; then fDest=$( wc -l "${DIR_TMP}/partidos.semana"* | sort -g | head -1 | gawk -F".semana" '{print $NF}' ); fi
    echo -e "${line}" >> "${DIR_TMP}/partidos.semana${fDest}"
done
mv "${DIR_TMP}/partidos" "${DIR_TMP}/partidos.orig"
prt_info "---- Generados los ficheros origen"


# 3/5 - Se repetira el proceso de ir desplazando partidos de una semana a otra hasta que todos los partidos encajen
prt_info "-- 3/5 - Se repetira el proceso de ir desplazando partidos de una semana a otra hasta que todos los partidos encajen"
semana=0; FINALIZADO=false
while [ "${FINALIZADO}" == "false" ]
do
       
    prt_info "---------------------------------------------------------------------------------------------"
    
    # 1/10 - Se calculan las fechas limite de la semana
    prt_info "---- 1/10 - Se calculan las fechas limite de la semana"
    if [ "${semana}" == "0" ]; then semana=1; else semana=${semanaSig}; fi
    n=$(( (semana - 1) * 7 )); FECHA_INI=$( date +"%Y%m%d" -d "${ARG_FECHA_INI} +${n} days" )
    n=$(( n + 5 ));            FECHA_FIN=$( date +"%Y%m%d" -d "${ARG_FECHA_INI} +${n} days" )
    prt_info "------ SEMANA ${semana}/${nSemanas} = ${FECHA_INI} - ${FECHA_FIN}"
    semanaSig=$(( (semana % nSemanas) + 1 ))

    # 2/10 - Se comprueba que hay suficientes huecos para poder colocar todos los partidos
    cp "${DIR_TMP}/partidos.semana${semana}" "${DIR_TMP}/partidos"
    prt_info "---- 2/10 - Se comprueba que hay suficientes huecos para poder colocar todos los partidos"
    gawk -F"|" '{if ($2>=FINI && $2<=FFIN) print}' FINI="${FECHA_INI}" FFIN="${FECHA_FIN}" "${DIR_TMP}/pistas" | sed 's/|/-/g' > "${DIR_TMP}/huecos"
    nHuecos=$(   wc -l "${DIR_TMP}/huecos"   | gawk '{print $1}' )
    nPartidos=$( wc -l "${DIR_TMP}/partidos" | gawk '{print $1}' )
    if [ "${nPartidos}" -gt "${nHuecos}" ]
    then
        prt_error "------ Hay mas partidos [${nPartidos}] que huecos disponibles [${nHuecos}]"
        nMover=$(( nHuecos - nPartidos ))
        prt_warn "------ Se mueven ${nMover} partidos de la semana ${semana} a la siguiente, la semana ${semanaSig}"
        tail -n+${nMover} "${DIR_TMP}/partidos.semana${semana}" >> "${DIR_TMP}/partidos.semana${semanaSig}" # se mueven a la siguiente
        head -${nHuecos}  "${DIR_TMP}/partidos.semana${semana}" >  "${DIR_TMP}/partidos"; mv "${DIR_TMP}/partidos" "${DIR_TMP}/partidos.semana${semana}" # se quitan de la actual
        semana=0 # para que vuelva a empezar
        continue
    fi

    # 3/10 - Se une partido=Pareja1+Pareja2 con todos los huecos posibles
    prt_info "---- 3/10 - Se une partido=Pareja1+Pareja2 con todos los huecos posibles"
    while read -r linea
    do
        gawk '{print "-"L"-"$0}' L="${linea}" "${DIR_TMP}/huecos"
    done < <( gawk -F"|" '{print $3"-"$4}' "${DIR_TMP}/partidos" ) > "${DIR_TMP}/combinaciones_todas"

    # 4/10 - Se elimina de la lista anterior, los partidos que no se pueden jugar por tener alguna restriccion
    prt_info "---- 4/10 - Se elimina de la lista anterior, los partidos que no se pueden jugar por tener alguna restriccion"
    while IFS="|" read -r NOMBRE APELLIDO FECHA
    do
        sed -i "/-${NOMBRE}${APELLIDO}-.*-${FECHA}-/d" "${DIR_TMP}/combinaciones_todas"
    done < "${DIR_TMP}/restricciones"

    # 5/10 - Se ordenan los partidos por numero de veces que si se pueden jugar
    prt_info "---- 5/10 - Se ordenan los partidos por numero de veces que si se pueden jugar"
    gawk -F"-" '{print $2"-"$3 " vs " $4"-"$5}' "${DIR_TMP}/combinaciones_todas" | sort | uniq -c > "${DIR_TMP}/combinaciones_ordenadas"

    # 6/10 - Se comprueba que todas las parejas tienen algun hueco
    prt_info "---- 6/10 - Se comprueba que todas las parejas tienen algun hueco"
    while IFS="|" read -r _ _ LOCAL VISITANTE _ _ _ _ _ _ _
    do
        out=$( grep -e " ${LOCAL} vs ${VISITANTE}" "${DIR_TMP}/combinaciones_ordenadas" )
        if [ "${out}" == "" ]
        then
            prt_error "------ El partido [${LOCAL} vs ${VISITANTE}] no se puede jugar, no esta en las opciones disponibles ordenadas"
            prt_warn "------ Se mueve ese partido de la semana ${semana} a la siguiente, la semana ${semanaSig}"
            grep -e "-${LOCAL}-${VISITANTE}-" "${DIR_TMP}/partidos" >> "${DIR_TMP}/partidos.semana${semanaSig}" # se mueve a la siguiente
            sed -i "/-${LOCAL}-${VISITANTE}-/d" "${DIR_TMP}/partidos.semana${semana}" # se quita de la semana actual
            semana=0 # para que vuelva a empezar
            continue
        fi
    done < "${DIR_TMP}/partidos"

    # 7/10 - Se calculan todas las permutaciones posibles
    # line 1 --> line 1 --> line 2 --> line 2 --> line 3 --> line 3
    # line 2 --> line 3 --> line 1 --> line 3 --> line 1 --> line 2
    # line 3 --> line 2 --> line 3 --> line 1 --> line 2 --> line 1
    prt_info "---- 7/10 - Se calculan todas las permutaciones posibles"
    nLineas=$( wc -l "${DIR_TMP}/combinaciones_ordenadas" | gawk '{print $1}' )
    nPermutaciones=$( factorial ${nLineas} )
    prt_info "------ Hay ${nLineas}! = ${nPermutaciones} posibles a probar"
    FGRL_getPermutacion "${DIR_TMP}/combinaciones_ordenadas" 1 # genera los ficheros DIR_TMP/combinaciones_ordenadas.permX donde X=numero de la permutacion
    prt_info "------ Calculadas todas las permutaciones"


    # 8/10 - Se ordenan las permutaciones para probar primero los partidos que tienen menos opciones
    prt_info "---- 8/10 - Se ordenan las permutaciones para probar primero los partidos que tienen menos opciones"
    # -- se calculan peso minimo y peso maximo para frenarla busqueda
    pesoMin=$( gawk '{print $1}' "${DIR_TMP}/combinaciones_ordenadas" | sort -g | head -1 )
    pesoMax=$( gawk '{print $1}' "${DIR_TMP}/combinaciones_ordenadas" | sort -g | tail -1 )
    if [ "${pesoMin}" == "${pesoMax}" ]
    then
        prt_debug "${ARG_VERBOSO}" "---- No se inicia la ordenacion porque no hay diferencias de peso pesoMin=${pesoMin} == pesoMax=${pesoMax}"
    else
        contador=1
        for i in $( seq 1 "${nLineas}" )
        do
            # Se calculan peso minimo y peso maximo para frenarla busqueda
            out=$( find "${DIR_TMP}/" -type f -name "combinaciones_ordenadas.perm*" | xargs tail -n+"${i}" -q | gawk 'BEGIN{max=0; min=99999;}{if ($1<min) {min=$1;} if ($1>max) {max=$1;}}END{print "min="min; print "max="max;}' )
            pesoMin=$( echo -e "${out}" | gawk -F"min=" '{print $2}' )
            pesoMax=$( echo -e "${out}" | gawk -F"max=" '{print $2}' )
            if [ "${pesoMin}" == "${pesoMax}" ]; then prt_debug "${ARG_VERBOSO}" "---- Se para la ordenacion porque no hay diferencias de peso pesoMin=${pesoMin} == pesoMax=${pesoMax}"; break; fi
            
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
            find "${DIR_TMP}"/ -type f -name "combinaciones_ordenadas.*.processing" -print0 | xargs -0 --no-run-if-empty rm
        done
    fi
    # -- cuando ya son todas iguales, se dejan tal y como estan
    files=$( find "${DIR_TMP}/" -type f -name "combinaciones_ordenadas.perm*" )
    for f in ${files}; do mv "${f}" "${DIR_TMP}/combinaciones_ordenadas.done.perm${contador}"; contador=$(( contador + 1 )); done

    # 9/10 - Se prueban cada una de las permutaciones
    prt_info "---- 9/10 - Se prueban cada una de las permutaciones"
    for f in "${DIR_TMP}/combinaciones_ordenadas.done.perm"*
    do
        
        prt_info "***** Probando iteracion ${f} (de ${nPermutaciones} posibles)"

        # Inicializacion = reset
        rm -f "${DIR_TMP}/calendario.semana${semana}.txt"; touch "${DIR_TMP}/calendario.semana${semana}.txt"
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
            prt_debug "${ARG_VERBOSO}" "---- Se intenta colocar el partido [${pLocal} vs ${pVisitante}]"

            # Se comprueba que esa pareja tiene huecos libres
            if [ "$( grep -e "-${pLocal}-${pVisitante}" "${DIR_TMP}/comb_todas" )" == "" ]
            then
                prt_debug "${ARG_VERBOSO}" "------ El partido [${pLocal} vs ${pVisitante}] no puede ir en ninguna de las posiciones posibles. Asi que se tira la iteracion"
                if [ "${primerPartido}" == "true" ]
                then
                    prt_error "------ El partido [${pLocal} vs ${pVisitante}] no puede ir en ninguna de las posiciones posibles. No va a ser posible encajarlo. Fin"
                    exit 1
                fi
                vuelveAEmpezar=true
                continue
            fi

            # Se coge el primer hueco en el que puede ir
            hueco=$( grep -e "-${pLocal}-${pVisitante}" "${DIR_TMP}/comb_todas" | head -1 | cut -d"-" -f 6- )
            prt_debug "${ARG_VERBOSO}" "------ en el hueco [${hueco}]"

            # Se comprueba si ese hueco esta disponible
            if [ "$( grep -e "${hueco}" "${DIR_TMP}/calendario.semana${semana}.txt" )" != "" ]
            then
                prt_debug "${ARG_VERBOSO}" "------ El partido [${pLocal} vs ${pVisitante}] no puede ir en el hueco [${hueco}] porque esta ocupado. Pasa a probar otro hueco"
                sed -i "/-${pLocal}-${pVisitante}-${hueco}/d" "${DIR_TMP}/comb_todas"  # Elimina ese hueco de los posibles para ese partido
                continue                                                               # Vuelve a probar
            fi

            # Si esta disponible
            prt_debug "${ARG_VERBOSO}" "------ El partido [${pLocal} vs ${pVisitante}] SI se puede jugar en [${hueco}]. Se registra"
            primerPartido=false  # el primer partido ya ha sido colocado
            grep -e "-${pLocal}-${pVisitante}-${hueco}" "${DIR_TMP}/comb_todas" >> "${DIR_TMP}/calendario.semana${semana}.txt"  # Se anade ese partido en ese huecos al calendario
            sed -i "/-${pLocal}-${pVisitante}-/d" "${DIR_TMP}/comb_todas"  # Dada la pareja, se eliminan todos los huecos de esa pareja
            sed -i "/-${hueco}/d" "${DIR_TMP}/comb_todas"                  # Dado el hueco, se eliminan todas las parejas que tenian posibilidad de jugar en ese hueco

            # Se recalculan las combinaciones ordenadas
            gawk -F"-" '{print $2"-"$3 " vs " $4"-"$5}' "${DIR_TMP}/comb_todas" | sort | uniq -c > "${DIR_TMP}/comb_ordenadas"
            
        done

        # Se comprueba si esa permutacion es valida y estan todos los partidos colocados
        if  [ "$( cat "${DIR_TMP}/comb_ordenadas" )" == "" ] && [ "${vuelveAEmpezar}" == "false" ]
        then
            prt_info "---- Esta iteracion es buena y se han podido colocar todos los partidos. Se termina con la semana"
            prt_info "----- Generado el fichero ${DIR_TMP}/calendario.semana${semana}.txt"
            break
        fi
        
    done

    # Se eliminan ficheros temporales
    find "${DIR_TMP}"/ -type f -name "comb*" -print0 | xargs -0 --no-run-if-empty rm

    # 10/10 - Comprueba si debe terminar: ya hay un calendario para todas las semanas
    prt_info "---- 10/10 - Comprueba si debe terminar: ya hay un calendario para todas las semanas"
    FINALIZADO=true
    for s in $( seq 1 "${nSemanas}" )
    do
        # -- debe existir el fichero del calendario de la semana = se ha procesado al menos una vez
        if [ ! -f "${DIR_TMP}/calendario.semana${s}.txt" ]; then prt_debug "${ARG_VERBOSO}" "------ Aun no existe ${DIR_TMP}/calendario.semana${s}.txt"; FINALIZADO=false; break; fi

        # -- deben tener el mismo numero de lineas = todos los partidos estan en el calendario, y todos los del calendario estan en el partido
        nCalendario=$( wc -l "${DIR_TMP}/calendario.semana${s}.txt" | gawk '{print $1}' )
        nPartidos=$(   wc -l "${DIR_TMP}/partidos.semana${s}"                     | gawk '{print $1}' )
        if [ "${nCalendario}" != "${nPartidos}" ]; then prt_debug "${ARG_VERBOSO}" "------ No tienen el mismo numero de lineas ${DIR_TMP}/calendario.semana${s}.txt y ${DIR_TMP}/partidos.semana${s}"; FINALIZADO=false; break; fi

        # -- se comprueba la condicion anterior linea por linea
        while IFS='|' read -r _ _ LOCAL VISITANTE _ _ _ _ _ _ _
        do
            if [ "$( grep -e "-${LOCAL}-${VISITANTE}-" "${DIR_TMP}/calendario.semana${s}.txt" )" == "" ]
            then
                prt_debug "${ARG_VERBOSO}" "------ La pareja -${LOCAL}-${VISITANTE}- de ${DIR_TMP}/partidos.semana${s}, no esta en ${DIR_TMP}/calendario.semana${s}.txt"
                FINALIZADO=false; break
            fi
        done < "${DIR_TMP}/partidos.semana${s}"
    done
    prt_info "------ Termina porque ya esta el calendario de todos los partidos"

done
prt_info "---- Ya esta la configuracion definitiva"


# 4/5 - Se unen los partidos de todas las semanas
prt_info "-- 4/5 - Se unen los partidos de todas las semanas"
echo "MES|LOCAL|VISITANTE|PISTA|FECHA|HORA_INI|HORA_FIN" > "calendario.txt"
cat "${DIR_TMP}/calendario.semana"*".txt" | gawk -F"-" 'BEGIN{OFS="|"}{MES=sprintf("%03d",MES); print MES,$2"-"$3,$4"-"$5,$6,$7,$8,$9}' MES="${ARG_MES}" >> "calendario.txt"
out=$( bash Script/formateaTabla.sh -f "calendario.txt" ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi
prt_info "---- Generado ${G}calendario.txt${NC}"

# -- limpia la tabla
out=$( FGRL_limpiaTabla "calendario.txt" "${DIR_TMP}/calendario" false ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi


# 5/5 - Se genera el html
prt_info "-- 5/5 - Se genera el html del calendario"
cat <<EOM >calendario.html
<!DOCTYPE html>
<html>
  <head>
    <link href='https://use.fontawesome.com/releases/v5.0.6/css/all.css' rel='stylesheet'>
    <link href='Calendario/packages/core/main.css' rel='stylesheet' />
    <link href='Calendario/packages/bootstrap/main.css' rel='stylesheet' />
    <link href='Calendario/packages/timegrid/main.css' rel='stylesheet' />
    <link href='Calendario/packages/daygrid/main.css' rel='stylesheet' />
    <link href='Calendario/packages/list/main.css' rel='stylesheet' />
    <link href='Calendario/packages/bootstrap/main.css' rel='stylesheet' />
    <script src='Calendario/packages/core/main.js'></script>
    <script src='Calendario/packages/interaction/main.js'></script>
    <script src='Calendario/packages/bootstrap/main.js'></script>
    <script src='Calendario/packages/daygrid/main.js'></script>
    <script src='Calendario/packages/timegrid/main.js'></script>
    <script src='Calendario/packages/list/main.js'></script>
    <script src='Calendario/packages/bootstrap/main.js'></script>
    <script src='Calendario/packages/resource-common/main.js'></script>
    <script src='Calendario/packages/resource-daygrid/main.js'></script>
    <script src='Calendario/packages/resource-timegrid/main.js'></script>
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
          editable: true,
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

# CON TOOLTIP
# cat <<EOM >>calendario.html
#           ],
#           eventRender: function(info) {
#             var tooltip = new Tooltip(info.el, {
#               title: info.event.extendedProps.description,
#               placement: 'top',
#               trigger: 'hover',
#               container: 'body'
#             });
#           },
#           events: [
# EOM

# SIN TOOLTIP
cat <<EOM >>calendario.html
          ],
          events: [
EOM

gawk -F"|" '
{
    print "            {";
    print "              id: " NR",";
    print "              title: \x27"$2" vs "$3"\x27,";
    print "              description: \x27Mes "$1":"$2" vs "$3"\x27,";
    print "              start: \x27" substr($5,1,4)"-"substr($5,5,2)"-"substr($5,7,2)"T"$6":00\x27,";
    print "              end:   \x27" substr($5,1,4)"-"substr($5,5,2)"-"substr($5,7,2)"T"$7":00\x27,";
    print "              resourceId: \x27" $5 "\x27";
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
