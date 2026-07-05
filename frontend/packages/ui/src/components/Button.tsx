import type { ButtonHTMLAttributes, ReactNode } from "react";

type Variant = "farm" | "admin";

const baseInteractive =
  "transition-colors duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 active:scale-[0.98] disabled:pointer-events-none";

const variantClasses: Record<Variant, string> = {
  farm: `${baseInteractive} bg-farm-primary text-white hover:bg-farm-primary-hover focus-visible:ring-farm-primary rounded-farm text-farm-body font-semibold`,
  admin: `${baseInteractive} bg-admin-primary text-white hover:bg-admin-primary-hover focus-visible:ring-admin-accent rounded-admin text-admin-body font-medium`,
};

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  children: ReactNode;
}

export function Button({
  variant = "farm",
  className = "",
  children,
  ...props
}: ButtonProps) {
  return (
    <button
      type="button"
      className={`tap-target inline-flex items-center justify-center px-4 disabled:opacity-50 ${variantClasses[variant]} ${className}`}
      {...props}
    >
      {children}
    </button>
  );
}

export interface IconButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  label: string;
  children: ReactNode;
}

export function IconButton({
  variant = "farm",
  label,
  className = "",
  children,
  ...props
}: IconButtonProps) {
  const surface =
    variant === "farm"
      ? "bg-farm-surface-alt text-farm-text border-farm-border hover:bg-farm-surface focus-visible:ring-farm-primary"
      : "bg-admin-surface-alt text-admin-text border-admin-border hover:bg-white focus-visible:ring-admin-accent";

  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      className={`tap-target inline-flex items-center justify-center rounded-full border ${baseInteractive} ${surface} ${className}`}
      {...props}
    >
      {children}
    </button>
  );
}

export interface AppShellProps {
  variant?: Variant;
  title: string;
  children: ReactNode;
  nav?: ReactNode;
}

export function AppShell({ variant = "farm", title, children, nav }: AppShellProps) {
  const bg = variant === "farm" ? "bg-farm-surface" : "bg-admin-surface";
  const text = variant === "farm" ? "text-farm-text" : "text-admin-text";
  const header =
    variant === "farm"
      ? "bg-farm-primary text-white"
      : "bg-admin-primary text-white";

  return (
    <div className={`flex min-h-dvh flex-col ${bg} ${text}`}>
      <header className={`${header} px-4 py-3 shadow-sm`}>
        <h1 className="text-lg font-bold tracking-tight">{title}</h1>
      </header>
      <main className="flex-1 p-4 pb-24">{children}</main>
      {nav}
    </div>
  );
}
