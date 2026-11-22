import { StrictMode } from "react";
import { act, fireEvent, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import App from "./App";

describe("Duration form validation", () => {
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

  async function openForm() {
    const user = userEvent.setup();
    render(
      <StrictMode>
        <App />
      </StrictMode>,
    );
    await user.click(screen.getByRole("button", { name: "Timer" }));
    await user.click(screen.getByRole("button", { name: "Input" }));
    return user;
  }

  async function expectNoStart(user: ReturnType<typeof userEvent.setup>) {
    await user.click(screen.getByRole("button", { name: "Start" }));
    await user.click(screen.getByRole("spinbutton", { name: "Seconds" }));
    await user.keyboard("{Enter}");
    act(() => vi.advanceTimersByTime(2000));
    expect(screen.getByRole("button", { name: "Start" })).toBeDisabled();
    expect(screen.queryByRole("button", { name: "Pause" })).not.toBeInTheDocument();
    expect(screen.getByText("Timers you start will appear here.")).toBeVisible();
  }

  it.each(["Hours", "Minutes", "Seconds"])(
    "requires a value for %s and clears the error after correction",
    async (label) => {
      const user = await openForm();
      const field = screen.getByRole("spinbutton", { name: label });
      await user.clear(field);

      expect(field).toHaveValue(null);
      expect(field).toBeRequired();
      expect(field).toHaveAttribute("aria-invalid", "true");
      expect(screen.getByRole("alert")).toHaveTextContent(`Enter a value for ${label}.`);
      expect(field).toHaveAccessibleDescription(`Enter a value for ${label}.`);
      await expectNoStart(user);

      await user.click(field);
      await user.type(field, "1");
      expect(screen.queryByRole("alert")).not.toBeInTheDocument();
      expect(field).not.toHaveAttribute("aria-invalid", "true");
      expect(screen.getByRole("button", { name: "Start" })).toBeEnabled();
      await user.click(screen.getByRole("button", { name: "Start" }));
      expect(screen.getByRole("button", { name: "Pause" })).toBeVisible();
    },
  );

  it.each([
    { label: "Hours", value: "-1", max: 23 },
    { label: "Hours", value: "24", max: 23 },
    { label: "Hours", value: "1.5", max: 23 },
    { label: "Minutes", value: "-1", max: 59 },
    { label: "Minutes", value: "60", max: 59 },
    { label: "Minutes", value: "1.5", max: 59 },
    { label: "Seconds", value: "-1", max: 59 },
    { label: "Seconds", value: "60", max: 59 },
    { label: "Seconds", value: "1.5", max: 59 },
  ])("rejects $label = $value with a specific error", async ({ label, value, max }) => {
    const user = await openForm();
    const field = screen.getByRole("spinbutton", { name: label });
    // A single change event supplies the complete invalid numeric value,
    // including negatives/fractions, without depending on browser keystroke filtering.
    fireEvent.change(field, { target: { value } });

    expect(field).toHaveValue(Number(value));
    expect(field).toHaveAttribute("aria-invalid", "true");
    expect(screen.getByRole("alert")).toHaveTextContent(
      `${label} must be a whole number from 0 to ${max}.`,
    );
    await user.click(field);
    await expectNoStart(user);

    await user.clear(field);
    await user.type(field, "1");
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Start" })).toBeEnabled();
  });

  it("rejects a zero total duration and allows starting after correction", async () => {
    const user = await openForm();
    await user.click(screen.getByRole("button", { name: "Cancel" }));

    expect(screen.getByRole("alert")).toHaveTextContent("Choose a duration of at least 1 second.");
    await expectNoStart(user);

    const seconds = screen.getByRole("spinbutton", { name: "Seconds" });
    await user.clear(seconds);
    await user.type(seconds, "1");
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Start" }));
    expect(screen.getByText("0:01", { selector: "time" })).toBeVisible();
  });

  it.each([
    { hours: "0", minutes: "0", seconds: "1", display: "0:01" },
    { hours: "23", minutes: "59", seconds: "59", display: "23:59:59" },
  ])(
    "accepts the valid boundary $hours:$minutes:$seconds",
    async ({ hours, minutes, seconds, display }) => {
      const user = await openForm();
      for (const [label, value] of [
        ["Hours", hours],
        ["Minutes", minutes],
        ["Seconds", seconds],
      ]) {
        const field = screen.getByRole("spinbutton", { name: label });
        await user.clear(field);
        await user.type(field, value);
      }
      expect(screen.queryByRole("alert")).not.toBeInTheDocument();
      await user.click(screen.getByRole("button", { name: "Start" }));
      expect(screen.getByText(display, { selector: "time" })).toBeVisible();
    },
  );
});
