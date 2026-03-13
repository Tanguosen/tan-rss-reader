import { app, BrowserWindow, ipcMain, shell } from 'electron'
import { spawn, ChildProcess } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import fs from 'node:fs'
import path from 'node:path'
import os from 'node:os'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

// The built directory structure
//
// ├─┬─┬ dist
// │ │ └── index.html
// │ │
// │ ├─┬ dist-electron
// │ │ ├── main.js
// │ │ └── preload.mjs
// │
process.env.APP_ROOT = path.join(__dirname, '..')

// 🚧 Use ['ENV_NAME'] avoid vite:define plugin - Vite@2.x
export const VITE_DEV_SERVER_URL = process.env['VITE_DEV_SERVER_URL']
export const MAIN_DIST = path.join(process.env.APP_ROOT, 'dist-electron')
export const RENDERER_DIST = path.join(process.env.APP_ROOT, 'dist')

// 在开发模式下禁用安全警告（这些警告在打包后不会出现）
if (VITE_DEV_SERVER_URL) {
  process.env.ELECTRON_DISABLE_SECURITY_WARNINGS = 'true'
}

process.env.VITE_PUBLIC = VITE_DEV_SERVER_URL ? path.join(process.env.APP_ROOT, 'public') : RENDERER_DIST

let win: BrowserWindow | null
let backendProcess: ChildProcess | null = null
let backendReady = false
let backendExitReason = ''
let logFilePath = path.join(os.tmpdir(), 'tan-app.log') // 初始化为临时目录，待 app ready 后切换到用户数据目录

const PRELOAD_PATH = resolvePreloadPath()
const projectRoot = path.join(process.env.APP_ROOT, '..')
const backendDir = path.join(projectRoot, 'rust-backend')
let devtoolsOpened = false

// 后端配置
const BACKEND_HOST = '127.0.0.1'
const BACKEND_PORT = 27497
// 后端健康检查实际暴露在 /api/health，直接使用该路径避免 404
const HEALTH_CHECK_URL = `http://${BACKEND_HOST}:${BACKEND_PORT}/api/health`
// 统一延长到 5 分钟，便于慢盘/首次安装完成数据库初始化
const HEALTH_CHECK_TIMEOUT = 5 * 60 * 1000
const HEALTH_CHECK_INTERVAL = 500 // 每500ms检查一次

function resolvePreloadPath(): string {
  const candidates = ['preload.mjs', 'preload.js', 'preload.cjs']

  for (const name of candidates) {
    const candidate = path.join(__dirname, name)
    if (fs.existsSync(candidate)) {
      return candidate
    }
  }

  const fallback = path.join(__dirname, 'preload.js')
  console.warn('⚠️  未找到预设的 preload 文件，回退到', fallback)
  return fallback
}

function logLine(message: string) {
  const line = `[${new Date().toISOString()}] ${message}`
  console.log(line)
  if (!logFilePath) return
  try {
    fs.appendFileSync(logFilePath, line + '\n')
  } catch (err) {
    // 如果写日志失败，至少不影响主流程
  }
}

function updateLogPathToUserData() {
  try {
    const logsDir = path.join(app.getPath('userData'), 'logs')
    fs.mkdirSync(logsDir, { recursive: true })
    logFilePath = path.join(logsDir, 'tan-app.log')
    logLine(`📄 日志文件: ${logFilePath}`)
  } catch (err) {
    console.error('⚠️ 无法创建日志目录，继续使用临时目录', err)
  }
}

/**
 * 健康检查：等待后端服务就绪
 */
