import { StrictMode } from "react";
import { act, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import App from "./App";

describe("Component rendering and user interactions", () => {
  beforeEach(() => {
    vi.useFakeTimers({ toFake: ["Date", "setInterval", "clearInterval"] });
    vi.setSystemTime(new Date("2026-11-22T09:00:00Z"));
    localStorage.clear();
    localStorage.setItem("focus-theme", "light");
  });

  afterEach(() => {
    vi.useRealTimers();
    localStorage.clear();
  });

  function openApp() {
    const user = userEvent.setup();
    render(
      <StrictMode>
        <App />
      </StrictMode>,
    );
    return user;
  }

  async function prepareTimer(seconds = 30) {
    const user = openApp();
    await user.click(screen.getByRole("button", { name: "Timer" }));
    await user.click(screen.getByRole("button", { name: "Input" }));
    const minutes = screen.getByRole("spinbutton", { name: "Minutes" });
    const secondsInput = screen.getByRole("spinbutton", { name: "Seconds" });
    await user.clear(minutes);
    await user.clear(secondsInput);
    await user.type(secondsInput, String(seconds));
    return user;
  }

  function advance(seconds: number) {
    act(() => vi.advanceTimersByTime(seconds * 1000));
  }

  function expectRemaining(text: string) {
    expect(screen.getByText(text, { selector: "time" })).toBeVisible();
  }

  it("shows the home components and opens timer setup through Start Focus", async () => {
    const user = openApp();

    expect(screen.getByRole("heading", { name: "Home", level: 1 })).toBeVisible();
    expect(screen.getByRole("navigation", { name: "Main navigation" })).toBeVisible();
    const overview = screen.getByRole("region", { name: "Focus overview" });
    expect(within(overview).getByText("1 h 45 min")).toBeVisible();
    expect(within(overview).getByText("8 h 20 min")).toBeVisible();
    expect(screen.getByRole("heading", { name: "Today’s tasks" })).toBeVisible();
    expect(screen.getByText("Review interface designs")).toBeVisible();

    await user.click(screen.getByRole("button", { name: "Start Focus" }));

    expect(screen.getByRole("heading", { name: "Timers", level: 1 })).toBeVisible();
    expect(screen.queryByRole("heading", { name: "Home" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Wheel" })).toHaveAttribute("aria-pressed", "true");
    expect(screen.getByRole("spinbutton", { name: "Minutes" })).toHaveAttribute(
      "aria-valuenow",
      "25",
    );
    expect(screen.getByRole("heading", { name: "Recents" })).toBeVisible();
    expect(screen.getByText("Timers you start will appear here.")).toBeVisible();
  });

  it("keeps wheel selections when switching to manual input and starts the edited duration", async () => {
    const user = openApp();
    await user.click(screen.getByRole("button", { name: "Timer" }));

    screen.getByRole("spinbutton", { name: "Hours" }).focus();
    await user.keyboard("{ArrowUp}");
    screen.getByRole("spinbutton", { name: "Minutes" }).focus();
    await user.keyboard("{ArrowDown}");
    screen.getByRole("spinbutton", { name: "Seconds" }).focus();
    await user.keyboard("{End}");
    await user.click(screen.getByRole("button", { name: "Input" }));

    expect(screen.getByRole("button", { name: "Input" })).toHaveAttribute("aria-pressed", "true");
    const hours = screen.getByRole("spinbutton", { name: "Hours" });
    const minutes = screen.getByRole("spinbutton", { name: "Minutes" });
    const seconds = screen.getByRole("spinbutton", { name: "Seconds" });
    expect(hours).toHaveValue(1);
    expect(minutes).toHaveValue(24);
    expect(seconds).toHaveValue(59);

    await user.clear(hours);
    await user.clear(minutes);
    await user.type(minutes, "2");
    await user.clear(seconds);
    await user.type(seconds, "3");
    await user.click(screen.getByRole("button", { name: "Start" }));

    expectRemaining("2:03");
    advance(2);
    expectRemaining("2:01");
  });

  it("clears the duration with Cancel and allows entering a new value", async () => {
    const user = await prepareTimer();

    await user.click(screen.getByRole("button", { name: "Cancel" }));

    for (const label of ["Hours", "Minutes", "Seconds"]) {
      expect(screen.getByRole("spinbutton", { name: label })).toHaveValue(0);
    }
    expect(screen.getByRole("button", { name: "Start" })).toBeDisabled();

    await user.type(screen.getByRole("spinbutton", { name: "Seconds" }), "5");
    expect(screen.getByRole("button", { name: "Start" })).toBeEnabled();
    await user.click(screen.getByRole("button", { name: "Start" }));
    expectRemaining("0:05");
  });

  it.each([
    { paused: false, dismiss: "Cancel" },
    { paused: false, dismiss: "Escape" },
    { paused: true, dismiss: "Cancel" },
    { paused: true, dismiss: "Escape" },
  ])(
    "opens and dismisses reset with $dismiss (paused: $paused), preserving the session",
    async ({ paused, dismiss }) => {
      const user = await prepareTimer();
      await user.click(screen.getByRole("button", { name: "Start" }));
      advance(5);
      if (paused) await user.click(screen.getByRole("button", { name: "Pause" }));
      expect(screen.queryByRole("dialog")).not.toBeInTheDocument();

      await user.click(screen.getByRole("button", { name: "Cancel" }));

      const dialog = screen.getByRole("dialog", { name: "Reset timer?" });
      expect(dialog).toBeVisible();
      expect(within(dialog).getByRole("button", { name: "Reset" })).toBeVisible();
      expect(within(dialog).getByRole("button", { name: "Cancel" })).toHaveFocus();
      advance(3);
      expectRemaining(paused ? "0:25" : "0:22");

      if (dismiss === "Escape") await user.keyboard("{Escape}");
      else await user.click(within(dialog).getByRole("button", { name: "Cancel" }));

      expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
      expect(screen.getByRole("button", { name: paused ? "Resume" : "Pause" })).toBeVisible();
      advance(2);
      expectRemaining(paused ? "0:25" : "0:20");
    },
  );

  it.each([false, true])(
    "confirms reset and keeps the duration without automatically restarting (paused: %s)",
    async (paused) => {
      const user = await prepareTimer();
      await user.click(screen.getByRole("button", { name: "Start" }));
      advance(5);
      if (paused) await user.click(screen.getByRole("button", { name: "Pause" }));
      await user.click(screen.getByRole("button", { name: "Cancel" }));
      const dialog = screen.getByRole("dialog", { name: "Reset timer?" });

      await user.click(within(dialog).getByRole("button", { name: "Reset" }));

      expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
      expect(screen.getByRole("spinbutton", { name: "Seconds" })).toHaveValue(30);
      expect(screen.getByRole("button", { name: "Start" })).toBeEnabled();
      advance(5);
      expect(screen.queryByRole("button", { name: "Pause" })).not.toBeInTheDocument();
      expect(screen.getByRole("spinbutton", { name: "Seconds" })).toHaveValue(30);
      await user.click(screen.getByRole("button", { name: "Start" }));
      expectRemaining("0:30");
    },
  );

  it("closes reset when time runs out and opens setup for the next session", async () => {
    const user = await prepareTimer(3);
    await user.click(screen.getByRole("button", { name: "Start" }));
    await user.click(screen.getByRole("button", { name: "Cancel" }));
    expect(screen.getByRole("dialog", { name: "Reset timer?" })).toBeVisible();

    advance(3);

    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
    expectRemaining("0:00");
    expect(screen.getByText("Time’s up")).toBeVisible();
    expect(screen.queryByRole("button", { name: "Pause" })).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Set a new timer" }));
    expect(screen.getByRole("spinbutton", { name: "Seconds" })).toHaveValue(3);
    await user.click(screen.getByRole("button", { name: "Start" }));
    expectRemaining("0:03");
  });

  it("starts the selected recent duration", async () => {
    localStorage.setItem("focus-recents", JSON.stringify([60, 120]));
    const user = openApp();
    await user.click(screen.getByRole("button", { name: "Timer" }));

    await user.click(screen.getByRole("button", { name: "Start 00:02:00 timer" }));

    expectRemaining("2:00");
    expect(screen.getByRole("button", { name: "Pause" })).toBeVisible();
    advance(5);
    expectRemaining("1:55");
    expect(JSON.parse(localStorage.getItem("focus-recents")!)).toEqual([120, 60]);
  });
});
