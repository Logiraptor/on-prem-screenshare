# electron-quick-start

**Clone and run for a quick way to see Electron in action.**

This is a minimal Electron application based on the [Quick Start Guide](http://electron.atom.io/docs/tutorial/quick-start) within the Electron documentation.

**Use this app along with the [Electron API Demos](http://electron.atom.io/#get-started) app for API code examples to help you get started.**

A basic Electron application needs just these files:

- `package.json` - Points to the app's main file and lists its details and dependencies.
- `main.js` - Starts the app and creates a browser window to render HTML. This is the app's **main process**.
- `index.html` - A web page to render. This is the app's **renderer process**.

You can learn more about each of these components within the [Quick Start Guide](http://electron.atom.io/docs/tutorial/quick-start).

## To Use

```bash
# Install dependencies
npm install
# Run the app
npm start
```

# TODO

- Add ice candidates only after sdp is received from the remote.
- Add fullscreen option
- Think about >2 clients connected at once.
- Clean up the ui (you can start sharing while sharing, etc)
- List rooms available + number of clients in each.
- Add names to clients