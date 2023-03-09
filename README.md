### Usage

You need to make sure that the `csadm` binary is available and can be executed by the script's user.
Check https://support.hsm.utimaco.com/support in the Download section to get your `csadm` binary

```
$ ruby check_utimaco_hsm.rb -H cryptoserver.domain.tld
OK - v0.1 Utimaco CryptoServer cryptoserver.domain.tld CSLAN  5.1.0|load=12.5%;20;40;  uptime=6;1;1 fan_speed=5100;6000;2500 cpu_temp=26;38;45 connections=32;65;100; battery_carrier=3.108 battery_external=3.586
OK: CSLAN  5.1.0
OK: Load: 12.5 % < 20
OK: state is OK
OK: GetState: mode: Operational Mode
OK: GetState: state: INITIALIZED (0x00100004)
OK: GetState: alarm: OFF
OK: uptime: 6 days >= 1 days
OK: fan_speed: 5100 rpm > 6000 rpm and < 6000 rpm
OK: cpu_temp: 26 C <= 38 C
OK: Connections: 32 < 65
OK: carrier Battery is ok == ok (3.108 V)
OK: external Battery is ok == ok (3.586 V)
```


WARNING state:
```
WARNING: Load: 20.1 % >= 20  Utimaco CryptoServer cryptoserver.domain.tld CSLAN  5.1.0|load=20.1%;20;40;  uptime=6;1;1 fan_speed=5100;6000;2500 cpu_temp=26;38;45 connections=32;65;100; battery_carrier=3.108 battery_external=3.586
CSLAN  5.1.0
OK: state is OK
OK: GetState: mode: Operational Mode
OK: GetState: state: INITIALIZED (0x00100004)
OK: GetState: alarm: OFF
OK: uptime: 6 days >= 1 days
OK: fan_speed: 5100 rpm > 6000 rpm and < 6000 rpm
OK: cpu_temp: 26 C <= 38 C
OK: Connections: 32 < 65
OK: carrier Battery is ok == ok (3.108 V)
OK: external Battery is ok == ok (3.586 V)
```