async function waitForBackendReady(): Promise<boolean> {
  const startTime = Date.now()

  logLine(`⏳ 等待后端服务就绪... (${HEALTH_CHECK_URL})`)

  while (Date.now() - startTime < HEALTH_CHECK_TIMEOUT) {
    // 如果我们在开发模式下且后端由外部管理，跳过进程检查
    const isExternalBackend = VITE_DEV_SERVER_URL && backendProcess === null

    try {
      const response = await fetch(HEALTH_CHECK_URL, {
        method: 'GET',
        signal: AbortSignal.timeout(2000) // 2秒超时
      })

      if (response.ok) {
        const data = await response.json()
        logLine(`✅ 后端服务已就绪: ${JSON.stringify(data)}`)
        backendReady = true
        return true
      } else {
        logLine(`⚠️ 健康检查返回非 2xx: ${response.status}`)
      }
    } catch (error) {
      logLine(`⚠️ 健康检查请求异常: ${String(error)}`)
    }

    // 如果不是外部管理的后端且进程已退出，则不再等待
    if (!isExternalBackend && backendProcess === null) {
      logLine('❌ 后端进程已退出，停止等待')
      return false
    }

    // 等待一段时间后重试
    await new Promise(resolve => setTimeout(resolve, HEALTH_CHECK_INTERVAL))
  }

  logLine('❌ 后端服务启动超时')
  return false
}

/**
 * 获取后端可执行文件路径
 */
function getBackendExecutable(): { exec: string; args: string[]; cwd: string } {
  // 优先尝试运行中的 Rust 后端服务（如果由 start.sh 启动）
  if (VITE_DEV_SERVER_URL) {
    logLine('🔧 检测到开发服务器，假设后端已由 start.sh 启动')
    return {
      exec: 'echo',
      args: ['Backend already running'],
      cwd: backendDir
    }
  }

  // 生产环境：使用打包好的后端可执行文件
  // 尝试多个可能的路径
  const possiblePaths = [
    // 方式1: 在 app.asar 同级的 resources 目录
    path.join(process.resourcesPath, 'resources', 'tan-backend'),
    path.join(process.resourcesPath, 'backend', 'tan-backend'),
    // 方式2: 在 APP_ROOT 的 rust-backend 目录
    path.join(process.env.APP_ROOT || '', 'rust-backend', 'target', 'release', 'tan-backend'),
    // 方式3: 在应用目录
    path.join(path.dirname(app.getPath('exe')), 'rust-backend', 'target', 'release', 'tan-backend'),
  ]

  // Windows 添加 .exe 后缀
  if (process.platform === 'win32') {
    possiblePaths.forEach((p, i) => {
      possiblePaths[i] = p + '.exe'
    })
  }

  logLine('🔍 搜索后端可执行文件...')
  for (const backendPath of possiblePaths) {
    logLine(`   检查: ${backendPath}`)
    if (fs.existsSync(backendPath)) {
      logLine(`✅ 找到后端: ${backendPath}`)

      // 确保文件有执行权限 (Unix系统)
      if (process.platform !== 'win32') {
        try {
          fs.chmodSync(backendPath, 0o755)
        } catch (err) {
          logLine(`⚠️  无法设置执行权限: ${String(err)}`)
        }
      }

      return {
        exec: backendPath,
        args: [],
        cwd: path.dirname(backendPath)
      }
    }
  }

  logLine(`❌ 找不到后端可执行文件，搜索路径: ${JSON.stringify(possiblePaths)}`)
  throw new Error('Backend executable not found in any expected location')
}

/**
 * 启动后端服务
 */
