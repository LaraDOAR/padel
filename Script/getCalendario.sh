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


##########
# - moverPartido
#     Funcion   --->  Se elige un partido aleatorio y se pone en la semana siguiente. Se evita que una pareja juegue la misma semana.
#                     Para no acumular partidos en una semana, si una semana se llena, se moverá a otra que tenga menos,
#                     de manera rotativa hasta que todos esten mas o menos igualados.             
#     Entrada   --->  $1 = semana actual
#                     $2 = (opcional) "check" si no se quiere mover, solo comprobar
#     Salida    --->  0 = ok
#                     1 = error
#                Modifica los ficheros partidos.semana*
#
function moverPartido {

    # Argumentos
    local _s=$1
    local _check=$2

    # Variables internas
    local _nLineas
    local _num
    local _sSig
    local _partido
    local _LOC
    local _VIS
    local _seMueve
    local _finalizado
    local _indS
    local _rv
    local _aux

    _nLineas=$( wc -l "${DIR_TMP}/partidos.semana${_s}" | gawk '{print $1}' )
    _sSig=$(( (_s % nSemanas) + 1 ))
    
    # Se elige un partido que este repetido
    _seMueve=false
    for _num in $( seq 1 "${_nLineas}" )
    do
        _LOC=$( head -"${_num}" "${DIR_TMP}/partidos.semana${_s}" | tail -1 | gawk -F"|" '{print $3}' )
        _VIS=$( head -"${_num}" "${DIR_TMP}/partidos.semana${_s}" | tail -1 | gawk -F"|" '{print $4}' )
        _aux=$(( _num + 1 ))
        if [ "$( tail -n+${_aux} "${DIR_TMP}/partidos.semana${_s}" | grep "${_LOC}" )" != "" ] || [ "$( tail -n+${_aux} "${DIR_TMP}/partidos.semana${_s}" | grep "${_VIS}" )" != "" ]
        then
            prt_info "------- <moverPartido ${_s}> El partido [${_LOC} vs ${_VIS}] se mueve de la semana ${_s} a ${_sSig}"
            #prt_info "----------- partidos pareja local:"
            #tail -n+${_aux} "${DIR_TMP}/partidos.semana${_s}" | grep "${_LOC}"
            #prt_info "----------- partidos pareja visitante:"
            #tail -n+${_aux} "${DIR_TMP}/partidos.semana${_s}" | grep "${_VIS}"
            _seMueve=true
            break
        fi
    done

    # Si solo es check y no hay ninguno repetido termina
    if [ "${_check}" == "check" ] && [ "${_seMueve}" == "false" ]; then return 0; fi
    
    # Si no se ha movido, se elige uno al azar
    if [ "${_seMueve}" == "false" ]
    then
        _num=$( shuf -i 1-${_nLineas} -n 1 )
        _partido=$( head -${_num} "${DIR_TMP}/partidos.semana${_s}" | tail -1 )
        _LOC=$( echo -e "${_partido}" | gawk -F"|" '{print $1}' )
        _VIS=$( echo -e "${_partido}" | gawk -F"|" '{print $2}' )
        prt_info "------- <moverPartido ${_s}> El partido [${_LOC} vs ${_VIS}] se mueve de la semana ${_s} a ${_sSig}, elegido aleatoriamente"
        _seMueve=true
    fi

    # Se mueve
    if [ "${_seMueve}" == "true" ]
    then
        grep -e "|${_LOC}|${_VIS}|"   "${DIR_TMP}/partidos.semana${_s}" >> "${DIR_TMP}/partidos.semana${_sSig}"  # se mueve a la semana siguiente
        sed -i "/|${_LOC}|${_VIS}|/d" "${DIR_TMP}/partidos.semana${_s}"                                          # se quita de la semana actual
    fi

    # Comprueba que el resto de semanas estan bien configuradas
    _finalizado=false
    while [ "${_finalizado}" == "false" ]
    do
        # -- condicion de parada
        _finalizado=true
        for _indS in $( seq 1 "${nSemanas}" )
        do
            moverPartido "${_indS}" "check"; _rv=$?
            if [ "${_rv}" != "0" ]; then _finalizado=false; break; fi
        done       
    done

    return 0
}






