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
- el wrapper `tools/android-native` empaqueta los recursos sobre el AAR oficial
  de Godot y produce un APK ARM64 firmado sin ejecutar el editor Linux.

El runtime nativo con `grun` es estable y más rápido que proot. El
editor/exportador Linux ARM64 todavía aborta en una liberación de memoria, por
lo que no se usa. El wrapper Android evita por completo esa ruta: Gradle
reutiliza sus cachés, ejecuta seis workers y empaqueta el proyecto como assets
del AAR oficial de Godot 4.7.1.

## Conclusión

La ruta reproducible principal del laboratorio es ahora Termux:

```sh
cd "$HOME/projects/oneproyect/tools/android-native"
./build-termux.sh
```

La ruta recomendada antes de entregar una prueba ejecuta seis procesos de test
en paralelo, valida después dos peers ENet y sólo entonces compila:

```sh
cd "$HOME/projects/oneproyect/tools/android-native"
TEST_WORKERS=6 GRADLE_WORKERS=6 ./validate-and-build-termux.sh
```

Gradle mantiene ahora su daemon vivo entre iteraciones para reutilizar JVM,
configuración y cachés. Los ocho núcleos no se ocupan todos: seis trabajan y dos
quedan disponibles para Android, SSH y picos de memoria.

El resultado se valida por firma y ABI y se copia a
`Downloads/oneproyect-android-native-local.apk`. ADB no interviene. El Editor
Android de Godot sigue siendo una alternativa para iteración visual manual.

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

## Exportación visual alternativa

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

Los APK de GitHub separan arquitecturas y comprimen las bibliotecas nativas; el
APK directo de Termux sólo contiene ARM64. Los modelos existentes son low-poly
y los efectos nuevos del shooter se generan con geometría y audio pequeños en
tiempo de carga. La mayor parte del peso restante pertenece a la plantilla
oficial de Godot.

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
