export const REVEALED_PHONE_VISIBLE_MS = 30000;
export const PHONE_MASK_MODES = ['last3', 'hidden'];
export const WINDOW_TICK_MS = 60000;
export const WINDOW_WARNING_SECONDS = 2 * 60 * 60;
export const EXPORT_FORMATS = ['csv', 'json'];
export const COST_CATEGORIES = [
  'service',
  'utility',
  'marketing',
  'authentication',
];
export const MESSAGE_RATES_EXAMPLE =
  '{"SA": {"service": 0.0045, "marketing": 0.0455}, "default": {"service": 0.004}}';
export const SETTING_SWITCHES = [
  { key: 'phone_masking_enabled', i18nKey: 'PHONE_MASKING' },
  { key: 'restricted_visibility_enabled', i18nKey: 'RESTRICTED_VISIBILITY' },
  { key: 'gateway_launch_enabled', i18nKey: 'GATEWAY_LAUNCH' },
];
