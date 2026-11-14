import Foundation

public enum Zone: String, Codable, CaseIterable {
    case train, frontier, citadel
    public var title: String {
        switch self { case .train: return "星轨列车"; case .frontier: return "裂界前线"; case .citadel: return "月影领地" }
    }
}

public struct Hero: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let role: String
    public let legendary: Bool
    public let attack: Double
    public let range: Double
    public let color: UInt32
    public static let all: [Hero] = [
        Hero(id: "rook", name: "洛克", role: "近卫 · 破阵", legendary: false, attack: 24, range: 2.6, color: 0x59C4CF),
        Hero(id: "ember", name: "绯羽", role: "远射 · 炎雨", legendary: false, attack: 18, range: 6.5, color: 0xF07969),
        Hero(id: "moss", name: "森铃", role: "辅助 · 回春", legendary: false, attack: 16, range: 4.5, color: 0xA2D18C),
        Hero(id: "ink", name: "墨鸦", role: "刺客 · 断章", legendary: false, attack: 30, range: 2.2, color: 0xB697D5),
        Hero(id: "nova", name: "星璃", role: "传说 · 星陨", legendary: true, attack: 29, range: 5, color: 0xE7C879),
        Hero(id: "king", name: "夜王", role: "传说 · 裂界", legendary: true, attack: 38, range: 3, color: 0x879DF0)
    ]
    public static func find(_ id: String) -> Hero { all.first { $0.id == id } ?? all[0] }
}

public enum Building: String, Codable, CaseIterable {
    case forge, garden, beacon
    public var title: String {
        switch self { case .forge: return "星铁工坊"; case .garden: return "月光花园"; case .beacon: return "领地灯塔" }
    }
}

public struct DrawResult: Equatable {
    public let heroID: String
    public let duplicate: Bool
    public let guaranteed: Bool
}

public struct Progress: Codable, Equatable {
    public var version = 1
    public var crystals = 1600
    public var supplies = 120
    public var shards = 0
    public var pity = 0
    public var owned = ["rook", "ember", "moss"]
    public var party = ["rook", "ember", "moss"]
    public var buildings: [String: Int] = [:]
    public var victories = 0
    public init() {}
    public func level(_ building: Building) -> Int { buildings[building.rawValue, default: 0] }
    public func cost(_ building: Building) -> Int { 60 * (level(building) + 1) }
    @discardableResult public mutating func upgrade(_ building: Building) -> Bool {
        let price = cost(building)
        guard level(building) < 3, supplies >= price else { return false }
        supplies -= price
        buildings[building.rawValue] = level(building) + 1
        return true
    }
    @discardableResult public mutating func equip(_ id: String, slot: Int) -> Bool {
        guard party.indices.contains(slot), owned.contains(id) else { return false }
        if let previous = party.firstIndex(of: id) { party.swapAt(previous, slot) }
        else { party[slot] = id }
        return true
    }
    /// Fixed 2% legendary rate; the 60th draw is guaranteed. No paid currency in this prototype.
    public mutating func recruit<R: RandomNumberGenerator>(using rng: inout R) -> DrawResult? {
        guard crystals >= 160 else { return nil }
        crystals -= 160
        let guaranteed = pity >= 59
        let rare = guaranteed || Double.random(in: 0..<1, using: &rng) < 0.02
        let pool = Hero.all.filter { $0.legendary == rare }
        let hero = pool[Int.random(in: 0..<pool.count, using: &rng)]
        let duplicate = owned.contains(hero.id)
        if duplicate { shards += rare ? 20 : 5 } else { owned.append(hero.id) }
        pity = rare ? 0 : pity + 1
        return DrawResult(heroID: hero.id, duplicate: duplicate, guaranteed: guaranteed)
    }
    /// Reject unsupported versions and malformed saves instead of silently overwriting them.
    public var isValid: Bool {
        let known = Set(Hero.all.map(\.id))
        return version == 1 && crystals >= 0 && supplies >= 0 && shards >= 0 && victories >= 0
            && (0..<60).contains(pity) && party.count == 3 && Set(party).count == 3
            && Set(owned).count == owned.count && Set(owned).isSubset(of: known)
            && Set(party).isSubset(of: Set(owned))
            && buildings.allSatisfy { Building(rawValue: $0.key) != nil && (0...3).contains($0.value) }
    }
}

public struct Point: Equatable {
    public var x: Double
    public var z: Double
    public init(_ x: Double = 0, _ z: Double = 0) { self.x = x; self.z = z }
    public func distance(to other: Point) -> Double { hypot(x - other.x, z - other.z) }
}
public struct Enemy: Identifiable {
    public let id: Int
    public var position: Point
    public var hp: Double
    public var cooldown: Double = 0
    public var windup: Double = 0
    public let boss: Bool
}
public enum BattleOutcome: Equatable { case fighting, victory, defeat }

