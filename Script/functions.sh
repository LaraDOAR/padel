#!/bin/bash

#================================================================================
#
# Libreria de funciones generales que se pueden usar
#
#================================================================================

############### FUNCIONES DISPONIBLES
# - FGRL_limpiaTabla
# - FGRL_getPermutacion
# - FGRL_backupFile




##########
# - FGRL_limpiaTabla
#     Funcion   --->  dado un fichero (que contiene una tabla) elimina cabecera y blancos
#     Entrada   --->  $1 = fichero entrada
#                     $2 = fichero salida
#                     $3 = true/false para indicar si se mantiene la cabecera o no
#     Salida    --->  0 = ok
#                     1 = error
#                ECHO lineaFinCabecera por si hiciera falta restaurarla despues
#
function FGRL_limpiaTabla {

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
export -f FGRL_limpiaTabla


##########
# - FGRL_getPermutacion
#     Funcion   --->  Genera n ficheros nuevos con las diferentes permutaciones de sus linea posibles
#     Entrada   --->  $1 = fichero
#                     $2 = iteracion: numero de la iteracion
#     Salida    --->  0 = ok
#                     1 = error
#                   $1.perm1
#                   $1.perm2
#                   $1.perm(...)
#
function FGRL_getPermutacion {

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

    # Se genera un fichero que no tiene la primera linea
    tail -n+2 "${_file}" > "${_file}.${_iteracion}"

    # Se calculan las permutaciones del fichero restante
    FGRL_getPermutacion "${_file}.${_iteracion}" "${_iteracion}"
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
export -f FGRL_getPermutacion


##########
# - FGRL_getPermutacion_conPesos
#     Funcion   --->  Igual que FGRL_getPermutacion_conPesos, pero asume que las lineas de los ficheros
#                     son de la forma: "peso texto". Esta funcion tambien genera permutaciones, pero lo hace
#                     de manera ordenada para ir usando esas permutaciones.
#                     Va registrando las permutaciones que están ya hechas, para porder ir usandolas.
#                     Cuando detecta la existencia del fichero "${DIR_TMP}/PERMUTACIONES.REGISTRO", para.
#     Entrada   --->  $1 = fichero
#                     $2 = iteracion: numero de la iteracion
#                     $3 = depth (parametro interno para saber cual es la profundidad)
#     Salida    --->  0 = ok
#                     1 = error
#                   $1.perm1
#                   $1.perm2
#                   $1.perm(...)
#                   PERMUTACIONES.REGISTRO
#
function FGRL_getPermutacion_conPesos {

    # Argumentos
    local _file=$1
    local _iteracion=$2
    local _depth=$3

    # Variables internas
    local _dir
    local _base
    local _f
    local _files
    local _nPosiciones
    local _i

    if [ -f "${DIR_TMP}/PARA.PERMUTACIONES" ]; then return 0; fi
    
    # Crea fichero de registro
    if [ "${_depth}" == "" ]; then rm -f "${DIR_TMP}/PERMUTACIONES.REGISTRO"; touch "${DIR_TMP}/PERMUTACIONES.REGISTRO"; fi
    
    # Condicion de parada: cuando solo queda un elemento
    if [ "$( wc -l "${_file}" | gawk '{print $1}' )" == "1" ]
    then
        if [ -f "${DIR_TMP}/PARA.PERMUTACIONES" ]; then return 0; fi
        cat "${_file}" > "${_file}.function${_iteracion}"

        if [ "${_depth}" == "" ]; then
            echo "${_file}.function${_iteracion}" >> "${DIR_TMP}/PERMUTACIONES.REGISTRO"
            echo "DONE" >> "${DIR_TMP}/PERMUTACIONES.REGISTRO"
        fi
        return 0
    fi

    # Se genera un fichero que no tiene la primera linea
    if [ -f "${DIR_TMP}/PARA.PERMUTACIONES" ]; then return 0; fi
    tail -n+2 "${_file}" > "${_file}.${_iteracion}"

    # Se calculan las permutaciones del fichero restante
    FGRL_getPermutacion_conPesos "${_file}.${_iteracion}" "${_iteracion}" "$(( _depth + 1 ))"
    if [ -f "${DIR_TMP}/PARA.PERMUTACIONES" ]; then return 0; fi
    rm "${_file}.${_iteracion}"

    # Se calculan las combinaciones: se pone la primera linea de _file
    # delante de todos los ficheros resultado
    _dir=$(  dirname  "${_file}" )
    _base=$( basename "${_file}" )
    _files=$( find "${_dir}/" -type f -name "${_base}.${_iteracion}.function*" )
    _newLine=$( head -1 "${_file}" )
    for _f in ${_files}
    do
        # En el fichero _f tengo "2 er" y "3 tq", y newLine es "1 ab"
        # Lo que quiero es meter "1 ab" en todas las posiciones posibles
        # En este caso: en la 1 (antes de "2 er"), en la 2 (entre "2 er" y "3 tq"), y en la 3 (despues de "3 tq")
        _nPosiciones=$( wc -l "${_f}" | gawk '{print $1}' )
        for _i in $( seq 1 "${_nPosiciones}" )
        do
            if [ -f "${DIR_TMP}/PARA.PERMUTACIONES" ]; then return 0; fi
            # -- crea iteracion (I)
            gawk '{if (NR==POSICION) print NEW; print;}' POSICION="${_i}" NEW="${_newLine}" "${_f}" > "${_file}.function${_iteracion}"
            # -- se registra (I)
            if [ "${_depth}" == "" ]; then echo "${_file}.function${_iteracion}" >> "${DIR_TMP}/PERMUTACIONES.REGISTRO"; fi
            _iteracion=$(( _iteracion + 1 ))
        done
        if [ -f "${DIR_TMP}/PARA.PERMUTACIONES" ]; then return 0; fi
        # -- crea iteracion (II)
        cat "${_f}" > "${_file}.function${_iteracion}"; echo "${_newLine}" >> "${_file}.function${_iteracion}"
        # -- se registra (II)
        if [ "${_depth}" == "" ]; then echo "${_file}.function${_iteracion}" >> "${DIR_TMP}/PERMUTACIONES.REGISTRO"; fi
        _iteracion=$(( _iteracion + 1 ))
        rm "${_f}"
    done

    # Fin
    if [ "${_depth}" == "" ]; then echo "DONE" >> "${DIR_TMP}/PERMUTACIONES.REGISTRO"; fi
    return 0
}
export -f FGRL_getPermutacion_conPesos


##########
# - FGRL_backupFile
#     Funcion   --->  hace backup del fichero actual
#     Entrada   --->  $1 = fichero (ranking, partidos...)
#                     $2 = terminacion del fichero (txt, html)
#     Salida    --->  0 = ok
#                     1 = error
#                   $1-ID.$2
#
function FGRL_backupFile {
    
    # Argumentos
    local _file=$1
    local _term=$2

    # Variables internas
    local _nFiles
    local _newID

    if [ ! -f "${_file}.${_term}" ]; then prt_warn "<FGRL_backupFile> No existe el fichero ${_file}.${_term}"; return 0; fi

    _nFiles=$( find . -maxdepth 1 -type f -name "${_file}-*.${_term}" | wc -l )
    if [ "${_nFiles}" == "0" ]
    then
        _newID=1
    else
        _newID=$( find . -maxdepth 1 -type f -name "${_file}-*.${_term}" -printf "%f\n" | gawk -F"${file}-" '{print $2}' | gawk -F".${_term}" '{print $1+1}' )
    fi
    prt_warn "-- El fichero ${_file}.${_term} pasa a ser ${G}${_file}-${_newID}.${_term}${NC}"
    cp "${_file}.${_term}" "${_file}-${_newID}.${_term}"
    
    return 0
}
export -f FGRL_backupFile
