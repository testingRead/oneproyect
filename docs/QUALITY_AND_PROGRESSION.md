# Calidad, personajes y progresión

## Perfiles sin duplicar recursos

Los tres perfiles usan las mismas escenas, mallas y texturas:

| Perfil | Antialiasing | Traje | Sombra de la única luz |
| --- | --- | --- | --- |
| Baja | Desactivado | Color plano | Desactivada |
| Media | MSAA 2× | Atlas 256×256 | Desactivada |
| Alta | MSAA 4× | Atlas 256×256 | Activada |

Esto mantiene un solo APK pequeño. Las texturas importadas pueden usar mipmaps y
la compresión de VRAM de Godot; los futuros modelos importados podrán usar el LOD
automático. Sólo se añadirá una variante física de una malla cuando su silueta
realmente lo justifique.

El perfil **Baja** sigue siendo el predeterminado y conserva el presupuesto de
una luz, sin sombras, sin posprocesamiento y con geometría sencilla. Los perfiles
altos son opcionales y deben medirse en cada teléfono.
No se ofrece FXAA porque el renderer Compatibility no lo admite.

Referencias:

- https://docs.godotengine.org/en/stable/tutorials/3d/resolution_scaling.html
- https://docs.godotengine.org/en/latest/tutorials/performance/optimizing_3d_performance.html
- https://docs.godotengine.org/en/latest/tutorials/performance/gpu_optimization.html

## Identidad y progreso

El perfil genera un identificador aleatorio de instalación y almacena por
separado victorias, experiencia, minijuegos jugados y supervivencias
multijugador. El modo local no modifica esos contadores. Cada clasificación
lleva un identificador de minijuego para que una retransmisión o reconexión no
otorgue dos veces la misma recompensa.

El preset Android activa
`retain_data_on_uninstall`, que permite que Android pregunte si se quieren
conservar los datos al desinstalar.

Esto no garantiza recuperación: si el usuario elimina los datos, rechaza
conservarlos, cambia de teléfono o el sistema no ofrece la opción, el perfil se
pierde. Una economía definitiva necesita una cuenta o un código de recuperación
guardado en el servidor. El identificador local tampoco debe tratarse como una
credencial segura.

La variante dorada cuesta cinco victorias durante el prototipo. Antes de vender
o intercambiar objetos habrá que mover saldo y desbloqueos a almacenamiento
autoritativo.

Referencia del preset Android:

- https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformandroid.html
