-- ============================================================
-- ST0244 - Practica I: De los pixeles a la integral
-- PARTE I: Solucion funcional en Haskell

--
-- Idea central: la matriz de alturas M es el resultado de
-- APLICAR una funcion f a cada posicion del dominio:
--
--     M = map f [0 .. ancho - 1]
--     area = sum M
--
-- Todo lo demas (lectura del PBM, acceso a bits, visualizacion)
-- son transformaciones auxiliares que alimentan esa idea central.
-- ============================================================

module Main where

import qualified Data.ByteString as BS
import Data.ByteString (ByteString)
import Data.Bits (testBit)
import Data.Word (Word8)
import Data.List (intercalate)
import Text.Printf (printf)
import System.Environment (getArgs)
import System.IO (hSetEncoding, stdout, utf8)

-- ------------------------------------------------------------
-- Tipo que representa la imagen binaria ya cargada en memoria:
-- el ancho, el alto, cuantos bytes ocupa cada fila y los bytes
-- crudos de datos (sin la cabecera P4).
-- ------------------------------------------------------------
data Imagen = Imagen
  { ancho        :: Int
  , alto         :: Int
  , bytesPorFila :: Int
  , datos        :: ByteString
  } deriving Show

-- ------------------------------------------------------------
-- 1. CARGA DEL ARCHIVO PBM P4
-- ------------------------------------------------------------
-- El formato PBM "P4" es binario. La cabecera es texto ASCII:
--   P4
--   [# comentarios opcionales]
--   ancho alto
-- seguida de UN solo caracter en blanco y luego los datos
-- binarios: cada fila ocupa ceil(ancho/8) bytes, y cada byte
-- empaqueta hasta 8 pixeles (bit 1 = negro, bit 0 = blanco).

-- Separa la cabecera textual de los datos binarios, saltando
-- espacios en blanco y comentarios ('#' hasta fin de linea).
parseCabecera :: ByteString -> (String, Int, Int, ByteString)
parseCabecera bs0 =
  let (magic, bs1) = leerToken bs0
      (wStr,  bs2) = leerToken bs1
      (hStr,  bs3) = leerToken bs2
      -- tras el ultimo numero viene exactamente UN byte en
      -- blanco (segun la especificacion PBM) y luego los datos
      bsDatos      = BS.drop 1 bs3
  in (magic, read wStr, read hStr, bsDatos)

-- Salta espacios en blanco y comentarios, y luego lee un token
-- (secuencia de caracteres no-blancos).
leerToken :: ByteString -> (String, ByteString)
leerToken bs =
  let bs' = saltarBlancosYComentarios bs
      (tok, resto) = BS.span (not . esBlanco) bs'
  in (map (toEnum . fromIntegral) (BS.unpack tok), resto)

saltarBlancosYComentarios :: ByteString -> ByteString
saltarBlancosYComentarios bs =
  let bs1 = BS.dropWhile esBlanco bs
  in if not (BS.null bs1) && BS.head bs1 == comentario
       then saltarBlancosYComentarios (BS.dropWhile (/= nl) bs1)
       else bs1
  where
    comentario = fromIntegral (fromEnum '#')
    nl         = fromIntegral (fromEnum '\n')

esBlanco :: Word8 -> Bool
esBlanco w = w `elem` map (fromIntegral . fromEnum) " \t\n\r"

-- Carga completa: de bytes de archivo a una Imagen tipada.
cargarPBM :: FilePath -> IO Imagen
cargarPBM ruta = do
  contenido <- BS.readFile ruta
  let (magic, w, h, bsDatos) = parseCabecera contenido
  if magic /= "P4"
    then error ("Formato no soportado (se esperaba P4): " ++ magic)
    else return Imagen
           { ancho        = w
           , alto         = h
           , bytesPorFila = (w + 7) `div` 8
           , datos        = bsDatos
           }

-- ------------------------------------------------------------
-- 2. ACCESO A PIXELES INDIVIDUALES
-- ------------------------------------------------------------
-- El pixel (x, y) vive en el bit (7 - x mod 8) del byte
-- ubicado en la fila y, columna (x div 8). En PBM, 1 = negro.
esNegro :: Imagen -> Int -> Int -> Bool
esNegro img x y =
  let fila       = y * bytesPorFila img
      byteIdx    = fila + (x `div` 8)
      byte       = BS.index (datos img) byteIdx
      bitIdx     = 7 - (x `mod` 8)
  in testBit byte bitIdx

-- ------------------------------------------------------------
-- 3. LA FUNCION DISCRETA f(x)
-- ------------------------------------------------------------
-- Para una columna x, se recorre desde el fondo de la imagen
-- (y = alto-1) hacia arriba, contando pixeles negros
-- consecutivos hasta encontrar el primer blanco.
--
-- Se expresa como el largo del prefijo negro de la lista de
-- pixeles de la columna leida de abajo hacia arriba: esto es
-- 'takeWhile' sobre una lista perezosa, el estilo idiomatico
-- de Haskell (no un bucle imperativo con contador mutable).
f :: Imagen -> Int -> Int
f img x = length (takeWhile id columnaDeAbajoHaciaArriba)
  where
    columnaDeAbajoHaciaArriba = [ esNegro img x y | y <- [alto img - 1, alto img - 2 .. 0] ]

-- ------------------------------------------------------------
-- 4. LA ESTRUCTURA DE ALTURAS M
-- ------------------------------------------------------------
-- M = [f(0), f(1), ..., f(ancho-1)]
-- Es, literalmente, la funcion f APLICADA a todo el dominio:
--     M = map f [0 .. ancho - 1]
alturas :: Imagen -> [Int]
alturas img = map (f img) [0 .. ancho img - 1]

-- ------------------------------------------------------------
-- 5. SUMA DE RIEMANN -> AREA
-- ------------------------------------------------------------
-- Como cada columna tiene base Δx = 1 pixel, el area es
-- simplemente la suma de las alturas:
--     area = sum M
area :: [Int] -> Int
area = sum

-- ------------------------------------------------------------
-- 6. VISUALIZACION DE LA IMAGEN BINARIA EN CONSOLA
-- ------------------------------------------------------------
-- Estrategia de escalado: la terminal tiene ~ (colsDeseadas x
-- filasDeseadas) caracteres disponibles, mientras que la
-- imagen es de (ancho x alto) pixeles, mucho mas grande.
--
-- Para cada caracter de la consola se muestrea (sampling) el
-- pixel del bloque de la imagen original que le corresponde
-- proporcionalmente (nearest-neighbor). Esto preserva la forma
-- general de la curva sin necesidad de recorrer o imprimir
-- cada uno de los pixeles originales.
visualizarImagen :: Imagen -> Int -> Int -> String
visualizarImagen img colsDeseadas filasDeseadas =
  intercalate "\n"
    [ [ caracterEn c fila | c <- [0 .. colsDeseadas - 1] ]
    | fila <- [0 .. filasDeseadas - 1] ]
  where
    w = ancho img
    h = alto img
    caracterEn c fila =
      let x = (c * w) `div` colsDeseadas
          y = (fila * h) `div` filasDeseadas
      in if esNegro img x y then '#' else '.'

-- ------------------------------------------------------------
-- 7. VISUALIZACION DE LA FUNCION DE ALTURAS M[x] = f(x)
-- ------------------------------------------------------------
-- Se muestrea M a 'colsDeseadas' columnas y se dibuja cada
-- columna como una barra vertical de bloques Unicode, escalada
-- a 'filasDeseadas' de alto segun la altura maxima observada.
bloques :: String
bloques = " ▁▂▃▄▅▆▇█"

visualizarAlturas :: [Int] -> Int -> Int -> String
visualizarAlturas m colsDeseadas filasDeseadas =
  intercalate "\n" [ [ caracterEn c fila | c <- [0 .. colsDeseadas - 1] ]
                    | fila <- [filasDeseadas - 1, filasDeseadas - 2 .. 0] ]
  where
    n       = length m
    maxAlt  = maximum m
    muestreado c = m !! ((c * n) `div` colsDeseadas)
    -- altura de la barra en "octavos de fila", para poder usar
    -- caracteres de bloque parcial en la fila superior
    nivelTotal c = (muestreado c * filasDeseadas * 8) `div` max 1 maxAlt
    caracterEn c fila
      | fila < nivelTotal c `div` 8     = '█'
      | fila == nivelTotal c `div` 8    = bloques !! (nivelTotal c `mod` 8)
      | otherwise                       = ' '

-- ------------------------------------------------------------
-- 8. VALORES DE MUESTRA x_i -> f(x_i)
-- ------------------------------------------------------------
-- Se seleccionan 'n' posiciones distribuidas uniformemente en
-- el dominio [0, ancho-1] y se listan junto a su f(x_i), tal
-- como pide el enunciado.
valoresMuestra :: [Int] -> Int -> [(Int, Int)]
valoresMuestra m n =
  let w = length m
      xs = [ (i * (w - 1)) `div` max 1 (n - 1) | i <- [0 .. n - 1] ]
  in [ (x, m !! x) | x <- xs ]

-- ------------------------------------------------------------
-- PROGRAMA PRINCIPAL
-- ------------------------------------------------------------
main :: IO ()
main = do
  hSetEncoding stdout utf8
  args <- getArgs
  let ruta = case args of
               (r:_) -> r
               []    -> "../curva_binaria_P4.pbm"

  img <- cargarPBM ruta
  printf "Imagen cargada: %d x %d pixeles\n" (ancho img) (alto img)

  -- M = map f [0 .. ancho - 1]   <-- transformacion funcional del dominio
  let m = alturas img
  -- area = sum M                <-- suma de Riemann
  let a = area m

  putStrLn ""
  putStrLn "== Vista de la curva (imagen binaria escalada a la consola) =="
  putStrLn (visualizarImagen img 90 30)

  putStrLn ""
  putStrLn "== Funcion de alturas M[x] = f(x) =="
  putStrLn (visualizarAlturas m 90 15)

  putStrLn ""
  putStrLn "== Valores de muestra x_i -> f(x_i) =="
  let muestras = zip [0 :: Int ..] (valoresMuestra m 10)
  mapM_ (\(i, (x, fx)) ->
            printf "x_%d = %-4d -> f(x_%d) = %d pixeles\n" i x i fx)
        muestras

  putStrLn ""
  printf "Cada columna tiene base = 1 pixel (Delta x = 1)\n"
  printf "Area = suma de f(x_i)  (Riemann sum: A = sum_{x=0}^{n-1} f(x))\n"
  printf "Area = %d pixeles cuadrados\n" a
