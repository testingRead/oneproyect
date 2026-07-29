# Exportación local en el POCO

## Estado comprobado del teléfono

El POCO X7 Pro ya funciona como worker ARM64 de validación:

- Godot oficial 4.7.1 ARM64 está fijado en
  `$HOME/toolchains/godot-4.7.1/godot`;
- Java, Gradle, Android SDK, `aapt2`, `apksigner`, `adb`, Clang y Cargo están
  disponibles;
- el proyecto público vive en `$HOME/projects/oneproyect`;
- `glibc`, `glibc-runner` y `fontconfig-glibc` permiten ejecutar el binario
  directamente con `grun`, sin proot;
- el smoke test y la prueba ENet de tres procesos funcionan con la caché
  `.godot` importada.

El runtime nativo con `grun` es estable y más rápido que proot. El
editor/exportador Linux ARM64, en cambio, aborta en una liberación de memoria
tanto con proot como con `grun`; tampoco llega a producir un PCK. Por tanto, el
POCO ya es un worker útil para tests ARM64 paralelos, pero no se considera una
ruta de exportación reproducible. GitHub Actions sigue exportando APK y servidor.

## Conclusión

Termux y TUR no empaquetan Godot, pero el binario Linux ARM64 oficial se ejecuta
con `glibc-runner`. La ruta Android soportada para editar y exportar visualmente
sigue siendo el **Editor Android de Godot 4.7.1**.

El editor Android aún no está instalado en el POCO. Termux sí está preparado:
Git funciona, `termux-open` está disponible, el almacenamiento compartido está
montado y quedan aproximadamente 140 GiB libres.

## Worker de pruebas

Después de sincronizar fuentes y la caché de clases, una prueba se ejecuta con:

```sh
grun "$HOME/toolchains/godot-4.7.1/godot" \
  --headless \
  --path "$HOME/projects/oneproyect" \
  --script res://tests/smoke_test.gd
```

Codec, sala y smoke pueden lanzarse como tres procesos en segundo plano. Así se
usan varios núcleos sin activar el importador que falla. La prueba servidor +
dos clientes también corre en paralelo y valida UDP, ACK, movimiento y
reconexión en ARM64. Para Gradle u otras herramientas que lo admitan se usarán
`--parallel --max-workers=6`; dos núcleos quedan para Android, SSH y picos de
memoria.

## Preparación única

1. Instalar Godot Engine 4.7.1 para Android desde la
   [página oficial](https://godotengine.org/download/android/). Elegir la
   versión estable, no una preview.
2. Conceder al editor acceso a todos los archivos y permiso para instalar APK.
3. Obtener una copia pública sin credenciales desde Termux:

   ```sh
   cd "$HOME/storage/downloads"
   git clone --depth 1 --branch agent/graybox \
     https://github.com/testingRead/oneproyect.git oneproyect
   ```

4. En Godot Android, importar:
   `/storage/emulated/0/Download/oneproyect/project.godot`.

Godot 4.7 puede exportar un APK normal desde el editor Android sin JDK, Android
SDK ni la aplicación GABE. GABE sólo es necesaria para una exportación Gradle;
los dos presets del proyecto usan las plantillas APK precompiladas.

## Exportar

1. Abrir **Project > Export**.
2. Elegir `Android Debug ARM64` para el POCO.
3. Para conservar la misma identidad de instalación, configurar localmente el
   keystore de debug con:
   `/storage/emulated/0/Download/Telegram/mi-release.jks`.
4. Introducir en la interfaz el alias y las contraseñas ya conocidas. No
   escribirlas en scripts ni subir el `export_presets.cfg` modificado.
5. Exportar a `/storage/emulated/0/Download/oneproyect-local-arm64.apk`.

El preset `Android Debug ARM32` queda únicamente para teléfonos antiguos. No se
deben combinar ARM32 y ARM64 en un APK universal, porque volvería a aumentar el
peso sin ayudar al POCO.

## Tamaño

Los APK actuales ya separan arquitecturas, usan una textura WebP pequeña y no
incluyen modelos, audio ni dependencias externas pesadas. La mayor parte del
peso restante pertenece a la plantilla oficial de Godot.

Una reducción mucho mayor exigiría compilar una plantilla Android personalizada
del motor, desactivando módulos no usados. No conviene hacerlo todavía: la
documentación de Godot indica que LTO requiere mucha memoria, y mantener una
plantilla propia añade tiempo de build y riesgo. Se evaluará cuando el conjunto
de funciones del juego esté estabilizado.

Fuentes oficiales:

- [Editor Android de Godot 4.7](https://docs.godotengine.org/en/4.7/tutorials/editor/using_the_android_editor.html)
- [Descarga oficial para Android](https://godotengine.org/download/android/)
- [Exportación Android](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html)
- [Optimización del motor por tamaño](https://docs.godotengine.org/en/4.7/engine_details/development/compiling/optimizing_for_size.html)
