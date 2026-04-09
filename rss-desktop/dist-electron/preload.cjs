var __getOwnPropNames = Object.getOwnPropertyNames;
var __commonJS = (cb, mod) => function __require() {
  return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
};
import { contextBridge, ipcRenderer } from "electron";
var require_preload = __commonJS({
  "preload.cjs"() {
    contextBridge.exposeInMainWorld("ipcRenderer", {
      on(...args) {
        const [channel, listener] = args;
        return ipcRenderer.on(channel, (event, ...args2) => listener(event, ...args2));
      },
      off(...args) {
        const [channel, ...omit] = args;
        return ipcRenderer.off(channel, ...omit);
      },
      send(...args) {
        const [channel, ...omit] = args;
        return ipcRenderer.send(channel, ...omit);
      },
      invoke(...args) {
        const [channel, ...omit] = args;
        return ipcRenderer.invoke(channel, ...omit);
      }
      // You can expose other APTs you need here.
      // ...
    });
    contextBridge.exposeInMainWorld("electron", {
      shell: {
        openExternal: (url) => ipcRenderer.invoke("shell:openExternal", url)
      }
    });
  }
});
export default require_preload();