async function startBackend(): Promise<boolean> {
  if (backendProcess) {
    console.log('⚠️  后端已在运行')
    return backendReady
  }

  try {
    const { exec, args, cwd } = getBackendExecutable()

    logLine('🚀 启动后端服务...')
    logLine(`   可执行文件: ${exec}`)
    logLine(`   参数: ${args.join(' ')}`)
    logLine(`   工作目录: ${cwd}`)

    // 如果是开发模式且后端已运行，直接返回
    if (VITE_DEV_SERVER_URL && exec === 'echo') {
      logLine('✅ 开发模式：后端已由 start.sh 启动')
      return true
    }

    const spawnOptions: any = {
      cwd,
      env: {
        ...process.env,
        // 不设置 AURORA_DATA_DIR，让后端使用项目内的统一数据目录
      },
      stdio: ['pipe', 'pipe', 'pipe'] as const
    }

    const spawnedProcess = spawn(exec, args, spawnOptions)
    backendProcess = spawnedProcess

    // 记录后端输出
    spawnedProcess.stdout?.on('data', (data) => {
        const output = data.toString().trim()
        if (output) logLine(`[Backend] ${output}`)
    })

    spawnedProcess.stderr?.on('data', (data) => {
      const output = data.toString().trim()
      if (output) logLine(`[Backend Error] ${output}`)
    })

    spawnedProcess.on('error', (error) => {
      logLine(`❌ 后端进程错误: ${String(error)}`)
      backendProcess = null
      backendReady = false
    })

    spawnedProcess.on('exit', (code, signal) => {
      const msg = `[Backend] 进程退出 - 代码: ${code}, 信号: ${signal}`
      logLine(msg)
      backendExitReason = `后端进程意外退出 (Code: ${code}, Signal: ${signal})`
      backendProcess = null
      backendReady = false
    })

    logLine('✅ 后端进程已启动，等待服务就绪...')

    // 等待后端服务就绪
    const ready = await waitForBackendReady()

    if (!ready) {
      logLine('❌ 后端服务未能在规定时间内就绪')
      stopBackend()
      return false
    }

    return true

  } catch (error) {
    logLine(`❌ 启动后端时发生错误: ${String(error)}`)
    backendProcess = null
    backendReady = false
    return false
  }
}

/**
 * 停止后端服务
 */
function stopBackend() {
  if (!backendProcess) return

  console.log('🛑 停止后端服务...')

  try {
    backendProcess.kill('SIGTERM')

    // 如果5秒后还没退出，强制杀死
    setTimeout(() => {
      if (backendProcess && !backendProcess.killed) {
        console.warn('⚠️  强制终止后端进程')
        backendProcess.kill('SIGKILL')
      }
    }, 5000)
  } catch (error) {
    console.error('❌ 停止后端时出错:', error)
  }

  backendProcess = null
  backendReady = false
}

/**
 * 创建主窗口
 */
function createWindow() {
  // 如果有已存在但已销毁的窗口句柄，清空引用
  if (win?.isDestroyed?.() === true) {
    win = null
  }

  // 复用尚未销毁的窗口
  if (win) return win

  win = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 400,
    minHeight: 600,
    show: true, // 强制显示窗口，以便调试
    icon: path.join(process.env.VITE_PUBLIC || '', 'icons', 'app-release.png'),
    webPreferences: {
      preload: PRELOAD_PATH,
      nodeIntegration: false,
      contextIsolation: true,
      webviewTag: true, // Enable <webview> tag for in-app reading mode
      // 统一使用较宽松的安全设置以支持阅读模式跨域请求
      webSecurity: false,
      allowRunningInsecureContent: true
    },
  })

  // macOS 用户关闭窗口（不退出）时，BrowserWindow 会被销毁。
  // 清空引用，避免后续对已销毁对象调用 loadURL/loadFile 导致
  // "TypeError: Object has been destroyed"
  win.on('closed', () => {
    win = null
  })

  // 窗口加载完成后显示
  win.once('ready-to-show', () => {
    win?.show()
  })

  win.webContents.on('did-finish-load', () => {
    const currentURL = win?.webContents.getURL() || ''

    if (isLoadingScreen(currentURL)) {
      return
    }

    win?.webContents.send('main-process-message', new Date().toLocaleString())

    // 在开发模式下自动打开开发者工具
    if (VITE_DEV_SERVER_URL && !devtoolsOpened) {
      win?.webContents.openDevTools()
      devtoolsOpened = true
    }
  })

  return win
}

function isLoadingScreen(url: string) {
  return url.startsWith('data:text/html')
}

