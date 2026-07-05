import type { ConsultReply } from "@livestok/api";
import { Button, Field, SelectInput } from "@livestok/ui";
import { useCallback, useEffect, useRef, useState } from "react";
import { ConsultMessage } from "./ConsultMessage";
import { formatApiError, useAuth } from "../context/AuthContext";

export interface ChatTurn {
  id: string;
  role: "user" | "assistant";
  content: string;
  reply?: ConsultReply;
}

interface ConsultChatProps {
  cowId: number | null;
  cowName?: string;
  onCowChange?: (cowId: number) => void;
  showCowPicker?: boolean;
  cows: { id: number; name: string }[];
}

export function ConsultChat({
  cowId,
  cowName,
  showCowPicker,
  cows,
  onCowChange,
}: ConsultChatProps) {
  const { consult } = useAuth();
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [turns, setTurns] = useState<ChatTurn[]>([]);
  const [input, setInput] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [starting, setStarting] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);

  const startSession = useCallback(
    async (id: number) => {
      setStarting(true);
      setError(null);
      setTurns([]);
      setSessionId(null);
      try {
        const { data } = await consult.startSession(id);
        setSessionId(data.session_id);
      } catch (e) {
        setError(formatApiError(e));
      } finally {
        setStarting(false);
      }
    },
    [consult],
  );

  useEffect(() => {
    if (cowId) void startSession(cowId);
    else {
      setSessionId(null);
      setTurns([]);
    }
  }, [cowId, startSession]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [turns, sending]);

  async function handleSend() {
    const text = input.trim();
    if (!text || !sessionId || sending) return;

    setInput("");
    setSending(true);
    setError(null);

    const userTurn: ChatTurn = { id: crypto.randomUUID(), role: "user", content: text };
    setTurns((prev) => [...prev, userTurn]);

    try {
      const { data } = await consult.sendMessage(sessionId, text);
      setTurns((prev) => [
        ...prev,
        {
          id: crypto.randomUUID(),
          role: "assistant",
          content: data.response,
          reply: data,
        },
      ]);
    } catch (e) {
      setError(formatApiError(e));
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="flex h-[calc(100dvh-11rem)] flex-col">
      {showCowPicker ? (
        <Field variant="farm" label="Consult about cow">
          <SelectInput
            variant="farm"
            value={cowId ?? ""}
            onChange={(e) => onCowChange?.(Number(e.target.value))}
          >
            <option value="">Select a cow…</option>
            {cows.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </SelectInput>
        </Field>
      ) : cowName ? (
        <p className="mb-2 shrink-0 text-sm font-semibold text-farm-text">
          Consulting about <span className="text-farm-primary">{cowName}</span>
        </p>
      ) : null}

      <div className="flex-1 space-y-3 overflow-y-auto rounded-farm border border-farm-border bg-farm-surface-alt/50 p-3">
        {!cowId ? (
          <p className="text-sm text-farm-text-muted">Select a cow to start a consult session.</p>
        ) : starting ? (
          <p className="text-sm text-farm-text-muted">Starting session…</p>
        ) : turns.length === 0 ? (
          <p className="text-sm text-farm-text-muted">
            Ask about this cow&apos;s history, health patterns, or management. Responses include
            provenance labels — not a generic chatbot.
          </p>
        ) : (
          turns.map((t) => (
            <ConsultMessage key={t.id} role={t.role} content={t.content} reply={t.reply} />
          ))
        )}
        {sending ? (
          <p className="text-sm font-semibold text-farm-primary" role="status">
            Assistant is thinking…
          </p>
        ) : null}
        <div ref={bottomRef} />
      </div>

      {error ? (
        <p className="mt-2 shrink-0 text-sm text-farm-danger" role="alert">
          {error}
        </p>
      ) : null}

      <div className="mt-3 flex shrink-0 gap-2">
        <textarea
          className="tap-target min-h-[3rem] flex-1 resize-none rounded-farm border border-farm-border bg-white px-3 py-2 text-base text-farm-text"
          placeholder="Ask the vet assistant…"
          value={input}
          disabled={!sessionId || sending}
          rows={2}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault();
              void handleSend();
            }
          }}
        />
        <Button
          variant="farm"
          type="button"
          className="!min-w-[4.5rem] self-end"
          disabled={!sessionId || sending || !input.trim()}
          onClick={() => void handleSend()}
        >
          {sending ? "…" : "Send"}
        </Button>
      </div>

      <p className="mt-2 shrink-0 text-xs text-farm-text-muted">
        Non-streaming JSON responses (backend has no SSE). Session expires after 30 min idle.
      </p>
    </div>
  );
}
