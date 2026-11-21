import Icon from "../components/Icon";

export default function Placeholder({ section }: { section: "stats" | "settings" }) {
  const isStats = section === "stats";
  return (
    <div className="page">
      <header className="page-header">
        <p className="eyebrow">{isStats ? "YOUR PROGRESS" : "APPLICATION"}</p>
        <h1>{isStats ? "Statistics" : "Settings"}</h1>
        <p className="subtitle">
          {isStats ? "Your focus session history and trends." : "Personalize your workspace."}
        </p>
      </header>
      <section className="placeholder-card">
        <span className="placeholder-card__icon">
          <Icon name={isStats ? "chart" : "settings"} size={30} />
        </span>
        <h2>Coming soon</h2>
        <p>
          {isStats
            ? "Detailed statistics will be available in a future update."
            : "More settings will be available in a future update."}
        </p>
      </section>
    </div>
  );
}
