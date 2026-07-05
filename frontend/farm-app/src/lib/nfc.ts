export type NfcCapability =
  | { supported: true }
  | { supported: false; reason: string };

export type NfcReadState =
  | { status: "idle" }
  | { status: "scanning" }
  | { status: "success"; serial: string; source: "nfc" }
  | { status: "error"; message: string }
  | { status: "timeout"; message: string };

export type NfcWriteState =
  | { status: "idle" }
  | { status: "writing" }
  | { status: "success" }
  | { status: "error"; message: string }
  | { status: "timeout"; message: string };

const NFC_LIMITATION =
  "Web NFC only works in Chrome on Android, over HTTPS, when you tap a button. " +
  "It does not work on iPhone/iPad Safari or most desktop browsers — use QR scan instead.";

export function getNfcCapability(): NfcCapability {
  if (typeof window === "undefined") {
    return { supported: false, reason: "NFC is not available during server render." };
  }
  if (!("NDEFReader" in window)) {
    return {
      supported: false,
      reason: NFC_LIMITATION,
    };
  }
  if (!window.isSecureContext) {
    return {
      supported: false,
      reason: `NFC requires HTTPS. ${NFC_LIMITATION}`,
    };
  }
  return { supported: true };
}

export function nfcLimitationText(): string {
  return NFC_LIMITATION;
}

export interface ReadNfcOptions {
  timeoutMs?: number;
  parseSerial?: (record: NDEFRecord) => string | null;
}

function defaultParseSerial(record: NDEFRecord): string | null {
  if (record.recordType === "text") {
    const decoder = new TextDecoder(record.encoding ?? "utf-8");
    return parseTextRecord(decoder.decode(record.data));
  }
  if (record.recordType === "url") {
    const decoder = new TextDecoder();
    return parseTextRecord(decoder.decode(record.data));
  }
  return null;
}

function parseTextRecord(text: string): string | null {
  // Strip optional language prefix from NDEF text records (status byte + lang)
  const cleaned = text.replace(/^\x02en/, "").trim();
  if (cleaned.toLowerCase().startsWith("livestok:necklace:")) {
    return cleaned.slice("livestok:necklace:".length).trim() || null;
  }
  return cleaned.length >= 4 ? cleaned : null;
}

export async function readNfcSerial(
  options: ReadNfcOptions = {},
): Promise<NfcReadState> {
  const cap = getNfcCapability();
  if (!cap.supported) {
    return { status: "error", message: cap.reason };
  }

  const timeoutMs = options.timeoutMs ?? 15_000;
  const parse = options.parseSerial ?? defaultParseSerial;

  const reader = new NDEFReader();
  let timeoutId: ReturnType<typeof setTimeout> | undefined;

  try {
    const readPromise = new Promise<NfcReadState>((resolve, reject) => {
      reader.addEventListener(
        "reading",
        (event: NDEFReadingEvent) => {
          const serial =
            event.message.records.map(parse).find(Boolean) ??
            event.serialNumber ??
            null;
          if (serial) {
            resolve({ status: "success", serial, source: "nfc" });
          } else {
            resolve({
              status: "error",
              message: "Tag read completed but no device UID was found on the tag.",
            });
          }
        },
        { once: true },
      );
      reader.addEventListener(
        "readingerror",
        () => {
          reject(new Error("NFC readingerror event — tag may have moved away too soon."));
        },
        { once: true },
      );
    });

    await reader.scan();

    const timeoutPromise = new Promise<NfcReadState>((resolve) => {
      timeoutId = setTimeout(() => {
        resolve({
          status: "timeout",
          message: `No tag detected within ${timeoutMs / 1000}s. Hold the phone steady against the necklace.`,
        });
      }, timeoutMs);
    });

    const result = await Promise.race([readPromise, timeoutPromise]);
    return result;
  } catch (err) {
    return {
      status: "error",
      message: err instanceof Error ? err.message : "NFC scan failed.",
    };
  } finally {
    if (timeoutId) clearTimeout(timeoutId);
  }
}

export async function writeNfcSerial(
  serial: string,
  options: { timeoutMs?: number } = {},
): Promise<NfcWriteState> {
  const cap = getNfcCapability();
  if (!cap.supported) {
    return { status: "error", message: cap.reason };
  }

  const timeoutMs = options.timeoutMs ?? 15_000;
  const writer = new NDEFWriter();
  const payload = `livestok:necklace:${serial.trim()}`;

  let timeoutId: ReturnType<typeof setTimeout> | undefined;

  try {
    const writePromise = writer.write({
      records: [{ recordType: "text", data: payload }],
    });

    const timeoutPromise = new Promise<never>((_, reject) => {
      timeoutId = setTimeout(() => {
        reject(new Error(`Write timed out after ${timeoutMs / 1000}s.`));
      }, timeoutMs);
    });

    await Promise.race([writePromise, timeoutPromise]);
    return { status: "success" };
  } catch (err) {
    const message = err instanceof Error ? err.message : "NFC write failed.";
    if (message.includes("timed out")) {
      return { status: "timeout", message };
    }
    return { status: "error", message };
  } finally {
    if (timeoutId) clearTimeout(timeoutId);
  }
}
