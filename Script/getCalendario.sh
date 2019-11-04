#!/bin/bash

#================================================================================
#
# Script averigua cuando se juegan los partidos de partidos.txt, que aun no tienen fecha y que son del mes dado
#  - Genera el fichero calendario.txt con la fecha de los partidos que hay pendiente por jugar
#  - Genera el fichero calendario.html para poder visualizar la tabla anterior
#
# Nota: es posible que por tema de restricciones 2 partidos se jueguen en la misma semana. En ese caso
# edita el fichero repitenEnLaSemana.txt, con el formato: PAREJA|N_REPETICIONES
# Puede llevar cabecera. Para dar formato <bash Script/formateaTabla.sh -f repitenEnLaSemana.txt>
#
# Entrada
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

 Nota: es posible que por tema de restricciones 2 partidos se jueguen en la misma semana. En ese caso
 edita el fichero repitenEnLaSemana.txt, con el formato: PAREJA|N_REPETICIONES
 Puede llevar cabecera. Para dar formato <bash Script/formateaTabla.sh -f repitenEnLaSemana.txt>

 Entrada
  -v            --> Verboso (para ver las iteraciones del algoritmo)

 Salida:
  0 --> ejecucion correcta
  1 --> ejecucion con errores
"

ARG_VERBOSO=false        # por defecto, no es verboso

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

N_MAX_REPETICIONES=1

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
# - checkSemana
#     Funcion   --->  comprueba que los partidos de la semana estan ya bien configurados
#     Entrada   --->  $1 = ruta al fichero de partidos de la semana
#                     $2 = ruta al fichero del calendario de la semana
#     Salida    --->  0 = ok
#                     1 = error
#
function checkSemana {

    # Argumentos
    local _p=${1}
    local _c=${2}

    # Variables internas
    local _nP
    local _nC
    local _loc
    local _vis

    # Existen los ficheros
    if [ ! -f "${_p}" ]; then prt_info "------ Aun no existe ${_p}"; return 1; fi
    if [ ! -f "${_c}" ]; then prt_info "------ Aun no existe ${_c}"; return 1; fi

    # Tienen el mismo numero de lineas
    _nP=$( wc -l "${_p}" | gawk '{print $1}' )
    _nC=$( wc -l "${_c}" | gawk '{print $1}' )
    if [ "${_nP}" != "${_nC}" ]
    then
        prt_info "------ No tienen el mismo numero de lineas ${_c} (${_nC}) y ${_p} (${_nP})"
        if [ "${ARG_VERBOSO}" == "true" ]; then echo "---- ${_p}"; cat "${_p}"; echo "---- ${_c}"; cat "${_c}"; fi
        return 1
    fi

    while IFS='|' read -r _ _ _loc _vis _
    do
        if [ "$( grep -e "-${_loc}-${_vis}-" "${_c}" )" == "" ]
        then
            prt_info "------ La pareja -${_loc}-${_vis}- de ${_p}, no esta en ${_c}"
            if [ "${ARG_VERBOSO}" == "true" ]; then echo "---- ${_p}"; cat "${_p}"; echo "---- ${_c}"; cat "${_c}"; fi
            return 1
        fi
    done < "${_p}"
    
    # Todo correcto
    return 0
}


##########
# - checkMoverPartido
#     Funcion   --->  Averigua si hay que mover un partido debido a que hay demasiadas repeticiones: es decir, local
#                     o visitante ya tienen un partido esa semana. Si es asi, mueve los partidos que corresponda.n.
#     Entrada   --->  $1 = semana actual
#     Salida    --->  0 = ok = se ha movido
#                     1 = error = no se ha movido
#                Modifica los ficheros partidos.semana*
#
function checkMoverPartido {

    # Argumentos
    local _s=$1

    # Variables internas
    local _sSig
    local _seMueve
    local _nLineas
    local _num
    local _LOC
    local _VIS
    local _nRepLoc
    local _nRepVis
    local _nRepLocSig
    local _nRepVisSig
    local _fin
    local _maxRepsLoc
    local _maxRepsVis
    
    # Se mueven todos los partidos que esten repetidos mas de N_MAX_REPETICIONES
    _seMueve=false
    _fin=false
    while [ "${_fin}" == "false" ]
    do
        _fin=true
        _nLineas=$( wc -l "${DIR_TMP}/partidos.semana${_s}" | gawk '{print $1}' )
        for _num in $( seq 1 "${_nLineas}" )
        do
            _LOC=$( head -"${_num}" "${DIR_TMP}/partidos.semana${_s}" | tail -1 | gawk -F"|" '{print $3}' )
            _VIS=$( head -"${_num}" "${DIR_TMP}/partidos.semana${_s}" | tail -1 | gawk -F"|" '{print $4}' )
            _nRepLoc=$( grep -c "${_LOC}" "${DIR_TMP}/partidos.semana${_s}" )
            _nRepVis=$( grep -c "${_VIS}" "${DIR_TMP}/partidos.semana${_s}" )

            # -- si existe el fichero de las repeticiones
            _maxRepsLoc=${N_MAX_REPETICIONES}
            _maxRepsVis=${N_MAX_REPETICIONES}
            if [ -f "${DIR_TMP}/repitenEnLaSemana" ]
            then
                if [ "$( grep -c "^${_LOC}|" "${DIR_TMP}/repitenEnLaSemana" )" == "1" ]; then _maxRepsLoc=$( grep "^${_LOC}|" "${DIR_TMP}/repitenEnLaSemana" | gawk -F"|" '{print $2+0}' ); fi
                if [ "$( grep -c "^${_VIS}|" "${DIR_TMP}/repitenEnLaSemana" )" == "1" ]; then _maxRepsVis=$( grep "^${_VIS}|" "${DIR_TMP}/repitenEnLaSemana" | gawk -F"|" '{print $2+0}' ); fi
            fi

            # -- si hay que moverlo, se averigua a que semana se puede mover
            if [ "${_nRepLoc}" -gt "${_maxRepsLoc}" ] || [ "${_nRepVis}" -gt "${_maxRepsVis}" ]
            then
                _sSig=${_s}
                for _num in $( seq 1 "${nSemanas}" )
                do
                    _sSig=$(( (_sSig % nSemanas) + 1 ))                    
                    _nRepLocSig=$( grep -c "${_LOC}" "${DIR_TMP}/partidos.semana${_sSig}" )
                    _nRepVisSig=$( grep -c "${_VIS}" "${DIR_TMP}/partidos.semana${_sSig}" )
                    if [ "${_nRepLocSig}" -gt "${_maxRepsLoc}" ] || [ "${_nRepVisSig}" -gt "${_maxRepsVis}" ] || [ "$( grep "^${_sSig}$" "${DIR_TMP}/huecosLibres.${_LOC}-${_VIS}" )" == "" ]
                    then
                        continue
                    fi
                    break
                done
                if [ "${_sSig}" == "${_s}" ]
                then
                    prt_error "------- <checkMoverPartido ${_s}> El partido [${_LOC} vs ${_VIS}] no se puede mover a ninguna semana"
                else
                    prt_info "------- <checkMoverPartido ${_s}> El partido [${_LOC} vs ${_VIS}] se mueve de la semana ${_s} a ${_sSig}"
                    prt_debug "${ARG_VERBOSO}" "----------- partidos pareja local:"
                    if [ "${ARG_VERBOSO}" == "true" ]; then tail -n+${_aux} "${DIR_TMP}/partidos.semana${_s}" | grep "${_LOC}"; fi
                    prt_debug "${ARG_VERBOSO}" "----------- partidos pareja visitante:"
                    if [ "${ARG_VERBOSO}" == "true" ]; then tail -n+${_aux} "${DIR_TMP}/partidos.semana${_s}" | grep "${_VIS}"; fi

                    grep -e "|${_LOC}|${_VIS}|"   "${DIR_TMP}/partidos.semana${_s}" >> "${DIR_TMP}/partidos.semana${_sSig}"  # se mueve a la semana siguiente
                    sed -i "/|${_LOC}|${_VIS}|/d" "${DIR_TMP}/partidos.semana${_s}"                                          # se quita de la semana actual

                    _seMueve=true
                    _fin=false
                    break
                fi
            fi
        done
    done

    if [ "${_seMueve}" == "true" ]; then return 0; fi

    return 1
}


