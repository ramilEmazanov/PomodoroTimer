import type { TimerState } from "../types";
import { formatTime } from "../utils/formatTime";
import DurationPicker from "../components/DurationPicker";
import { useState } from "react";
import Icon from "../components/Icon";
import AppButton from "../components/AppButton";

export default function TimerView({
  state,
  endsAt,
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
  recents,
  startRecent,
}: {
  recents: number[];
  startRecent: (seconds: number) => void;
  endsAt: number | null;
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
  const [entryMode, setEntryMode] = useState<"wheel" | "input">("wheel");
  const [manualValues, setManualValues] = useState<string[] | null>(null);
  const duration = Number(input) || 0;
  const units = [
    { label: "Hours", factor: 3600, max: 23, value: Math.floor(duration / 3600) },
    { label: "Minutes", factor: 60, max: 59, value: Math.floor((duration % 3600) / 60) },
    { label: "Seconds", factor: 1, max: 59, value: duration % 60 },
  ];
  const displayedValues = manualValues ?? units.map((unit) => String(unit.value).padStart(2, "0"));
  const invalidFields = displayedValues.map(
    (value, index) =>
      value === "" ||
      !Number.isInteger(Number(value)) ||
      Number(value) < 0 ||
      Number(value) > units[index].max,
  );
  const invalidIndex = entryMode === "input" ? invalidFields.findIndex(Boolean) : -1;
  const validationMessage =
    invalidIndex >= 0
      ? displayedValues[invalidIndex] === ""
        ? `Enter a value for ${units[invalidIndex].label}.`
        : `${units[invalidIndex].label} must be a whole number from 0 to ${units[invalidIndex].max}.`
      : error || duration === 0
        ? "Choose a duration of at least 1 second."
        : null;
  const startCurrent = () => {
    if (validationMessage) return;
    setManualValues(null);
    start();
  };
  const progress = total > 0 ? Math.max(0, Math.min(1, remaining / total)) : 0;
  const circumference = 2 * Math.PI * 148;
  const status =
    state === "running" && endsAt !== null
      ? new Intl.DateTimeFormat("en-GB", { hour: "2-digit", minute: "2-digit" }).format(
          new Date(endsAt),
        )
      : state === "paused"
        ? "Paused"
        : "Time’s up";
  const displayTime =
    remaining >= 3600
      ? formatTime(remaining)
      : `${Math.floor(remaining / 60)}:${String(remaining % 60).padStart(2, "0")}`;

  return (
    <div className="page page--timer">
      <header className="page-header timer-header">
        <h1>Timers</h1>
      </header>

      <div className="timers-layout">
        <section className="timer-card">
          {state === "setup" ? (
            <div className="iphone-timer-setup">
              <div
                className="segmented timer-entry-mode"
                role="group"
                aria-label="Duration entry mode"
              >
                <button
                  className={entryMode === "wheel" ? "active" : ""}
                  aria-pressed={entryMode === "wheel"}
                  onClick={() => {
                    setManualValues(null);
                    setEntryMode("wheel");
                  }}
                >
                  Wheel
                </button>
                <button
                  className={entryMode === "input" ? "active" : ""}
                  aria-pressed={entryMode === "input"}
                  onClick={() => {
                    setManualValues(null);
                    setEntryMode("input");
                  }}
                >
                  Input
                </button>
              </div>
              {entryMode === "wheel" ? (
                <DurationPicker seconds={duration} onChange={(value) => setInput(String(value))} />
              ) : (
                <div className="duration-manual" role="group" aria-label="Timer duration">
                  {units.map((unit, index) => (
                    <label key={unit.label}>
                      <span aria-hidden="true">
                        {unit.label === "Hours" ? "hr" : unit.label === "Minutes" ? "min" : "sec"}
                      </span>
                      <input
                        type="number"
                        inputMode="numeric"
                        min={0}
                        max={unit.max}
                        step={1}
                        required
                        aria-label={unit.label}
                        aria-invalid={invalidFields[index] || undefined}
                        aria-describedby={validationMessage ? "duration-error" : undefined}
                        value={displayedValues[index]}
                        onFocus={(event) => event.currentTarget.select()}
                        onChange={(event) => {
                          const next = displayedValues.map((value, i) =>
                            i === index ? event.target.value : value,
                          );
                          setManualValues(next);
                          if (
                            next.every(
                              (value, i) =>
                                value !== "" &&
                                Number.isInteger(Number(value)) &&
                                Number(value) >= 0 &&
                                Number(value) <= units[i].max,
                            )
                          ) {
                            setInput(
                              String(
                                next.reduce(
                                  (total, value, i) => total + Number(value) * units[i].factor,
                                  0,
                                ),
                              ),
                            );
                          }
                        }}
                        onKeyDown={(event) => {
                          if (event.key === "Enter") startCurrent();
                        }}
                      />
                    </label>
                  ))}
                </div>
              )}
              {validationMessage && (
                <p className="field-error" role="alert" id="duration-error">
                  {validationMessage}
                </p>
              )}
              <div className="clock-actions">
                <button
                  className="clock-button clock-button--cancel"
                  disabled={duration === 0 && !manualValues}
                  onClick={() => {
                    setManualValues(null);
                    setInput("0");
                  }}
                >
                  Cancel
                </button>
                <button
                  className="clock-button clock-button--start"
                  disabled={Boolean(validationMessage)}
                  onClick={startCurrent}
                >
                  Start
                </button>
              </div>
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
                <div className={`timer-readout ${remaining >= 3600 ? "timer-readout--hours" : ""}`}>
                  <p aria-live="polite" className={`timer-status timer-status--${state}`}>
                    {state === "running" && <Icon name="timer" size={14} />}
                    {status}
                  </p>
                  <time aria-label={`Time remaining: ${formatTime(remaining)}`}>{displayTime}</time>
                </div>
              </div>

              <div className="timer-actions">
                {state === "finished" ? (
                  <AppButton onClick={newTimer}>Set a new timer</AppButton>
                ) : (
                  <>
                    <AppButton onClick={requestReset} variant="secondary">
                      Cancel
                    </AppButton>
                    <AppButton
                      data-action={state === "paused" ? "resume" : "pause"}
                      onClick={state === "paused" ? resume : pause}
                    >
                      {state === "paused" ? "Resume" : "Pause"}
                    </AppButton>
                  </>
                )}
              </div>
            </div>
          )}
        </section>
        <section className="recents-card" aria-labelledby="recents-title">
          <h2 id="recents-title">Recents</h2>
          {recents.length === 0 ? (
            <p className="recents-empty">Timers you start will appear here.</p>
          ) : (
            <ul className="recents-list">
              {recents.map((seconds) => (
                <li className="recent-timer" key={seconds}>
                  <div>
                    <p className="recent-timer__time">
                      {seconds >= 3600
                        ? formatTime(seconds)
                        : `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`}
                    </p>
                    <p className="recent-timer__duration">
                      {[
                        Math.floor(seconds / 3600) ? `${Math.floor(seconds / 3600)} h` : "",
                        Math.floor((seconds % 3600) / 60)
                          ? `${Math.floor((seconds % 3600) / 60)} min`
                          : "",
                        seconds % 60 ? `${seconds % 60} sec` : "",
                      ]
                        .filter(Boolean)
                        .join(" ")}
                    </p>
                  </div>
                  <button
                    className="recent-timer__start"
                    aria-label={`Start ${formatTime(seconds)} timer`}
                    disabled={state === "running" || state === "paused"}
                    onClick={() => startRecent(seconds)}
                  >
                    <Icon name="play" size={24} />
                  </button>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    </div>
  );
}
