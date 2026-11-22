import NavigationSymbol from "./NavigationSymbol";
import TimerSymbol from "./TimerSymbol";
import type { Section } from "../types";

const navItems: Array<{ id: Section; label: string }> = [
  { id: "home", label: "Home" },
  { id: "timer", label: "Timer" },
  { id: "stats", label: "Statistics" },
  { id: "settings", label: "Settings" },
];

export default function Sidebar({
  active,
  onNavigate,
  onPreview,
  dark,
  toggleTheme,
}: {
  dark: boolean;
  toggleTheme: () => void;
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
        <span>Focus</span>
      </div>

      <p className="nav-caption">Workspace</p>
      <nav aria-label="Main navigation" className="navigation">
        {navItems.map((item) => (
          <button
            aria-label={item.label}
            aria-current={active === item.id ? "page" : undefined}
            className={`nav-item ${active === item.id ? "nav-item--active" : ""}`}
            key={item.id}
            onClick={() => onNavigate(item.id)}
          >
            {item.id === "timer" ? <TimerSymbol /> : <NavigationSymbol name={item.id} />}
            <span>{item.label}</span>
          </button>
        ))}
      </nav>

      <button className="theme-toggle" role="switch" aria-checked={dark} onClick={toggleTheme}>
        <span>Dark mode</span>
        <span className="theme-toggle__track" aria-hidden="true">
          <span />
        </span>
      </button>
      <div className="sidebar__footer">
        <label className="preview-label" htmlFor="preview-state">
          Prototype preview
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
              Choose a state
            </option>
            <option value="home-data">Home with data</option>
            <option value="home-empty">Empty home</option>
            <option value="setup">Timer setup</option>
            <option value="error">Validation error</option>
            <option value="running">Running timer</option>
            <option value="paused">Pause</option>
            <option value="dialog">Reset dialog</option>
            <option value="finished">Finished timer</option>
          </select>
        </div>
      </div>
    </aside>
  );
}
