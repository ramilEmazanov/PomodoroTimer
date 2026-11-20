import type { TimerState } from "../types";
import { formatTime } from "../utils/formatTime";
import Icon from "../components/Icon";
import AppButton from "../components/AppButton";

export default function TimerView({
  state,
  input,
  error,
  remaining,
  total,
  setInput,
  start,
  pause,
  resume,
  requestReset,
  newTimer,
}: {
  state: TimerState;
  input: string;
  error: boolean;
  remaining: number;
  total: number;
  setInput: (value: string) => void;
  start: () => void;
  pause: () => void;
  resume: () => void;
  requestReset: () => void;
  newTimer: () => void;
}) {
  const progress = total > 0 ? Math.max(0, Math.min(1, remaining / total)) : 0;
  const circumference = 2 * Math.PI * 148;
  const status =
    state === "running"
      ? "Сосредоточьтесь на текущей задаче"
      : state === "paused"
        ? "На паузе"
        : "Время вышло";

  return (
    <div className="page page--timer">
      <header className="page-header timer-header">
        <p className="eyebrow">СЕССИЯ ФОКУСА</p>
        <h1>{state === "setup" ? "Настройте таймер" : "Таймер фокуса"}</h1>
        <p className="subtitle">
          {state === "setup"
            ? "Выберите комфортное время для сосредоточенной работы."
            : "Одна задача. Никаких отвлечений."}
        </p>
      </header>

      <section className="timer-card">
        {state === "setup" ? (
          <div className="timer-setup">
            <div className="setup-icon">
              <Icon name="timer" size={30} />
            </div>
            <div className="field-group">
              <label htmlFor="duration">Длительность, мин</label>
              <input
                aria-describedby={error ? "duration-error duration-hint" : "duration-hint"}
                aria-invalid={error}
                autoComplete="off"
                id="duration"
                inputMode="numeric"
                onChange={(event) => setInput(event.target.value)}
                onKeyDown={(event) => {
                  if (event.key === "Enter") start();
                }}
                placeholder="25"
                value={input}
              />
              <p className="field-hint" id="duration-hint">
                Допустимое значение: от 1 до 1440 минут
              </p>
              {error && (
                <p className="field-error" id="duration-error" role="alert">
                  Введите целое число от 1 до 1440 минут
                </p>
              )}
            </div>
            <AppButton onClick={start}>
              <Icon name="play" size={18} /> Запустить
            </AppButton>
          </div>
        ) : (
          <div className="timer-active">
            <div className={`progress-ring progress-ring--${state}`}>
              <svg aria-hidden="true" viewBox="0 0 320 320">
                <circle className="progress-ring__track" cx="160" cy="160" r="148" />
                <circle
                  className="progress-ring__value"
                  cx="160"
                  cy="160"
                  r="148"
                  style={{
                    strokeDasharray: circumference,
                    strokeDashoffset: circumference * (1 - progress),
                  }}
                />
              </svg>
              <div className="timer-readout">
                <p aria-live="polite" className={`timer-status timer-status--${state}`}>
                  {status}
                </p>
                <time aria-label={`Осталось ${formatTime(remaining)}`}>
                  {formatTime(remaining)}
                </time>
                {state !== "finished" && <span>из {Math.round(total / 60)} мин</span>}
              </div>
            </div>

            <div className="timer-actions">
              {state === "finished" ? (
                <AppButton onClick={newTimer}>Настроить новый таймер</AppButton>
              ) : (
                <>
                  <AppButton onClick={state === "paused" ? resume : pause}>
                    <Icon name={state === "paused" ? "play" : "pause"} size={18} />
                    {state === "paused" ? "Продолжить" : "Пауза"}
                  </AppButton>
                  <AppButton onClick={requestReset} variant="secondary">
                    <Icon name="reset" size={17} /> Сбросить
                  </AppButton>
                </>
              )}
            </div>
          </div>
        )}
      </section>
      <p className="timer-footnote">
        <Icon name="focus" size={16} /> Время для спокойной и продуктивной работы
      </p>
    </div>
  );
}
