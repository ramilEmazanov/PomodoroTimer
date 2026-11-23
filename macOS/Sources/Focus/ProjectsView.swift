import SwiftUI

struct ProjectsView: View {
  @Bindable var state: InterfaceState
  @State private var selection: UUID?
  @State private var newTitle = ""
  @State private var renameTitle = ""
  @State private var renaming = false
  @State private var deleting = false
  @FocusState private var composerFocused: Bool

  private var project: FocusProject? { state.projects.first { $0.id == selection } }

  var body: some View {
    Group {
      if let project {
        VStack(spacing: 0) {
          HStack {
            Button {
              selection = nil
            } label: {
              Label("Projects", systemImage: "chevron.left")
            }
            .buttonStyle(.borderless)
            Spacer()
            Menu {
              Button("Rename project") {
                renameTitle = project.title
                renaming = true
              }
              Button("Delete project…", role: .destructive) { deleting = true }
            } label: {
              Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Project actions")
          }
          .padding(.horizontal, 24).padding(.top, 20)
          TasksView(state: state, projectID: project.id).id(project.id)
        }
        .alert("Rename project", isPresented: $renaming) {
          TextField("Project name", text: $renameTitle)
          Button("Cancel", role: .cancel) {}
          Button("Save") { state.renameProject(project.id, title: renameTitle) }
            .disabled(renameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .alert("Delete project?", isPresented: $deleting) {
          Button("Cancel", role: .cancel) {}
          Button("Delete", role: .destructive) {
            state.deleteProject(project.id)
            selection = nil
          }
        } message: {
          Text(
            "Tasks will stay in Tasks without a project. Recorded focus time will stay in your history."
          )
        }
      } else {
        projectList
      }
    }
  }

  private var projectList: some View {
    VStack(alignment: .leading, spacing: 24) {
      PageHeading(title: "Projects", subtitle: "Organize tasks and see where your focus goes.")
      if state.pendingProjects != nil {
        Label(
          "Project changes haven’t been saved. Use Retry storage above.",
          systemImage: "exclamationmark.triangle"
        )
        .font(.callout).foregroundStyle(.orange)
      }
      HStack(spacing: 12) {
        Image(systemName: "plus").foregroundStyle(.blue)
        TextField("New project", text: $newTitle).textFieldStyle(.plain)
          .focused($composerFocused).onSubmit(addProject)
        Button("Add project", action: addProject).buttonStyle(.borderless)
          .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
      .padding(14).background(Color.panel, in: RoundedRectangle(cornerRadius: 12))
      ScrollView {
        LazyVStack(spacing: 8) {
          if state.projects.isEmpty {
            VStack(spacing: 12) {
              Image(systemName: "folder").font(.system(size: 34, weight: .light))
              Text("Give your tasks a home").font(.headline)
              Text("Create a project, add tasks and focus on one at a time.")
                .font(.callout).multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary).padding(.vertical, 48)
            .frame(maxWidth: .infinity)
          }
          ForEach(state.projects) { project in
            Button {
              selection = project.id
            } label: {
              HStack(spacing: 16) {
                Image(systemName: "folder").font(.system(size: 22)).foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 6) {
                  Text(project.title).font(.system(size: 18, weight: .semibold)).lineLimit(2)
                  let tasks = state.tasks.filter { $0.projectID == project.id }
                  Text(
                    "\(tasks.filter { !$0.isCompleted }.count) active · \(tasks.filter(\.isCompleted).count) completed"
                  )
                  .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Text(FocusHistory.display(state.focusedSeconds(projectID: project.id)))
                  .font(.system(size: 15, weight: .medium)).monospacedDigit()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
              }
              .padding(20).background(Color.panel, in: RoundedRectangle(cornerRadius: 12))
              .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain).accessibilityLabel("Open project: \(project.title)")
          }
        }
      }
    }
    .padding(24)
  }

  private func addProject() {
    guard let id = state.addProject(title: newTitle) else { return }
    newTitle = ""
    selection = id
  }
}
