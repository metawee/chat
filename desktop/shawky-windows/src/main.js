const path = require('path');
const { app, BrowserWindow, Menu, Tray, shell, session } = require('electron');
const { APP_URL, PROTOCOL, launchUrlFrom, deepLinkFromArgv, isAppUrl } = require('./links');

const ICON = path.join(__dirname, '..', 'build', 'icon.png');
// Notifications, microphone (voice notes) and copying are the only permissions the dashboard gets.
const ALLOWED_PERMISSIONS = new Set(['notifications', 'media', 'clipboard-sanitized-write']);

let mainWindow = null;
let tray = null;
let quitting = false;

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.setAppUserModelId('com.shawkygroup.whatsapp');
  if (process.defaultApp && process.argv.length >= 2) {
    app.setAsDefaultProtocolClient(PROTOCOL, process.execPath, [path.resolve(process.argv[1])]);
  } else {
    app.setAsDefaultProtocolClient(PROTOCOL);
  }

  // A second launch (e.g. the CRM button while the app is open) hands its deep link to this instance.
  app.on('second-instance', (_event, argv) => openDeepLink(deepLinkFromArgv(argv)));
  app.whenReady().then(() => {
    createWindow(launchUrlFrom(deepLinkFromArgv(process.argv)) || APP_URL);
    createTray();
  });
  app.on('before-quit', () => {
    quitting = true;
  });
}

function createWindow(url) {
  // One persistent partition: the login survives restarts like a normal browser.
  const appSession = session.fromPartition('persist:shawky');
  appSession.setPermissionRequestHandler((webContents, permission, callback) => {
    callback(ALLOWED_PERMISSIONS.has(permission) && isAppUrl(webContents.getURL()));
  });

  mainWindow = new BrowserWindow({
    width: 1280,
    height: 820,
    minWidth: 900,
    minHeight: 600,
    title: 'Shawky WhatsApp',
    icon: ICON,
    autoHideMenuBar: true,
    webPreferences: {
      session: appSession,
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      spellcheck: true,
    },
  });

  // Only the Shawky WhatsApp site loads inside the app; every other link opens in the default browser.
  mainWindow.webContents.setWindowOpenHandler(({ url: target }) => {
    if (isAppUrl(target)) return { action: 'allow' };
    if (/^https?:/.test(target)) shell.openExternal(target);
    return { action: 'deny' };
  });
  mainWindow.webContents.on('will-navigate', (event, target) => {
    if (isAppUrl(target)) return;
    event.preventDefault();
    if (/^https?:/.test(target)) shell.openExternal(target);
  });

  // Closing hides to the tray so new-message notifications keep arriving.
  mainWindow.on('close', event => {
    if (quitting) return;
    event.preventDefault();
    mainWindow.hide();
  });

  mainWindow.loadURL(url);
}

function createTray() {
  tray = new Tray(ICON);
  tray.setToolTip('Shawky WhatsApp');
  tray.setContextMenu(
    Menu.buildFromTemplate([
      { label: 'فتح Shawky WhatsApp', click: showWindow },
      { type: 'separator' },
      { label: 'خروج', click: () => app.quit() },
    ])
  );
  tray.on('click', showWindow);
}

function showWindow() {
  if (!mainWindow) return;
  if (mainWindow.isMinimized()) mainWindow.restore();
  mainWindow.show();
  mainWindow.focus();
}

function openDeepLink(deepLink) {
  const url = deepLink && launchUrlFrom(deepLink);
  if (url && mainWindow) mainWindow.loadURL(url);
  showWindow();
}
