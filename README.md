# vivaldi-shim

This is a macOS shim I use with Finicky to *ensure* external links load in Vivaldi (for raindrop.io, CLI authentication, etc.)

Configured as the default browser, the shim supersedes Vivaldi's (apparently) wonky Apple event handler, sending the URL directly to the Vivaldi executable and letting Chromium handle the behavior.

The behavior it changes:[^1]

| When Vivaldi is… | an external link.. | With the shim it.. |
| --- | --- | --- |
| not running | opens in a tab added to the startup window | opens in a window with a single tab |
| running, no windows open[^2] | ***does not open*** \[in the new window\] | opens in a window with a single tab |
| running, window open | opens in a tab added to an open window | opens in a tab added to an open window |

[^1]: as of 8.2.4133.76 on macOS 15.7.1 with `session.restore_on_startup` unset, exact behavior might vary with configuration.
[^2]: i.e. most of the time

Requires Xcode Command Line Tools (`xcode-select --install`) and macOS 13+

To build and install `VivaldiShim.app`:

```sh
 ./scripts/build-shim.sh
```

In my `.finicky.js` I've replaced `"Vivaldi"` with..

```js
export default {
  defaultBrowser: "VivaldiShim",
  handlers: [
    {
      match: /youtube\.com/,
      browser: "YouTube Wrapper"
...
```

`VivaldiShim.app` is not set up to be a default browser candidate in macOS settings. 

If you need that:

```sh
brew install duti
```

```sh
duti -s net.evokateur.vivaldi-shim http
```
