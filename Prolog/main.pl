% ============================================================
% ST0244 - Practica I: De los pixeles a la integral
% PARTE II: Solucion declarativa en Prolog
% Autor: (equipo)
%
% Idea central: en vez de describir COMO calcular M y el area
% (un algoritmo, paso a paso), se describen las RELACIONES que
% deben cumplirse entre la imagen, una posicion X, su altura
% f(X) y el area resultante. Prolog encuentra los valores que
% satisfacen esas relaciones.
%
%   f(X, Datos, Alto, BytesPorFila, Altura)
%       <-- Altura es la altura de la columna X
%
%   findall(Altura, (between(0, MaxX, X), f(X,...,Altura)), M)
%       <-- M es la coleccion de TODAS las alturas que
%           satisfacen la relacion f/5
%
%   sum_list(M, Area)
%       <-- Area es la suma de esa lista
% ============================================================

:- initialization(main, main).

% ------------------------------------------------------------
% 1. CARGA DEL ARCHIVO PBM P4
% ------------------------------------------------------------
% El predicado cargar_pbm/5 relaciona una Ruta de archivo con
% el Ancho, el Alto, los BytesPorFila y los Datos binarios
% (una lista de bytes) de la imagen que contiene.

cargar_pbm(Ruta, Ancho, Alto, BytesPorFila, Datos) :-
    read_file_to_codes(Ruta, Codigos, [encoding(octet)]),
    % Version en bytes (0-255) para poder indexar bits comodamente
    string_codes(_, Codigos),
    codigos_a_bytes(Codigos, Bytes),
    parsear_cabecera(Bytes, "P4", Ancho, Alto, Datos),
    BytesPorFila is (Ancho + 7) // 8.

codigos_a_bytes(Codigos, Codigos).  % ya son codigos 0-255 (octet)

% parsear_cabecera(+Bytes, -Magic, -Ancho, -Alto, -Datos)
% Recorre la cabecera de texto (magic, comentarios opcionales,
% ancho, alto) y separa el resto como los datos binarios.
parsear_cabecera(Bytes, "P4", Ancho, Alto, Datos) :-
    leer_token(Bytes, MagicCodes, R0),
    string_codes(MagicStr, MagicCodes),
    string_to_atom(MagicStr, 'P4'),
    leer_token(R0, AnchoCodes, R1),
    number_codes(Ancho, AnchoCodes),
    leer_token(R1, AltoCodes, R2),
    number_codes(Alto, AltoCodes),
    % tras el ultimo numero hay exactamente UN byte en blanco
    R2 = [_UnBlanco | Datos].

% leer_token(+Bytes, -Token, -Resto)
% Salta blancos y comentarios ('#' hasta fin de linea) y
% extrae la siguiente secuencia de caracteres no blancos.
leer_token(Bytes, Token, Resto) :-
    saltar_blancos_comentarios(Bytes, Bytes1),
    take_no_blanco(Bytes1, Token, Resto).

