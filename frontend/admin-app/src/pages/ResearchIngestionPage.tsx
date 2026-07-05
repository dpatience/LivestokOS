import type { IngestionStatus, ResearchArticleRecord } from "@livestok/api";
import {
  Button,
  Play,
  RefreshCw,
  ResponsiveDataList,
  StatusIndicator,
  type DataColumn,
} from "@livestok/ui";
import { useCallback, useEffect, useState } from "react";
import {
  formatIngestionErrors,
  ingestionDisplayStatus,
  ingestionStatusIcon,
  ingestionStatusLabel,
  ingestionStatusTone,
} from "../lib/ingestion-status";
import { useAdminAuth } from "../context/AdminAuthContext";

export function ResearchIngestionPage() {
  const { admin } = useAdminAuth();
  const [articles, setArticles] = useState<ResearchArticleRecord[]>([]);
  const [status, setStatus] = useState<IngestionStatus | null>(null);
  const [triggering, setTriggering] = useState(false);
  const [error, setError] = useState("");

  const refresh = useCallback(async () => {
    const [articlesRes, statusRes] = await Promise.all([
      admin.listResearchArticles({ limit: 500 }),
      admin.getIngestionStatus(),
    ]);
    setArticles(articlesRes.data);
    setStatus(statusRes.data);
  }, [admin]);

  useEffect(() => {
    void refresh().catch((err: unknown) => {
      setError(err instanceof Error ? err.message : "Failed to load research corpus");
    });
  }, [refresh]);

  useEffect(() => {
    const display = status ? ingestionDisplayStatus(status.job.state) : null;
    if (display !== "in_progress") return;

    const timer = window.setInterval(() => {
      void admin.getIngestionStatus().then((res) => setStatus(res.data));
    }, 4000);

    return () => window.clearInterval(timer);
  }, [admin, status]);

  async function handleTrigger() {
    setTriggering(true);
    setError("");
    try {
      await admin.triggerIngestion();
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to trigger ingestion");
    } finally {
      setTriggering(false);
    }
  }

  const displayStatus = status ? ingestionDisplayStatus(status.job.state) : "idle";
  const statusErrors = status ? formatIngestionErrors(status.job.errors) : null;

  const columns: DataColumn<ResearchArticleRecord>[] = [
    { id: "title", header: "Title", cell: (a) => a.title },
    { id: "authors", header: "Authors", cell: (a) => a.authors ?? "—" },
    { id: "source", header: "Source", cell: (a) => a.source ?? "—" },
    {
      id: "published",
      header: "Published",
      cell: (a) => (a.published_date ? a.published_date : "—"),
    },
    {
      id: "ingested",
      header: "Ingested",
      cell: (a) => new Date(a.inserted_at).toLocaleDateString(),
    },
    {
      id: "url",
      header: "Link",
      cell: (a) =>
        a.url ? (
          <a
            href={a.url}
            target="_blank"
            rel="noopener noreferrer"
            className="text-admin-accent underline transition-colors hover:text-admin-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-admin-accent"
          >
            Citation
          </a>
        ) : (
          "—"
        ),
    },
  ];

  return (
    <div className="space-y-4">
      <h2 className="text-xl font-bold">Research corpus ingestion</h2>
      <p className="text-sm text-admin-text-muted">
        Oversight for the Stage 6F ingestion pipeline — ingested sources, manual run trigger, and
        last-run status. No AI chat here.
      </p>

      <div className="flex flex-col gap-3 rounded-admin border border-admin-border bg-admin-surface-alt p-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="space-y-1">
          <StatusIndicator
            tone={ingestionStatusTone(displayStatus)}
            icon={ingestionStatusIcon(displayStatus)}
            label={status ? ingestionStatusLabel(status.job.state) : "Loading…"}
          />
          {status ? (
            <p className="text-xs text-admin-text-muted">
              {status.article_count} article{status.article_count === 1 ? "" : "s"} in corpus
              {status.job.completed_at
                ? ` · Last finished ${new Date(status.job.completed_at).toLocaleString()}`
                : status.job.inserted_at
                  ? ` · Job queued ${new Date(status.job.inserted_at).toLocaleString()}`
                  : ""}
            </p>
          ) : null}
          {statusErrors ? (
            <p className="text-xs text-admin-danger">{statusErrors}</p>
          ) : null}
        </div>
        <div className="flex flex-wrap gap-2">
          <Button
            variant="admin"
            className="inline-flex gap-2"
            disabled={triggering}
            onClick={() => void handleTrigger()}
          >
            <Play size={16} aria-hidden />
            {triggering ? "Triggering…" : "Trigger ingestion run"}
          </Button>
          <Button
            variant="admin"
            className="inline-flex gap-2 bg-admin-surface-alt text-admin-text ring-1 ring-admin-border hover:bg-white"
            onClick={() => void refresh()}
          >
            <RefreshCw size={16} aria-hidden />
            Refresh
          </Button>
        </div>
      </div>

      {error ? <p className="text-sm text-admin-danger">{error}</p> : null}

      <ResponsiveDataList
        rows={articles}
        columns={columns}
        rowKey={(a) => a.id}
        emptyMessage="No research articles ingested yet."
      />

      {articles.some((a) => a.abstract_summary) ? (
        <details className="rounded-admin border border-admin-border bg-admin-surface-alt p-4">
          <summary className="cursor-pointer text-sm font-semibold transition-colors hover:text-admin-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-admin-accent">
            Abstract summaries ({articles.filter((a) => a.abstract_summary).length})
          </summary>
          <ul className="mt-3 space-y-4">
            {articles
              .filter((a) => a.abstract_summary)
              .map((a) => (
                <li key={a.id} className="border-t border-admin-border pt-3 first:border-0 first:pt-0">
                  <p className="font-medium">{a.title}</p>
                  <p className="mt-1 text-sm text-admin-text-muted">{a.abstract_summary}</p>
                </li>
              ))}
          </ul>
        </details>
      ) : null}
    </div>
  );
}
