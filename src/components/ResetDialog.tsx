import { useEffect, useRef } from "react";
import AppButton from "./AppButton";

export default function ResetDialog({
  onCancel,
  onConfirm,
}: {
  onCancel: () => void;
  onConfirm: () => void;
}) {
  const cancelRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    cancelRef.current?.focus();
    const handleKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") onCancel();
    };
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, [onCancel]);

  return (
    <div
      aria-describedby="reset-description"
      aria-labelledby="reset-title"
      aria-modal="true"
      className="modal-backdrop"
      role="dialog"
    >
      <div className="dialog">
        <h2 id="reset-title">Reset timer?</h2>
        <p id="reset-description">Your progress in this session will not be lost</p>
        <div className="dialog__actions">
          <AppButton onClick={onConfirm} variant="danger">
            Reset
          </AppButton>
          <AppButton onClick={onCancel} ref={cancelRef} variant="secondary">
            Cancel
          </AppButton>
        </div>
      </div>
    </div>
  );
}
