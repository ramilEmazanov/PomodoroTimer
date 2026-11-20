import Icon from "../components/Icon";

export default function Placeholder({ section }: { section: "stats" | "settings" }) {
  const isStats = section === "stats";
  return (
    <div className="page">
      <header className="page-header">
        <p className="eyebrow">{isStats ? "ВАШ ПРОГРЕСС" : "ПРИЛОЖЕНИЕ"}</p>
        <h1>{isStats ? "Статистика" : "Настройки"}</h1>
        <p className="subtitle">
          {isStats
            ? "История и динамика фокус-сессий."
            : "Персонализация вашего рабочего пространства."}
        </p>
      </header>
      <section className="placeholder-card">
        <span className="placeholder-card__icon">
          <Icon name={isStats ? "chart" : "settings"} size={30} />
        </span>
        <h2>Раздел в разработке</h2>
        <p>
          {isStats
            ? "Подробная статистика появится в следующих версиях."
            : "Дополнительные параметры появятся в следующих версиях."}
        </p>
      </section>
    </div>
  );
}
