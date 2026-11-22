import { StrictMode } from "react";
import { act, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import App from "./App";

// No HTTP requests are made by this app. The pending operation is the active
// local countdown: repeated input must not start another clock or reset it.
describe("Protection against repeated timer starts", () => {
  beforeEach(() => {
    // Freeze the countdown clock while leaving user-event's input delivery real.
    vi.useFakeTimers({ toFake: ["Date", "setInterval", "clearInterval"] });
    vi.setSystemTime(new Date("2026-11-22T09:00:00Z"));
    localStorage.clear();
    localStorage.setItem("focus-theme", "light");
    localStorage.setItem("focus-recents", JSON.stringify([60, 120]));
  });

  afterEach(() => {
    vi.useRealTimers();
    localStorage.clear();
  });

  async function prepareTimer() {
    const user = userEvent.setup();
    render(
      <StrictMode>
        <App />
      </StrictMode>,
    );
    await user.click(screen.getByRole("button", { name: "Timer" }));
    await user.click(screen.getByRole("button", { name: "Input" }));
    const minutes = screen.getByRole("spinbutton", { name: "Minutes" });
    await user.clear(minutes);
    await user.type(minutes, "1");
    return { user, minutes, clockStarts: vi.spyOn(window, "setInterval") };
  }

  function expectRemaining(text: string) {
    expect(screen.getByText(text, { selector: "time" })).toBeVisible();
  }

  it("a double click on Start starts one countdown", async () => {
    const { user, clockStarts } = await prepareTimer();

    await user.dblClick(screen.getByRole("button", { name: "Start" }));

    expect(clockStarts).toHaveBeenCalledTimes(1);
    expect(screen.queryByRole("button", { name: "Start" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Pause" })).toBeVisible();
    act(() => vi.advanceTimersByTime(5000));
    expectRemaining("0:55");
  });

  it("holding Enter in the duration field starts one countdown", async () => {
    const { user, minutes, clockStarts } = await prepareTimer();
    await user.click(minutes);

    await user.keyboard("{Enter>5/}");

    expect(clockStarts).toHaveBeenCalledTimes(1);
    expect(screen.getByRole("button", { name: "Pause" })).toBeVisible();
    act(() => vi.advanceTimersByTime(5000));
    expectRemaining("0:55");
  });

  it("Recents cannot restart or replace a running or paused countdown", async () => {
    const { user, clockStarts } = await prepareTimer();
    await user.click(screen.getByRole("button", { name: "Start" }));
    act(() => vi.advanceTimersByTime(5000));

    const recentStarts = screen.getAllByRole("button", { name: /^Start .* timer$/ });
    expect(recentStarts).toHaveLength(2);
    for (const button of recentStarts) {
      await user.dblClick(button);
    }
    expectRemaining("0:55");
    expect(clockStarts).toHaveBeenCalledTimes(1);
    for (const button of recentStarts) expect(button).toBeDisabled();
    act(() => vi.advanceTimersByTime(5000));
    expectRemaining("0:50");

    await user.click(screen.getByRole("button", { name: "Pause" }));
    for (const button of recentStarts) {
      expect(button).toBeDisabled();
      await user.dblClick(button);
    }
    act(() => vi.advanceTimersByTime(5000));
    expectRemaining("0:50");
    expect(screen.getByRole("button", { name: "Resume" })).toBeVisible();

    await user.click(screen.getByRole("button", { name: "Resume" }));
    act(() => vi.advanceTimersByTime(5000));
    expectRemaining("0:45");
  });
});
