import { useLayoutEffect, useRef } from "react";

function updateDepth(wheel: HTMLDivElement) {
  const position = wheel.scrollTop / 48;
  Array.from(wheel.children).forEach((row, index) => {
    const face = row.firstElementChild as HTMLElement | null;
    if (!face) return;
    const distance = Math.max(-4, Math.min(4, index - position));
    face.style.transform = `perspective(320px) rotateX(${-distance * 18}deg) scale(${1 - Math.abs(distance) * 0.055})`;
    face.style.opacity = String(Math.max(0.2, 1 - Math.abs(distance) * 0.2));
  });
}

function Wheel({
  value,
  max,
  label,
  unit,
  onChange,
}: {
  value: number;
  max: number;
  label: string;
  unit: string;
  onChange: (value: number) => void;
}) {
  const ref = useRef<HTMLDivElement>(null);
  useLayoutEffect(() => {
    const wheel = ref.current;
    if (!wheel) return;
    if (Math.round(wheel.scrollTop / 48) !== value) wheel.scrollTop = value * 48;
    updateDepth(wheel);
  }, [value]);
  return (
    <div className="duration-wheel-wrap">
      <div
        className="duration-wheel"
        ref={ref}
        role="spinbutton"
        tabIndex={0}
        aria-label={label}
        aria-valuemin={0}
        aria-valuemax={max}
        aria-valuenow={value}
        onScroll={(event) => {
          updateDepth(event.currentTarget);
          const next = Math.max(0, Math.min(max, Math.round(event.currentTarget.scrollTop / 48)));
          if (next !== value) onChange(next);
        }}
        onKeyDown={(event) => {
          let next = value;
          if (event.key === "ArrowUp") next++;
          else if (event.key === "ArrowDown") next--;
          else if (event.key === "Home") next = 0;
          else if (event.key === "End") next = max;
          else return;
          event.preventDefault();
          onChange(Math.max(0, Math.min(max, next)));
        }}
      >
        {Array.from({ length: max + 1 }, (_, n) => (
          <div
            aria-hidden="true"
            className={`duration-wheel__item ${n === value ? "is-selected" : ""}`}
            key={n}
            onClick={() => onChange(n)}
          >
            <span className="duration-wheel__face">{n}</span>
          </div>
        ))}
      </div>
      <span className="duration-wheel__unit" aria-hidden="true">
        {unit}
      </span>
    </div>
  );
}

export default function DurationPicker({
  seconds,
  onChange,
}: {
  seconds: number;
  onChange: (seconds: number) => void;
}) {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;
  return (
    <div className="duration-picker" role="group" aria-label="Timer duration">
      <Wheel
        value={hours}
        max={23}
        label="Hours"
        unit="h"
        onChange={(n) => onChange(n * 3600 + minutes * 60 + secs)}
      />
      <Wheel
        value={minutes}
        max={59}
        label="Minutes"
        unit="min"
        onChange={(n) => onChange(hours * 3600 + n * 60 + secs)}
      />
      <Wheel
        value={secs}
        max={59}
        label="Seconds"
        unit="s"
        onChange={(n) => onChange(hours * 3600 + minutes * 60 + n)}
      />
    </div>
  );
}