saltar_blancos_comentarios(Bytes, Resto) :-
    drop_blancos(Bytes, Bytes1),
    (   Bytes1 = [0'# | _]
    ->  drop_hasta_nl(Bytes1, Bytes2),
        saltar_blancos_comentarios(Bytes2, Resto)
    ;   Resto = Bytes1
    ).

drop_blancos([C | Cs], Resto) :- es_blanco(C), !, drop_blancos(Cs, Resto).
drop_blancos(Cs, Cs).

drop_hasta_nl([0'\n | Cs], Cs) :- !.
drop_hasta_nl([_ | Cs], Resto) :- !, drop_hasta_nl(Cs, Resto).
drop_hasta_nl([], []).

take_no_blanco([C | Cs], [C | Tok], Resto) :-
    \+ es_blanco(C), !, take_no_blanco(Cs, Tok, Resto).
take_no_blanco(Cs, [], Cs).

es_blanco(0' ).
es_blanco(0'\t).
es_blanco(0'\n).
es_blanco(0'\r).

% ------------------------------------------------------------
% 2. ACCESO A PIXELES INDIVIDUALES
% ------------------------------------------------------------
% pixel(X, Y, Datos, BytesPorFila, Valor)
% Relaciona la posicion (X,Y) con su valor de bit (0 o 1) dentro
% de los Datos binarios de la imagen. Un byte empaqueta 8
% pixeles; el pixel X vive en el bit (7 - X mod 8).
pixel(X, Y, Datos, BytesPorFila, Valor) :-
    FilaOffset is Y * BytesPorFila,
    ByteIdx is FilaOffset + (X // 8),
    nth0(ByteIdx, Datos, Byte),
    BitIdx is 7 - (X mod 8),
    Valor is (Byte >> BitIdx) /\ 1.

es_negro(X, Y, Datos, BytesPorFila) :-
    pixel(X, Y, Datos, BytesPorFila, 1).

% ------------------------------------------------------------
% 3. LA RELACION f(X) - altura de una columna
% ------------------------------------------------------------
% f(X, Datos, Alto, BytesPorFila, Altura)
% Altura es el numero de pixeles negros consecutivos contados
% desde el fondo de la imagen (Y = Alto-1) hacia arriba, hasta
% encontrar el primer pixel blanco. Se define recursivamente
% mediante un contador auxiliar altura_desde/6.
f(X, Datos, Alto, BytesPorFila, Altura) :-
    YInicial is Alto - 1,
    altura_desde(X, YInicial, Datos, BytesPorFila, 0, Altura).

% altura_desde(+X, +Y, +Datos, +BytesPorFila, +Acumulada, -Altura)
altura_desde(X, Y, Datos, BytesPorFila, Acc, Altura) :-
    Y >= 0,
    es_negro(X, Y, Datos, BytesPorFila),
    !,
    Acc1 is Acc + 1,
    Y1 is Y - 1,
    altura_desde(X, Y1, Datos, BytesPorFila, Acc1, Altura).
altura_desde(_, _, _, _, Acc, Acc).

% ------------------------------------------------------------
% 4. LA LISTA DE ALTURAS M, CONSTRUIDA DECLARATIVAMENTE
% ------------------------------------------------------------
% M es la coleccion de TODOS los valores Altura para los cuales
% existe una X en [0, Ancho-1] tal que f(X,...) = Altura.
% findall/3 recoge, en orden, cada solucion de la relacion.
alturas(Datos, Ancho, Alto, BytesPorFila, M) :-
    MaxX is Ancho - 1,
    findall(Altura,
            ( between(0, MaxX, X),
              f(X, Datos, Alto, BytesPorFila, Altura) ),
            M).

% ------------------------------------------------------------
% 5. SUMA DE RIEMANN -> AREA
% ------------------------------------------------------------
% Como cada columna tiene base Delta x = 1 pixel, el area es
% la suma de la lista de alturas.
area(M, Area) :- sum_list(M, Area).

% ------------------------------------------------------------
% 6. VISUALIZACION DE LA IMAGEN BINARIA EN CONSOLA
% ------------------------------------------------------------
% Estrategia de escalado: se muestrea (nearest-neighbor) un
% pixel de la imagen original por cada caracter disponible en
% la consola, igual que en la version Haskell, para preservar
% la forma general de la curva sin imprimir cada pixel.
visualizar_imagen(Datos, Ancho, Alto, BytesPorFila, ColsDeseadas, FilasDeseadas) :-
    forall(between(0, FilasDeseadas, Fila0),
           ( Fila0 < FilasDeseadas
           -> ( forall(between(0, ColsDeseadas, C0),
                       ( C0 < ColsDeseadas
                       -> ( X is (C0 * Ancho) // ColsDeseadas,
                            Y is (Fila0 * Alto) // FilasDeseadas,
                            ( es_negro(X, Y, Datos, BytesPorFila)
                            -> put_char('#')
                            ;  put_char('.') )
                          )
                       ;  true )),
                nl )
           ;  true )).

% ------------------------------------------------------------
% 7. VISUALIZACION DE LA FUNCION DE ALTURAS M[x] = f(x)
% ------------------------------------------------------------
% Se muestrea M a ColsDeseadas columnas y se dibuja cada una
% como una barra vertical de bloques Unicode, escalada segun
% la altura maxima observada en M.
% Los caracteres de bloque Unicode (U+2581 .. U+2588) se
% construyen a partir de su codepoint numerico con char_code/2,
% para no depender de que el archivo fuente .pl se relea con la
% codificacion correcta en cada entorno.
bloque_char(0, ' ') :- !.
bloque_char(N, Ch) :- Code is 0x2580 + N, char_code(Ch, Code).

visualizar_alturas(M, ColsDeseadas, FilasDeseadas) :-
    length(M, N),
    max_list(M, MaxAlt),
    MaxAltSeg is max(1, MaxAlt),
    ( between(1, FilasDeseadas, FilaInv),
      Fila is FilasDeseadas - FilaInv,
      forall(between(0, ColsDeseadas, C0),
             ( C0 < ColsDeseadas
             -> ( Idx is (C0 * N) // ColsDeseadas,
                  nth0(Idx, M, Altura),
                  NivelTotal is (Altura * FilasDeseadas * 8) // MaxAltSeg,
                  NivelFila is NivelTotal // 8,
                  ( Fila < NivelFila
                  -> ( char_code(ChFull, 0x2588), put_char(ChFull) )
                  ;  Fila =:= NivelFila
                  -> ( Resto is NivelTotal mod 8,
                       bloque_char(Resto, Ch),
                       put_char(Ch) )
                  ;  put_char(' ')
                  )
                )
             ;  true )),
      nl,
      fail
    ; true ).

% ------------------------------------------------------------
% 8. VALORES DE MUESTRA x_i -> f(x_i)
% ------------------------------------------------------------
% Se seleccionan N posiciones distribuidas uniformemente en el
% dominio de M y se listan junto a su valor f(x_i).
valores_muestra(M, N, Muestras) :-
    length(M, Ancho),
    AnchoM1 is Ancho - 1,
    NM1 is max(1, N - 1),
    findall(X-Fx,
            ( between(0, NM1, I),
              X is (I * AnchoM1) // NM1,
              nth0(X, M, Fx) ),
            Muestras).

imprimir_muestras(Muestras) :-
    imprimir_muestras(Muestras, 0).
imprimir_muestras([], _).
imprimir_muestras([X-Fx | Resto], I) :-
    format("x_~w = ~w~t~10| -> f(x_~w) = ~w pixeles~n", [I, X, I, Fx]),
    I1 is I + 1,
    imprimir_muestras(Resto, I1).

% ------------------------------------------------------------
% PROGRAMA PRINCIPAL
% ------------------------------------------------------------
main(Argv) :-
    set_stream(user_output, encoding(utf8)),
    ( Argv = [Ruta | _] -> true ; Ruta = '../curva_binaria_P4.pbm' ),

    cargar_pbm(Ruta, Ancho, Alto, BytesPorFila, Datos),
    format("Imagen cargada: ~w x ~w pixeles~n", [Ancho, Alto]),

    % M: lista de alturas obtenida declarativamente con findall/3
    alturas(Datos, Ancho, Alto, BytesPorFila, M),
    % Area: suma de Riemann sobre esa lista
    area(M, Area),

    nl,
    write('== Vista de la curva (imagen binaria escalada a la consola) =='), nl,
    visualizar_imagen(Datos, Ancho, Alto, BytesPorFila, 90, 30),

    nl,
    write('== Funcion de alturas M[x] = f(x) =='), nl,
    visualizar_alturas(M, 90, 15),

    nl,
    write('== Valores de muestra x_i -> f(x_i) =='), nl,
    valores_muestra(M, 10, Muestras),
    imprimir_muestras(Muestras),

    nl,
    format("Cada columna tiene base = 1 pixel (Delta x = 1)~n", []),
    format("Area = suma de f(x_i)  (Riemann sum: A = sum_{x=0}^{n-1} f(x))~n", []),
    format("Area = ~w pixeles cuadrados~n", [Area]),

    halt.

main(_) :-
    write('Error: no se pudo procesar la imagen.'), nl,
    halt(1).
