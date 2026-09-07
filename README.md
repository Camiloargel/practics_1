# Práctica I: De los píxeles a la integral
**Por:** Camilo Argel - Nicolás Gil

Repositorio para la primera práctica del curso ST0244, enfocada en el procesamiento digital de imágenes a bajo nivel (formato PBM P4) y su conversión a un modelo matemático discreto para calcular el área mediante sumas de Riemann. El proyecto cuenta con dos implementaciones independientes bajo diferentes paradigmas:

* **Paradigma Funcional:** Implementado en Haskell.
* **Paradigma Declarativo / Lógico:** Implementado en Prolog.

---

## Estructura del Repositorio

```text
├── Haskell/
│   └── Main.hs
├── Prolog/
│   └── main.pl
├── curva_binaria_P4.pbm
└── README.md
```
Entorno de Desarrollo
Sistema operativo: Windows

Editor: Visual Studio Code

Haskell: GHC (verificar versión con ghc --version)

Prolog: SWI-Prolog (verificar versión con swipl --version)

Cómo Ejecutar
1. Haskell
Desde la carpeta Haskell/:

Bash

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

ghc -O2 -o main Main.hs

./main ../curva_binaria_P4.pbm

2. Prolog
Desde la carpeta Prolog/:

Bash

swipl main.pl ../curva_binaria_P4.pbm


Estrategia de Visualización en Consola
La imagen original (567 × 319 píxeles) es mucho más grande que una terminal. Por eso se usa muestreo espacial (nearest-neighbor): por cada carácter disponible en la consola, se calcula proporcionalmente a qué píxel de la imagen original le corresponde, y solo se consulta ese píxel. Así se conserva la forma general de la curva sin imprimir los más de 180 000 píxeles originales.

Área Obtenida
Ambos programas calculan exactamente la misma área sobre curva_binaria_P4.pbm:

Área = 108660 píxeles cuadrados

Este resultado coincide con la implementación de referencia en C++ del profesor, confirmando que ambos paradigmas llegan al mismo resultado matemático.

