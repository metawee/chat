const test = require('node:test');
const assert = require('node:assert');
const { launchUrlFrom, deepLinkFromArgv, isAppUrl } = require('../src/links');

const APP = 'https://web.shawkygroup.com';

test('turns the CRM deep link into the launch URL', () => {
  assert.strictEqual(
    launchUrlFrom('shawkywhatsapp://launch?session=s_arZUC0VOUpqBfwQqO8ymgPZm', APP),
    'https://web.shawkygroup.com/shawky/launch?session=s_arZUC0VOUpqBfwQqO8ymgPZm'
  );
});

test('ignores other hosts, bad sessions and other schemes', () => {
  [
    'shawkywhatsapp://other?session=s_arZUC0VOUpqBfwQqO8ymgPZm',
    'shawkywhatsapp://launch?session=../../etc',
    'shawkywhatsapp://launch?session=s_short',
    'shawkywhatsapp://launch',
    'https://evil.example/launch?session=s_arZUC0VOUpqBfwQqO8ymgPZm',
    'not a url',
  ].forEach(link => assert.strictEqual(launchUrlFrom(link, APP), null, link));
});

test('finds the deep link among Windows command-line arguments', () => {
  const argv = ['C:\\Shawky WhatsApp.exe', '--flag', 'shawkywhatsapp://launch?session=s_abcdefgh12'];
  assert.strictEqual(deepLinkFromArgv(argv), 'shawkywhatsapp://launch?session=s_abcdefgh12');
  assert.strictEqual(deepLinkFromArgv(['app.exe']), null);
});

test('keeps navigation inside the Shawky WhatsApp site', () => {
  assert.ok(isAppUrl('https://web.shawkygroup.com/app/accounts/1/conversations/2', APP));
  assert.ok(!isAppUrl('https://web.shawkygroup.com.evil.example/', APP));
  assert.ok(!isAppUrl('https://system.shawkygroup.com/', APP));
});
