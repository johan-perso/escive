###### Version française [ici](https://github.com/johan-perso/escive/blob/main/README.fr.md).

# eScive

eScive is a mobile app that aims to be a third-party client for e-scooters with Bluetooth functionality, allowing an alternative interface with more features, and more importantly, without all the telemetry that is included in some official apps (generally Chinese ones 👀).

For now, the project specifically targets iScooter "i10" electric scooters, but is coded in a way that will allow other brands in the future.
Communications between devices are based on reverse engineering of packets sent using the BLE protocols, and directly from the decompiled source code of official apps.

| ![Homepage / Onboarding](https://r2.johanstick.fr/illustrationsdevs/escive/home_onboarding.png) | ![Homepage / speedometer](https://r2.johanstick.fr/illustrationsdevs/escive/home_speedometer.png) |
| --- | --- |

## Installation

### Android

~~You can download the app directly from the [Play Store](https://play.google.com/store/apps/details?id=fr.johanstick.escive) if your device supports it.~~

The app is still in a very intensive development phase and is not yet available for download, neither through the Play Store, nor through a provided APK file.
You can follow the commits on this repository to be up-to-date with the development progress and its eventual release, which will first be on GitHub and then on the Play Store.

### iOS

The app is not yet available for iOS, and will probably not be for a while. I put a priority on supporting Android to reduce development time, mainly because of the native features (widgets, Bluetooth...) that are more complex to implement and test.
However, the app can be compiled and installed on an iPhone/iPad by first running a build using Xcode on a Mac, and then by using the command `flutter build ios`. Some features will be limited or not available, and others will not be as optimized as on Android.

## Protocole

You can directly open the app on your phone from a URL starting with `escive://`. Depending on the URL, you can choose any predefined actions from the list below that will be done as soon as possible.

| Path                                                        | Description                                                         |
| ----------------------------------------------------------- | ------------------------------------------------------------------- |
| [app](escive://app)                                         | Open the app without any actions                                    |
| [controls/lock/on](escive://controls/lock/on)               | Lock the current associated device                                  |
| [controls/lock/off](escive://controls/lock/off)             | Unlock the current associated device                                |
| [controls/lock/toggle](escive://controls/lock/toggle)       | Lock or unlock depending on the current state                       |
| [controls/light/on](escive://controls/light/on)             | Turn on the LED                                                     |
| [controls/light/off](escive://controls/light/off)           | Turn off the LED                                                    |
| [controls/light/toggle](escive://controls/light/toggle)     | Toggle the LED                                                      |
| [controls/speed/0](escive://controls/speed/0)               | Set speed profile on the mode #1                                    |
| [controls/speed/1](escive://controls/speed/1)               | Set speed profile on the mode #2                                    |
| [controls/speed/2](escive://controls/speed/2)               | Set speed profile on the mode #3                                    |
| [controls/speed/3](escive://controls/speed/3)               | Set speed profile on the mode #4                                    |

## License

MIT © [Johan](https://johanstick.fr/). [Support this project](https://johanstick.fr/#donate) if you want to help me 💙