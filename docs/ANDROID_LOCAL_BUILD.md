# Exportación local en el POCO

## Conclusión

Termux no ofrece un comando oficial de Godot para exportar este proyecto. La
ruta local soportada es usar Termux para Git y el **Editor Android de Godot
4.7.1** para importar, ejecutar y exportar el APK.

El editor Android aún no está instalado en el POCO. Termux sí está preparado:
Git funciona, `termux-open` está disponible, el almacenamiento compartido está
montado y quedan aproximadamente 140 GiB libres.

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
