import { useMemo } from "react";
import Icon from "../components/Icon";
import AppButton from "../components/AppButton";

export default function Home({ empty, openTimer }: { empty: boolean; openTimer: () => void }) {
  const today = useMemo(
    () =>
      new Intl.DateTimeFormat("en-US", {
        weekday: "long",
        day: "numeric",
        month: "long",
      }).format(new Date()),
    [],
  );

  return (
    <div className="page page--home">
      <header className="page-header page-header--split">
        <div>
          <p className="eyebrow">{today}</p>
          <h1>Home</h1>
        </div>
      </header>

      {empty ? (
        <section className="empty-state">
          <div className="empty-state__icon">
            <Icon name="focus" size={28} />
          </div>
          <h2>Start your first session</h2>
          <p>Your focus time and completed tasks will appear here.</p>
          <AppButton onClick={openTimer}>
            <Icon name="play" size={18} /> Start timer
          </AppButton>
        </section>
      ) : (
        <>
          <section aria-label="Focus overview" className="metric-grid">
            <article className="metric-card metric-card--accent">
              <div>
                <p>Focus today</p>
                <strong>1 h 45 min</strong>
                <span>18 min more than yesterday</span>
              </div>
            </article>
            <article className="metric-card">
              <div>
                <p>Focus this week</p>
                <strong>8 h 20 min</strong>
                <span>12% more than last week</span>
              </div>
            </article>
            <article className="metric-card">
              <div>
                <p>Sessions completed</p>
                <strong>4</strong>
                <span>Your best this week</span>
              </div>
            </article>
          </section>

          <section className="content-card tasks">
            <div className="section-heading">
              <div>
                <h2>Today’s tasks</h2>
                <p>3 of 5 completed</p>
              </div>
            </div>
            <div className="task-list">
              {[
                ["Outline the presentation", true, "45 min"],
                ["Review incoming messages", true, "25 min"],
                ["Update the project plan", true, "35 min"],
                ["Review interface designs", false, "25 min"],
                ["Reflect on the day", false, "15 min"],
              ].map(([label, done, duration]) => (
                <div className={`task ${done ? "task--done" : ""}`} key={String(label)}>
                  <span className="task__check">{done && <Icon name="check" size={14} />}</span>
                  <span className="task__label">{label}</span>
                  <span className="task__duration">{duration}</span>
                </div>
              ))}
            </div>
          </section>
        </>
      )}
    </div>
  );
}