##########
# - moverPartido
#     Funcion   --->  Se elige un partido aleatorio y se pone en la semana siguiente. Se evita que una pareja juegue la misma semana.
#                     Para no acumular partidos en una semana, si una semana se llena, se movera a otra que tenga menos,
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
    local _sSig
    local _rv
    local _LOC
    local _VIS
    local _nLineas
    local _num
    local _partido
    local _finalizado
    local _indS

    _sSig=$(( (_s % nSemanas) + 1 ))

    checkMoverPartido "${_s}"; _rv=$?

    # Si no es check y no se ha movido ninguo, se mueve uno al azar
    if [ "${_check}" != "check" ] && [ "${_rv}" == "1" ]
    then
        _num=$( shuf -i 1-5 -n 1 )
        # Se extrae en un fichero las parejas con el numero mas grande
        while IFS="|" read -r _ _ _LOC _VIS _
        do
            gawk '{print LOC"_"VIS, $0}' LOC="${_LOC}" VIS="${_VIS}" "${DIR_TMP}/huecosLibresContador.${_LOC}-${_VIS}"
        #done < "${DIR_TMP}/partidos.semana${_s}" | sort -g -k2,2 | tail -${_num} > "${DIR_TMP}/moverPartido.contador"
        #done < "${DIR_TMP}/partidos.semana${_s}" | sort -g -k2,2 | tail -100 > "${DIR_TMP}/moverPartido.contador"
        done < "${DIR_TMP}/partidos.semana${_s}" | sort -g -k2,2 > "${DIR_TMP}/moverPartido.contador"
        
        # Se elige al azar
        _nLineas=$( wc -l "${DIR_TMP}/moverPartido.contador" | gawk '{print $1}' )
        _num=$( shuf -i 1-${_nLineas} -n 1 )
        _partido=$( head -${_num} "${DIR_TMP}/moverPartido.contador" | tail -1 | gawk '{print $1}' )
        _LOC=$( echo -e "${_partido}" | gawk -F"_" '{print $1}' )
        _VIS=$( echo -e "${_partido}" | gawk -F"_" '{print $2}' )
        prt_info "------- <moverPartido ${_s} ${_check}> El partido [${_LOC} vs ${_VIS}] se mueve de la semana ${_s} a ${_sSig}, elegido aleatoriamente < shuf -i 1-${_nLineas} -n 1 >"
        rm "${DIR_TMP}/moverPartido.contador"

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
            checkMoverPartido "${_indS}"; _rv=$?
            if [ "${_rv}" == "0" ]; then _finalizado=false; break; fi  # si rv=0 es que se ha movido, y hay que volver a empezar
        done
    done

    return 0
}


