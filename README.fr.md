###### English version [here](https://github.com/johan-perso/escive/blob/main/README.md).

# eScive

eScive est une application mobile qui vise à être un client tiers pour les trottinettes électriques dotées de fonctionnalités Bluetooth, proposant une interface alternative avec plus de fonctionnalités et sans systèmes de télémétrie comme ceux inclus dans quelques apps officielles (souvent de marques chinoises 👀).

Pour l'instant, le projet cible surtout les modèles "i10" de la marque iScooter, mais est codé d'une manière à permettre l'ajout d'autres modèles et d'autres marques dans le futur.
La communication entre les appareils est basée sur le reverse engineering des paquets envoyés via les protocoles utilisant le BLE, et directement à partir du code source décompilé des apps officielles (mdrrr jme cache tlm pas).

![Bannière eScive](https://r2.johanstick.fr/illustrationsdevs/escive/shots_fr_16_10.png)

## Installation

### Android

L'application n'est pas disponible *officiellement* sur le Play Store.  
Vous pouvez la télécharger via un APK fourni dans les [releases](https://github.com/johan-perso/escive/releases) de ce dépôt.

> Vous pouvez également rejoindre la [bêta fermée](https://johanstick.fr/escive-fr-androidbeta) pour recevoir les mises à jour via le Play Store. Vous devrez attendre d'être accepté, alors il est donc recommandé de télécharger l'APK pour commencer à utiliser l'app.

### iOS

L'application n'est pas encore disponible sur iOS, et ne le sera sûrement pas avant un certain temps : j'ai préféré privilégier un support Android pour réduire le temps de développement, surtout en raison des fonctionnalités natives (widgets, Bluetooth, ...), plus compliquées à implémenter et à tester.
Cependant, l'app peut être compilée et installée sur un iPhone en exécutant un premier build via Xcode, puis en faisant un build final via la commande `flutter build ios` : certaines fonctionnalités seront restreintes et les autres ne seront pas aussi optimisées que sur Android.

## Automatisation

### Protocole

Il est possible d'ouvrir l'app avec une action qui s'effectuera dès que possible depuis une URL débutant par `escive://`, cela permet à une app tierce de prendre le contrôle d'un véhicule.

| Chemin                                                      | Description                                                         |
| ----------------------------------------------------------- | ------------------------------------------------------------------- |
| [app](escive://app)                                         | Ouvre l'app sans action                                             |
| [controls/lock](escive://controls/lock)                     | Verrouille le véhicule actuellement associé                         |
| [controls/unlock](escive://controls/unlock)                 | Déverrouille le véhicule actuellement associé                       |
| [controls/toggle](escive://controls/toggle)                 | Verrouille ou déverrouille selon l'état actuel                      |
| [controls/light/on](escive://controls/light/on)             | Allume le phare                                                     |
| [controls/light/off](escive://controls/light/off)           | Éteint le phare                                                     |
| [controls/light/toggle](escive://controls/light/toggle)     | Bascule l'état du phare                                             |
| [controls/speed/1](escive://controls/speed/1)               | Définit le mode de vitesse sur le mode n°1                          |
| [controls/speed/2](escive://controls/speed/2)               | Définit le mode de vitesse sur le mode n°2                          |
| [controls/speed/3](escive://controls/speed/3)               | Définit le mode de vitesse sur le mode n°3                          |
| [controls/speed/4](escive://controls/speed/4)               | Définit le mode de vitesse sur le mode n°4                          |

### Variables [Kustom](https://docs.kustom.rocks/docs/reference/functions/br)

Sur Android, vous pouvez utiliser les données d'eScive dans un widget ou fond d'écran personnalisé avec une app comme [KWGT](https://docs.kustom.rocks/#kwgt) ou [KLWP](https://docs.kustom.rocks/#klwp) via la fonction "BR - Broadcast receiver". *App tierce non affiliée à eScive*.

Les variables disponibles sont :

| Nom de la variable     | Type                  | Description                                                                         |
| ---------------------- | --------------------- | ----------------------------------------------------------------------------------- |
| `id`                   | Chaîne de caractères  | UUID aléatoire généré assigné à cet appareil                                        |
| `name`                 | Chaîne de caractères  | Nom de l'appareil, peut être changé manuellement par l'utilisateur dans l'app       |
| `bluetoothName`        | Chaîne de caractères  | Nom de l'appareil Bluetooth, ne peut pas être changé par l'utilisateur              |
| `protocol`             | Chaîne de caractères  | Protocole utilisé pour gérer les échanges entre l'app et l'appareil                 |
| `state`                | Chaîne de caractères  | La valeur sera `none`, `connecting` ou `connected` selon l'état de connexion        |
| `battery`              | Nombre                | La valeur sera contenu entre `0` et `100` et représente le pourcentage de batterie  |
| `speedMode`            | Nombre                | La valeur sera contenu entre `0` et `3` (`0` = premier mode de vitesse)             |
| `speedKmh`             | Nombre                | La valeur représente la vitesse à laquelle l'appareil roule (en km/h)               |
| `light`                | Booléen               | Indique l'état du phare avec `false` ou `true`                                      |
| `locked`               | Booléen               | Indique l'état du verrouillage intégré de l'appareil avec `false` ou `true`         |

```ini
# Formule :
$br(escive, speedMode)$

# Exemple de résultat :
2
```

## Licence

MIT © [Johan](https://johanstick.fr). [Soutenez ce projet](https://johanstick.fr/#donate) si vous souhaitez m'aider 💙