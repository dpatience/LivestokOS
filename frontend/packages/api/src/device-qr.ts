/** QR payload: plain serial or livestok:necklace:<serial> */
const PREFIX = "livestok:necklace:";

export function formatDeviceQrPayload(serial: string): string {
  return `${PREFIX}${serial.trim()}`;
}

export function parseDeviceQrPayload(raw: string): string | null {
  const text = raw.trim();
  if (!text) return null;
  if (text.toLowerCase().startsWith(PREFIX)) {
    const serial = text.slice(PREFIX.length).trim();
    return serial.length > 0 ? serial : null;
  }
  // Plain UID on the label
  if (/^[A-Za-z0-9._:-]+$/.test(text) && text.length >= 4) {
    return text;
  }
  return null;
}

export function buildPrintableQrUrl(serial: string): string {
  const payload = encodeURIComponent(formatDeviceQrPayload(serial));
  return `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${payload}`;
}
