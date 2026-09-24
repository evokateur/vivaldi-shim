# vivaldi-shim

This is a macOS shim I use with Finicky to *ensure* external links load in Vivaldi[^1] (for raindrop.io, CLI authentication, etc.)

| When Vivaldi is… | An external link.. | With the shim.. |
| --- | --- | --- |
| not running | opens in a new tab in a window with the start tab | opens in a window with a single tab |
| running, no windows open | **does not open** - only a new window with the start tab | opens in a window with a single tab |
| running, window open | opens in a new tab in already open window | opens in a new tab in already open window |

[^1]: as of 8.2.4133.76 on macOS 15.7.1 with `session.restore_on_startup` unset, exact behavior will vary with configuration.

Requires Xcode Command Line Tools (`xcode-select --install`) and macOS 13

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

This is not set up to be a default browser candidate in macOS settings. If you need that:

```sh
brew install duti
```

```sh
duti -s net.evokateur.vivaldi-shim http
```