function showStartupStatus(message: string) {
  if (!win) return

  // 确保窗口没有被销毁
  if (win.isDestroyed && win.isDestroyed()) {
    win = null
    return
  }

  const safeMessage = message.replace(/</g, '&lt;').replace(/>/g, '&gt;')
  const html = /* html */ `
    <!doctype html>
    <html lang="zh-CN">
      <head>
        <meta charset="utf-8" />
        <title>TAN</title>
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
          <h2>TAN</h2>
          <div class="status">${safeMessage}</div>
        </div>
      </body>
    </html>
  `

  try {
    win.loadURL(`data:text/html;charset=utf-8,${encodeURIComponent(html)}`)
  } catch (error) {
    console.error('Failed to load startup status:', error)
    // 如果加载失败，可能窗口已被销毁，重置引用
    win = null
  }
}

function loadRendererContent() {
  if (!win) return

  // 检查窗口是否已销毁
  if (win.isDestroyed && win.isDestroyed()) {
    win = null
    return
  }

  try {
    if (VITE_DEV_SERVER_URL) {
      win.loadURL(VITE_DEV_SERVER_URL)
    } else {
      win.loadFile(path.join(RENDERER_DIST, 'index.html'))
    }
  } catch (error) {
    console.error('Failed to load renderer content:', error)
    // 如果加载失败，可能窗口已被销毁，重置引用
    win = null
  }
}

/**
 * 应用启动
 */
app.whenReady().then(async () => {
  // 注册 IPC 处理器：用于在系统默认浏览器中打开链接
  ipcMain.handle('shell:openExternal', async (_event, url: string) => {
    if (url && typeof url === 'string') {
      try {
        await shell.openExternal(url)
      } catch (error) {
        console.error('Failed to open external URL:', url, error)
      }
    }
  })

  updateLogPathToUserData()

  console.log('🎯 TAN 启动中...')
  logFilePath = path.join(app.getPath('userData'), 'tan-app.log')
  logLine(`   用户数据目录: ${app.getPath('userData')}`)
  logLine(`   资源路径: ${process.resourcesPath}`)

  createWindow()

  // 统一的启动逻辑：检测是否有开发服务器，否则启动内置后端
  if (VITE_DEV_SERVER_URL) {
    console.log('⚠️  检测到开发服务器，假设后端已由 start.sh 启动')
    console.log('   等待后端就绪...')
    showStartupStatus('等待开发后端服务就绪...')

    const backendReady = await waitForBackendReady()

    if (!backendReady) {
      console.error('❌ 后端未就绪，请确保运行了 ./start.sh')
      showStartupStatus('后端未就绪，请检查终端中的启动命令')
      app.quit()
      return
    }

    loadRendererContent()
  } else {
    const startupMessage = process.platform === 'win32'
      ? '正在启动后端服务（Windows 首次启动可能需要 2-3 分钟进行初始化，请耐心等待）...'
      : '正在启动后端服务，请稍候...'

    showStartupStatus(startupMessage)

    const backendStarted = await startBackend()

    if (!backendStarted) {
      console.error('❌ 后端启动失败，应用无法继续')
      const errorMsg = backendExitReason || '后端启动失败，请查看日志或重启应用'
      showStartupStatus(errorMsg)
      // 延迟退出以便用户能看到错误信息
      setTimeout(() => app.quit(), 5000)
      return
    }

    loadRendererContent()
  }
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
    win = null
  }
})

app.on('activate', () => {
  // macOS: 当用户点击 dock 图标时，如果没有窗口则创建新窗口
  // 检查是否有任何可见的窗口（排除已销毁的窗口）
  const visibleWindows = BrowserWindow.getAllWindows().filter(window => !window.isDestroyed())

  if (visibleWindows.length === 0) {
    // 没有可见窗口，创建新窗口
    createWindow()
    if (backendReady) {
      loadRendererContent()
    } else {
      showStartupStatus('正在等待后端服务...')
    }
  } else {
    // 有可见窗口，将其显示到前台
    const mainWindow = visibleWindows[0]
    if (mainWindow.isMinimized()) {
      mainWindow.restore()
    }
    mainWindow.show()
    mainWindow.focus()
  }
})

app.on('before-quit', () => {
  // 统一停止后端服务（除了开发模式下由 start.sh 管理的后端）
  stopBackend()
})

app.on('quit', () => {
  // 统一停止后端服务
  stopBackend()
})
