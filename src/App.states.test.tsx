import { StrictMode } from "react";
import { act, fireEvent, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import App from "./App";

// This application reads synchronous localStorage, not an HTTP API.
// Fixtures enter at the storage boundary; components and timer logic stay real.
describe("Interface states with controlled local data", () => {
  beforeEach(() => {
    vi.useFakeTimers({ toFake: ["Date", "setInterval", "clearInterval"] });
    vi.setSystemTime(new Date("2026-11-22T09:00:00Z"));
    localStorage.clear();
    localStorage.setItem("focus-theme", "light");
  });

  afterEach(() => {
    vi.restoreAllMocks();
    vi.useRealTimers();
    localStorage.clear();
  });

  async function openTimer() {
    const user = userEvent.setup();
    render(
      <StrictMode>
        <App />
      </StrictMode>,
    );
    await user.click(screen.getByRole("button", { name: "Timer" }));
    return user;
  }

  function recents() {
    return screen.getByRole("region", { name: "Recents" });
  }

  it("shows an empty history and populates it after an actual start", async () => {
    localStorage.setItem("focus-recents", "[]");
    const user = await openTimer();
    expect(within(recents()).getByText("Timers you start will appear here.")).toBeVisible();
    expect(within(recents()).queryByRole("list")).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Start" }));

    expect(
      within(recents()).queryByText("Timers you start will appear here."),
    ).not.toBeInTheDocument();
    expect(within(recents()).getAllByRole("listitem")).toHaveLength(1);
    expect(within(recents()).getByText("25:00")).toBeVisible();
    expect(screen.getByText("25:00", { selector: "time" })).toBeVisible();
    expect(JSON.parse(localStorage.getItem("focus-recents")!)).toEqual([1500]);
  });

  it("renders saved fixture data and starts the selected duration", async () => {
    localStorage.setItem("focus-recents", JSON.stringify([90, 3600]));
    const user = await openTimer();

    expect(within(recents()).getAllByRole("listitem")).toHaveLength(2);
    expect(within(recents()).getByText("1:30")).toBeVisible();
    expect(within(recents()).getByText("01:00:00")).toBeVisible();
    expect(
      within(recents()).queryByText("Timers you start will appear here."),
    ).not.toBeInTheDocument();
    await user.click(within(recents()).getByRole("button", { name: "Start 00:01:30 timer" }));
    expect(screen.getByText("1:30", { selector: "time" })).toBeVisible();
  });

  it.each([
    { name: "malformed JSON", data: "not-json" },
    { name: "unexpected object", data: '{"timers":[60]}' },
  ])("recovers from $name with a usable empty history", async ({ data }) => {
    localStorage.setItem("focus-recents", data);
    const user = await openTimer();

    expect(within(recents()).getByText("Timers you start will appear here.")).toBeVisible();
    expect(within(recents()).queryByRole("list")).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Start" }));
    expect(screen.getByText("25:00", { selector: "time" })).toBeVisible();
    expect(within(recents()).getAllByRole("listitem")).toHaveLength(1);
  });

  it("keeps the timer usable when reading history throws", async () => {
    const getItem = Storage.prototype.getItem;
    vi.spyOn(Storage.prototype, "getItem").mockImplementation(function (
      this: Storage,
      key: string,
    ) {
      if (key === "focus-recents") throw new DOMException("Storage access denied", "SecurityError");
      return getItem.call(this, key);
    });
    const user = await openTimer();

    expect(within(recents()).getByText("Timers you start will appear here.")).toBeVisible();
    await user.click(screen.getByRole("button", { name: "Start" }));
    expect(screen.getByText("25:00", { selector: "time" })).toBeVisible();
    expect(screen.getByRole("button", { name: "Pause" })).toBeVisible();
  });

  it("shows the active session even when saving history fails", async () => {
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new DOMException("Storage quota exceeded", "QuotaExceededError");
    });
    const user = await openTimer();

    await user.click(screen.getByRole("button", { name: "Start" }));

    expect(screen.getByText("25:00", { selector: "time" })).toBeVisible();
    expect(within(recents()).getAllByRole("listitem")).toHaveLength(1);
    act(() => vi.advanceTimersByTime(5000));
    expect(screen.getByText("24:55", { selector: "time" })).toBeVisible();
  });

  it("shows success after the real countdown finishes", async () => {
    const user = await openTimer();
    await user.click(screen.getByRole("button", { name: "Input" }));
    for (const [label, value] of [
      ["Minutes", "0"],
      ["Seconds", "1"],
    ]) {
      const field = screen.getByRole("spinbutton", { name: label });
      await user.clear(field);
      await user.type(field, value);
    }
    await user.click(screen.getByRole("button", { name: "Start" }));
    expect(screen.queryByText("Time’s up")).not.toBeInTheDocument();

    act(() => vi.advanceTimersByTime(1000));

    expect(screen.getByText("0:00", { selector: "time" })).toBeVisible();
    expect(screen.getByText("Time’s up")).toBeVisible();
    expect(screen.queryByRole("button", { name: "Pause" })).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Set a new timer" }));
    expect(screen.getByRole("button", { name: "Start" })).toBeEnabled();
    expect(screen.getByRole("spinbutton", { name: "Seconds" })).toHaveValue(1);
  });

  it("shows an input error and recovers after the user corrects it", async () => {
    const user = await openTimer();
    await user.click(screen.getByRole("button", { name: "Input" }));
    const minutes = screen.getByRole("spinbutton", { name: "Minutes" });
    fireEvent.change(minutes, { target: { value: "60" } });

    expect(screen.getByRole("alert")).toHaveTextContent(
      "Minutes must be a whole number from 0 to 59.",
    );
    expect(screen.getByRole("button", { name: "Start" })).toBeDisabled();
    expect(within(recents()).getByText("Timers you start will appear here.")).toBeVisible();

    await user.clear(minutes);
    await user.type(minutes, "1");
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Start" }));
    expect(screen.getByText("1:00", { selector: "time" })).toBeVisible();
    expect(within(recents()).getAllByRole("listitem")).toHaveLength(1);
  });
});
