import { useMemo } from "react";
import Icon from "../components/Icon";
import AppButton from "../components/AppButton";

export default function Home({
  empty,
  setEmpty,
  openTimer,
}: {
  empty: boolean;
  setEmpty: (value: boolean) => void;
  openTimer: () => void;
}) {
  const today = useMemo(
    () =>
      new Intl.DateTimeFormat("ru-RU", {
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
          <h1>Добрый день, Алексей</h1>
          <p className="subtitle">Небольшой шаг к важной цели начинается с фокуса.</p>
        </div>
        <div aria-label="Состояние главной" className="segmented">
          <button className={!empty ? "active" : ""} onClick={() => setEmpty(false)}>
            С данными
          </button>
          <button className={empty ? "active" : ""} onClick={() => setEmpty(true)}>
            Пусто
          </button>
        </div>
      </header>

      {empty ? (
        <section className="empty-state">
          <div className="empty-state__icon">
            <Icon name="focus" size={28} />
          </div>
          <h2>Начните первую сессию</h2>
          <p>Здесь появится статистика времени и список завершённых задач.</p>
          <AppButton onClick={openTimer}>
            <Icon name="play" size={18} /> Запустить таймер
          </AppButton>
        </section>
      ) : (
        <>
          <section aria-label="Краткая статистика" className="metric-grid">
            <article className="metric-card metric-card--accent">
              <div className="metric-card__icon">
                <Icon name="timer" size={20} />
              </div>
              <div>
                <p>В фокусе сегодня</p>
                <strong>1 ч 45 мин</strong>
                <span>На 18 мин больше, чем вчера</span>
              </div>
            </article>
            <article className="metric-card">
              <div className="metric-card__icon">
                <Icon name="calendar" size={20} />
              </div>
              <div>
                <p>В фокусе на этой неделе</p>
                <strong>8 ч 20 мин</strong>
                <span>На 12% больше прошлой недели</span>
              </div>
            </article>
            <article className="metric-card">
              <div className="metric-card__icon">
                <Icon name="check" size={20} />
              </div>
              <div>
                <p>Сессий завершено</p>
                <strong>4</strong>
                <span>Лучший результат недели</span>
              </div>
            </article>
          </section>

          <section className="content-card tasks">
            <div className="section-heading">
              <div>
                <h2>Задачи на сегодня</h2>
                <p>3 из 5 выполнено</p>
              </div>
              <AppButton onClick={openTimer} variant="secondary">
                <Icon name="play" size={17} /> Начать фокус
              </AppButton>
            </div>
            <div className="task-list">
              {[
                ["Подготовить структуру презентации", true, "45 мин"],
                ["Разобрать входящие сообщения", true, "25 мин"],
                ["Обновить план проекта", true, "35 мин"],
                ["Согласовать макеты интерфейса", false, "25 мин"],
                ["Подвести итоги дня", false, "15 мин"],
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
