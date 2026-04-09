import { app, ipcMain, shell, BrowserWindow } from "electron";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
const __dirname$1 = path.dirname(fileURLToPath(import.meta.url));
process.env.APP_ROOT = path.join(__dirname$1, "..");
const VITE_DEV_SERVER_URL = process.env["VITE_DEV_SERVER_URL"];
const MAIN_DIST = path.join(process.env.APP_ROOT, "dist-electron");
const RENDERER_DIST = path.join(process.env.APP_ROOT, "dist");
if (VITE_DEV_SERVER_URL) {
  process.env.ELECTRON_DISABLE_SECURITY_WARNINGS = "true";
}
process.env.VITE_PUBLIC = VITE_DEV_SERVER_URL ? path.join(process.env.APP_ROOT, "public") : RENDERER_DIST;
let win;
let backendProcess = null;
let backendReady = false;
let backendExitReason = "";
let logFilePath = path.join(os.tmpdir(), "aurora-app.log");
const PRELOAD_PATH = resolvePreloadPath();
const projectRoot = path.join(process.env.APP_ROOT, "..");
const backendDir = path.join(projectRoot, "rust-backend");
let devtoolsOpened = false;
const BACKEND_HOST = "127.0.0.1";
const BACKEND_PORT = 27495;
const HEALTH_CHECK_URL = `http://${BACKEND_HOST}:${BACKEND_PORT}/api/health`;
const HEALTH_CHECK_TIMEOUT = 5 * 60 * 1e3;
const HEALTH_CHECK_INTERVAL = 500;
function resolvePreloadPath() {
  const candidates = ["preload.mjs", "preload.js", "preload.cjs"];
  for (const name of candidates) {
    const candidate = path.join(__dirname$1, name);
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }
  const fallback = path.join(__dirname$1, "preload.js");
  console.warn("⚠️  未找到预设的 preload 文件，回退到", fallback);
  return fallback;
}
function logLine(message) {
  const line = `[${(/* @__PURE__ */ new Date()).toISOString()}] ${message}`;
  console.log(line);
  if (!logFilePath) return;
  try {
    fs.appendFileSync(logFilePath, line + "\n");
  } catch (err) {
  }
}
function updateLogPathToUserData() {
  try {
    const logsDir = path.join(app.getPath("userData"), "logs");
    fs.mkdirSync(logsDir, { recursive: true });
    logFilePath = path.join(logsDir, "aurora-app.log");
    logLine(`📄 日志文件: ${logFilePath}`);
  } catch (err) {
    console.error("⚠️ 无法创建日志目录，继续使用临时目录", err);
  }
}
async function waitForBackendReady() {
  const startTime = Date.now();
  logLine(`⏳ 等待后端服务就绪... (${HEALTH_CHECK_URL})`);
  while (Date.now() - startTime < HEALTH_CHECK_TIMEOUT) {
    const isExternalBackend = VITE_DEV_SERVER_URL && backendProcess === null;
    try {
      const response = await fetch(HEALTH_CHECK_URL, {
        method: "GET",
        signal: AbortSignal.timeout(2e3)
        // 2秒超时
      });
      if (response.ok) {
        const data = await response.json();
        logLine(`✅ 后端服务已就绪: ${JSON.stringify(data)}`);
        backendReady = true;
        return true;
      } else {
        logLine(`⚠️ 健康检查返回非 2xx: ${response.status}`);
      }
    } catch (error) {
      logLine(`⚠️ 健康检查请求异常: ${String(error)}`);
    }
    if (!isExternalBackend && backendProcess === null) {
      logLine("❌ 后端进程已退出，停止等待");
      return false;
    }
    await new Promise((resolve) => setTimeout(resolve, HEALTH_CHECK_INTERVAL));
  }
  logLine("❌ 后端服务启动超时");
  return false;
}
function getBackendExecutable() {
  if (VITE_DEV_SERVER_URL) {
    logLine("🔧 检测到开发服务器，假设后端已由 start.sh 启动");
    return {
      exec: "echo",
      args: ["Backend already running"],
      cwd: backendDir
    };
  }
  const possiblePaths = [
    // 方式1: 在 app.asar 同级的 resources 目录
    path.join(process.resourcesPath, "resources", "aurora-backend"),
    path.join(process.resourcesPath, "backend", "aurora-backend"),
    path.join(process.resourcesPath, "resources", "rss-backend"),
    path.join(process.resourcesPath, "backend", "rss-backend"),
    // 方式2: 在 APP_ROOT 的 rust-backend 目录
    path.join(process.env.APP_ROOT || "", "rust-backend", "target", "release", "aurora-backend"),
    path.join(process.env.APP_ROOT || "", "rust-backend", "target", "release", "rss-backend"),
    // 方式3: 在应用目录
    path.join(path.dirname(app.getPath("exe")), "rust-backend", "target", "release", "aurora-backend"),
    path.join(path.dirname(app.getPath("exe")), "rust-backend", "target", "release", "rss-backend")
  ];
  if (process.platform === "win32") {
    possiblePaths.forEach((p, i) => {
      possiblePaths[i] = p + ".exe";
    });
  }
  logLine("🔍 搜索后端可执行文件...");
  for (const backendPath of possiblePaths) {
    logLine(`   检查: ${backendPath}`);
    if (fs.existsSync(backendPath)) {
      logLine(`✅ 找到后端: ${backendPath}`);
      if (process.platform !== "win32") {
        try {
          fs.chmodSync(backendPath, 493);
        } catch (err) {
          logLine(`⚠️  无法设置执行权限: ${String(err)}`);
        }
      }
      return {
        exec: backendPath,
        args: [],
        cwd: path.dirname(backendPath)
      };
    }
  }
  logLine(`❌ 找不到后端可执行文件，搜索路径: ${JSON.stringify(possiblePaths)}`);
  throw new Error("Backend executable not found in any expected location");
}
async function startBackend() {
  var _a, _b;
  if (backendProcess) {
    console.log("⚠️  后端已在运行");
    return backendReady;
  }
  try {
    const { exec, args, cwd } = getBackendExecutable();
    logLine("🚀 启动后端服务...");
    logLine(`   可执行文件: ${exec}`);
    logLine(`   参数: ${args.join(" ")}`);
    logLine(`   工作目录: ${cwd}`);
    if (VITE_DEV_SERVER_URL && exec === "echo") {
      logLine("✅ 开发模式：后端已由 start.sh 启动");
      return true;
    }
    const spawnOptions = {
      cwd,
      env: {
        ...process.env
        // 不设置 AURORA_DATA_DIR，让后端使用项目内的统一数据目录
      },
      stdio: ["pipe", "pipe", "pipe"]
    };
    const spawnedProcess = spawn(exec, args, spawnOptions);
    backendProcess = spawnedProcess;
    (_a = spawnedProcess.stdout) == null ? void 0 : _a.on("data", (data) => {
      const output = data.toString().trim();
      if (output) logLine(`[Backend] ${output}`);
    });
    (_b = spawnedProcess.stderr) == null ? void 0 : _b.on("data", (data) => {
      const output = data.toString().trim();
      if (output) logLine(`[Backend Error] ${output}`);
    });
    spawnedProcess.on("error", (error) => {
      logLine(`❌ 后端进程错误: ${String(error)}`);
      backendProcess = null;
      backendReady = false;
    });
    spawnedProcess.on("exit", (code, signal) => {
      const msg = `[Backend] 进程退出 - 代码: ${code}, 信号: ${signal}`;
      logLine(msg);
      backendExitReason = `后端进程意外退出 (Code: ${code}, Signal: ${signal})`;
      backendProcess = null;
      backendReady = false;
    });
    logLine("✅ 后端进程已启动，等待服务就绪...");
    const ready = await waitForBackendReady();
    if (!ready) {
      logLine("❌ 后端服务未能在规定时间内就绪");
      stopBackend();
      return false;
    }
    return true;
  } catch (error) {
    logLine(`❌ 启动后端时发生错误: ${String(error)}`);
    backendProcess = null;
    backendReady = false;
    return false;
  }
}
function stopBackend() {
  if (!backendProcess) return;
  console.log("🛑 停止后端服务...");
  try {
    backendProcess.kill("SIGTERM");
    setTimeout(() => {
      if (backendProcess && !backendProcess.killed) {
        console.warn("⚠️  强制终止后端进程");
        backendProcess.kill("SIGKILL");
      }
    }, 5e3);
  } catch (error) {
    console.error("❌ 停止后端时出错:", error);
  }
  backendProcess = null;
  backendReady = false;
}
function createWindow() {
  var _a;
  if (((_a = win == null ? void 0 : win.isDestroyed) == null ? void 0 : _a.call(win)) === true) {
    win = null;
  }
  if (win) return win;
  win = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 400,
    minHeight: 600,
    show: true,
    // 强制显示窗口，以便调试
    icon: path.join(process.env.VITE_PUBLIC || "", "icons", "app-release.png"),
    webPreferences: {
      preload: PRELOAD_PATH,
      nodeIntegration: false,
      contextIsolation: true,
      webviewTag: true,
      // Enable <webview> tag for in-app reading mode
      // 统一使用较宽松的安全设置以支持阅读模式跨域请求
      webSecurity: false,
      allowRunningInsecureContent: true
    }
  });
  win.on("closed", () => {
    win = null;
  });
  win.once("ready-to-show", () => {
    win == null ? void 0 : win.show();
  });
  win.webContents.on("did-finish-load", () => {
    const currentURL = (win == null ? void 0 : win.webContents.getURL()) || "";
    if (isLoadingScreen(currentURL)) {
      return;
    }
    win == null ? void 0 : win.webContents.send("main-process-message", (/* @__PURE__ */ new Date()).toLocaleString());
    if (VITE_DEV_SERVER_URL && !devtoolsOpened) {
      win == null ? void 0 : win.webContents.openDevTools();
      devtoolsOpened = true;
    }
  });
  return win;
}
function isLoadingScreen(url) {
  return url.startsWith("data:text/html");
}
function showStartupStatus(message) {
  if (!win) return;
  if (win.isDestroyed && win.isDestroyed()) {
    win = null;
    return;
  }
  const safeMessage = message.replace(/</g, "&lt;").replace(/>/g, "&gt;");
  const html = (
    /* html */
    `
    <!doctype html>
    <html lang="zh-CN">
      <head>
        <meta charset="utf-8" />
        <title>Aurora RSS Reader</title>
        <style>
          :root {
            color-scheme: light dark;
          }
          body {
            margin: 0;
            display: flex;
            height: 100vh;
            align-items: center;
            justify-content: center;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: #0f172a;
            color: #f8fafc;
          }
          .card {
            text-align: center;
          }
          .status {
            margin-top: 12px;
            font-size: 16px;
            color: #cbd5f5;
          }
        </style>
      </head>
      <body>
        <div class="card">
          <h2>Aurora RSS Reader</h2>
          <div class="status">${safeMessage}</div>
        </div>
      </body>
    </html>
  `
  );
  try {
    win.loadURL(`data:text/html;charset=utf-8,${encodeURIComponent(html)}`);
  } catch (error) {
    console.error("Failed to load startup status:", error);
    win = null;
  }
}
function loadRendererContent() {
  if (!win) return;
  if (win.isDestroyed && win.isDestroyed()) {
    win = null;
    return;
  }
  try {
    if (VITE_DEV_SERVER_URL) {
      win.loadURL(VITE_DEV_SERVER_URL);
    } else {
      win.loadFile(path.join(RENDERER_DIST, "index.html"));
    }
  } catch (error) {
    console.error("Failed to load renderer content:", error);
    win = null;
  }
}
app.whenReady().then(async () => {
  ipcMain.handle("shell:openExternal", async (_event, url) => {
    if (url && typeof url === "string") {
      try {
        await shell.openExternal(url);
      } catch (error) {
        console.error("Failed to open external URL:", url, error);
      }
    }
  });
  updateLogPathToUserData();
  console.log("🎯 Aurora RSS Reader 启动中...");
  logFilePath = path.join(app.getPath("userData"), "aurora-app.log");
  logLine(`   用户数据目录: ${app.getPath("userData")}`);
  logLine(`   资源路径: ${process.resourcesPath}`);
  createWindow();
  if (VITE_DEV_SERVER_URL) {
    console.log("⚠️  检测到开发服务器，假设后端已由 start.sh 启动");
    console.log("   等待后端就绪...");
    showStartupStatus("等待开发后端服务就绪...");
    const backendReady2 = await waitForBackendReady();
    if (!backendReady2) {
      console.error("❌ 后端未就绪，请确保运行了 ./start.sh");
      showStartupStatus("后端未就绪，请检查终端中的启动命令");
      app.quit();
      return;
    }
    loadRendererContent();
  } else {
    const startupMessage = process.platform === "win32" ? "正在启动后端服务（Windows 首次启动可能需要 2-3 分钟进行初始化，请耐心等待）..." : "正在启动后端服务，请稍候...";
    showStartupStatus(startupMessage);
    const backendStarted = await startBackend();
    if (!backendStarted) {
      console.error("❌ 后端启动失败，应用无法继续");
      const errorMsg = backendExitReason || "后端启动失败，请查看日志或重启应用";
      showStartupStatus(errorMsg);
      setTimeout(() => app.quit(), 5e3);
      return;
    }
    loadRendererContent();
  }
});
app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
    win = null;
  }
});
app.on("activate", () => {
  const visibleWindows = BrowserWindow.getAllWindows().filter((window) => !window.isDestroyed());
  if (visibleWindows.length === 0) {
    createWindow();
    if (backendReady) {
      loadRendererContent();
    } else {
      showStartupStatus("正在等待后端服务...");
    }
  } else {
    const mainWindow = visibleWindows[0];
    if (mainWindow.isMinimized()) {
      mainWindow.restore();
    }
    mainWindow.show();
    mainWindow.focus();
  }
});
app.on("before-quit", () => {
  stopBackend();
});
app.on("quit", () => {
  stopBackend();
});
export {
  MAIN_DIST,
  RENDERER_DIST,
  VITE_DEV_SERVER_URL
};
