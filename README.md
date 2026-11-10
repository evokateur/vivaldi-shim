# Vivaldi Shim

This is a macOS shim I ginned up to ensure external links loaded in Vivaldi (for raindrop.io, CLI authentication, etc.)

As the default browser, it bypasses Vivaldi's URL Apple event handler, sending the URL as an argument to the Vivaldi executable and letting Chromium handle the behavior.

**Original behavior — Vivaldi 8.2.4133.76 on macOS 15.7.1**, using **Startup with → Homepage**, Homepage set to **Start Page**:

| Vivaldi state | Without the shim | With the shim |
| --- | --- | --- |
| Not running | Adds the URL to the startup window | Opens a window containing only the URL |
| Running, no windows open | Opens a new window, but ***does not load the URL*** | Opens a window containing only the URL |
| Running, window open | Adds the URL to an existing window | Adds the URL to an existing window |

**Last observed behavior — Vivaldi 8.3.4191.35 on macOS 13.7.8**, using **Startup with → Homepage**, Homepage set to **Start Page**:

| Vivaldi state | Without the shim | With the shim |
| --- | --- | --- |
| Not running | Opens a window with the Start Page followed by the URL tab | Opens a window containing only the URL |
| Running, no windows open | Opens a window with the URL tab followed by Speed Dial | Opens a window containing only the URL |
| Running, window open | Adds the URL to an existing window | Adds the URL to an existing window |

Since the no-window URL delivery failure no longer reproduces, the shim's remaining benefit is avoiding unneeded Start Page tabs

> [!IMPORTANT]
> Avoid using this with **Startup with → Last Session**. Launching the Vivaldi executable seems to trigger a restore of the last *persisted* session, possibly windows and tabs open when Vivaldi was last quit.

Requires Xcode Command Line Tools (`xcode-select --install`) and macOS 13+

To build and install `Vivaldi Shim.app`:

```sh
 ./scripts/build-shim.sh
```

In my `.finicky.js` I replace `"Vivaldi"` with:

```js
export default {
  defaultBrowser: "Vivaldi Shim",
  handlers: [
    {
      match: /youtube\.com/,
      browser: "YouTube Wrapper"
...
```

`Vivaldi Shim.app` is not set up to be a default browser candidate in macOS settings.

If it needs to be the default, you can use `duti` to set it directly:

```sh
brew install duti
```

```sh
duti -s net.evokateur.vivaldi-shim http
```

This covers `https` as well; there is no separate protocol setting.
