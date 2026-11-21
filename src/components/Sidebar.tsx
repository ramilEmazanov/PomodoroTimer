import type { Section } from "../types";
import Icon from "./Icon";
import type { ComponentProps } from "react";

const navItems: Array<{ id: Section; label: string; icon: ComponentProps<typeof Icon>["name"] }> = [
  { id: "home", label: "Главная", icon: "home" },
  { id: "timer", label: "Таймер", icon: "timer" },
  { id: "stats", label: "Статистика", icon: "chart" },
  { id: "settings", label: "Настройки", icon: "settings" },
];

export default function Sidebar({
  active,
  onNavigate,
  onPreview,
}: {
  active: Section;
  onNavigate: (section: Section) => void;
  onPreview: (state: string) => void;
}) {
  return (
    <aside className="sidebar">
      <div className="traffic-lights" aria-hidden="true">
        <span className="traffic-light traffic-light--red" />
        <span className="traffic-light traffic-light--yellow" />
        <span className="traffic-light traffic-light--green" />
      </div>

      <div className="brand">
        <span className="brand__mark">
          <Icon name="focus" size={21} />
        </span>
        <span>Фокус</span>
      </div>

      <p className="nav-caption">Рабочее пространство</p>
      <nav aria-label="Основная навигация" className="navigation">
        {navItems.map((item) => (
          <button
            aria-label={item.label}
            aria-current={active === item.id ? "page" : undefined}
            className={`nav-item ${active === item.id ? "nav-item--active" : ""}`}
            key={item.id}
            onClick={() => onNavigate(item.id)}
          >
            <Icon name={item.icon} size={19} />
            <span>{item.label}</span>
          </button>
        ))}
      </nav>

      <div className="sidebar__footer">
        <label className="preview-label" htmlFor="preview-state">
          Просмотр прототипа
        </label>
        <div className="select-wrap">
          <select
            defaultValue=""
            id="preview-state"
            onChange={(event) => {
              if (event.target.value) onPreview(event.target.value);
              event.target.value = "";
            }}
          >
            <option disabled value="">
              Выбрать состояние
            </option>
            <option value="home-data">Главная с данными</option>
            <option value="home-empty">Главная без данных</option>
            <option value="setup">Настройка таймера</option>
            <option value="error">Ошибка ввода</option>
            <option value="running">Работающий таймер</option>
            <option value="paused">Пауза</option>
            <option value="dialog">Диалог сброса</option>
            <option value="finished">Завершённый таймер</option>
          </select>
          <Icon name="chevron" size={15} />
        </div>
      </div>
    </aside>
  );
}
