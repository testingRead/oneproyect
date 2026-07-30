# Contrato de escala de la base local

Una unidad de Godot equivale a un metro. La fuente ejecutable de estas medidas
es `shared/gameplay_scale.gd`; escenas y scripts no deben copiar números.

## Personaje estándar

| Medida | Valor |
| --- | ---: |
| Altura visual | 1,80 m |
| Ancho de torso | 0,72 m |
| Masa física de referencia | 70 kg |
| Altura de cápsula | 1,72 m |
| Radio de cápsula | 0,34 m |
| Origen lógico | planta de los pies, `y = 0` |
| Offset visual de suelo | 0,00 m |
| Escalón objetivo | 0,30 m |
| Floor snap | 0,28 m |
| Caminar | 3,60 m/s |
| Correr | 6,00 m/s |
| Salto | 1,35 m |
| Distancia balística aproximada al correr | 4,65 m |

La colisión se desplaza hacia arriba la mitad de su altura. Ni el modelo ni el
`CharacterRoot` se desplazan para ocultar errores de contacto. El marcador
`AnchorPoints/Feet`, el punto inferior de la cápsula y el origen lógico
coinciden.

Las siluetas de prueba baja (`0,86`), estándar (`1,00`) y alta (`1,14`) escalan
la altura visual y la cápsula alrededor del mismo origen de pies. Comparten
escena, controlador, cámara, animación y anclajes.

## Mundo y objetos

| Referencia | Valor |
| --- | ---: |
| Mundo físico | 150 × 150 m |
| Isla contenedora | 120 × 120 m |
| Área pequeña | 30 × 30 m |
| Área mediana | 60 × 60 m |
| Área grande | 100 × 100 m |
| Plataforma estándar | 0,45 m |
| Puerta mínima | 2,20 m |
| Paso mínimo | 1,10 m |
| Objeto pequeño | 0,40 m |
| Objeto mediano | 1,00 m |
| Objeto grande | 2,00 m |
| Balón | 0,44 m · 0,43 kg |
| Piedra equipable | 0,28 m · 0,32 kg |

El mundo físico no cambia entre rondas. La costa mantiene cuatro colisiones
invisibles permanentes en el borde de la isla para impedir entrar al océano.
`LocalPlayableArea` conserva 30/60/100 m como zonas lógicas de eventos; sus
cuatro barreras internas están desactivadas por defecto y sólo se habilitan si
un minijuego declara `PHYSICAL_AREA`.
