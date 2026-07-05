/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_BASE_URL: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

/** Web NFC — Chrome Android only; https://developer.mozilla.org/en-US/docs/Web/API/NDEFReader */
interface NDEFRecord {
  recordType: string;
  mediaType?: string;
  id?: string;
  encoding?: string;
  lang?: string;
  data?: DataView;
}

interface NDEFMessage {
  records: NDEFRecord[];
}

interface NDEFReadingEvent extends Event {
  serialNumber?: string;
  message: NDEFMessage;
}

declare class NDEFReader extends EventTarget {
  scan(options?: { signal?: AbortSignal }): Promise<void>;
  write(message: NDEFMessageInit, options?: { signal?: AbortSignal }): Promise<void>;
}

interface NDEFMessageInit {
  records: NDEFRecordInit[];
}

interface NDEFRecordInit {
  recordType: string;
  data?: string | BufferSource;
  encoding?: string;
  lang?: string;
}

declare class NDEFWriter {
  write(message: NDEFMessageInit, options?: { signal?: AbortSignal }): Promise<void>;
}

interface Window {
  NDEFReader?: typeof NDEFReader;
}
