import { useEffect, useState } from "react";
import type { Section, TimerState } from "./types";
import Sidebar from "./components/Sidebar";
import ResetDialog from "./components/ResetDialog";
import Home from "./pages/Home";
import TimerView from "./pages/TimerView";
import Placeholder from "./pages/Placeholder";

const INITIAL_MINUTES = 25;
const INITIAL_SECONDS = INITIAL_MINUTES * 60;

export default function App() {
  const [theme, setTheme] = useState<"light" | "dark">(() => {
    try {
      const saved = localStorage.getItem("focus-theme");
      if (saved === "light" || saved === "dark") return saved;
    } catch {
      /* Storage may be unavailable in private contexts. */
    }
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  });

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    try {
      localStorage.setItem("focus-theme", theme);
    } catch {
      /* Keep the in-memory preference. */
    }
  }, [theme]);

  const [recents, setRecents] = useState<number[]>(() => {
    try {
      const stored: unknown = JSON.parse(localStorage.getItem("focus-recents") || "[]");
      return Array.isArray(stored)
        ? [
            ...new Set(
              stored.filter(
                (value): value is number => Number.isInteger(value) && value > 0 && value <= 86399,
              ),
            ),
          ].slice(0, 8)
        : [];
    } catch {
      return [];
    }
  });
  useEffect(() => {
    try {
      localStorage.setItem("focus-recents", JSON.stringify(recents));
    } catch {
      /* Storage is optional. */
    }
  }, [recents]);

  const [section, setSection] = useState<Section>("home");
  const [homeEmpty, setHomeEmpty] = useState(false);
  const [timerState, setTimerState] = useState<TimerState>("setup");
  const [durationInput, setDurationInput] = useState(String(INITIAL_SECONDS));
  const [totalSeconds, setTotalSeconds] = useState(INITIAL_SECONDS);
  const [remaining, setRemaining] = useState(INITIAL_SECONDS);
  const [endAt, setEndAt] = useState<number | null>(null);
  const [inputError, setInputError] = useState(false);
  const [dialogOpen, setDialogOpen] = useState(false);

  useEffect(() => {
    if (timerState !== "running" || endAt === null) return;
    const update = () => {
      const next = Math.max(0, Math.ceil((endAt - Date.now()) / 1000));
      setRemaining(next);
      if (next <= 0) {
        setTimerState("finished");
        setEndAt(null);
        setDialogOpen(false);
      }
    };
    update();
    const interval = window.setInterval(update, 250);
    return () => window.clearInterval(interval);
  }, [timerState, endAt]);

  const startTimer = (presetSeconds?: number) => {
    const seconds = presetSeconds ?? Number(durationInput);
    if (!Number.isInteger(seconds) || seconds < 1 || seconds > 86399) {
      setInputError(true);
      return;
    }
    setInputError(false);
    setRecents((previous) =>
      [seconds, ...previous.filter((value) => value !== seconds)].slice(0, 8),
    );
    setDurationInput(String(seconds));
    setTotalSeconds(seconds);
    setRemaining(seconds);
    setEndAt(Date.now() + seconds * 1000);
    setTimerState("running");
  };

  const pauseTimer = () => {
    if (endAt !== null) setRemaining(Math.max(0, Math.ceil((endAt - Date.now()) / 1000)));
    setEndAt(null);
    setTimerState("paused");
  };

  const resumeTimer = () => {
    if (remaining <= 0) {
      setTimerState("finished");
      return;
    }
    setEndAt(Date.now() + remaining * 1000);
    setTimerState("running");
  };

  const resetTimer = () => {
    setDialogOpen(false);
    setEndAt(null);
    setRemaining(totalSeconds);
    setTimerState("setup");
  };

  const newTimer = () => {
    setEndAt(null);
    setRemaining(totalSeconds);
    setTimerState("setup");
  };

  const previewState = (state: string) => {
    setDialogOpen(false);
    setInputError(false);
    if (state === "home-data" || state === "home-empty") {
      setSection("home");
      setHomeEmpty(state === "home-empty");
      return;
    }
    setSection("timer");
    if (state === "error") {
      setDurationInput("0");
      setInputError(true);
      setTimerState("setup");
      return;
    }
    if (state === "setup") {
      setDurationInput(String(INITIAL_SECONDS));
      setTimerState("setup");
      return;
    }
    const demoRemaining = state === "finished" ? 0 : 12 * 60 + 34;
    setTotalSeconds(INITIAL_SECONDS);
    setRemaining(demoRemaining);
    setTimerState(state === "dialog" ? "running" : (state as TimerState));
    if (state === "running" || state === "dialog") setEndAt(Date.now() + demoRemaining * 1000);
    else setEndAt(null);
    if (state === "dialog") setDialogOpen(true);
  };

  return (
    <div className="app-shell">
      <Sidebar
        active={section}
        onNavigate={setSection}
        onPreview={previewState}
        dark={theme === "dark"}
        toggleTheme={() => setTheme(theme === "dark" ? "light" : "dark")}
      />
      <main>
        {section === "home" && <Home empty={homeEmpty} openTimer={() => setSection("timer")} />}
        {section === "timer" && (
          <TimerView
            endsAt={endAt}
            error={inputError}
            input={durationInput}
            newTimer={newTimer}
            pause={pauseTimer}
            remaining={remaining}
            requestReset={() => setDialogOpen(true)}
            resume={resumeTimer}
            setInput={(value) => {
              setDurationInput(value);
              if (inputError) setInputError(false);
            }}
            recents={recents}
            startRecent={(seconds) => startTimer(seconds)}
            start={() => startTimer()}
            state={timerState}
            total={totalSeconds}
          />
        )}
        {(section === "stats" || section === "settings") && <Placeholder section={section} />}
      </main>
      {dialogOpen && <ResetDialog onCancel={() => setDialogOpen(false)} onConfirm={resetTimer} />}
    </div>
  );
}