###############################################
###
### Captura de senal
###
###############################################

function killtree {

    # control de errores
    if [ "$#" != "2" ]
    then
        err_error 0 "ERROR: killtree necesita, 2 argumentos: [pid] [depth], ahora hay $#" > /dev/tty
        return
    fi

    # args: proceso a matar y profundidad del arbol
    local _pid=$1
    local _depth=$2

    # variables internas
    local _depthINT
    local _child

    # es necesario parar al padre, para que no siga generando nuevos hijos
    # no paro al proceso raiz, porque sino paro esta funcion (suicidio)
    if [ "${_depth}" != "0" ]
    then
        if ps -p "${_pid}" > /dev/null; then kill -stop "${_pid}"; fi
    fi

    # se matan los procesos hijos
    _depthINT=$(( _depth + 1 ))
    for _child in $( ps -o pid --no-headers --ppid "${_pid}" )
    do
        killtree "${_child}" "${_depthINT}"
    done

    # finalmente, se mata al padre (solo si no es el nodo raiz)
    if [ "${_depth}" != "0" ]
    then
        if ps -p "${_pid}" > /dev/null; then kill -9 "${_pid}"; fi
    fi
}

function interrumpir {
    exit 1
}
trap "interrumpir;" INT

function salir {
    _rv=$?

    if [ "${_rv}" == "0" ]; then prt_info  "**** Ejecucion correcta"
    else                         prt_error "**** Ejecucion fallida"
    fi

    killtree "$PID" "0"
    
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
if [ -f calendario.txt ]; then out=$( FGRL_limpiaTabla calendario.txt "${DIR_TMP}/calendario" false ); fi

# Se hace backup de los ficheros de salida, para no sobreescribir
FGRL_backupFile calendario txt
FGRL_backupFile calendario html



############# EJECUCION

prt_info "Ejecucion..."

# 1/6 - Se hace por semanas para evitar que una pareja juegue mas de 1 partido la misma semana
prt_info "-- 1/6 - Se hace por semanas para evitar que una pareja juegue mas de 1 partido la misma semana"
dIni=$( date -d "${ARG_FECHA_INI}" +%s )
dFin=$( date -d "${ARG_FECHA_FIN}" +%s )
nSemanas=$( echo "" | gawk '{printf("%d",((FIN-INI)/(86400*7))+0.5)}' INI="${dIni}" FIN="${dFin}" )
prt_info "---- Hay ${nSemanas} semanas"
for semana in $( seq 1 "${nSemanas}" )
do
    touch "${DIR_TMP}/partidos.semana${semana}"
done


# 2/6 - Comprueba que todos los partidos se pueden jugar al menos un dia
prt_info "-- 2/6 - Comprueba que todos los partidos se pueden jugar al menos un dia"
# -- se generan los huecos disponibles, poniendo al principio la pista 7
#sed 's/|/-/g' "${DIR_TMP}/pistas" | sort -t"-" -k1,1r -k3,3 -k2,2  > "${DIR_TMP}/huecos" #-----------------------------------------PRIORIZANDO POR PISTA, DESPUES HORA, Y DESPUES DIA
sed 's/|/-/g' "${DIR_TMP}/pistas"  > "${DIR_TMP}/huecos"
nHuecos=$(   wc -l "${DIR_TMP}/huecos"   | gawk '{print $1}' )
nPartidos=$( wc -l "${DIR_TMP}/partidos" | gawk '{print $1}' )
if [ "${nPartidos}" -gt "${nHuecos}" ]; then prt_error "------ Hay mas partidos [${nPartidos}] que huecos disponibles [${nHuecos}]"; exit 1; fi
# -- se une partido=Pareja1+Pareja2 con todos los huecos posibles
while read -r linea; do gawk '{print "-"L"-"$0}' L="${linea}" "${DIR_TMP}/huecos"; done < <( gawk -F"|" '{print $3"-"$4}' "${DIR_TMP}/partidos" ) > "${DIR_TMP}/combinaciones_todas"
# -- se elimina de la lista anterior, los partidos que no se pueden jugar por tener alguna restriccion
while IFS="|" read -r NOMBRE APELLIDO FECHA
do
    sed -i "/-${NOMBRE}${APELLIDO}-.*-${FECHA}-/d" "${DIR_TMP}/combinaciones_todas"
done < "${DIR_TMP}/restricciones"
# -- por cada partido busca si existe en las combinaciones posibles
IMPOSIBLE=false
while IFS="|" read -r _ _ LOCAL VISITANTE _ _ _ _ _ _ _ _
do
    if [ "$( grep -c -e "-${LOCAL}-${VISITANTE}-" "${DIR_TMP}/combinaciones_todas" )" == "0" ]
    then
        prt_error "--- Por problemas de restricciones el partido [${LOCAL} vs ${VISITANTE}] no se puede jugar"
        IMPOSIBLE=true
    fi
done < "${DIR_TMP}/partidos"
if [ "${IMPOSIBLE}" == "true" ]; then exit 1; fi


# 3/6 - Se coloca un partido en cada semana, que sera la configuracion por defecto
prt_info "-- 3/6 - Se coloca un partido en cada semana, que sera la configuracion por defecto"
gawk -F"|" '{if ($5=="-") print}' "${DIR_TMP}/partidos" | # solo partidos que no tienen fecha asignada todavia (da igual que sean de meses viejos, si es que aun estan pendientes)
    while read line
    do
        pLocal=$(     echo -e "${line}" | gawk -F"|" '{print $3}' )
        pVisitante=$( echo -e "${line}" | gawk -F"|" '{print $4}' )
        
        fDest=-1
        for semana in $( seq 1 "${nSemanas}" )
        do
            if [ "$( grep "|${pLocal}|" "${DIR_TMP}/partidos.semana${semana}" )" == "" ] && [ "$( grep "|${pVisitante}|" "${DIR_TMP}/partidos.semana${semana}" )" == "" ]; then fDest=${semana}; break; fi
        done
        if [ "${fDest}" == "-1" ]; then fDest=$( wc -l "${DIR_TMP}/partidos.semana"* | sort -g | head -1 | gawk -F".semana" '{print $NF}' ); fi
        echo -e "${line}" >> "${DIR_TMP}/partidos.semana${fDest}"
    done
mv "${DIR_TMP}/partidos" "${DIR_TMP}/partidos.orig"
prt_info "---- Generados los ficheros origen"

# -- Se comprueba que ninguna pareja repite la misma semana
moverPartido 1 "check"


# 4/6 - Se repetira el proceso de ir desplazando partidos de una semana a otra hasta que todos los partidos encajen
prt_info "-- 4/6 - Se repetira el proceso de ir desplazando partidos de una semana a otra hasta que todos los partidos encajen"
semana=0; FINALIZADO=false
while [ "${FINALIZADO}" == "false" ]
do
    
    prt_info "---------------------------------------------------------------------------------------------"
    VUELVE_A_EMPEZAR=false
    
    # 1/10 - Se calculan las fechas limite de la semana
    prt_info "---- 1/10 - Se calculan las fechas limite de la semana"
    if [ "${semana}" == "0" ]; then semana=1; else semana=$(( (semana % nSemanas) + 1 )); fi
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
        # -- vuelve a empezar con la semana actual
        VUELVE_A_EMPEZAR=true
    fi
    # -- comprueba si tiene que volver a empezar
    if [ "${VUELVE_A_EMPEZAR}" == "true" ]
    then
        prt_debug "${ARG_VERBOSO}" "------ Vuelve a empezar con la semana ${semana}"
        semana=$(( semana - 1 )) # para que vuelva a empezar con la semana actual
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
    gawk -F"-" '{print $2"-"$3 " vs " $4"-"$5}' "${DIR_TMP}/combinaciones_todas" | sort | uniq -c | sort -k1,1 -g > "${DIR_TMP}/combinaciones_ordenadas"

    # 6/10 - Se comprueba que todas las parejas tienen algun hueco
    prt_info "---- 6/10 - Se comprueba que todas las parejas tienen algun hueco"
    while IFS="|" read -r _ _ LOCAL VISITANTE _ _ _ _ _ _ _
    do
        out=$( grep -e " ${LOCAL} vs ${VISITANTE}" "${DIR_TMP}/combinaciones_ordenadas" )
        if [ "${out}" == "" ]
        then
            prt_error "------ El partido [${LOCAL} vs ${VISITANTE}] no se puede jugar, no esta en las opciones disponibles ordenadas"
            prt_warn "------ Se mueve ese partido de la semana ${semana} a la siguiente, la semana ${semanaSig}"
            grep -e "|${LOCAL}|${VISITANTE}|" "${DIR_TMP}/partidos" >> "${DIR_TMP}/partidos.semana${semanaSig}" # se mueve a la siguiente
            sed -i "/|${LOCAL}|${VISITANTE}|/d" "${DIR_TMP}/partidos.semana${semana}" # se quita de la semana actual
            # -- vuelve a empezar con la semana 1
            VUELVE_A_EMPEZAR=true; break
        fi
    done < "${DIR_TMP}/partidos"
    # -- comprueba si tiene que volver a empezar
    if [ "${VUELVE_A_EMPEZAR}" == "true" ]
    then
        prt_debug "${ARG_VERBOSO}" "------ Vuelve a empezar con la semana ${semana}"
        semana=$(( semana - 1 )) # para que vuelva a empezar con la semana actual
        continue
    fi

    # Antes de arrancar las permutaciones se asegura de que las anteriores ya han acabado
    if [ -f "${DIR_TMP}/PARA.PERMUTACIONES" ]
    then
        rm -f "${DIR_TMP}/PERMUTACIONES.REGISTRO"*
        rm -f "${DIR_TMP}/combinaciones_ordenadas."*
        rm -f "${DIR_TMP}/PARA.PERMUTACIONES"
    fi
    
    # 7/10 - Se calculan todas las permutaciones posibles
    # line 1 --> line 1 --> line 2 --> line 2 --> line 3 --> line 3
    # line 2 --> line 3 --> line 1 --> line 3 --> line 1 --> line 2
    # line 3 --> line 2 --> line 3 --> line 1 --> line 2 --> line 1
    prt_info "---- 7/10 - Se calculan todas las permutaciones posibles"
    nLineas=$( wc -l "${DIR_TMP}/combinaciones_ordenadas" | gawk '{print $1}' )
    nPermutaciones=$( factorial ${nLineas} )
    prt_info "------ Hay ${nLineas}! = ${nPermutaciones} posibles a probar"
    if [ "${nLineas}" == "0" ]
    then
        prt_warn "------ No hay partidos esta semana"
    else
        # genera los ficheros DIR_TMP/combinaciones_ordenadas.functionX donde X=numero de la permutacion
        FGRL_getPermutacion_conPesos "${DIR_TMP}/combinaciones_ordenadas" 1 "$( seq ${nLineas} -1 1 | xargs printf "%d " | sed -r "s/^ +//g; s/ +$//g;" )" "${nLineas}" "${nLineas}" &
        prt_info "------ Se ha iniciado el calculo de permutaciones"
        sleep 3s
    fi

    ######### EL PROCESO DE GENERACION DE PERMUTACIONES SE VA A EJECUTAR EN BACKGROUND
    ######### MIENTRAS TANTO, SE PUEDEN IR COGIENDO LAS ITERACIONES QUE HAYA, ORDENARLAS Y PROBAR

    while [ "$( tail -1 "${DIR_TMP}/PERMUTACIONES.REGISTRO" )" != "DONE" ] && [ ! -f "${DIR_TMP}/PARA.PERMUTACIONES" ]
    do
        sleep 1s # para dar tiempo a generar el fichero de registro

        # Se copia el registro
        cp "${DIR_TMP}/PERMUTACIONES.REGISTRO" "${DIR_TMP}/PERMUTACIONES.REGISTRO.tmp"
        
        # Se eliminan las que ya se han procesado (no existen)
        cp "${DIR_TMP}/PERMUTACIONES.REGISTRO" "${DIR_TMP}/PERMUTACIONES.REGISTRO.tmp"
        while read -r FILE
        do
            identificador=$( basename "${FILE}" | gawk -F"done.perm" '{print $2}' )
            file=$( find "${DIR_TMP}" -type f -name "combinaciones_ordenadas*.${identificador}" | grep "${identificador}$" )
            if [ ${file} != "" ]
            then
                sed -i "/.${identificador}$/d" "${DIR_TMP}/PERMUTACIONES.REGISTRO.tmp"
            fi
        done < <(find "${DIR_TMP}/" -type f -name "combinaciones_ordenadas.done.perm*")
        sed -i "/DONE/d" "${DIR_TMP}/PERMUTACIONES.REGISTRO.tmp" # por si acaso ya ha terminado
        
        # Espera hasta que ella alguna permutacion
        if [ "$( head -1 "${DIR_TMP}/PERMUTACIONES.REGISTRO.tmp" )" == "" ]; then continue; fi

        # Se cogen todas las permutaciones disponibles y se les cambia de nombre, para que el programa las coja
        while read -r FILE
        do
            newName=$( echo -e "${FILE}" | sed 's/combinaciones_ordenadas.function/combinaciones_ordenadas.perm/g' )
            mv "${FILE}" "${newName}"
        done < "${DIR_TMP}/PERMUTACIONES.REGISTRO.tmp"


        # 8/10 - Se ordenan las permutaciones para probar primero los partidos que tienen menos opciones
        prt_info "---- 8/10 - Se ordenan las permutaciones para probar primero los partidos que tienen menos opciones"
        # -- se calculan peso minimo y peso maximo para frenar la busqueda
        pesoMin=$( gawk '{print $1}' "${DIR_TMP}/combinaciones_ordenadas" | sort -g | head -1 )
        pesoMax=$( gawk '{print $1}' "${DIR_TMP}/combinaciones_ordenadas" | sort -g | tail -1 )
        if [ "${pesoMin}" == "${pesoMax}" ]
        then
            prt_debug "${ARG_VERBOSO}" "---- No se inicia la ordenacion porque no hay diferencias de peso pesoMin=${pesoMin} == pesoMax=${pesoMax}"
        else

            # -- se crea un fichero de ordenacion: FICHERO | PESOS FILA1 | SUMA PESOS FILA1 + FILA2 | SUMA PESOS FILA1 + FILA2 + FILA3...
            rm -f "${DIR_TMP}/combinaciones_ordenadas.TOTAL_PESOS"; touch "${DIR_TMP}/combinaciones_ordenadas.TOTAL_PESOS"

            # -- por cada fichero, escribe en TOTAL_PESOS, con todas las columnas que se han dicho
            while read -r FILE
            do
                {
                    printf "%s|" "$FILE"
                    gawk '{sum+=$1; printf("%s|",sum)}' "${FILE}"
                    echo ""
                } >> "${DIR_TMP}/combinaciones_ordenadas.TOTAL_PESOS"
            done < <(find "${DIR_TMP}/" -type f -name "combinaciones_ordenadas.perm*")

            # -- se ordenan los ficheros
            cmd=""; for indexCmd in $( seq 1 "${nLineas}" ); do aux=$(( indexCmd+1 )); cmd="${cmd} -k${aux},${aux} "; done
            sort -t"|" -g ${cmd} "${DIR_TMP}/combinaciones_ordenadas.TOTAL_PESOS" > "${DIR_TMP}/combinaciones_ordenadas.TOTAL_PESOS.tmp"
            mv "${DIR_TMP}/combinaciones_ordenadas.TOTAL_PESOS.tmp" "${DIR_TMP}/combinaciones_ordenadas.TOTAL_PESOS"

            # -- se cambia la numeracion de las permutaciones segun este orden
            contador=0
            while IFS="|" read -r FILE _
            do
                contador=$( echo "" | gawk '{printf("%015d",N+1)}' N="${contador}" )
                mv "${FILE}" "${DIR_TMP}/combinaciones_ordenadas.done.perm${contador}"
            done < "${DIR_TMP}/combinaciones_ordenadas.TOTAL_PESOS"
            rm "${DIR_TMP}/combinaciones_ordenadas.TOTAL_PESOS"
        fi


        # 9/10 - Se prueban cada una de las permutaciones
        prt_info "---- 9/10 - Se prueban cada una de las permutaciones"
        for f in "${DIR_TMP}/combinaciones_ordenadas.done.perm"*
        do
            
            prt_info "***** Probando iteracion ${f} (de ${nPermutaciones} posibles)"
            if [ "${ARG_VERBOSO}" == "true" ]; then cat "${f}"; fi

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
                dia=$( echo -e "${hueco}" | gawk -F"-" '{print $2}' )  # Pista3-20190603-18:00-19:00
                sed -i "/-${pLocal}-${pVisitante}-.*-${dia}/d" "${DIR_TMP}/comb_todas"  # La pareja, como ya juega ese dia, no puede jugar mas partidos ese dia, sea la pista o la hora que sea

                # Se recalculan las combinaciones ordenadas
                gawk -F"-" '{print $2"-"$3 " vs " $4"-"$5}' "${DIR_TMP}/comb_todas" | sort | uniq -c | sort -k1,1 -g > "${DIR_TMP}/comb_ordenadas"
                
            done

            # Se comprueba si se han colocado todos los partidos
            if  [ "$( wc -l "${DIR_TMP}/calendario.semana${semana}.txt" | gawk '{print $1}' )" != "${nLineas}" ]
            then
                prt_debug "${ARG_VERBOSO}" "------ Al colocar los partidos dados, ha habido otros que se quedan sin hueco y no se pueden jugar. Asi que se tira la iteracion"
                vuelveAEmpezar=true
                continue
            fi

            # Se comprueba si esa permutacion es valida y estan todos los partidos colocados
            if  [ "$( cat "${DIR_TMP}/comb_ordenadas" )" == "" ] && [ "${vuelveAEmpezar}" == "false" ]
            then
                prt_info "---- Esta iteracion es buena y se han podido colocar todos los partidos. Se termina con la semana"
                prt_info "----- Generado el fichero ${DIR_TMP}/calendario.semana${semana}.txt"
                touch "${DIR_TMP}/PARA.PERMUTACIONES"
                break
            fi
            
        done

        # Se elimina la permutacion actual
        rm "${f}"
        
        # Se comprueba si se han colocado todos los partidos
        if  [ "$( wc -l "${DIR_TMP}/calendario.semana${semana}.txt" | gawk '{print $1}' )" != "${nLineas}" ]
        then
            prt_warn "------ Ninguna permutacion es valida, por lo que esta semana no es valida, no se puede configurar"
            prt_info "-------- hay que cambiar la semana por lo que se elige el partido mas complicado y se mueve a otra semana"
            moverPartido "${semana}"
            semana=$(( semana - 1 )) # para que vuelva a empezar con la semana actual
            continue
        fi

        # 10/10 - Comprueba si debe terminar: ya hay un calendario para todas las semanas
        prt_info "---- 10/10 - Comprueba si debe terminar: ya hay un calendario para todas las semanas"
        FINALIZADO=true
        for s in $( seq 1 "${nSemanas}" )
        do
            # -- debe existir el fichero del calendario de la semana = se ha procesado al menos una vez
            if [ ! -f "${DIR_TMP}/calendario.semana${s}.txt" ]; then prt_debug "${ARG_VERBOSO}" "------ Aun no existe ${DIR_TMP}/calendario.semana${s}.txt"; FINALIZADO=false; break; fi

            # -- deben tener el mismo numero de lineas = todos los partidos estan en el calendario, y todos los del calendario estan en el partido
            nCalendario=$( wc -l "${DIR_TMP}/calendario.semana${s}.txt" | gawk '{print $1}' )
            nPartidos=$(   wc -l "${DIR_TMP}/partidos.semana${s}"       | gawk '{print $1}' )
            if [ "${nCalendario}" != "${nPartidos}" ]
            then
                prt_debug "${ARG_VERBOSO}" "------ No tienen el mismo numero de lineas ${DIR_TMP}/calendario.semana${s}.txt (${nCalendario}) y ${DIR_TMP}/partidos.semana${s} (${nPartidos})"
                if [ "${ARG_VERBOSO}" == "true" ]; then echo "---- ${DIR_TMP}/partidos.semana${s}"; cat "${DIR_TMP}/partidos.semana${s}"; echo "---- ${DIR_TMP}/calendario.semana${s}.txt"; cat "${DIR_TMP}/calendario.semana${s}.txt"; fi
                FINALIZADO=false; break
            fi

            # -- se comprueba la condicion anterior linea por linea
            while IFS='|' read -r _ _ LOCAL VISITANTE _ _ _ _ _ _ _
            do
                if [ "$( grep -e "-${LOCAL}-${VISITANTE}-" "${DIR_TMP}/calendario.semana${s}.txt" )" == "" ]
                then
                    prt_debug "${ARG_VERBOSO}" "------ La pareja -${LOCAL}-${VISITANTE}- de ${DIR_TMP}/partidos.semana${s}, no esta en ${DIR_TMP}/calendario.semana${s}.txt"
                    if [ "${ARG_VERBOSO}" == "true" ]; then echo "---- ${DIR_TMP}/partidos.semana${s}"; cat "${DIR_TMP}/partidos.semana${s}"; echo "---- ${DIR_TMP}/calendario.semana${s}.txt"; cat "${DIR_TMP}/calendario.semana${s}.txt"; fi
                    FINALIZADO=false; break
                fi
            done < "${DIR_TMP}/partidos.semana${s}"
        done
        if [ "${FINALZIADO}" == "true" ]; then prt_info "------ Termina porque ya esta el calendario de todos los partidos"; fi

    done
    prt_info "---- Ya esta la configuracion definitiva"
    
done


# 5/6 - Se unen los partidos de todas las semanas
prt_info "-- 5/6 - Se unen los partidos de todas las semanas"
#  -- cabecera
echo "MES|LOCAL|VISITANTE|PISTA|FECHA|HORA_INI|HORA_FIN" > calendario.txt.new
# -- se escriben los nuevos partidos
cat "${DIR_TMP}/calendario.semana"*".txt" | gawk -F"-" 'BEGIN{OFS="|"}{MES=sprintf("%03d",MES); print MES,$2"-"$3,$4"-"$5,$6,$7,$8,$9}' MES="${ARG_MES}" >> calendario.txt.new
# -- se escribe lo que ya teniamos
if [ -f "${DIR_TMP}/calendario" ]; then tail -n+2 "${DIR_TMP}/calendario" >> calendario.txt.new; fi
# -- se cambia el nombre
mv calendario.txt.new calendario.txt
# -- se le da formato
out=$( bash Script/formateaTabla.sh -f "calendario.txt" ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi
prt_info "---- Generado ${G}calendario.txt${NC}"

# -- limpia la tabla
out=$( FGRL_limpiaTabla "calendario.txt" "${DIR_TMP}/calendario" false ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi


# 6/6 - Se genera el html
prt_info "-- 6/6 - Se genera el html del calendario"
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
    <script src='Calendario/other/jquery.min.js'></script>
    <script src='Calendario/other/popper.min.js'></script>
    <script src='Calendario/other/tooltip.min.js'></script>
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
