import SwiftUI

@MainActor final class GameStore: ObservableObject {
    @Published var progress = Progress()
    @Published var zone: Zone = .train
    @Published var battle = Battle()
    @Published var notice = "欢迎登车。招募伙伴，前往裂界，建设你的领地。"
    @Published var draw: DrawResult?
    @Published var panel: Panel?
    var movement = Point()
    var suspended = false
    private var rewardClaimed = false
    private var saveBlocked = false
    private var destination: URL?
    enum Panel: String, Identifiable { case recruit, roster, build; var id: String { rawValue } }

    init() {
        do {
            let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true)
            destination = root.appendingPathComponent("mooncard-v1.json")
            if let url = destination, FileManager.default.fileExists(atPath: url.path) {
                let loaded = try JSONDecoder().decode(Progress.self, from: Data(contentsOf: url))
                guard loaded.isValid else { throw CocoaError(.fileReadCorruptFile) }
                progress = loaded
            }
        } catch {
            saveBlocked = true
            notice = "存档读取失败，已保护原文件；本次为临时游玩。\(error.localizedDescription)"
        }
    }
    func save() {
        guard !saveBlocked, let destination else { return }
        do { try JSONEncoder().encode(progress).write(to: destination, options: .atomic) }
        catch { notice = "保存失败：\(error.localizedDescription)" }
    }
    var hero: Hero { Hero.find(progress.party[battle.active]) }
    var attackBonus: Double { Double(progress.level(.forge)) * 3 }
    var canAct: Bool { zone == .frontier && panel == nil && !suspended }
    func travel(_ next: Zone) {
        guard zone != next else { return }
        zone = next
        movement = Point()
        if next == .frontier { battle = Battle(); rewardClaimed = false }
        notice = next == .frontier ? "击败三波敌人。红色蓄力时闪避，最后一波是守门巨像。" : "已抵达\(next.title)"
        save()
    }
    func tick(_ delta: Double) {
        guard canAct else { return }
        battle.tick(delta, movement: movement)
        settle()
    }
    func attack() { guard canAct else { return }; battle.attack(hero: hero, bonus: attackBonus); settle() }
    func skill() { guard canAct else { return }; battle.skill(hero: hero, bonus: attackBonus); settle() }
    func dodge() { guard canAct else { return }; battle.dodge(direction: movement) }
    func settle() {
        guard battle.outcome == .victory, !rewardClaimed else { return }
        rewardClaimed = true
        let supplies = 90 + progress.level(.garden) * 15
        let crystals = 160 + progress.level(.beacon) * 20
        progress.supplies += supplies; progress.crystals += crystals; progress.victories += 1
        notice = "远征胜利：物资 +\(supplies)，星晶 +\(crystals)。返回领地建设，或回列车招募。"
        save()
    }
    func recruit() {
        var rng = SystemRandomNumberGenerator()
        guard let result = progress.recruit(using: &rng) else { notice = "星晶不足，完成裂界远征可获取。"; return }
        draw = result
        notice = result.duplicate ? "重复角色已转换为星屑。" : "新伙伴 \(Hero.find(result.heroID).name) 已登车！"
        save()
    }
    func upgrade(_ building: Building) {
        guard progress.upgrade(building) else { notice = "物资不足或建筑已满级。"; return }
        notice = "\(building.title)已升至 \(progress.level(building)) 级。"
        save()
    }
    func equip(_ id: String, slot: Int) {
        // Party changes are restricted to safe zones to avoid swapping health identities mid-battle.
        guard zone != .frontier, progress.equip(id, slot: slot) else { return }
        save()
    }
}