/// Pure simulation: no renderer dependency; seconds are supplied by the display loop.
public struct Battle {
    public var player = Point(0, 4)
    public var enemies: [Enemy] = []
    public var health = [120.0, 120.0, 120.0]
    public var active = 0
    public var wave = 0
    public var outcome = BattleOutcome.fighting
    public var attackCooldown = 0.0
    public var skillCooldown = 0.0
    public var dodgeCooldown = 0.0
    public var invulnerability = 0.0
    public var combo = 0
    public var comboWindow = 0.0
    public var comic = ""
    public var comicRemaining = 0.0
    private var dash = Point()
    public init() { spawn() }
    private mutating func spawn() {
        wave += 1
        let count = wave == 3 ? 1 : 3 + wave
        enemies = (0..<count).map { index in
            Enemy(id: wave * 100 + index, position: Point(Double(index) * 2 - Double(count - 1), -4),
                  hp: wave == 3 ? 360 : 55 + Double(wave) * 10, boss: wave == 3)
        }
    }
    public mutating func switchHero(_ index: Int) {
        guard health.indices.contains(index), health[index] > 0, outcome == .fighting else { return }
        active = index
    }
    @discardableResult public mutating func dodge(direction: Point) -> Bool {
        guard outcome == .fighting, dodgeCooldown <= 0 else { return false }
        let length = hypot(direction.x, direction.z)
        dash = length > 0.01 ? Point(direction.x / length, direction.z / length) : Point(0, 1)
        dodgeCooldown = 1.2
        invulnerability = 0.28
        return true
    }
    @discardableResult public mutating func attack(hero: Hero, bonus: Double = 0) -> Bool {
        guard outcome == .fighting, attackCooldown <= 0 else { return false }
        attackCooldown = 0.32
        combo = comboWindow > 0 ? combo % 3 + 1 : 1
        comboWindow = 0.85
        guard let target = enemies.indices.filter({ enemies[$0].hp > 0 && player.distance(to: enemies[$0].position) <= hero.range })
            .min(by: { player.distance(to: enemies[$0].position) < player.distance(to: enemies[$1].position) }) else {
            show("挥空 · 靠近目标"); return true
        }
        enemies[target].hp -= (hero.attack + bonus) * (combo == 3 ? 1.8 : 1)
        show(combo == 3 ? "BREAK! 三连击" : "HIT! \(combo)")
        resolveWave()
        return true
    }
    @discardableResult public mutating func skill(hero: Hero, bonus: Double = 0) -> Bool {
        guard outcome == .fighting, skillCooldown <= 0 else { return false }
        skillCooldown = 6
        for i in enemies.indices where player.distance(to: enemies[i].position) < 7 {
            enemies[i].hp -= hero.attack * 2.3 + bonus
        }
        if hero.id == "moss" { health[active] = min(120, health[active] + 40) }
        show("\(hero.name) · \(hero.role.components(separatedBy: " · ").last ?? "裂界")")
        resolveWave()
        return true
    }
    private mutating func show(_ text: String) { comic = text; comicRemaining = 0.65 }
    private mutating func resolveWave() {
        enemies.removeAll { $0.hp <= 0 }
        if enemies.isEmpty {
            if wave >= 3 { outcome = .victory; show("TO BE CONTINUED…") }
            else { spawn(); show("第 \(wave) 波 · 敌袭") }
        }
    }
    public mutating func tick(_ seconds: Double, movement: Point) {
        guard seconds.isFinite, seconds > 0, outcome == .fighting else { return }
        let dt = min(seconds, 0.05) // Never simulate a huge background/resume delta.
        attackCooldown = max(0, attackCooldown - dt)
        skillCooldown = max(0, skillCooldown - dt)
        dodgeCooldown = max(0, dodgeCooldown - dt)
        comboWindow = max(0, comboWindow - dt)
        comicRemaining = max(0, comicRemaining - dt)
        let protected = invulnerability > 0
        invulnerability = max(0, invulnerability - dt)
        let magnitude = max(1, hypot(movement.x, movement.z))
        player.x += (protected ? dash.x * 12 : movement.x / magnitude * 4) * dt
        player.z += (protected ? dash.z * 12 : movement.z / magnitude * 4) * dt
        player.x = min(8, max(-8, player.x)); player.z = min(7, max(-7, player.z))
        for i in enemies.indices {
            enemies[i].cooldown = max(0, enemies[i].cooldown - dt)
            let distance = player.distance(to: enemies[i].position)
            if enemies[i].windup > 0 {
                enemies[i].windup = max(0, enemies[i].windup - dt)
                if enemies[i].windup == 0 {
                    if distance < (enemies[i].boss ? 2.7 : 1.6), !protected {
                        health[active] = max(0, health[active] - (enemies[i].boss ? 28 : 9))
                    }
                    enemies[i].cooldown = enemies[i].boss ? 1.6 : 1.1
                }
            } else if distance < (enemies[i].boss ? 2.2 : 1.25), enemies[i].cooldown <= 0 {
                enemies[i].windup = enemies[i].boss ? 0.9 : 0.5
            } else if distance > 1.1 {
                let step = min(distance - 1.1, dt * (enemies[i].boss ? 1.1 : 1.6))
                enemies[i].position.x += (player.x - enemies[i].position.x) / distance * step
                enemies[i].position.z += (player.z - enemies[i].position.z) / distance * step
            }
        }
        if health[active] <= 0 {
            if let survivor = health.firstIndex(where: { $0 > 0 }) { active = survivor }
            else { outcome = .defeat; show("本章未完 · 整备再战") }
        }
    }
}
