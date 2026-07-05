import type { ReactNode } from "react";
import { NavLink, type NavLinkProps } from "react-router-dom";

type Variant = "farm" | "admin";

export interface NavItemProps extends Omit<NavLinkProps, "className"> {
  variant?: Variant;
  icon: ReactNode;
  label: string;
}

const navClass = (variant: Variant, isActive: boolean) => {
  const active =
    variant === "farm"
      ? "text-farm-primary bg-farm-primary/10"
      : "text-admin-accent bg-admin-accent/10";
  const idle =
    variant === "farm"
      ? "text-farm-text-muted hover:bg-farm-surface-alt hover:text-farm-text"
      : "text-admin-text-muted hover:bg-admin-surface-alt hover:text-admin-text";

  return `tap-target flex flex-1 flex-col items-center justify-center gap-1 rounded-admin px-1 py-2 text-xs font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-1 active:scale-[0.98] ${
    variant === "farm" ? "focus-visible:ring-farm-primary" : "focus-visible:ring-admin-accent"
  } ${isActive ? active : idle}`;
};

export function NavItem({ variant = "admin", icon, label, ...props }: NavItemProps) {
  return (
    <NavLink {...props} className={({ isActive }) => navClass(variant, isActive)}>
      <span className="flex h-6 w-6 items-center justify-center" aria-hidden>
        {icon}
      </span>
      {label}
    </NavLink>
  );
}

export interface BottomNavProps {
  variant?: Variant;
  children: ReactNode;
}

export function BottomNav({ variant = "admin", children }: BottomNavProps) {
  const border = variant === "farm" ? "border-farm-border bg-farm-surface" : "border-admin-border bg-admin-surface";
  return (
    <nav className={`fixed inset-x-0 bottom-0 border-t shadow-[0_-4px_12px_rgba(0,0,0,0.08)] ${border}`}>
      <div className="mx-auto flex max-w-5xl px-1">{children}</div>
    </nav>
  );
}
