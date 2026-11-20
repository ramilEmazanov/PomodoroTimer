import { useEffect, useRef } from "react";
import Icon from "./Icon";
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
    <div aria-labelledby="reset-title" aria-modal="true" className="modal-backdrop" role="dialog">
      <div className="dialog">
        <div className="dialog__icon">
          <Icon name="reset" size={24} />
        </div>
        <h2 id="reset-title">Сбросить таймер?</h2>
        <p>Прогресс текущей сессии будет потерян</p>
        <div className="dialog__actions">
          <AppButton onClick={onCancel} ref={cancelRef} variant="secondary">
            Отмена
          </AppButton>
          <AppButton onClick={onConfirm} variant="danger">
            Сбросить
          </AppButton>
        </div>
      </div>
    </div>
  );
}
