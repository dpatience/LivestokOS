import type { ConsultAttribution, ConsultReply, ConsultSource } from "@livestok/api";
import {
  formatConfirmedDate,
  isConfirmedCaseReply,
  isInsufficientReply,
  sourceLabel,
} from "@livestok/api";
import { Activity, FileText, Link2, Search, type LucideIcon } from "@livestok/ui";

const BADGE_STYLES: Record<string, string> = {
  cow_own_data: "bg-farm-primary/15 text-farm-primary border-farm-primary/40",
  cross_farm_pattern: "bg-farm-accent/15 text-farm-accent border-farm-accent/40",
  research_corpus: "bg-blue-100 text-blue-900 border-blue-300",
  unknown: "bg-farm-surface-alt text-farm-text-muted border-farm-border",
};

const PROVENANCE_ICONS: Record<string, LucideIcon> = {
  cow_own_data: Activity,
  cross_farm_pattern: Link2,
  research_corpus: FileText,
  unknown: Search,
};

export function ProvenanceBadges({
  attributions,
  sources,
}: {
  attributions?: ConsultAttribution[];
  sources?: ConsultSource[];
}) {
  const items =
    attributions && attributions.length > 0
      ? attributions.map((a) => ({ type: a.source_type, count: a.count }))
      : (sources ?? []).map((s) => ({ type: s.source_type, count: 1 }));

  if (items.length === 0) {
    return (
      <span className="inline-flex items-center rounded-full border border-dashed border-farm-text-muted px-2 py-0.5 text-xs font-semibold text-farm-text-muted">
        Not enough data yet
      </span>
    );
  }

  return (
    <ul className="flex flex-wrap gap-1.5" aria-label="Source provenance">
      {items.map((item) => {
        const Icon = PROVENANCE_ICONS[item.type] ?? PROVENANCE_ICONS.unknown;
        return (
          <li key={item.type}>
            <span
              className={`inline-flex items-center gap-1 rounded-md border px-2 py-0.5 text-xs font-bold uppercase tracking-wide ${BADGE_STYLES[item.type] ?? BADGE_STYLES.unknown}`}
            >
              <Icon size={14} aria-hidden />
              {sourceLabel(item.type)}
              {item.count > 1 ? ` ×${item.count}` : ""}
            </span>
          </li>
        );
      })}
    </ul>
  );
}

export function ConfirmedCaseBanner({ reply }: { reply: ConsultReply }) {
  if (!isConfirmedCaseReply(reply)) return null;

  const date = reply.confirmed_case?.confirmed_at
    ? formatConfirmedDate(reply.confirmed_case.confirmed_at)
    : "a prior date";

  return (
    <div
      className="mb-2 rounded-farm border-2 border-farm-accent bg-farm-accent/10 px-3 py-2 text-sm font-semibold text-farm-accent"
      role="note"
    >
      Based on a vet-confirmed case from {date}
      {reply.confirmed_case?.situation_summary ? (
        <p className="mt-1 font-normal text-farm-text">{reply.confirmed_case.situation_summary}</p>
      ) : null}
    </div>
  );
}

export function InsufficientDataPanel({ reply }: { reply: ConsultReply }) {
  if (!isInsufficientReply(reply)) return null;

  return (
    <div
      className="rounded-farm border-2 border-dashed border-farm-accent bg-farm-accent/5 p-4"
      role="alert"
    >
      <p className="flex items-center gap-2 text-sm font-bold uppercase tracking-wide text-farm-accent">
        <Search size={18} aria-hidden />
        Insufficient data — dig further
      </p>
      <p className="mt-2 text-farm-text">{reply.response}</p>
      {reply.recommended_next_steps && reply.recommended_next_steps.length > 0 ? (
        <ul className="mt-3 list-inside list-disc space-y-1 text-sm text-farm-text-muted">
          {reply.recommended_next_steps.map((step) => (
            <li key={step}>{step}</li>
          ))}
        </ul>
      ) : null}
    </div>
  );
}

interface ConsultMessageProps {
  role: "user" | "assistant";
  content: string;
  reply?: ConsultReply;
}

export function ConsultMessage({ role, content, reply }: ConsultMessageProps) {
  if (role === "user") {
    return (
      <div className="flex justify-end">
        <div className="max-w-[85%] rounded-farm rounded-br-sm bg-farm-primary px-4 py-3 text-white">
          <p className="whitespace-pre-wrap text-sm">{content}</p>
        </div>
      </div>
    );
  }

  const insufficient = reply && isInsufficientReply(reply);
  const confirmed = reply && isConfirmedCaseReply(reply);

  return (
    <div className="flex justify-start">
      <div
        className={`max-w-[92%] space-y-2 rounded-farm px-4 py-3 ${
          insufficient
            ? "border-2 border-dashed border-farm-accent bg-farm-accent/5"
            : confirmed
              ? "border-2 border-farm-accent/50 bg-white shadow-sm"
              : "border border-farm-border bg-white shadow-sm"
        }`}
      >
        {reply ? <ConfirmedCaseBanner reply={reply} /> : null}

        {insufficient && reply ? (
          <InsufficientDataPanel reply={reply} />
        ) : (
          <p className="whitespace-pre-wrap text-sm text-farm-text">{content}</p>
        )}

        {reply && !insufficient ? (
          <ProvenanceBadges attributions={reply.attributions} sources={reply.sources} />
        ) : null}
      </div>
    </div>
  );
}
