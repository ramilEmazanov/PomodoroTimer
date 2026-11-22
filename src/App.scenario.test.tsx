import { StrictMode } from "react";
import { act, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import App from "./App";

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

it("completes the main journey from Home through input, start, pause and resume to a visible result", async () => {
  const user = userEvent.setup();
  render(
    <StrictMode>
      <App />
    </StrictMode>,
  );
  const advance = (seconds: number) => act(() => vi.advanceTimersByTime(seconds * 1000));
  const expectRemaining = (value: string) =>
    expect(screen.getByText(value, { selector: "time" })).toBeVisible();

  // Enter through the same Home action as a user, without selecting preview states.
  expect(screen.getByRole("heading", { name: "Home", level: 1 })).toBeVisible();
  await user.click(screen.getByRole("button", { name: "Start Focus" }));
  expect(screen.getByRole("heading", { name: "Timers", level: 1 })).toBeVisible();
  expect(screen.getByText("Timers you start will appear here.")).toBeVisible();

  await user.click(screen.getByRole("button", { name: "Input" }));
  for (const [label, value] of [
    ["Hours", "0"],
    ["Minutes", "0"],
    ["Seconds", "5"],
  ]) {
    const field = screen.getByRole("spinbutton", { name: label });
    await user.clear(field);
    await user.type(field, value);
  }
  expect(screen.queryByRole("alert")).not.toBeInTheDocument();
  await user.click(screen.getByRole("button", { name: "Start" }));
  expectRemaining("0:05");
  expect(screen.queryByRole("button", { name: "Start" })).not.toBeInTheDocument();
  expect(within(screen.getByRole("region", { name: "Recents" })).getByText("0:05")).toBeVisible();

  advance(2);
  expectRemaining("0:03");
  await user.click(screen.getByRole("button", { name: "Pause" }));
  expect(screen.getByText("Paused")).toBeVisible();
  advance(10);
  expectRemaining("0:03");

  await user.click(screen.getByRole("button", { name: "Resume" }));
  expect(screen.queryByText("Paused")).not.toBeInTheDocument();
  advance(2);
  expectRemaining("0:01");
  expect(screen.queryByText("Time’s up")).not.toBeInTheDocument();
  advance(1);

  // Verify the actual result of the countdown, not just successful navigation.
  expectRemaining("0:00");
  expect(screen.getByText("Time’s up")).toBeVisible();
  expect(screen.queryByRole("button", { name: "Pause" })).not.toBeInTheDocument();
  expect(screen.queryByRole("button", { name: "Resume" })).not.toBeInTheDocument();
  advance(10);
  expectRemaining("0:00");

  await user.click(screen.getByRole("button", { name: "Set a new timer" }));
  expect(screen.getByRole("spinbutton", { name: "Seconds" })).toHaveValue(5);
  expect(screen.getByRole("button", { name: "Start" })).toBeEnabled();
  expect(screen.queryByText("Time’s up")).not.toBeInTheDocument();
});
