import SwiftUI
import Combine

// MARK: - Floating Object

struct FloatingObject: Identifiable, Equatable {
    let id = UUID()
    var position: CGPoint
    var size: CGSize
    var payload: ResultPayload
    var isExpanded: Bool
    var zIndex: Int
    var isDragging: Bool = false
    var driftPhase: Double = 0

    static func == (lhs: FloatingObject, rhs: FloatingObject) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Floating Tool

struct FloatingTool: Identifiable, Equatable {
    let id = UUID()
    var position: CGPoint
    var size: CGSize
    var destination: WorkspaceDestination
    var isExpanded: Bool
    var zIndex: Int
    var isDragging: Bool = false
    var driftPhase: Double = 0

    static func == (lhs: FloatingTool, rhs: FloatingTool) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Void Canvas View Model

@MainActor
final class VoidCanvasViewModel: ObservableObject {
    @Published var floatingObjects: [FloatingObject] = []
    @Published var floatingTools: [FloatingTool] = []
    @Published var showToolLayer: Bool = false
    @Published var centerInputFocused: Bool = false
    @Published var isTyping: Bool = false

    private var nextZ: Int = 1
    private var spawnOffset: CGFloat = 0

    // Input origin for spawning near the center input
    var inputOrigin: CGPoint = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.maxY - 120)

    func spawnText(_ content: String, at position: CGPoint? = nil) {
        let payload = ResultPayload(
            type: .text,
            content: content,
            url: nil,
            imageData: nil,
            status: .complete
        )
        spawn(payload: payload, at: position)
    }

    func spawnResult(_ payload: ResultPayload, at position: CGPoint? = nil) {
        spawn(payload: payload, at: position)
    }

    func spawnTool(_ destination: WorkspaceDestination, at position: CGPoint? = nil) {
        let defaultSize = CGSize(width: UIScreen.main.bounds.width - 48, height: UIScreen.main.bounds.height * 0.65)

        let pos: CGPoint
        if let position = position {
            pos = position
        } else {
            let offsetRange: CGFloat = 40
            let offsetX = CGFloat.random(in: -offsetRange...offsetRange) + spawnOffset
            let offsetY = CGFloat.random(in: -offsetRange...offsetRange) - 80
            pos = CGPoint(
                x: inputOrigin.x + offsetX,
                y: inputOrigin.y + offsetY
            )
            spawnOffset = (spawnOffset + 25).truncatingRemainder(dividingBy: 100)
        }

        let clampedX = max(defaultSize.width / 2 + 8, min(UIScreen.main.bounds.width - defaultSize.width / 2 - 8, pos.x))
        let clampedY = max(defaultSize.height / 2 + 8, min(UIScreen.main.bounds.height - defaultSize.height / 2 - 8, pos.y))

        let tool = FloatingTool(
            position: CGPoint(x: clampedX, y: clampedY),
            size: defaultSize,
            destination: destination,
            isExpanded: false,
            zIndex: nextZ,
            driftPhase: Double.random(in: 0...Double.pi * 2)
        )
        nextZ += 1

        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            floatingTools.append(tool)
        }
    }

    func dismissObject(id: UUID) {
        withAnimation(.easeIn(duration: 0.2)) {
            floatingObjects.removeAll { $0.id == id }
        }
    }

    func dismissTool(id: UUID) {
        withAnimation(.easeIn(duration: 0.2)) {
            floatingTools.removeAll { $0.id == id }
        }
    }

    func bringToFront(id: UUID) {
        if let index = floatingObjects.firstIndex(where: { $0.id == id }) {
            nextZ += 1
            floatingObjects[index].zIndex = nextZ
        }
        if let index = floatingTools.firstIndex(where: { $0.id == id }) {
            nextZ += 1
            floatingTools[index].zIndex = nextZ
        }
    }

    func updatePosition(id: UUID, to position: CGPoint) {
        if let index = floatingObjects.firstIndex(where: { $0.id == id }) {
            floatingObjects[index].position = position
        }
        if let index = floatingTools.firstIndex(where: { $0.id == id }) {
            floatingTools[index].position = position
        }
    }

    func updateSize(id: UUID, to size: CGSize) {
        if let index = floatingObjects.firstIndex(where: { $0.id == id }) {
            floatingObjects[index].size = size
        }
        if let index = floatingTools.firstIndex(where: { $0.id == id }) {
            floatingTools[index].size = size
        }
    }

    func toggleExpanded(id: UUID) {
        if let index = floatingObjects.firstIndex(where: { $0.id == id }) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                floatingObjects[index].isExpanded.toggle()
            }
        }
        if let index = floatingTools.firstIndex(where: { $0.id == id }) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                floatingTools[index].isExpanded.toggle()
            }
        }
    }

    func clearAll() {
        withAnimation(.easeIn(duration: 0.25)) {
            floatingObjects.removeAll()
            floatingTools.removeAll()
        }
    }

    // MARK: - Private

    private func spawn(payload: ResultPayload, at position: CGPoint? = nil) {
        let screenBounds = UIScreen.main.bounds
        let defaultSize: CGSize
        switch payload.type {
        case .image:
            defaultSize = CGSize(width: 320, height: 320)
        case .video:
            defaultSize = CGSize(width: 360, height: 240)
        case .text:
            defaultSize = CGSize(width: 340, height: 220)
        case .media:
            defaultSize = CGSize(width: 280, height: 200)
        }

        let pos: CGPoint
        if let position = position {
            pos = position
        } else {
            // Spawn near the input origin (bottom center), drifting upward
            let offsetRange: CGFloat = 50
            let offsetX = CGFloat.random(in: -offsetRange...offsetRange) + spawnOffset
            let offsetY = CGFloat.random(in: -offsetRange...offsetRange) - 120
            pos = CGPoint(
                x: inputOrigin.x + offsetX,
                y: inputOrigin.y + offsetY
            )
            spawnOffset = (spawnOffset + 25).truncatingRemainder(dividingBy: 100)
        }

        let clampedX = max(defaultSize.width / 2 + 8, min(screenBounds.width - defaultSize.width / 2 - 8, pos.x))
        let clampedY = max(defaultSize.height / 2 + 8, min(screenBounds.height - defaultSize.height / 2 - 8, pos.y))

        let object = FloatingObject(
            position: CGPoint(x: clampedX, y: clampedY),
            size: defaultSize,
            payload: payload,
            isExpanded: false,
            zIndex: nextZ,
            driftPhase: Double.random(in: 0...Double.pi * 2)
        )
        nextZ += 1

        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            floatingObjects.append(object)
        }
    }
}
