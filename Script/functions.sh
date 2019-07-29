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
#                     Va registrando las permutaciones que estan ya hechas, para porder ir usandolas.
#                     Cuando detecta la existencia del fichero "${DIR_TMP}/PERMUTACIONES.REGISTRO", para.
#     Entrada   --->  $1 = fichero
#                     $2 = iteracion
#                     $3 = combinacion (la inicial siempre es: 1 2 3 4...)
#                     $4 = total, que es longitud(combinacion), pero se pasa para no calcular todo el rato
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
    local _comb=${3}
    local _totalGeneral=$4

    # Variables internas
    local _indice
    local _posPivote
    local _valorPivoteActual
    local _valorPivoteNuevo
    local _fijos
    local _variables
    local _val
    local _valSig
    local _detrasIndice
    local _yaOrdenado
    local _preComb
    local _total
    local _maxValue

    if [ -f "${DIR_TMP}/PARA.PERMUTACIONES" ]; then return 0; fi

    # -- control de errores
    if [ "$( echo -e "${_comb}" | gawk '{print NF}' )" != "${_totalGeneral}" ]; then echo "<FGRL_getPermutacion_conPesos> Error porque [${_comb}] no tiene ${_totalGeneral} elementos"; return 1; fi

    # Para ejecutar en background
    if [ "${_iteracion}" == "1" ]; then rm -f "${DIR_TMP}/PERMUTACIONES.REGISTRO"; touch "${DIR_TMP}/PERMUTACIONES.REGISTRO"; fi
    
    # Se escribe la original
    while read -r _indice; do head -"${_indice}" "${_file}" | tail -1 >> "${_file}.function${_iteracion}"; done < <( echo -e "${_comb}" | sed 's/ /\n/g' )
    echo "${_file}.function${_iteracion}" >> "${DIR_TMP}/PERMUTACIONES.REGISTRO"  # registra la permutacion que acaba de generar
    _iteracion=$(( _iteracion + 1 ))

    # **** INDICA QUE YA HA CREADO AL MENOS UNA INTERACION
    touch "${DIR_TMP}/INICIO.PERMUTACIONES"

    # CONDICION DE PARADA (1): cuando se llegue a la numeracion al reves (si tenemos 1 2 3 4 --> para con 4 3 2 1)
    _parada=$( seq ${_totalGeneral} -1 1 | xargs printf "%d " | sed -r "s/^ +//g; s/ +$//g;" )
    if [ "${_comb}" == "${_parada}" ]; then return 0; fi

    # Cuando ya tenemos el maximo a la derecha del todo, lo quitamos para calcular la posicion del pivote
    _yaOrdenado=0
    _total=${_totalGeneral}
    for _indice in $( seq 1 "${_total}" )
    do
        if [ "$( echo -e "${_parada}" | gawk '{print $POS}' POS="${_indice}" )" != "$( echo -e "${_comb}" | gawk '{print $POS}' POS="${_indice}" )" ]; then break; fi
        _yaOrdenado=${_indice}
        _total=$(( _total - 1 ))
    done
    _preComb=$( echo -e "${_comb}" | gawk '{for(i=1;    i<=POS;i++) printf("%d ",$i)}' POS=${_yaOrdenado} | sed -r "s/^ +//g; s/ +$//g;" )
    _comb=$(    echo -e "${_comb}" | gawk '{for(i=POS+1;i<=NF; i++) printf("%d ",$i)}' POS=${_yaOrdenado} | sed -r "s/^ +//g; s/ +$//g;" )
    if [ "${_comb}" == "" ]; then return 0; fi
    
    
    # Genera la siguiente comb
    # -- localiza cual es el termino que hace de pivote
    # -------- si tenemos 1 2 3 4, queremos que el pivote en la posicion 1 sea el 4, que es el numero mas alto)
    # -------- pero tenemos que ir de 1 en 1. Primero el 1 despues el 2...
    # -------- para poder elegir el 1, en la siguiente posicion tiene que haber un 4
    # -------- si no es asi, tendremos que mirar: 2 3 4 (ignorando el 1)
    _posPivote=""
    _maxValue=${_total}
    for _indice in $( seq 1 $(( _total-1 )) )
    do
        _val=$(    echo -e "${_comb}" | gawk '{print $(POS)}'   POS="${_indice}" )
        _valSig=$( echo -e "${_comb}" | gawk '{print $(POS+1)}' POS="${_indice}" )
        _detrasIndice=$( echo -e "${_comb}" | gawk '{for(i=POS+1;i<=NF;i++) printf("%d ",$i)}' POS="${_indice}" | sed -r "s/^ +//g; s/ +$//g;" )
        _detrasIndiceSorted=$( echo -e "${_detrasIndice}" | sed 's/ /\n/g' | sort -r | xargs printf "%d " | sed -r "s/^ +//g; s/ +$//g;" )
        if [ "${_val}" != "${_maxValue}" ] && ( [ "${_valSig}" == "${_maxValue}" ] || [ "${_maxValue}" != "${_total}" ] ) && [ "${_detrasIndice}" == "${_detrasIndiceSorted}" ]
        then
            _posPivote=${_indice}; break
        fi
        if [ "${_val}" == "${_maxValue}" ]; then _maxValue=$(( _maxValue - 1 )); fi
    done

    # -- mira los que estan fijos, que son los que hay antes del pivote
    _fijos=$( echo -e "${_comb}" | gawk '{for(i=1;i<POS;i++) printf("%d ",$i)}' POS="${_posPivote}" )
    
    # -- los variables son el resto
    _variables=$( echo -e "${_comb}" | gawk '{for(i=POS;i<=NF;i++) printf("%d ",$i)}' POS="${_posPivote}" )

    # -- el nuevo valor del pivote debe ser mayor que el valor actual, pero sin estar en los fijos
    _valorPivoteActual=$( echo -e "${_comb}" | gawk '{print $POS}' POS="${_posPivote}" )
    _valorPivoteNuevo=$(( _valorPivoteActual + 1 ))
    for _indice in $( seq "${_valorPivoteNuevo}" "${_totalGeneral}" )
    do
        if [ "$( echo -e "${_fijos}" | sed 's/ /\n/g' | grep "${_indice}" )" == "" ]; then break; fi
    done
    _valorPivoteNuevo=${_indice}
    
    # *** a los variables hay que quitar el nuevo valor del pivote
    _variables=$( echo -e "${_variables}" | sed 's/ /\n/g' | grep -v "${_valorPivoteNuevo}" | xargs printf "%d " )
    
    # *** a los fijos hay que anadir el nuevo pivote
    _fijos=$( echo -e "${_fijos} ${_valorPivoteNuevo}" )
    
    # -- ordena los variables
    _variables=$( echo -e "${_variables}" | sed 's/ /\n/g' | sort | xargs printf "%d " )
    
    # -- une los fijos con los variables ordenados (eliminando blancos por delantes y por detras)
    _comb=$( echo -e "${_preComb} ${_fijos} ${_variables}" | sed -r "s/  / /g; s/^ +//g; s/ +$//g;" )

    # Vuelve a hacer lo mismo
    if [ -f "${DIR_TMP}/PARA.PERMUTACIONES" ]; then return 0; fi
    FGRL_getPermutacion_conPesos "${_file}" "${_iteracion}" "${_comb}" "${_totalGeneral}"

    # Fin (==2, porque la 1 ya se ha escrito y se ha aumentado el contador)
    if [ "${_iteracion}" == "2" ]
    then
        echo "DONE" >> "${DIR_TMP}/PERMUTACIONES.REGISTRO"
    fi
    return 0
}
export -f FGRL_getPermutacion_conPesos


