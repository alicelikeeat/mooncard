import XCTest
@testable import MoonCardCore

final class GameCoreTests: XCTestCase {
    struct Seeded: RandomNumberGenerator {
        var seed: UInt64 = 17
        mutating func next() -> UInt64 {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return seed
        }
    }
    func testPityAndInsufficientCurrency() {
        var p = Progress(); var rng = Seeded()
        p.pity = 59
        let draw = p.recruit(using: &rng)!
        XCTAssertTrue(draw.guaranteed)
        XCTAssertTrue(Hero.find(draw.heroID).legendary)
        XCTAssertEqual(p.pity, 0)
        XCTAssertEqual(p.crystals, 1440)
        p.crystals = 0
        let before = p
        XCTAssertNil(p.recruit(using: &rng))
        XCTAssertEqual(p, before)
    }
    func testDuplicateConversionAndPityInvariant() {
        var p = Progress(); var rng = Seeded()
        p.owned = Hero.all.map(\.id); p.crystals = 160 * 500
        var expectedShards = 0
        for _ in 0..<500 {
            let draw = p.recruit(using: &rng)!
            XCTAssertTrue(draw.duplicate)
            expectedShards += Hero.find(draw.heroID).legendary ? 20 : 5
            XCTAssertTrue((0..<60).contains(p.pity))
        }
        XCTAssertEqual(p.shards, expectedShards)
        XCTAssertEqual(p.crystals, 0)
        XCTAssertTrue(p.isValid)
    }
    func testBuildingsCannotOverspendOrExceedCap() {
        var p = Progress()
        XCTAssertTrue(p.upgrade(.forge)); XCTAssertEqual(p.supplies, 60)
        XCTAssertFalse(p.upgrade(.forge)); XCTAssertEqual(p.supplies, 60)
        p.supplies = 1000
        XCTAssertTrue(p.upgrade(.forge)); XCTAssertTrue(p.upgrade(.forge))
        let before = p
        XCTAssertFalse(p.upgrade(.forge)); XCTAssertEqual(p, before)
    }
    func testPartySwapAndLockedHero() {
        var p = Progress()
        XCTAssertTrue(p.equip("moss", slot: 0))
        XCTAssertEqual(p.party, ["moss", "ember", "rook"])
        XCTAssertFalse(p.equip("nova", slot: 0))
        XCTAssertFalse(p.equip("rook", slot: 3))
        XCTAssertTrue(p.isValid)
    }
    func testSaveRoundTripAndCorruptionValidation() throws {
        var p = Progress(); p.upgrade(.garden)
        let copy = try JSONDecoder().decode(Progress.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(copy, p); XCTAssertTrue(copy.isValid)
        p.party = ["rook", "rook", "moss"]; XCTAssertFalse(p.isValid)
        p = Progress(); p.pity = 60; XCTAssertFalse(p.isValid)
        p = Progress(); p.version = 2; XCTAssertFalse(p.isValid)
    }
    func testAttackRangeCooldownAndCombo() {
        var b = Battle()
        b.enemies = [Enemy(id: 1, position: Point(0, 3), hp: 1000, boss: false)]
        XCTAssertTrue(b.attack(hero: Hero.all[0]))
        XCTAssertEqual(b.enemies[0].hp, 976)
        XCTAssertFalse(b.attack(hero: Hero.all[0]))
        for _ in 0..<7 { b.tick(0.05, movement: Point()) }
        b.attack(hero: Hero.all[0]); XCTAssertEqual(b.combo, 2)
        for _ in 0..<7 { b.tick(0.05, movement: Point()) }
        b.attack(hero: Hero.all[0]); XCTAssertEqual(b.combo, 3)
        XCTAssertEqual(b.enemies[0].hp, 908.8, accuracy: 0.001)
        b.attackCooldown = 0; b.player = Point(8, 7)
        b.attack(hero: Hero.all[0]); XCTAssertEqual(b.enemies[0].hp, 908.8, accuracy: 0.001)
    }
    func testDodgeProtectsAgainstTelegraphedHit() {
        var b = Battle()
        b.enemies = [Enemy(id: 1, position: Point(0, 4), hp: 100, windup: 0.01, boss: false)]
        XCTAssertTrue(b.dodge(direction: Point(1, 0)))
        XCTAssertFalse(b.dodge(direction: Point()))
        b.tick(0.02, movement: Point())
        XCTAssertEqual(b.health[0], 120)
        XCTAssertGreaterThan(b.player.x, 0)
    }
    func testDefeatSwitchesToSurvivingHeroThenEnds() {
        var b = Battle(); b.health = [0, 20, 0]
        b.tick(0.01, movement: Point()); XCTAssertEqual(b.active, 1)
        b.health[1] = 0
        b.tick(0.01, movement: Point()); XCTAssertEqual(b.outcome, .defeat)
        XCTAssertFalse(b.attack(hero: Hero.all[0]))
    }
    func testThreeWavesThenTerminalVictory() {
        var b = Battle()
        for wave in 1...3 {
            XCTAssertEqual(b.wave, wave)
            b.enemies = [Enemy(id: wave, position: b.player, hp: 1, boss: wave == 3)]
            b.attackCooldown = 0
            b.attack(hero: Hero.all[0])
        }
        XCTAssertEqual(b.outcome, .victory)
        XCTAssertTrue(b.enemies.isEmpty)
        XCTAssertFalse(b.skill(hero: Hero.all[0]))
    }
    func testHugeFrameDeltaAndArenaBounds() {
        var b = Battle()
        b.tick(100, movement: Point(100, 100))
        XCTAssertLessThan(b.player.distance(to: Point(0, 4)), 0.21)
        b.player = Point(8, 7)
        b.tick(0.05, movement: Point(1, 1))
        XCTAssertEqual(b.player, Point(8, 7))
    }
}
