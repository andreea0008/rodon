# WireGuard для Windows

Сюди кладуться бінарники, які RodONService.exe завантажує під час роботи:

    third_party/wireguard/
      include/wireguard.h     <- з архіву wireguard-nt (уже покладено; краще замінити версією з того самого архіву)
      amd64/wireguard.dll     <- з архіву wireguard-nt: bin/amd64/wireguard.dll
      amd64/tunnel.dll        <- збирається з wireguard-windows (див. нижче)
      LICENSE-wireguard-nt.txt
      LICENSE-wireguard-windows.txt

## wireguard.dll (WireGuardNT, підписаний драйвер)
1. Завантаж останній `wireguard-nt-*.zip` з https://download.wireguard.com/wireguard-nt/
2. `bin/amd64/wireguard.dll` -> `amd64/`
3. `include/wireguard.h`    -> `include/`
4. Ліцензію (`LICENSE.txt`) -> `LICENSE-wireguard-nt.txt`

## tunnel.dll (embeddable-dll-service)
Потрібен лише git; build.bat сам завантажить Go і llvm-mingw.

    git clone https://git.zx2c4.com/wireguard-windows
    cd wireguard-windows\embeddable-dll-service
    build.bat

Результат: `amd64\tunnel.dll` -> `amd64/`. Ліцензія wireguard-windows (MIT, `COPYING`) -> `LICENSE-wireguard-windows.txt`.

Обидва файли мають лежати поруч з RodONService.exe (build-скрипт і CMake копіюють їх самі).
