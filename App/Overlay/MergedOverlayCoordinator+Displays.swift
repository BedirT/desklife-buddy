import Domain

extension MergedOverlayCoordinator {
    func reconcile(
        to plan: OverlayDisplayPlan,
        content: MergedPanelContent,
        presenting: Bool,
    ) {
        let retainedIDs = Set(plan.displays.map(\.id))
        for assignment in plan.assignments where assignment.role == .atmosphere {
            panels[assignment.display.id]?.update(
                frame: assignment.display.frame,
                role: assignment.role,
            )
        }
        for assignment in plan.assignments {
            let display = assignment.display
            if let panel = panels[display.id] {
                panel.update(frame: display.frame, role: assignment.role)
            } else {
                let panel = makePanel(
                    display,
                    assignment.role,
                    content,
                    accessibilityPreferences,
                    // D-032: the visual countdown starts in the committed open
                    // action; entrance settlement gates nothing.
                    {},
                ) { [weak self] in
                    self?.cancelActiveSegment()
                }
                panels[display.id] = panel
                if !presenting {
                    panel.present(makeKey: false)
                }
            }
        }
        for (id, panel) in panels where !retainedIDs.contains(id) {
            panel.close()
            panels[id] = nil
        }
        if let resolvedInteractiveDisplayID = plan.interactiveDisplayID {
            interactiveDisplayID = resolvedInteractiveDisplayID
        }
        if !presenting, isAppFrontmost(), let interactiveDisplayID = plan.interactiveDisplayID {
            panels[interactiveDisplayID]?.makeKey()
        }
    }
}