##########
# - FGRL_getPermutacion_conPesos
#     Funcion   --->  Igual que FGRL_getPermutacion_conPesos, pero asume que las lineas de los ficheros
#                     son de la forma: "peso texto". Esta funcion tambien genera permutaciones, pero lo hace
#                     de manera ordenada para ir usando esas permutaciones.
#                     Va registrando las permutaciones que estan ya hechas, para porder ir usandolas.
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
function FGRL_getPermutacion_conPesos_BCK {

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
export -f FGRL_getPermutacion_conPesos_BCK


##########
# - FGRL_backupFile
#     Funcion   --->  hace backup del fichero actual (teniendo en cuenta el actual y los que hay en Historico)
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
    local _lastFile

    if [ ! -f "${_file}.${_term}" ]; then prt_warn "<FGRL_backupFile> No existe el fichero ${_file}.${_term}"; return 0; fi

    if [ ! -d Historico ]; then prt_error "<FGRL_backupFile> No existe el directorio Historico"; return 1; fi
       
    _nFiles=$( find Historico/ -maxdepth 1 -type f -name "${_file}-*.${_term}" | wc -l )

    # Si no hay ficheros en el Historico, se hace el backup y ya
    if [ "${_nFiles}" == "0" ]
    then
        _newID=1
        prt_warn "-- El fichero ${_file}.${_term} pasa a ser ${G}Historico/${_file}-${_newID}.${_term}${NC}"
        cp "${_file}.${_term}" "Historico/${_file}-${_newID}.${_term}"
        return 0
    fi

    # Si ya hay ficheros, solo se hara backup si el nuevo es diferente al ultimo, sino no se hara nada
    _lastFile=$( find Historico/ -maxdepth 1 -type f -name "${_file}-*.${_term}" -printf "%f\n" | gawk -F"${file}-" '{print $2+0"|"$0}' | sort -u -g -t"|" -k1,1 | tail -1 | gawk -F"|" '{print $2}' )
    if [ "$( diff "Historico/${_lastFile}" "${_file}.${_term}" )" != "" ]
    then
        _newID=$( echo -e "${_lastFile}" | gawk -F"${file}-" '{print $2+0}' | gawk -F".${_term}" '{print $1+1}' )
        prt_warn "-- El fichero ${_file}.${_term} pasa a ser ${G}Historico/${_file}-${_newID}.${_term}${NC}"
        cp "${_file}.${_term}" "Historico/${_file}-${_newID}.${_term}"
        return 0
    fi

    # Si no son diferentes, se avisa y no se hace nada
    prt_warn "<FGRL_backupFile> El fichero ${_file}.${_term} y Historico/${_lastFile} son iguales, asi que no se hace backup"
    
    return 0
}
export -f FGRL_backupFile
