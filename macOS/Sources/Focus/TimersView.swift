import SwiftUI

struct TimersView: View {
  @Bindable var state: InterfaceState
  @FocusState private var focusedField: Int?

  var body: some View {
    VStack(alignment: .leading, spacing: 28) {
      PageHeading(title: "Timers")
      Surface {
        Group {
          if state.phase == .setup { setup } else { active }
        }
        .frame(maxWidth: .infinity, minHeight: 360)
      }
      .frame(maxWidth: 560).frame(maxWidth: .infinity)
      recents.frame(maxWidth: 560, alignment: .leading).frame(maxWidth: .infinity)
    }
  }

  private var setup: some View {
    VStack(spacing: 16) {
      Picker("Task", selection: $state.timerTaskID) {
        Text("No task").tag(nil as UUID?)
        ForEach(state.timerTasks) { task in
          let project = state.projects.first { $0.id == task.projectID }
          Text(project.map { "\($0.title) / \(task.title)" } ?? task.title)
            .tag(Optional(task.id))
        }
      }
      .frame(maxWidth: .infinity)
      DurationEntryModePicker(selection: $state.entryMode)
        .onChange(of: state.entryMode) { _, mode in
          if mode == .wheel { state.setDuration(min(86399, max(0, state.duration))) }
        }
      if state.entryMode == .wheel {
        HStack(spacing: 0) {
          DurationWheel(text: $state.fields[0], maximum: 23, label: "Hours", unit: "h")
          DurationWheel(text: $state.fields[1], maximum: 59, label: "Minutes", unit: "min")
          DurationWheel(text: $state.fields[2], maximum: 59, label: "Seconds", unit: "s")
        }
        .frame(maxWidth: .infinity)
        .background {
          RoundedRectangle(cornerRadius: 12).fill(Color.selection).frame(height: 40)
        }
      } else {
        HStack(alignment: .bottom, spacing: 4) {
          ForEach(0..<3, id: \.self) { index in
            if index > 0 {
              Text(":").font(.system(size: 56, weight: .light)).padding(.bottom, 4)
            }
            VStack(spacing: 16) {
              Text(["hr", "min", "sec"][index]).foregroundStyle(.secondary)
              TextField("00", text: $state.fields[index])
                .textFieldStyle(.plain).multilineTextAlignment(.center)
                .font(.system(size: 56, weight: .medium)).monospacedDigit()
                .focused($focusedField, equals: index)
                .accessibilityLabel(["Hours", "Minutes", "Seconds"][index])
                .onSubmit { state.start() }
                .padding(.vertical, 4)
                .background(
                  focusedField == index ? Color.blue.opacity(0.08) : .clear,
                  in: RoundedRectangle(cornerRadius: 8))
            }
            .frame(maxWidth: .infinity)
          }
        }
        .frame(height: 200)
      }
      Text(state.validation ?? " ")
        .font(.system(size: 12)).foregroundStyle(.red)
        .frame(minHeight: 18).fixedSize(horizontal: false, vertical: true)
        .accessibilityHidden(state.validation == nil)
      HStack {
        Button("Cancel") { state.setDuration(0) }
          .buttonStyle(ClockButtonStyle(start: false)).disabled(
            state.fields.allSatisfy { Int($0) == 0 })
        Spacer()
        Button("Start") {
          focusedField = nil
          state.start()
        }
        .buttonStyle(ClockButtonStyle(start: true)).disabled(state.validation != nil)
      }
    }
  }

  private var active: some View {
    VStack(spacing: 30) {
      if let assignment = state.saved.active?.assignment {
        VStack(spacing: 5) {
          Text(assignment.taskTitle).font(.headline).lineLimit(2)
          if let title = assignment.projectTitle {
            Label(title, systemImage: "folder").font(.callout).foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
        .multilineTextAlignment(.center)
      }

      ZStack {
        Circle().stroke(Color.selection, lineWidth: 8)
        Circle()
          .trim(from: 0, to: CGFloat(state.remaining) / CGFloat(max(1, state.total)))
          .stroke(
            state.phase == .finished ? Color.green : .orange,
            style: StrokeStyle(lineWidth: 8, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))
        VStack(spacing: 10) {
          if state.phase == .running {
            Label("Running", systemImage: "timer").foregroundStyle(.orange)
          } else {
            Text(state.phase == .paused ? "Paused" : "Time’s up")
              .foregroundStyle(state.phase == .finished ? .green : .secondary)
          }
          Text(InterfaceState.time(state.remaining))
            .font(.system(size: state.remaining >= 3600 ? 40 : 56, weight: .light))
            .monospacedDigit()
            .accessibilityLabel("Time remaining: \(InterfaceState.durationLabel(state.remaining))")
        }
      }
      .frame(width: 260, height: 260)
      HStack(spacing: 14) {
        if state.phase == .finished {
          Button("Set a new timer") { state.reset() }.buttonStyle(ActionStyle())
        } else {
          Button("Cancel") { state.showReset = true }.buttonStyle(ActionStyle(prominent: false))
          Button(state.phase == .paused ? "Resume" : "Pause") {
            state.pauseOrResume()
          }.buttonStyle(ActionStyle())
        }
      }
    }
    .padding(.vertical, 12)
  }

  private var recents: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Recents").font(.system(size: 22, weight: .semibold))
      if state.recents.isEmpty {
        Text("Timers you start will appear here.").font(.system(size: 14)).foregroundStyle(
          .secondary)
      } else {
        ForEach(state.recents, id: \.self) { seconds in
          HStack {
            VStack(alignment: .leading, spacing: 5) {
              Text(InterfaceState.time(seconds)).font(.system(size: 30, weight: .light))
                .monospacedDigit()
              Text(InterfaceState.durationLabel(seconds)).font(.system(size: 12)).foregroundStyle(
                .secondary)
            }
            Spacer()
            Button {
              state.start(seconds)
            } label: {
              Image(systemName: "play.fill").font(.system(size: 18))
                .foregroundStyle(.green).frame(width: 46, height: 46)
                .background(.green.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start \(InterfaceState.durationLabel(seconds)) timer")
            .disabled(state.phase == .running || state.phase == .paused)
            .opacity(state.phase == .running || state.phase == .paused ? 0.4 : 1)
          }
          .padding(.vertical, 8)
          Divider()
        }
      }
    }
  }
}

private struct ClockButtonStyle: ButtonStyle {
  let start: Bool
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 17))
      .frame(width: 76, height: 76)
      .foregroundStyle(start ? Color(light: 0x248239, dark: 0x70DB7B) : .primary)
      .background(start ? Color(light: 0xDAF4DF, dark: 0x193B20) : .selection, in: Circle())
      .opacity(!enabled ? 0.4 : configuration.isPressed ? 0.7 : 1)
  }
}