##########
# - checkCompatible
#     Funcion   --->  Comprueba que todos los partidos se pueden jugar, y sin repetir en la misma semana la misma pareja
#     Entrada   --->  --
#     Salida    --->  0 = compatible
#                     1 = no-compatible
#
function checkCompatible {

    # Argumentos
    # -- no hay

    # Variables internas
    local _s
    local _n
    local _fIni
    local _fFin
    local _loc
    local _vis
    local _div
    local _nDivisiones
    local _pa
    local _pb
    local _cabecera
    local _len
    local _semanaPartido
    local _line
    local _maxRepsLoc
    local _maxRepsVis
    local _locAux
    local _visAux

    # Inicializacion de variables auxiliares
    rm -f "${DIR_TMP}/imposible"
    rm -f "${DIR_TMP}/tabla"
    _nDivisiones=$( gawk -F"|" '{print $2}' "${DIR_TMP}/partidos.CHECK" | sort -u | wc -l )

    # Se saca la lista de parejas por division (despues compararemos que estan todas)
    for _div in $( seq 1 "${_nDivisiones}" )
    do
        gawk -F"|" '{ if ($2==DIV) {print $3; print $4;}}' DIV="${_div}" "${DIR_TMP}/partidos.CHECK" | sort -u > "${DIR_TMP}/listaParejas.division${_div}"
    done
    
    # Se mira uno a uno cada partido
    while IFS="|" read -r _ _div _loc _vis _
    do
        prt_debug "${ARG_VERBOSO}" "Div=${_div} ---> ${_loc} vs ${_vis}"
        rm -f "${DIR_TMP}/parejaCompatible"

        # -- si la division ya sabemos que tiene problemas, no miramos mas partidos de esa division
        if [ -f "${DIR_TMP}/tabla" ] && [ "$( grep -e "${_div}" "${DIR_TMP}/tabla" )" != "" ]; then continue; fi

        # -- posibles fechas del partido en esa semana
        grep -e "-${_loc}-${_vis}-" "${DIR_TMP}/combinaciones_todas.CHECK" | gawk -F"-" '{print $7}' | sort -u  > "${DIR_TMP}/fechas_del_partido"

        while read -r _fecha
        do
            prt_debug "${ARG_VERBOSO}" "-- ${_fecha}"
            
            # -- se averigua en que semana esta ese partido: se sabe _s, _fIni y _fFin
            for _s in $( seq 1 "${nSemanas}" )
            do
                _n=$(( (_s - 1) * 7 )); _fIni=$( date +"%Y%m%d" -d "${CFG_FECHA_INI} +${_n} days" )
                _n=$(( _n + 5 ));       _fFin=$( date +"%Y%m%d" -d "${CFG_FECHA_INI} +${_n} days" )
                if [ "${_fecha}" -ge "${_fIni}" ] && [ "${_fecha}" -le "${_fFin}" ]; then break; fi
            done
            _semanaPartido=${_s}

            # -- se averigua que partidos quedan
            # ---- solo nos interesan las parejas de la division
            grep -f "${DIR_TMP}/listaParejas.division${_div}" "${DIR_TMP}/combinaciones_todas.CHECK" |
                # ---- se quita el partido original
                grep -v -e "-${_loc}-${_vis}-" |
                # ---- se imprime solo partido + fecha |
                gawk 'BEGIN{OFS=FS="-";}{print "",$2,$3,$4,$5,$7}' |
                # ---- registros unicos
                sort -u |
                # ---- nos quedamos con partido + semana que se juega
                while read -r _line
                do
                    # averigua la semana del partido
                    _fecha=$( echo -e "${_line}" | gawk -F"-" '{print $6}' )
                    for _s in $( seq 1 "${nSemanas}" )
                    do
                        _n=$(( (_s - 1) * 7 )); _fIni=$( date +"%Y%m%d" -d "${CFG_FECHA_INI} +${_n} days" )
                        _n=$(( _n + 5 ));       _fFin=$( date +"%Y%m%d" -d "${CFG_FECHA_INI} +${_n} days" )
                        if [ "${_fecha}" -ge "${_fIni}" ] && [ "${_fecha}" -le "${_fFin}" ]; then break; fi
                    done

                    # se ignoran los que son de la semana actual
                    if [ "${_s}" == "${_semanaPartido}" ]; then continue; fi

                    # averigua si a alguno se le permite tener mas de 1 partido en la misma semana
                    _locAux=$( echo -e "${_line}" | gawk -F"-" '{print $2"-"$3}' )
                    _visAux=$( echo -e "${_line}" | gawk -F"-" '{print $4"-"$5}' )
                    _maxRepsLoc=${N_MAX_REPETICIONES}
                    _maxRepsVis=${N_MAX_REPETICIONES}
                    if [ -f "${DIR_TMP}/repitenEnLaSemana" ]
                    then
                        if [ "$( grep -c "^${_locAux}|" "${DIR_TMP}/repitenEnLaSemana" )" == "1" ]; then _maxRepsLoc=$( grep "^${_locAux}|" "${DIR_TMP}/repitenEnLaSemana" | gawk -F"|" '{print $2+0}' ); fi
                        if [ "$( grep -c "^${_visAux}|" "${DIR_TMP}/repitenEnLaSemana" )" == "1" ]; then _maxRepsVis=$( grep "^${_visAux}|" "${DIR_TMP}/repitenEnLaSemana" | gawk -F"|" '{print $2+0}' ); fi
                    fi
                    if [ "${_maxRepsLoc}" -gt "1" ] && [ "${_maxRepsVis}" -gt "1" ]; then echo -e "${_line}" | gawk -F"-" '{print $2"-"$3,$4"-"$5,"-1"}'; fi
                    
                    echo -e "${_line}" | gawk -F"-" '{print $2"-"$3,$4"-"$5,SEMANA}' SEMANA="${_s}"
                done |
                # ---- registros unicos
                sort -u |
                # ---- nos quedamos solo con las semanas (en las que se juega algun partido)
                gawk '{print $3}' | sort -u > "${DIR_TMP}/check.output"

            # -- Si falta alguna semana, es un error
            # ---- Debe haber 1 partido por semana, a no ser que se haya especificado en el fichero repitenEnLaSemana.txt lo contrario
            # *** semanas que quedan disponibles si se juega ese partido
            _pa=$( wc -l "${DIR_TMP}/check.output" | gawk '{print $1+1}' ) # +1 por la pareja actual, que juega esa semana
            # *** semanas que hay en total
            _pb=$( wc -l "${DIR_TMP}/listaParejas.division${_div}" | gawk '{print $1}' )
            _pb=$(( $( factorial "${_pb}" ) / (2*( $( factorial $((_pb-2)) ) )) ))
            if [ "${_pa}" -ge "${_pb}" ]
            then
                prt_debug "${ARG_VERBOSO}" "---- Es compatible"
                touch "${DIR_TMP}/parejaCompatible"
                break
            else
                prt_debug "${ARG_VERBOSO}" "---- NO compatible porque ${_pa} < ${_pb}"
            fi

        done < "${DIR_TMP}/fechas_del_partido"

        # -- si no se ha creado es porque esta pareja es problematica
        if [ ! -f "${DIR_TMP}/parejaCompatible" ]
        then
            touch "${DIR_TMP}/imposible"
            echo "${_div}|${_loc} vs ${_vis}" >> "${DIR_TMP}/tabla"
        fi
    done < "${DIR_TMP}/partidos.CHECK"

    # Si ha habido problemas, para hacer mas facil entender el problema, se imprime una tabla
    if [ -f "${DIR_TMP}/tabla" ]
    then
        prt_error "--- Problemas de restricciones para que una pareja no repita partido en la misma semana"
        prt_error "--- Las parejas con problemas son las siguientes:"
        while read -r line; do prt_error "********** Division $( echo -e ${line} | gawk -F"|" '{print $1}'): $( echo -e ${line} | gawk -F"|" '{print $2}')"; done < "${DIR_TMP}/tabla"
        prt_error "--- Se imprime tabla con restricciones para poder visualizar el problema (X es restriccion)"
        echo ""

        gawk 'BEGIN{OFS=FS="|"}{print $1$2,$3}' "${DIR_TMP}/restricciones" > "${DIR_TMP}/restricciones.CHECK"

        # -- cabecera
        _cabecera=$( printf "%70s |" "DIVISION" )
        for _s in $( seq 1 "${nSemanas}" )
        do
            _n=$(( (_s - 1) * 7 )); _fIni=$( date +"%Y%m%d" -d "${CFG_FECHA_INI} +${_n} days" )
            _n=$(( _n + 5 ));       _fFin=$( date +"%Y%m%d" -d "${CFG_FECHA_INI} +${_n} days" )
            gawk -F"|" '{if ($2>=MIN && $2<=MAX) print $2}' MIN="${_fIni}" MAX="${_fFin}" "${DIR_TMP}/pistas" | sort -u > "${DIR_TMP}/listaDias.semana${_s}"
            _cabecera="${_cabecera} $( gawk '{printf("%02d | ",substr($1,7))}' "${DIR_TMP}/listaDias.semana${_s}" )"
            _cabecera="${_cabecera}### |"
        done
        _len=$( echo -e "${_cabecera}" | gawk '{print length()}' )
        printf "${_cabecera}\n"; printf "%*s\n" "${_len}" " " | sed 's/ /-/g'

        # -- cuerpo
        while read -r _div
        do
            printf "Division %s\n" "${_div}"; printf "%*s\n" "${_len}" " " | sed 's/ /-/g'
            while IFS="|" read -r _loc _vis
            do
                printf "%70s | " "${_loc} vs ${_vis}"
                for _s in $( seq 1 "${nSemanas}" )
                do
                    while read -r _fecha
                    do
                        _pa1=$( echo -e "${_loc}" | gawk -F"-" '{print $1}' ); _pa2=$( echo -e "${_loc}" | gawk -F"-" '{print $2}' )
                        _pb1=$( echo -e "${_vis}" | gawk -F"-" '{print $1}' ); _pb2=$( echo -e "${_vis}" | gawk -F"-" '{print $2}' )
                        if     [ "$( grep "${_pa1}" "${DIR_TMP}/restricciones.CHECK" | grep "${_fecha}" )" != "" ] || [ "$( grep "${_pb1}" "${DIR_TMP}/restricciones.CHECK" | grep "${_fecha}" )" != "" ] ||
                               [ "$( grep "${_pa2}" "${DIR_TMP}/restricciones.CHECK" | grep "${_fecha}" )" != "" ] || [ "$( grep "${_pb2}" "${DIR_TMP}/restricciones.CHECK" | grep "${_fecha}" )" != "" ]
                        then
                            printf " X | "
                        else
                            printf "   | "
                        fi
                    done < "${DIR_TMP}/listaDias.semana${_s}"
                    printf "### | "
                done
                printf "\n"; printf "%*s\n" "${_len}" " " | sed 's/ /-/g'
            done < <( gawk 'BEGIN{OFS=FS="|";}{if ($2==DIV) print $3,$4}' DIV="${_div}" "${DIR_TMP}/partidos.orig" )
        done < <( gawk -F"|" '{print $1}' "${DIR_TMP}/tabla" | sort -u )
    fi

    # Final
    rm -f "${DIR_TMP}/fechas_del_partido" "${DIR_TMP}/output"
    if [ -f "${DIR_TMP}/imposible" ]; then return 1; fi
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

### CABECERA DEL FICHERO DE PARTIDOS ---> Mes | Division |                     Local |            Visitante |    Fecha | Hora_ini | Hora_fin |   Lugar | Set1 | Set2 | Set3 | Puntos | Ranking
###                                         1 |        1 | AlbertoMateos-IsraelAlonso| EricPerez-DanielRamos| 20190507 |    18:00 |    19:30 | Pista 7 |  7/5 |  6/5 |    - |      - | false


############# INICIALIZACION

prt_info "Inicializacion..."

# Resetea un directorio temporal solo para este script, dentro de tmp/
mkdir -p tmp; DIR_TMP="tmp/tmp.${SCRIPT}.${PID}"; rm -rf "${DIR_TMP}"; mkdir "${DIR_TMP}"

# Limpia los diferentes ficheros
out=$( FGRL_limpiaTabla pistas.txt        "${DIR_TMP}/pistas"        false )
out=$( FGRL_limpiaTabla restricciones.txt "${DIR_TMP}/restricciones" false )
out=$( FGRL_limpiaTabla partidos.txt      "${DIR_TMP}/partidos"      false )
if [ -f calendario.txt ];        then out=$( FGRL_limpiaTabla calendario.txt        "${DIR_TMP}/calendario"        false ); fi
if [ -f repitenEnLaSemana.txt ]; then out=$( FGRL_limpiaTabla repitenEnLaSemana.txt "${DIR_TMP}/repitenEnLaSemana" false ); fi

# Se hace backup de los ficheros de salida, para no sobreescribir
FGRL_backupFile calendario txt;  rv=$?; if [ "${rv}" != "0" ]; then exit 1; fi
FGRL_backupFile calendario html; rv=$?; if [ "${rv}" != "0" ]; then exit 1; fi



############# EJECUCION

prt_info "Ejecucion..."

# Solo nos quedamos con los partidos de la jornada que corresponde y
# los que no tengan ya ranking ----> para eliminar partidos de INCOMPATIBILIDAD TOTAL
gawk -F"|" '{if ($1+0==MES && $13=="false") print}' MES="${CFG_JORNADA}" "${DIR_TMP}/partidos" > "${DIR_TMP}/partidos.tmp"
mv "${DIR_TMP}/partidos.tmp" "${DIR_TMP}/partidos"

# 1/9 - Se hace por semanas para evitar que una pareja juegue mas de 1 partido la misma semana
prt_info "-- 1/9 - Se hace por semanas para evitar que una pareja juegue mas de 1 partido la misma semana"
dIni=$( date -d "${CFG_FECHA_INI}" +%s )
dFin=$( date -d "${CFG_FECHA_FIN}" +%s )
nSemanas=$( echo "" | gawk '{printf("%d",((FIN-INI)/(86400*7))+0.5)}' INI="${dIni}" FIN="${dFin}" )
prt_info "---- Hay ${nSemanas} semanas"
for semana in $( seq 1 "${nSemanas}" )
do
    touch "${DIR_TMP}/partidos.semana${semana}"
done


# 2/9 - Se muestra la disponibilidad por divisiones
prt_info "-- 2/9 - Se muestra la disponibilidad por divisiones"
gawk 'BEGIN{OFS=FS="|"}{print $1$2,$3}' "${DIR_TMP}/restricciones" > "${DIR_TMP}/restricciones.DISPO"
_nDivisiones=$( gawk -F"|" '{print $2}' "${DIR_TMP}/partidos" | sort -u | wc -l )

# -- cabecera
_cabecera=$( printf "%70s |" "DIVISION" )
for _s in $( seq 1 "${nSemanas}" )
do
    _n=$(( (_s - 1) * 7 )); _fIni=$( date +"%Y%m%d" -d "${CFG_FECHA_INI} +${_n} days" )
    _n=$(( _n + 5 ));       _fFin=$( date +"%Y%m%d" -d "${CFG_FECHA_INI} +${_n} days" )
    gawk -F"|" '{if ($2>=MIN && $2<=MAX) print $2}' MIN="${_fIni}" MAX="${_fFin}" "${DIR_TMP}/pistas" | sort -u > "${DIR_TMP}/listaDias.semana${_s}"
    _cabecera="${_cabecera} $( gawk '{printf("%02d | ",substr($1,7))}' "${DIR_TMP}/listaDias.semana${_s}" )"
    _cabecera="${_cabecera}### |"
done
_len=$( echo -e "${_cabecera}" | gawk '{print length()}' )
printf "${_cabecera}\n"; printf "%*s\n" "${_len}" " " | sed 's/ /-/g'

# -- cuerpo
for _div in $( seq 1 "${_nDivisiones}" )
do
    printf "Division %s\n" "${_div}"; printf "%*s\n" "${_len}" " " | sed 's/ /-/g'
    while IFS="|" read -r _loc _vis
    do
        contador=0
        printf "%70s | " "${_loc} vs ${_vis}"
        for _s in $( seq 1 "${nSemanas}" )
        do
            semanaLibre=false
            while read -r _fecha
            do
                _pa1=$( echo -e "${_loc}" | gawk -F"-" '{print $1}' ); _pa2=$( echo -e "${_loc}" | gawk -F"-" '{print $2}' )
                _pb1=$( echo -e "${_vis}" | gawk -F"-" '{print $1}' ); _pb2=$( echo -e "${_vis}" | gawk -F"-" '{print $2}' )
                if     [ "$( grep "${_pa1}" "${DIR_TMP}/restricciones.DISPO" | grep "${_fecha}" )" != "" ] || [ "$( grep "${_pb1}" "${DIR_TMP}/restricciones.DISPO" | grep "${_fecha}" )" != "" ] ||
                       [ "$( grep "${_pa2}" "${DIR_TMP}/restricciones.DISPO" | grep "${_fecha}" )" != "" ] || [ "$( grep "${_pb2}" "${DIR_TMP}/restricciones.DISPO" | grep "${_fecha}" )" != "" ]
                then
                    printf " X | "
                else
                    printf "   | "; semanaLibre=true
                fi
            done < "${DIR_TMP}/listaDias.semana${_s}"
            printf "### | "
            if [ "${semanaLibre}" == "true" ]; then contador=$(( contador + 1 )); echo "${_s}" >> "${DIR_TMP}/huecosLibres.${_loc}-${_vis}"; fi
        done
        printf " (${contador})\n"; printf "%*s\n" "${_len}" " " | sed 's/ /-/g'
        echo "${contador}" > "${DIR_TMP}/huecosLibresContador.${_loc}-${_vis}"
    done < <( gawk 'BEGIN{OFS=FS="|";}{if ($2==DIV) print $3,$4}' DIV="${_div}" "${DIR_TMP}/partidos" )
done




# 3/9 - Comprueba que todos los partidos se pueden jugar al menos un dia
prt_info "-- 3/9 - Comprueba que todos los partidos se pueden jugar al menos un dia"
# -- se generan los huecos disponibles, poniendo al principio la pista 7
sed 's/|/-/g' "${DIR_TMP}/pistas" | sort -t"-" -k1,1r -k3,3 -k2,2  > "${DIR_TMP}/huecos" #-----------------------------------------PRIORIZANDO POR PISTA, DESPUES HORA, Y DESPUES DIA
#sed 's/|/-/g' "${DIR_TMP}/pistas"  > "${DIR_TMP}/huecos"
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
while IFS="|" read -r _ _ LOCAL VISITANTE _
do
    if [ "$( grep -c -e "-${LOCAL}-${VISITANTE}-" "${DIR_TMP}/combinaciones_todas" )" == "0" ]
    then
        prt_error "--- Por problemas de restricciones el partido [${LOCAL} vs ${VISITANTE}] no se puede jugar"
        IMPOSIBLE=true
    fi
done < "${DIR_TMP}/partidos"
if [ "${IMPOSIBLE}" == "true" ]; then exit 1; fi


# 4/9 - Se coloca un partido en cada semana, que sera la configuracion por defecto
prt_info "-- 4/9 - Se coloca un partido en cada semana, que sera la configuracion por defecto"
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


# 5/9 - Comprueba que todos los partidos de una division son compatibles = se pueden jugar sin repetir en la misma semana
prt_info "-- 5/9 - Comprueba que todos los partidos de una division son compatibles = se pueden jugar sin repetir en la misma semana"
cp "${DIR_TMP}/partidos.orig" "${DIR_TMP}/partidos.CHECK"
cp "${DIR_TMP}/combinaciones_todas" "${DIR_TMP}/combinaciones_todas.CHECK"
checkCompatible; rv=$?; if [ "${rv}" != "0" ]; then exit 1; fi


# 6/9 - Se repetira el proceso de ir desplazando partidos de una semana a otra hasta que todos los partidos encajen
prt_info "-- 6/9 - Se repetira el proceso de ir desplazando partidos de una semana a otra hasta que todos los partidos encajen"
semana=0; FINALIZADO=false
while [ "${FINALIZADO}" == "false" ]
do

    prt_info "---------------------------------------------------------------------------------------------"
    VUELVE_A_EMPEZAR=false

    # 1/10 - Se calculan las fechas limite de la semana
    prt_info "---- 1/10 - Se calculan las fechas limite de la semana"
    if [ "${semana}" == "0" ]; then semana=1; else semana=$(( (semana % nSemanas) + 1 )); fi
    n=$(( (semana - 1) * 7 )); FECHA_INI=$( date +"%Y%m%d" -d "${CFG_FECHA_INI} +${n} days" )
    n=$(( n + 5 ));            FECHA_FIN=$( date +"%Y%m%d" -d "${CFG_FECHA_INI} +${n} days" )
    prt_info "------ SEMANA ${semana}/${nSemanas} = ${FECHA_INI} - ${FECHA_FIN}"
    semanaSig=$(( (semana % nSemanas) + 1 ))

    # Se comprueba si hay partidos a colocar esa semana
    if [ ! -s "${DIR_TMP}/partidos.semana${semana}" ]
    then
        prt_info "------ No hay partidos a colocar en la semana ${semana}. Pasa a al siguiente"
        rm -f "${DIR_TMP}/calendario.semana${semana}.txt"; touch "${DIR_TMP}/calendario.semana${semana}.txt"
        continue
    fi

    # Si no se ha tocado el fichero, es decir, partidos = calendario, se pasa al siguiente
    checkSemana "${DIR_TMP}/partidos.semana${semana}" "${DIR_TMP}/calendario.semana${semana}.txt" > /dev/null; rv=$?
    if [ "${rv}" == "0" ]
    then
        prt_info "------ La semana ${semana} no ha sido modificada. Pasa a al siguiente"
        continue
    fi  

    # 2/10 - Se comprueba que hay suficientes huecos para poder colocar todos los partidos
    cp "${DIR_TMP}/partidos.semana${semana}" "${DIR_TMP}/partidos"
    prt_info "---- 2/10 - Se comprueba que hay suficientes huecos para poder colocar todos los partidos"
    gawk -F"|" '{if ($2>=FINI && $2<=FFIN) print}' FINI="${FECHA_INI}" FFIN="${FECHA_FIN}" "${DIR_TMP}/pistas" | sed 's/|/-/g' > "${DIR_TMP}/huecos"
    nHuecos=$(   wc -l "${DIR_TMP}/huecos"   | gawk '{print $1}' )
    nPartidos=$( wc -l "${DIR_TMP}/partidos" | gawk '{print $1}' )
    if [ "${nPartidos}" -gt "${nHuecos}" ]
    then
        prt_error "------ Hay mas partidos [${nPartidos}] que huecos disponibles [${nHuecos}]"
        prt_warn "------ Se mueve al menos un partido de la semana ${semana} a la siguiente, la semana ${semanaSig}"
        moverPartido "${semana}"      
        # -- se comprueba que ninguna pareja repite la misma semana
        moverPartido 1 "check"
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
    while IFS="|" read -r _ _ LOCAL VISITANTE _
    do
        out=$( grep -e " ${LOCAL} vs ${VISITANTE}" "${DIR_TMP}/combinaciones_ordenadas" )
        if [ "${out}" == "" ]
        then
            prt_error "------ El partido [${LOCAL} vs ${VISITANTE}] no se puede jugar, no esta en las opciones disponibles ordenadas"
            prt_debug "${ARG_VERBOSO}"  "[ ${LOCAL} vs ${VISITANTE}] no esta en el fichero:"; if [ "${ARG_VERBOSO}" == "1" ]; then cat  "${DIR_TMP}/combinaciones_todas"; fi
            prt_warn "------ Se mueve ese partido de la semana ${semana} a la siguiente, la semana ${semanaSig}"
            grep -e "|${LOCAL}|${VISITANTE}|" "${DIR_TMP}/partidos" >> "${DIR_TMP}/partidos.semana${semanaSig}" # se mueve a la siguiente
            sed -i "/|${LOCAL}|${VISITANTE}|/d" "${DIR_TMP}/partidos.semana${semana}" # se quita de la semana actual
            # -- se comprueba que ninguna pareja repite la misma semana
            moverPartido 1 "check"
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
    rm -f "${DIR_TMP}/INICIO.PERMUTACIONES"
    rm -f "${DIR_TMP}/PARA.PERMUTACIONES"
    rm -f "${DIR_TMP}/PERMUTACIONES.REGISTRO"*
    rm -f "${DIR_TMP}/combinaciones_ordenadas."*

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
        prt_debug "${ARG_VERBOSO}" "-------- Llamada a <FGRL_getPermutacion_conPesos ${DIR_TMP}/combinaciones_ordenadas 1 \"$( seq 1 ${nLineas} | xargs printf "%d " | sed -r "s/^ +//g; s/ +$//g;" )\" ${nLineas} ${nLineas} &"
        FGRL_getPermutacion_conPesos "${DIR_TMP}/combinaciones_ordenadas" 1 "$( seq 1 ${nLineas} | xargs printf "%d " | sed -r "s/^ +//g; s/ +$//g;" )" "${nLineas}" "${nLineas}" &
        prt_info "------ Se ha iniciado el calculo de permutaciones"
    fi

    # Espera hasta que se haya creado al menos 1 iteracion = permutacion
    while [ ! -f "${DIR_TMP}/INICIO.PERMUTACIONES" ]
    do
        sleep 1s
    done
    prt_info "------ (ya hay al menos una permutacion)"
    rm "${DIR_TMP}/INICIO.PERMUTACIONES"
    

    ######### EL PROCESO DE GENERACION DE PERMUTACIONES SE VA A EJECUTAR EN BACKGROUND
    ######### MIENTRAS TANTO, SE PUEDEN IR COGIENDO LAS ITERACIONES QUE HAYA, ORDENARLAS Y PROBAR

    while [ ! -f "${DIR_TMP}/PARA.PERMUTACIONES" ]
    do       
        # Se eliminan las que ya se han procesado (no existen)
        identificador=$( find "${DIR_TMP}/" -type f -name "combinaciones_ordenadas.DONE.perm*" | sort | tail -1 | gawk -F"DONE.perm" '{print $2+1}' )
        if [ "${identificador}" == "" ]; then identificador=1; fi

        # Nos quedamos con las que aun no se han revisado
        tail -n+"${identificador}" "${DIR_TMP}/PERMUTACIONES.REGISTRO" > "${DIR_TMP}/PERMUTACIONES.REGISTRO.tmp"
        sed -i "/DONE/d" "${DIR_TMP}/PERMUTACIONES.REGISTRO.tmp" # por si acaso ya ha terminado

        # Espera hasta que haya alguna permutacion
        if [ ! -s "${DIR_TMP}/PERMUTACIONES.REGISTRO.tmp" ]; then continue; fi

        # Se cogen todas las permutaciones disponibles y se les cambia de nombre, para que el programa las coja: de '.function' a '.perm'
        while read -r FILE
        do
            newName=$( echo -e "${FILE}" | sed 's/combinaciones_ordenadas.function/combinaciones_ordenadas.perm/g' )
            mv "${FILE}" "${newName}"
        done < "${DIR_TMP}/PERMUTACIONES.REGISTRO.tmp"

        # 8/10 - Se ordenan las permutaciones para probar primero los partidos que tienen menos opciones
        prt_info "---- 8/10 - Se ordenan las permutaciones para probar primero los partidos que tienen menos opciones"

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

        # -- se cambia la numeracion de las permutaciones segun este orden: de '.perm' a 'done.perm'
        contador=$( find "${DIR_TMP}/" -type f -name "combinaciones_ordenadas.DONE.perm*" | sort | tail -1 | gawk -F"DONE.perm" '{print $2+0}' )
        while IFS="|" read -r FILE _
        do
            contador=$( echo "" | gawk '{printf("%015d",N+1)}' N="${contador}" )
            mv "${FILE}" "${DIR_TMP}/combinaciones_ordenadas.done.perm${contador}"
        done < "${DIR_TMP}/combinaciones_ordenadas.TOTAL_PESOS"
        rm "${DIR_TMP}/combinaciones_ordenadas.TOTAL_PESOS"


        # 9/10 - Se prueban cada una de las permutaciones
        old=$( find "${DIR_TMP}/" -type f -name "combinaciones_ordenadas.DONE.perm*" | wc -l )
        new=$( find "${DIR_TMP}/" -type f -name "combinaciones_ordenadas.done.perm*" | wc -l )
        total=$(( old + new ))
        prt_info "---- 9/10 - Se prueban cada una de las permutaciones generadas hasta ahora (old=${old} + new=${new} = ${total} -- nPermutaciones=${nPermutaciones})"
        for f in "${DIR_TMP}/combinaciones_ordenadas.done.perm"*
        do

            prt_info "***** Probando iteracion ${f} (de ${total} posibles)"
            if [ "${ARG_VERBOSO}" == "true" ]; then cat "${f}"; fi

            # Inicializacion = reset
            rm -f "${DIR_TMP}/calendario.semana${semana}.txt"; touch "${DIR_TMP}/calendario.semana${semana}.txt"
            cp "${DIR_TMP}/combinaciones_todas" "${DIR_TMP}/comb_todas"
            cp "${f}"                           "${DIR_TMP}/comb_ordenadas"
            # -- se cambia el nombre a la permutacion, para que se registre como 'procesada': de 'done.perm' a 'DONE.perm'
            newName=$( echo -e "${f}" | sed 's/.done./.DONE./g' ); mv "${f}" "${newName}"

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
                # *** Dando prioridad a pista buena + hora temprana + ultima posicion los viernes
                hueco=$(
                    grep -e "-${pLocal}-${pVisitante}" "${DIR_TMP}/comb_todas" |  # Formato:"-CristinaLeon-ManuelHidalgo-MariaTeresaSolano-LaraDominguez-Pista3-20191112-18:00-19:00"
                        sort -t"-" -k6,6r -k8,8 -k7,7 | # se ordena por pista (damos por hecho que las pistas con mas numeracion son mejores) + hora + fecha
                        while read -r line              # se averigua el dia de la semana que es: Lun=1 ... Dom=7
                        do
                            fecha=$( echo -e "${line}" | gawk -F"-" '{print $7}' )
                            n=$( date +%u -d "${fecha}" )
                            if [ "${n}" -lt "5" ]; then n=0; fi
                            echo "${n}|${line}"
                        done |                                    
                        sort -t"|" -k1,1 | gawk -F"|" '{print $2}' | # se mueven los viernes/sabados/domingos al final
                        head -1 |         # se coge el primero
                        cut -d"-" -f 6-   # nos quedamos con el hueco=Pista3-20190603-18:00-19:00
                     )
                fechaHueco=$( echo -e "${hueco}" | gawk -F"-" '{print $2}'  )
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

                grep -e "-${pLocal}-${pVisitante}-${hueco}" "${DIR_TMP}/comb_todas" >> "${DIR_TMP}/calendario.semana${semana}.txt"  # Se anade al calendario a ese partido en ese hueco
                sed -i "/-${pLocal}-${pVisitante}-/d" "${DIR_TMP}/comb_todas"   # Como ese partido ya esta acoplado, se eliminan el resto de huecos para ese partido
                sed -i "/-${hueco}/d" "${DIR_TMP}/comb_todas"                   # Como ese hueco ya esta usado, se eliminan todas las parejas que tenian posibilidad de jugar en ese hueco
                sed -i "/-${pLocal}-.*-${fechaHueco}/d" "${DIR_TMP}/comb_todas" # Ninguna de las parejas puede jugar ya ese dia
                sed -i "/-${pVisitante}-.*-${fechaHueco}/d" "${DIR_TMP}/comb_todas" # Ninguna de las parejas puede jugar ya ese dia

                # Como ya hay una pareja de la division, ninguna pareja de la division puede jugar esa semana
                # a no ser que el fichero repitenEnLaSemana.txt diga lo contrario
                # -- se extrae la division de la pareja
                div=$( grep -e "|${pLocal}|${pVisitante}|" "${DIR_TMP}/partidos.orig" | gawk -F"|" '{print $2}' )
                # -- se busca la semana a la que pertenece ese hueco: _s + _fIni + _fFin
                _fecha=$( echo -e "${hueco}" | gawk -F"-" '{print $2}' )  # Pista3-20190603-18:00-19:00
                for _s in $( seq 1 "${nSemanas}" )
                do
                    _n=$(( (_s - 1) * 7 )); _fIni=$( date +"%Y%m%d" -d "${CFG_FECHA_INI} +${_n} days" )
                    _n=$(( _n + 5 ));       _fFin=$( date +"%Y%m%d" -d "${CFG_FECHA_INI} +${_n} days" )
                    if [ "${_fecha}" -ge "${_fIni}" ] && [ "${_fecha}" -le "${_fFin}" ]; then break; fi
                done
                # -- se eliminan los partidos de la misma division en esas fechas
                grep -f "${DIR_TMP}/listaParejas.division${div}" "${DIR_TMP}/comb_todas" | gawk -F"-" '{print $2"-"$3, $4"-"$5}' | sort -u > "${DIR_TMP}/limpiandoParejasMismaSemana"
                while read -r pLoc pVis
                do
                    # # solo se queda con un partido por dia (luego vera si por semana), pero lo que no se permite es que una pareja juegue el mismo dia mas de un partido
                    # terminado=FALSE
                    # while [ "${terminado}" == "FALSE" ]
                    # do
                    #     terminado=TRUE
                    #     _fecha=$( date +"%Y%m%d" -d "${_fIni} -1 days" )  # porque despues suma 1
                    #     while  [ "${_fecha}" -lt "${_fFin}" ] && [ "${terminado}" == "TRUE" ]
                    #     do
                    #         _fecha=$( date +"%Y%m%d" -d "${_fecha} +1 days" )
                    #         n=$( grep -e "-${pLoc}-" "${DIR_TMP}/comb_todas" | grep -c -e "-${_fecha}" )
                    #         if [ "${n}" -gt "1" ]
                    #         then
                    #             sed -i "0,/-${pLoc}-.*-${_fecha}/{//d;}" "${DIR_TMP}/comb_todas"
                    #             terminado=FALSE
                    #         fi
                    #         n=$( grep -e "-${pVis}-" "${DIR_TMP}/comb_todas" | grep -c -e "-${_fecha}" )
                    #         if [ "${n}" -gt "1" ]
                    #         then
                    #             sed -i "0,/-${pVis}-.*-${_fecha}/{//d;}" "${DIR_TMP}/comb_todas"
                    #             terminado=FALSE
                    #         fi
                    #     done
                    # done
                    
                    # -- LOCAL

                    # averigua si a alguno se le permite tener mas de 1 partido en la misma semana
                    maxRepsLoc=${N_MAX_REPETICIONES}
                    if [ -f "${DIR_TMP}/repitenEnLaSemana" ] && [ "$( grep -c "^${pLoc}|" "${DIR_TMP}/repitenEnLaSemana" )" == "1" ]; then maxRepsLoc=$( grep "^${pLoc}|" "${DIR_TMP}/repitenEnLaSemana" | gawk -F"|" '{print $2+0}' ); fi

                    # averigua cuantos partidos tiene esa pareja esa semana y cuantos se deberian eliminar
                    nTotalLoc=$( grep -e "-${pLoc}-" "${DIR_TMP}/comb_todas" | gawk -F"-" '{if ($7>=FINI && $7<=FFIN) print }' FINI="${_fIni}" FFIN="${_fFin}"| wc -l )
                    nToRemoveLoc=$(( nTotalLoc - maxRepsLoc ))
                    
                    # elimina los nPrimeros partidos de la pareja local que haya en esa semana
                    _fecha=$( date +"%Y%m%d" -d "${_fIni} -1 days" )  # porque despues suma 1
                    contador=1
                    while [ "${contador}" -le "${nToRemoveLoc}" ]
                    do
                        _fecha=$( date +"%Y%m%d" -d "${_fecha} +1 days" )                                  # actualiza la fecha
                        if [ "${_fecha}" -gt "${_fFin}" ]; then break; fi                                  # ya ha mirado todas la fechas de la semana (no deberia llegar hasta aqui)
                        n=$( grep -e "-${pLoc}-" "${DIR_TMP}/comb_todas" | grep -c -e "-${_fecha}" )       # averigua si hay algun partido a eliminar en esa fecha
                        if [ "${n}" == "0" ]; then continue; fi                                            # si no hay partidos pasa a la siguiente fecha
                        sed -i "0,/-${pLoc}-.*-${_fecha}/{//d;}" "${DIR_TMP}/comb_todas"                   # se quita la primera aparicion
                        contador=$(( contador + 1 ))                                                       # se actualiza el contador de partidos eliminados
                        if [ "${n}" -gt "1" ]; then _fecha=$( date +"%Y%m%d" -d "${_fecha} -1 days" ); fi  # si aun hay partidos en esa fecha, se insiste
                    done

                    # -- VISITANTE
                    
                    # averigua si a alguno se le permite tener mas de 1 partido en la misma semana
                    maxRepsVis=${N_MAX_REPETICIONES}
                    if [ -f "${DIR_TMP}/repitenEnLaSemana" ] && [ "$( grep -c "^${pVis}|" "${DIR_TMP}/repitenEnLaSemana" )" == "1" ]; then maxRepsVis=$( grep "^${pVis}|" "${DIR_TMP}/repitenEnLaSemana" | gawk -F"|" '{print $2+0}' ); fi

                    # averigua cuantos partidos tiene esa pareja esa semana y cuantos se deberian eliminar
                    nTotalVis=$( grep -e "-${pVis}-" "${DIR_TMP}/comb_todas" | gawk -F"-" '{if ($7>=FINI && $7<=FFIN) print }' FINI="${_fIni}" FFIN="${_fFin}"| wc -l )
                    nToRemoveVis=$(( nTotalVis - maxRepsVis ))
                    
                    # elimina los nPrimeros partidos de la pareja visitante que haya en esa semana
                    _fecha=$( date +"%Y%m%d" -d "${_fIni} -1 days" )  # porque despues suma 1
                    contador=1
                    while [ "${contador}" -le "${nToRemoveVis}" ]
                    do
                        _fecha=$( date +"%Y%m%d" -d "${_fecha} +1 days" )                                  # actualiza la fecha
                        if [ "${_fecha}" -gt "${_fFin}" ]; then break; fi                                  # ya ha mirado todas la fechas de la semana (no deberia llegar hasta aqui)
                        n=$( grep -e "-${pVis}-" "${DIR_TMP}/comb_todas" | grep -c -e "-${_fecha}" )       # averigua si hay algun partido a eliminar en esa fecha
                        if [ "${n}" == "0" ]; then continue; fi                                            # si no hay partidos pasa a la siguiente fecha
                        sed -i "0,/-${pVis}-.*-${_fecha}/{//d;}" "${DIR_TMP}/comb_todas"                   # se quita la primera aparicion
                        contador=$(( contador + 1 ))                                                       # se actualiza el contador de partidos eliminados
                        if [ "${n}" -gt "1" ]; then _fecha=$( date +"%Y%m%d" -d "${_fecha} -1 days" ); fi  # si aun hay partidos en esa fecha, se insiste
                    done
                done < "${DIR_TMP}/limpiandoParejasMismaSemana"
                rm "${DIR_TMP}/limpiandoParejasMismaSemana"

                # Se recalculan las combinaciones ordenadas
                gawk -F"-" '{print $2"-"$3 " vs " $4"-"$5}' "${DIR_TMP}/comb_todas" | sort | uniq -c | sort -k1,1 -g > "${DIR_TMP}/comb_ordenadas"

            done

            # Se comprueba si se han colocado todos los partidos
            if  [ "$( wc -l "${DIR_TMP}/calendario.semana${semana}.txt" | gawk '{print $1}' )" != "${nLineas}" ]
            then
                prt_debug "${ARG_VERBOSO}" "------ Al colocar los partidos dados, ha habido otros que se quedan sin hueco y no se pueden jugar. Asi que se tira la iteracion"
                vuelveAEmpezar=true
                continue  # pasa a la siguiente iteracion
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

        # Se comprueba si se han colocado todos los partidos de la semana
        checkSemana "${DIR_TMP}/partidos.semana${semana}" "${DIR_TMP}/calendario.semana${semana}.txt" > /dev/null; rv=$?
        if [ "${rv}" == "0" ]
        then
            prt_debug "${ARG_VERBOSO}" "------ Ya se ha encontrado una iteracion buena, se comprobara si ya se ha terminado o hay que seguir con otra semana"
            break
        fi
        prt_warn "------ Ninguna permutacion (de las que se han generado hasta ahora es valida) asi que se siguen probando nuevas permutaciones"
        
        # **** SI SOLO QUEREMOS PROBAR UNA VEZ (con la primera permutacion) ---> PARA IR MAS RAPIDO
        touch "${DIR_TMP}/PARA.PERMUTACIONES"

    done

    # Se comprueba si se han colocado todos los partidos de la semana
    checkSemana "${DIR_TMP}/partidos.semana${semana}" "${DIR_TMP}/calendario.semana${semana}.txt" > /dev/null; rv=$?
    if [ "${rv}" == "1" ]
    then
        prt_warn "------ Se han acabado las permutaciones a probar, y ninguna de ellas es valida"
        prt_info "-------- Esta semana no se puede configurar, hay que cambiar la semana por lo que se elige un partido al azar y se mueve a otra semana"
        moverPartido "${semana}"
        semana=$(( semana - 1 )) # para que vuelva a empezar con la semana actual
        continue
    fi

    # 10/10 - Comprueba si debe terminar: ya hay un calendario para todas las semanas
    prt_info "---- 10/10 - Comprueba si debe terminar: ya hay un calendario para todas las semanas"
    FINALIZADO=true
    for s in $( seq 1 "${nSemanas}" )
    do
        checkSemana "${DIR_TMP}/partidos.semana${s}" "${DIR_TMP}/calendario.semana${s}.txt"; rv=$?
        if [ "${rv}" == "1" ]; then FINALIZADO=false; break; fi
    done
    if [ "${FINALZADO}" == "true" ]; then prt_info "------ Termina porque ya esta el calendario de todos los partidos"; fi
done


# 7/9 - Se unen los partidos de todas las semanas
prt_info "-- 7/9 - Se unen los partidos de todas las semanas"
#  -- cabecera
echo "MES|LOCAL|VISITANTE|PISTA|FECHA|HORA_INI|HORA_FIN|PISTA_CONFIRMADA" > calendario.txt.new
# -- se escriben los nuevos partidos
cat "${DIR_TMP}/calendario.semana"*".txt" | gawk -F"-" 'BEGIN{OFS="|"}{MES=sprintf("%03d",MES); print MES,$2"-"$3,$4"-"$5,$6,$7,$8,$9,"false"}' MES="${CFG_JORNADA}" >> calendario.txt.new
# -- se escribe lo que ya teniamos
if [ -f "${DIR_TMP}/calendario" ]; then cat "${DIR_TMP}/calendario" >> calendario.txt.new; fi
# -- se cambia el nombre
mv calendario.txt.new calendario.txt


# 8/9 - Se reordenan los partidos dentro de cada dia
prt_info "-- 8/9 - Se reordenan los partidos dentro de cada dia"
out=$( FGRL_limpiaTabla calendario.txt "${DIR_TMP}/calendario" false )
out=$( FGRL_limpiaTabla ranking.txt    "${DIR_TMP}/ranking"    false )
out=$( FGRL_limpiaTabla pistas.txt     "${DIR_TMP}/pistas"     false )
fecha=$( date +"%Y%m%d" -d "${CFG_FECHA_INI} -1 days" ) # porque despues va a sumar 1 dia
while [ "${fecha}" -le "${CFG_FECHA_FIN}" ]
do
    fecha=$( date +"%Y%m%d" -d "${fecha} +1 days" )
    # Solo se hace algo si hay mas de 1 partido y mas 1 pista
    if [ "$( grep -c "|${fecha}|" "${DIR_TMP}/calendario" )" -le "1" ]; then continue; fi
    if [ "$( grep -c "|${fecha}|" "${DIR_TMP}/pistas" )"     -le "1" ]; then continue; fi
    
    # Extrae los partidos que hay ese dia y ordena los partidos por ranking (suma el ranking de las 2 parejas)
    grep "|${fecha}|" "${DIR_TMP}/calendario" |
        while read -r line
        do
            loc=$( echo -e "${line}" | gawk -F"|" '{print $2}' )
            vis=$( echo -e "${line}" | gawk -F"|" '{print $3}' )
            posRankLoc=$( gawk -F"|" '{if ($2==PAREJA) print $1+0}' PAREJA="${loc}" "${DIR_TMP}/ranking" )
            posRankVis=$( gawk -F"|" '{if ($2==PAREJA) print $1+0}' PAREJA="${vis}" "${DIR_TMP}/ranking" )
            pos=$(( posRankLoc + posRankVis ))
            echo "${pos} ${line}"
        done |
        sort -g -k1,1 | gawk '{print $2}' > "${DIR_TMP}/reordenaPartidos"
    
    # Extrae las pistas disponibles ese dia y las ordena
    grep "|${fecha}|" "${DIR_TMP}/pistas" |
        gawk -F"|" '{aux=$1; gsub("Pista", "", aux); aux*=-1; if (substr($3,1,2)==20) {aux+=50;} print aux,$0}' |
        sort -g -k1,1 |
        gawk '{print $2}' > "${DIR_TMP}/reordenaPistas"

    # Se cambia los partidos
    while IFS="|" read -r _ LOCAL VISITANTE LUGAR FECHA HINI HFIN _
    do
        newLugar=$( head -1 "${DIR_TMP}/reordenaPistas" | gawk -F"|" '{print $1}' )
        newHIni=$(  head -1 "${DIR_TMP}/reordenaPistas" | gawk -F"|" '{print $3}' )
        newHFin=$(  head -1 "${DIR_TMP}/reordenaPistas" | gawk -F"|" '{print $4}' )
        sed -i "s/|${LOCAL}|${VISITANTE}|${LUGAR}|${FECHA}|${HINI}|${HFIN}/|${LOCAL}|${VISITANTE}|${newLugar}|${FECHA}|${newHIni}|${newHFin}/g" "${DIR_TMP}/calendario"
        tail -n+2 "${DIR_TMP}/reordenaPistas" > "${DIR_TMP}/reordenaPistas.tmp"
        mv "${DIR_TMP}/reordenaPistas.tmp" "${DIR_TMP}/reordenaPistas"
    done < "${DIR_TMP}/reordenaPartidos"
done
echo "MES|LOCAL|VISITANTE|PISTA|FECHA|HORA_INI|HORA_FIN|PISTA_CONFIRMADA" > calendario.txt
cat "${DIR_TMP}/calendario" >> calendario.txt

# 9/9 - Actualizaciones de ficheros
prt_info "-- 9/9 - Actualizaciones de ficheros"

# -- se le da formato
out=$( bash Script/formateaTabla.sh -f calendario.txt ); rv=$?; if [ "${rv}" != "0" ]; then echo -e "${out}"; exit 1; fi
prt_info "---- Generado ${G}calendario.txt${NC}"

# -- se comprueba el formato de calendario
bash Script/checkCalendario.sh; rv=$?
if [ "${rv}" != "0" ]
then
    prt_error "Error ejecutando <bash Script/checkCalendario.sh>"
    prt_error "---- Soluciona el problema y ejecutalo a mano"
    prt_warn "*** Despues quedaria ejecutar lo siguiente:"
    prt_warn "-----  bash Script/updateCalendario.sh  # para actualizar el fichero de calendario html"
    prt_warn "-----  bash Script/updatePartidos.sh    # para actualizar el fichero de partidos html"
    prt_warn "-----  bash Script/checkPartidos.sh     # para comprobar formado de partidos"
    exit 1
fi

# -- se crea el fichero web de calendario
bash Script/updateCalendario.sh; rv=$?
if [ "${rv}" != "0" ]
then
    prt_error "Error ejecutando <bash Script/updateCalendario.sh>"
    prt_error "---- Soluciona el problema y ejecutalo a mano"
    prt_warn "*** Despues quedaria ejecutar lo siguiente:"
    prt_warn "-----  bash Script/updatePartidos.sh  # para actualizar el fichero de partidos html"
    prt_warn "-----  bash Script/checkPartidos.sh   # para comprobar formado de partidos"
    exit 1
fi

# -- se crea el fichero web de partidos
bash Script/updatePartidos.sh; rv=$?
if [ "${rv}" != "0" ]
then
    prt_error "Error ejecutando <bash Script/updatePartidos.sh>"
    prt_error "---- Soluciona el problema y ejecutalo a mano"
    prt_warn "*** Despues quedaria ejecutar lo siguiente:"
    prt_warn "-----  bash Script/checkPartidos.sh         # para comprobar formado de partidos"
    exit 1
fi

# -- se comprueba el formato de partidos
bash Script/checkPartidos.sh; rv=$?
if [ "${rv}" != "0" ]
then
    prt_error "Error ejecutando <bash Script/checkPartidos.sh>"
    prt_error "---- Soluciona el problema y ejecutalo a mano"
    exit 1
fi


############# FIN
exit 0
