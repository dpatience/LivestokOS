/** Shared hover / active / focus classes — Rules 9–12. */

const base =
  "transition-colors duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 active:scale-[0.98]";

export const farmInteractive = `${base} focus-visible:ring-farm-primary`;
export const adminInteractive = `${base} focus-visible:ring-admin-accent`;

export const farmLinkPrimary = `${farmInteractive} tap-target inline-flex items-center justify-center rounded-farm bg-farm-primary px-4 font-semibold text-white hover:bg-farm-primary-hover`;

export const farmLinkSecondary = `${farmInteractive} tap-target inline-flex items-center justify-center rounded-farm border border-farm-border bg-farm-surface-alt px-4 font-semibold text-farm-text hover:border-farm-primary hover:bg-white`;

export const farmLinkInline = `${farmInteractive} font-semibold text-farm-primary underline-offset-2 hover:underline`;

export const farmCardRow = `${farmInteractive} tap-target block rounded-farm border border-farm-border bg-farm-surface-alt px-4 py-3 hover:border-farm-primary hover:bg-white focus-visible:ring-farm-primary`;

export const farmChip = `${farmInteractive} tap-target rounded-full border px-4 py-2 text-sm font-semibold focus-visible:ring-farm-primary`;

export const farmTile = `${farmInteractive} tap-target flex flex-col items-center justify-center rounded-farm border-2 py-4 focus-visible:ring-farm-primary`;

export const farmTab = `${farmInteractive} tap-target flex-1 rounded-farm border px-2 text-sm font-semibold focus-visible:ring-farm-primary`;

export const adminLinkPrimary = `${adminInteractive} tap-target inline-flex items-center justify-center rounded-admin bg-admin-primary px-4 font-medium text-white hover:bg-admin-primary-hover`;

export const adminLinkInline = `${adminInteractive} font-semibold text-admin-accent underline-offset-2 hover:underline`;
