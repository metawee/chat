// Pure helpers (no Electron imports) so they can be unit tested with node --test.
const APP_URL = process.env.SHAWKY_APP_URL || 'https://web.shawkygroup.com';
const PROTOCOL = 'shawkywhatsapp';
// Same format the server accepts (Shawky::LaunchesController::SESSION_FORMAT).
const SESSION_FORMAT = /^s_[A-Za-z0-9_-]{8,128}$/;

// shawkywhatsapp://launch?session=s_xxx  ->  https://web.shawkygroup.com/shawky/launch?session=s_xxx
// Anything else (bad host, bad session, other params) is ignored.
function launchUrlFrom(deepLink, appUrl = APP_URL) {
  let url;
  try {
    url = new URL(deepLink);
  } catch {
    return null;
  }
  if (url.protocol !== `${PROTOCOL}:` || url.hostname !== 'launch') return null;

  const session = url.searchParams.get('session');
  if (!session || !SESSION_FORMAT.test(session)) return null;

  const target = new URL('/shawky/launch', appUrl);
  target.searchParams.set('session', session);
  return target.toString();
}

// The deep link arrives as a command-line argument on Windows.
function deepLinkFromArgv(argv) {
  return argv.find(arg => typeof arg === 'string' && arg.startsWith(`${PROTOCOL}://`)) || null;
}

function isAppUrl(candidate, appUrl = APP_URL) {
  try {
    return new URL(candidate).origin === new URL(appUrl).origin;
  } catch {
    return false;
  }
}

module.exports = { APP_URL, PROTOCOL, launchUrlFrom, deepLinkFromArgv, isAppUrl };
