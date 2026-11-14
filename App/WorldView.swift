import SwiftUI
import RealityKit
import UIKit

struct WorldView: UIViewRepresentable {
    let game: GameStore
    func makeCoordinator() -> Coordinator { Coordinator(game: game) }
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(UIColor(red: 0.055, green: 0.075, blue: 0.14, alpha: 1))
        context.coordinator.attach(view)
        return view
    }
    func updateUIView(_ uiView: ARView, context: Context) {}
    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) { coordinator.stop() }

    @MainActor final class Coordinator: NSObject {
        let game: GameStore
        weak var view: ARView?
        private var displayLink: CADisplayLink?
        private var previous = 0.0
        private let world = AnchorEntity(world: .zero)
        private let scenery = Entity()
        private var player = Entity()
        private var enemies: [Int: Entity] = [:]
        private var lastZone: Zone?
        private var signature = ""
        private var heroID = ""
        private var elapsed = 0.0
        init(game: GameStore) { self.game = game }
        func attach(_ view: ARView) {
            self.view = view
            view.scene.addAnchor(world)
            world.addChild(scenery)
            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 48
            camera.look(at: SIMD3<Float>(0, 0, 0), from: SIMD3<Float>(0, 17, 18), relativeTo: nil)
            world.addChild(camera)
            let sun = DirectionalLight()
            sun.light.intensity = 2400
            sun.look(at: .zero, from: SIMD3<Float>(-5, 12, 6), relativeTo: nil)
            world.addChild(sun)
            view.environment.lighting.intensityExponent = 0.6
            rebuild()
            let link = CADisplayLink(target: self, selector: #selector(frame(_:)))
            link.preferredFramesPerSecond = 60
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
        func stop() { displayLink?.invalidate(); displayLink = nil }
        @objc private func frame(_ link: CADisplayLink) {
            let dt = previous == 0 ? 1.0 / 60 : min(link.timestamp - previous, 0.05)
            previous = link.timestamp
            guard !game.suspended else { return }
            elapsed += dt
            game.tick(dt)
            let nextSignature = Building.allCases.map { String(game.progress.level($0)) }.joined()
                + game.progress.party.joined() + game.progress.owned.joined()
            if lastZone != game.zone || signature != nextSignature { rebuild(); signature = nextSignature }
            if game.zone == .frontier { syncBattle() }
        }
        private func rebuild() {
            lastZone = game.zone
            for child in Array(scenery.children) { child.removeFromParent() }
            for entity in enemies.values { entity.removeFromParent() }
            enemies.removeAll()
            player.removeFromParent(); heroID = ""
            // Checker tiles give the blockout a readable pixel-grid rhythm without external assets.
            for x in -9...9 {
                for z in -8...8 {
                    let shade: UInt32 = (x + z).isMultiple(of: 2) ? 0x26394A : 0x2A4050
                    box(scenery, size: [0.99, 0.2, 0.99], at: [Float(x), -0.2, Float(z)], color: shade)
                }
            }
            switch game.zone {
            case .train: makeTrain()
            case .citadel: makeCitadel()
            case .frontier:
                for x: Float in [-8, 8] {
                    for z: Float in [-6, 0, 6] {
                        box(scenery, size: [0.9, 3, 0.9], at: [x, 1.4, z], color: 0x526477)
                        box(scenery, size: [1.2, 0.25, 1.2], at: [x, 3, z], color: 0xA6CDD0)
                    }
                }
                box(scenery, size: [6, 0.6, 1], at: [0, 3, -7], color: 0x879DF0)
            }
        }
        private func makeTrain() {
            for x: Float in [-1, 1] { box(scenery, size: [0.12, 0.1, 16], at: [x, 0, 0], color: 0xA3ACB7) }
            for z: Float in [-4, 0, 4] {
                box(scenery, size: [4, 0.7, 3.4], at: [0, 0.4, z], color: 0x527680)
                // Open-roof carriage: inhabitants stay visible from the game camera.
                box(scenery, size: [0.2, 1.2, 3.4], at: [-2, 1.2, z], color: 0x253248)
                box(scenery, size: [0.2, 1.2, 3.4], at: [2, 1.2, z], color: 0x253248)
                for x: Float in [-1.4, 1.4] {
                    box(scenery, size: [0.5, 0.5, 0.7], at: [x, 0.95, z - 0.8], color: 0xD2AD72)
                }
            }
            box(scenery, size: [2.8, 2, 2], at: [0, 1, -6.6], color: 0x476C79)
            box(scenery, size: [0.6, 1.6, 0.6], at: [0, 2.6, -6.6], color: 0xE6C677)
            for (i, id) in game.progress.owned.enumerated() {
                let passenger = character(Hero.find(id).color)
                passenger.position = [Float(i % 2) * 1.5 - 0.75, 0.8, Float(i / 2) * 4 - 4]
                scenery.addChild(passenger)
            }
            // A station landmark, visible beyond the train.
            box(scenery, size: [2, 4, 2], at: [-6, 2, -4], color: 0x53617D)
            box(scenery, size: [2.6, 0.4, 2.6], at: [-6, 4.2, -4], color: 0xD6BB81)
        }
        private func makeCitadel() {
            box(scenery, size: [5, 2, 3], at: [0, 1, -4.5], color: 0x596483)
            for x: Float in [-3, 3] {
                box(scenery, size: [1.4, 4, 1.4], at: [x, 2, -4.5], color: 0x78849D)
                box(scenery, size: [1.8, 0.5, 1.8], at: [x, 4.2, -4.5], color: 0xCFAD71)
            }
            for (index, building) in Building.allCases.enumerated() {
                let x = Float(index - 1) * 5
                let level = game.progress.level(building)
                let palette: [UInt32] = [0xDC9873, 0x91C9A3, 0x91A3EA]
                box(scenery, size: [3, 0.15, 3], at: [x, 0, 2], color: palette[index])
                if level > 0 {
                    let height = Float(level) * 0.7 + 0.5
                    box(scenery, size: [2, height, 2], at: [x, height / 2, 2], color: palette[index])
                    box(scenery, size: [2.6, 0.3, 2.6], at: [x, height + 0.15, 2], color: 0xEEE2BD)
                }
            }
            for (index, id) in game.progress.party.enumerated() {
                let hero = character(Hero.find(id).color)
                hero.position = [Float(index - 1) * 1.5, 0, 5]
                scenery.addChild(hero)
            }
        }
        private func syncBattle() {
            if heroID != game.hero.id {
                player.removeFromParent()
                player = character(game.hero.color)
                world.addChild(player)
                heroID = game.hero.id
            }
            let point = game.battle.player
            player.position = [Float(point.x), 0, Float(point.z)]
            let attacking = game.battle.attackCooldown > 0.18
            let stretch: Float = attacking ? 1.12 : 1
            player.scale = SIMD3<Float>(stretch, game.battle.invulnerability > 0 ? 0.7 : 1, stretch)
            if hypot(game.movement.x, game.movement.z) > 0.1 {
                player.orientation = simd_quatf(angle: Float(atan2(game.movement.x, game.movement.z)), axis: [0, 1, 0])
            }
            let live = Set(game.battle.enemies.map(\.id))
            for id in Array(enemies.keys) where !live.contains(id) { enemies.removeValue(forKey: id)?.removeFromParent() }
            for enemy in game.battle.enemies {
                let entity: Entity
                if let existing = enemies[enemy.id] { entity = existing }
                else {
                    entity = character(enemy.boss ? 0xB195D2 : 0xDD797B)
                    world.addChild(entity); enemies[enemy.id] = entity
                }
                let scale: Float = enemy.boss ? 2 : 1
                entity.scale = SIMD3<Float>(repeating: scale * (enemy.windup > 0 ? 1.12 : 1))
                entity.position = [Float(enemy.position.x), enemy.windup > 0 ? 0.15 : 0, Float(enemy.position.z)]
                // Nameplate bar is a tiny mesh, updated without adding entities every frame.
                if let bar = entity.findEntity(named: "health") {
                    let maxHP = enemy.boss ? 360.0 : 55 + Double(game.battle.wave) * 10
                    bar.scale.x = Float(max(0.01, enemy.hp / maxHP))
                }
                if let warning = entity.findEntity(named: "warning") { warning.isEnabled = enemy.windup > 0 }
            }
        }
        private func character(_ color: UInt32) -> Entity {
            let entity = Entity()
            box(entity, size: [0.65, 0.65, 0.4], at: [0, 0.85, 0], color: color)
            box(entity, size: [0.48, 0.45, 0.45], at: [0, 1.43, 0], color: 0xF2D6B8)
            box(entity, size: [0.54, 0.18, 0.48], at: [0, 1.7, 0], color: color)
            for x: Float in [-0.2, 0.2] {
                box(entity, size: [0.22, 0.5, 0.27], at: [x, 0.25, 0], color: 0x26324A)
                box(entity, size: [0.18, 0.5, 0.22], at: [x * 2.3, 0.85, 0], color: color)
                box(entity, size: [0.07, 0.07, 0.04], at: [x * 0.55, 1.45, 0.24], color: 0x172233)
            }
            let bar = box(entity, size: [0.8, 0.06, 0.06], at: [0, 2, 0], color: 0x94E2C8)
            bar.name = "health"
            let warning = box(entity, size: [1.5, 0.04, 1.5], at: [0, 0.02, 0], color: 0xFF4343)
            warning.name = "warning"; warning.isEnabled = false
            return entity
        }
        @discardableResult private func box(_ parent: Entity, size: SIMD3<Float>, at: SIMD3<Float>, color: UInt32) -> ModelEntity {
            let tint = UIColor(red: CGFloat((color >> 16) & 255) / 255,
                               green: CGFloat((color >> 8) & 255) / 255,
                               blue: CGFloat(color & 255) / 255, alpha: 1)
            let model = ModelEntity(mesh: .generateBox(size: size), materials: [SimpleMaterial(color: tint, roughness: 0.85, isMetallic: false)])
            model.position = at; parent.addChild(model)
            return model
        }
    }
}
