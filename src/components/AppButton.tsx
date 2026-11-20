import type { ComponentPropsWithRef } from "react";

export default function AppButton({
  children,
  variant = "primary",
  ...props
}: ComponentPropsWithRef<"button"> & {
  variant?: "primary" | "secondary" | "danger" | "quiet";
}) {
  return (
    <button className={`button button--${variant}`} {...props}>
      {children}
    </button>
  );
}
