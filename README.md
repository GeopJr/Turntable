<p align="center">
  <img alt="A turntable in the style of GNOME icons" width="160" src="./data/icons/hicolor/scalable/apps/dev.geopjr.Turntable.svg">
</p>
<h1 align="center">Turntable</h1>
<h3 align="center">Scrobble your music</h3>
<p align="center">
  <br />
    <a href="./CODE_OF_CONDUCT.md"><img src="https://img.shields.io/badge/Code%20of%20Conduct-GNOME-f5c211.svg?style=for-the-badge&labelColor=f9f06b" alt="GNOME Code of Conduct" /></a>
    <a href="./LICENSE"><img src="https://img.shields.io/badge/LICENSE-GPL--3.0-f5c211.svg?style=for-the-badge&labelColor=f9f06b" alt="License GPL-3.0" /></a>
    <a href='https://stopthemingmy.app'><img width='193.455' alt='Please do not theme this app' src='https://stopthemingmy.app/badge.svg'/></a>
</p>

<p align="center">
    <img alt="Screenshot of the Turntable app in light mobile. Heartache - BritPop by A. G. Cook is playing though GNOME Music." src="./data/screenshots/screenshot-1.png">
</p>

<p align="center">Keep track of your listening habits by scrobbling them to last.fm, ListenBrainz, Libre.fm and Maloja at the same time using your favorite music app's, favorite music app! Turntable comes with a highly customizable and sleek design that displays information about the currently playing song and allows you to control your music player, allowlist it for scrobbling and manage your scrobbling accounts. All MPRIS-enabled apps are supported.</p>
<p align="center">Not interested in the GUI but still want to scrobble your MPRIS-enabled players? Turntable comes with a CLI, allowing you to scrobble in the background! Try it out using <code>flatpak run dev.geopjr.Turntable --help</code>.</p>

# Install

## Official

### Release

<a href="https://flathub.org/apps/details/dev.geopjr.Turntable" rel="noreferrer noopener" target="_blank"><img loading="lazy" draggable="false" width='240' alt='Download on Flathub' src='https://flathub.org/api/badge?svg&locale=en' /></a>

## From Source

<details>
<summary>Dependencies</summary>

Package Name | Required
:--- | ---:
meson | ✅
valac | ✅
libadwaita-1.0-dev | ✅
libsecret-1-dev | ❌
libjson-glib-dev  | ❌
libsoup3.0-dev | ❌

</details>

### Scrobbling

Scrobbling will only be enabled if last.fm tokens are provided. The optional deps are only required then. Read [`meson_options.txt`](./meson_options.txt) on how to generate one. Please avoid using the official debug or release tokens.

### Makefile

```
$ make
$ make install
```

### GNOME Builder

- Clone
- Open in GNOME Builder

# FaQ

- **XYZ player controls is missing**
- Most likely MPRIS doesn't give us enough enough about whether the player supports it or is inaccurate.

- **What's MBID?**
- MusicBrainz is, among other things, a big database for song metadata. Enabling the option on Turntable, will check if the song to-be scrolled exists and will fix its metadata.

- **When does a scrobble get sent?**
- A song will be scrobbled either when it hits 4 minutes of playtime or half the playtime, whichever one comes first. Playtime does not count while the song is not playing.

- **What if I have multiple Turntable windows open?**
- Turntable was built with multiple windows open in mind. The scrobbling manager will make sure a filter out requests so only 1 instance of an MPRIS client will get counted.

- **CLI can't find any accounts**
- Use the GUI to set them up. They require validation and callbacks which the GUI can handle.

- **Flatpak can't access my player's cover**
- Due to the way the sandbox works, Turntable has to get access to its files. Please open an issue.

# Sponsors

<div align="center">

[![GeopJr Sponsors](https://cdn.jsdelivr.net/gh/GeopJr/GeopJr@main/sponsors.svg)](https://github.com/sponsors/GeopJr)

</div>

[![Translation status](https://translate.codeberg.org/widgets/turntable/-/turntable/287x66-white.png)](https://translate.codeberg.org/engage/turntable)

# Contributing

1. Read the [Code of Conduct](./CODE_OF_CONDUCT.md)
2. Fork it ( https://codeberg.org/GeopJr/Turntable/fork )
3. Create your feature branch (git checkout -b my-new-feature)
4. Commit your changes (git commit -am 'Add some feature')
5. Push to the branch (git push origin my-new-feature)
6. Create a new Pull Request
