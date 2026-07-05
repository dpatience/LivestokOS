import type { InputHTMLAttributes, ReactNode, SelectHTMLAttributes } from "react";

type Variant = "farm" | "admin";

const labelClass: Record<Variant, string> = {
  farm: "text-farm-label text-farm-text",
  admin: "text-admin-body font-medium text-admin-text",
};

const inputClass: Record<Variant, string> = {
  farm:
    "w-full min-h-tap rounded-farm border border-farm-border bg-farm-surface px-3 text-farm-body text-farm-text placeholder:text-farm-text-muted focus:outline-none focus:ring-2 focus:ring-farm-primary",
  admin:
    "w-full min-h-tap rounded-admin border border-admin-border bg-admin-surface px-3 text-admin-body text-admin-text placeholder:text-admin-text-muted focus:outline-none focus:ring-2 focus:ring-admin-accent",
};

export interface FieldProps {
  variant?: Variant;
  label: string;
  error?: string;
  children: ReactNode;
}

export function Field({ variant = "farm", label, error, children }: FieldProps) {
  return (
    <label className="block space-y-1">
      <span className={labelClass[variant]}>{label}</span>
      {children}
      {error ? (
        <span className="block text-sm text-farm-danger" role="alert">
          {error}
        </span>
      ) : null}
    </label>
  );
}

export interface TextInputProps extends InputHTMLAttributes<HTMLInputElement> {
  variant?: Variant;
}

export function TextInput({ variant = "farm", className = "", ...props }: TextInputProps) {
  return (
    <input className={`${inputClass[variant]} ${className}`} {...props} />
  );
}

export interface SelectInputProps extends SelectHTMLAttributes<HTMLSelectElement> {
  variant?: Variant;
}

export function SelectInput({ variant = "farm", className = "", children, ...props }: SelectInputProps) {
  return (
    <select className={`${inputClass[variant]} ${className}`} {...props}>
      {children}
    </select>
  );
}

export interface CardProps {
  variant?: Variant;
  children: ReactNode;
  className?: string;
}

export function Card({ variant = "farm", children, className = "" }: CardProps) {
  const border = variant === "farm" ? "border-farm-border bg-farm-surface-alt" : "border-admin-border bg-admin-surface-alt";
  return (
    <div className={`rounded-farm border p-4 ${border} ${className}`}>{children}</div>
  );
}
