import type { ReactNode } from "react";

type Variant = "farm" | "admin";

export interface StatusIndicatorProps {
  variant?: Variant;
  tone: "success" | "warning" | "danger" | "muted";
  icon: ReactNode;
  label: string;
}

const toneClass: Record<StatusIndicatorProps["tone"], string> = {
  success: "text-admin-success",
  warning: "text-farm-accent",
  danger: "text-admin-danger",
  muted: "text-admin-text-muted",
};

export function StatusIndicator({ tone, icon, label }: StatusIndicatorProps) {
  return (
    <span className={`inline-flex items-center gap-1.5 text-sm font-medium ${toneClass[tone]}`}>
      <span className="flex h-4 w-4 shrink-0 items-center justify-center" aria-hidden>
        {icon}
      </span>
      <span>{label}</span>
    </span>
  );
}

export interface DataColumn<T> {
  id: string;
  header: string;
  cell: (row: T) => ReactNode;
  /** Shown as label in stacked mobile card layout */
  mobileLabel?: string;
}

export interface ResponsiveDataListProps<T> {
  rows: T[];
  columns: DataColumn<T>[];
  rowKey: (row: T) => string | number;
  onRowClick?: (row: T) => void;
  /** Column ids that keep native controls (e.g. action buttons) without row-click wrapper */
  nonClickableColumnIds?: string[];
  emptyMessage?: string;
}

export function ResponsiveDataList<T>({
  rows,
  columns,
  rowKey,
  onRowClick,
  nonClickableColumnIds = [],
  emptyMessage = "No records.",
}: ResponsiveDataListProps<T>) {
  if (rows.length === 0) {
    return <p className="text-sm text-admin-text-muted">{emptyMessage}</p>;
  }

  const clickableColumns = columns.filter((col) => !nonClickableColumnIds.includes(col.id));
  const actionColumns = columns.filter((col) => nonClickableColumnIds.includes(col.id));

  return (
    <>
      {/* Desktop / tablet table — hidden below md (768px) */}
      <div className="hidden overflow-x-auto rounded-admin border border-admin-border md:block">
        <table className="w-full min-w-[640px] text-left text-sm">
          <thead className="bg-admin-surface-alt text-admin-text-muted">
            <tr>
              {columns.map((col) => (
                <th key={col.id} className="px-4 py-3 font-semibold">
                  {col.header}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr
                key={rowKey(row)}
                className={`border-t border-admin-border transition-colors hover:bg-admin-accent/5 focus-within:bg-admin-accent/5 ${
                  onRowClick ? "cursor-pointer" : ""
                }`}
              >
                {columns.map((col) => (
                  <td key={col.id} className="px-4 py-3">
                    {onRowClick && !nonClickableColumnIds.includes(col.id) ? (
                      <button
                        type="button"
                        className="w-full text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-admin-accent"
                        onClick={() => onRowClick(row)}
                      >
                        {col.cell(row)}
                      </button>
                    ) : (
                      col.cell(row)
                    )}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Mobile stacked cards — visible below md */}
      <ul className="space-y-3 md:hidden">
        {rows.map((row) => (
          <li key={rowKey(row)}>
            <div className="w-full rounded-admin border border-admin-border bg-admin-surface-alt p-4 text-left transition-colors hover:border-admin-accent/40 hover:bg-white focus-within:ring-2 focus-within:ring-admin-accent">
              {onRowClick ? (
                <button
                  type="button"
                  className="w-full text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-admin-accent active:scale-[0.99]"
                  onClick={() => onRowClick(row)}
                >
                  <dl className="space-y-2">
                    {clickableColumns.map((col) => (
                      <div key={col.id} className="flex justify-between gap-3">
                        <dt className="text-xs font-semibold uppercase tracking-wide text-admin-text-muted">
                          {col.mobileLabel ?? col.header}
                        </dt>
                        <dd className="text-right text-sm font-medium text-admin-text">
                          {col.cell(row)}
                        </dd>
                      </div>
                    ))}
                  </dl>
                </button>
              ) : (
                <dl className="space-y-2">
                  {clickableColumns.map((col) => (
                    <div key={col.id} className="flex justify-between gap-3">
                      <dt className="text-xs font-semibold uppercase tracking-wide text-admin-text-muted">
                        {col.mobileLabel ?? col.header}
                      </dt>
                      <dd className="text-right text-sm font-medium text-admin-text">{col.cell(row)}</dd>
                    </div>
                  ))}
                </dl>
              )}
              {actionColumns.length > 0 ? (
                <div className="mt-3 flex flex-wrap justify-end gap-2 border-t border-admin-border pt-3">
                  {actionColumns.map((col) => (
                    <div key={col.id}>{col.cell(row)}</div>
                  ))}
                </div>
              ) : null}
            </div>
          </li>
        ))}
      </ul>
    </>
  );
}
