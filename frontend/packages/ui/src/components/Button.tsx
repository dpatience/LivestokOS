import type { ButtonHTMLAttributes, ReactNode } from "react";

type Variant = "farm" | "admin";

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  children: ReactNode;
}

const variantClasses: Record<Variant, string> = {
  farm:
    "bg-farm-primary text-white hover:bg-farm-primary-hover rounded-farm text-farm-body font-semibold",
  admin:
    "bg-admin-primary text-white hover:bg-admin-primary-hover rounded-admin text-admin-body font-medium",
};

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
      ? "bg-farm-surface-alt text-farm-text border-farm-border"
      : "bg-admin-surface-alt text-admin-text border-admin-border";

  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      className={`tap-target inline-flex items-center justify-center rounded-full border ${surface} ${className}`}
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
}

export function AppShell({ variant = "farm", title, children }: AppShellProps) {
  const bg = variant === "farm" ? "bg-farm-surface" : "bg-admin-surface";
  const text = variant === "farm" ? "text-farm-text" : "text-admin-text";
  const header =
    variant === "farm"
      ? "bg-farm-primary text-white"
      : "bg-admin-primary text-white";

  return (
    <div className={`min-h-dvh flex flex-col ${bg} ${text}`}>
      <header className={`${header} px-4 py-3 shadow-sm`}>
        <h1 className="text-lg font-bold tracking-tight">{title}</h1>
      </header>
      <main className="flex-1 p-4">{children}</main>
    </div>
  );
}
