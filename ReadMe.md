# Event Calendar

https://store.kde.org/p/998901/

Plasmoid for a calendar+agenda with weather that syncs to Google Calendar.

## Plasma 6 fork

This `plasma6` branch is a Plasma 6 / Qt6 port maintained by Nathan Doyle
([@Natetronn](https://github.com/Natetronn/plasma-applet-eventcalendar)), built on top of
[Chris Holland's](https://github.com/Zren) (@Zren, the original author) own `plasma6`
work-in-progress branch and `kpac` porting tool. See [Changelog.md](Changelog.md) for what
changed. It remains licensed under the GPL, same as upstream.

```
git clone -b plasma6 https://github.com/Natetronn/plasma-applet-eventcalendar.git eventcalendar
cd eventcalendar
sh ./install --restart
```

The rest of this ReadMe describes the original (Plasma 5) applet; most of it — screenshots,
configuration steps, the KDE Store listing — still applies as-is.

## Screenshots

![](https://i.imgur.com/qdJ71sb.jpg)
![](https://i.imgur.com/Ow8UlFj.jpg)


## A) Install via KDE

1. Right Click Panel > Panel Options > Add Widgets
2. Get New Widgets > Download New Widgets
3. Search: Event Calendar
4. Install
5. Right Click your current calendar widget > Alternatives
6. Select Event Calendar

## B) Install via GitHub

```
git clone https://github.com/Zren/plasma-applet-eventcalendar.git eventcalendar
cd eventcalendar
sh ./install
```

To update, run the `sh ./update` script. It will run a `git pull` then reinstall the applet. Please note this script will restart plasmashell (so you don't have to relog)!

## C) Install via Package Manager

Some awesome users seemed to have packaged this applet under `plasma5-applets-eventcalendar`.

* Arch: https://aur.archlinux.org/packages/plasma5-applets-eventcalendar/
* Chakra: https://chakralinux.org/ccr/packages.php?ID=7656

(Old) There's also a russian who's patched the widget with russian translations. It's out of date though, and we now bundle russian translations with the rest.

* ABF: https://abf.rosalinux.ru/victorr2007/plasma5-applet-eventcalendar

## Update to GitHub master

If you're asked to test something, you can do so by installing the latest unreleased code.

Beforehand, uninstall the AUR version if you are running Arch (you can reinstall after testing).

Then install pen the Terminal and run the following commands. Please note the install script will restart plasmashell so that you don't have to relog.

```
sudo apt install git
git clone https://github.com/Zren/plasma-applet-eventcalendar.git eventcalendar
cd eventcalendar
sh ./install --restart
```

When you've finished testing, you may wish to reinstall the KDE Store or AUR version. First uninstall the widget with the following command, then reinstall your desired version of the widget.

```
sh ./uninstall
```

## Configure

1. Right click the Calendar > Event Calendar Settings > Google Calendar
2. Follow the numbered steps shown there to create your own free Google OAuth client, then
   click Login - this opens your browser to Google's login page.
3. After the settings window says it's synched, click apply.
4. Go to the Weather Tab > Enter your city id for OpenWeatherMap. If their search can't find your city, try googling it with [site:openweathermap.org/city](https://www.google.ca/search?q=site%3Aopenweathermap.org%2Fcity+toronto).


