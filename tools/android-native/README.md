# Android native runner

Wrapper experimental basado en la biblioteca Android oficial de Godot. Empaqueta
el proyecto directamente como assets y evita ejecutar el editor Linux en
Termux.

Desde el POCO:

```sh
cd "$HOME/projects/oneproyect/tools/android-native"
./build-termux.sh
```

Para ejecutar primero toda la regresión local y LAN, aprovechando cuatro
procesos Godot y compilando únicamente si todos pasan:

```sh
cd "$HOME/projects/oneproyect/tools/android-native"
TEST_WORKERS=6 GRADLE_WORKERS=6 ./validate-and-build-termux.sh
```

Cada prueba conserva su log separado bajo `$TMPDIR/oneproyect-validation`. Un
fallo muestra las últimas líneas relevantes y evita generar un APK engañoso.

El wrapper fija AGP 9.3.1, compatible con el Gradle 9.6.1 de Termux. El primer
build descarga y cachea AGP y el AAR `4.7.1.stable`. Los siguientes
reutilizan Gradle Build Cache. El APK de laboratorio usa el package separado
`com.testingread.oneproyect.local`; no reemplaza el playtest firmado.

El script usa seis workers, valida firma y ABI ARM64, y copia el resultado
directamente a:

```text
$HOME/storage/downloads/oneproyect-android-native-local.apk
```

Este APK abre el menú principal. Desde allí se puede iniciar Local, preparar
una sala LAN local o entrar al multijugador remoto. AGP 9.3 exige
Build Tools 36; el paquete ARM64 de Termux omite `dexdump`, `split-select` y
`llvm-rs-cc`, así que el script enlaza las implementaciones ARM64 reales del
Build Tools 35 instalado. ADB no forma parte de esta ruta.
