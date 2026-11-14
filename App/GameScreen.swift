import SwiftUI

struct GameScreen: View {
    @ObservedObject var game: GameStore
    var body: some View {
        ZStack {
            WorldView(game: game).ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.65), .clear, .black.opacity(0.6)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea().allowsHitTesting(false)
            VStack(spacing: 8) {
                header
                HStack {
                    Text(game.notice).font(.caption).foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2).padding(10).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    Spacer()
                }
                Spacer(minLength: 8)
                if game.zone == .frontier { battleControls } else { homeControls }
            }.padding(18)
            if game.zone == .frontier, game.battle.comicRemaining > 0 {
                if game.battle.comicHasPortrait {
                    MangaCutIn(hero: Hero.find(game.comicHeroID), text: game.battle.comic)
                } else {
                    Text(game.battle.comic).font(.headline.bold()).padding(12)
                        .foregroundStyle(.black).background(.yellow)
                        .overlay(Rectangle().stroke(.black, lineWidth: 2)).allowsHitTesting(false)
                }
            }
            if game.zone == .frontier, game.battle.outcome != .fighting { resultPanel }
        }
        .sheet(item: $game.panel) { panel in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if panel == .recruit { recruitment }
                        if panel == .roster { roster }
                        if panel == .build { construction }
                        Text(game.notice).font(.footnote).foregroundStyle(.secondary)
                    }.padding(24)
                }
                .navigationTitle(panel == .recruit ? "星轨召集" : panel == .roster ? "旅伴名册" : "领地建设")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { game.panel = nil } } }
            }.presentationDetents([.large])
        }
        .onChange(of: game.panel) { _ in game.movement = Point() }
    }
    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MOONCARD").font(.caption.weight(.heavy)).tracking(4)
                Text(game.zone.title).font(.title3.bold())
            }
            Spacer()
            Label("\(game.progress.crystals)", systemImage: "sparkles")
            Label("\(game.progress.supplies)", systemImage: "shippingbox.fill")
            if game.zone == .frontier {
                Text("第 \(game.battle.wave)/3 波").font(.callout.bold())
                Button("撤回列车") { game.travel(.train) }.buttonStyle(.bordered)
            } else {
                ForEach(Zone.allCases, id: \.self) { zone in
                    Button(zone.title) { game.travel(zone) }.buttonStyle(.bordered)
                        .tint(game.zone == zone ? .cyan : .gray)
                }
            }
        }.font(.subheadline.monospacedDigit())
    }
    private var homeControls: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(game.zone == .train ? "下一站 · 裂界前线" : "把远征战利品变成家园")
                    .font(.title2.bold())
                Text(game.zone == .train ? "三名旅伴，一段尚未写完的故事。" : "工坊提升攻击，花园增加物资，灯塔增加星晶。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("旅伴 / 编队") { game.panel = .roster }.buttonStyle(.bordered)
            Button(game.zone == .train ? "召集伙伴" : "建设领地") {
                game.panel = game.zone == .train ? .recruit : .build
            }.buttonStyle(.borderedProminent).tint(.indigo)
            Button("出发远征") { game.travel(.frontier) }.buttonStyle(.borderedProminent).tint(.teal)
        }.padding(16).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
    private var battleControls: some View {
        HStack(alignment: .bottom, spacing: 20) {
            Joystick { game.movement = $0 }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(0..<3, id: \.self) { slot in
                    let hero = Hero.find(game.progress.party[slot])
                    Button { game.battle.switchHero(slot) } label: {
                        HStack {
                            HeroPortrait(hero: hero).frame(width: 28, height: 34)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            Text(hero.name).fontWeight(game.battle.active == slot ? .black : .regular)
                            ProgressView(value: game.battle.health[slot], total: 120).frame(width: 75)
                            Text("\(Int(game.battle.health[slot]))").font(.caption.monospacedDigit())
                        }.padding(7).background(game.battle.active == slot ? Color.teal.opacity(0.45) : .black.opacity(0.3),
                                                in: RoundedRectangle(cornerRadius: 8))
                    }.disabled(game.battle.health[slot] <= 0)
                }
            }
            Spacer()
            action("闪避", cooldown: game.battle.dodgeCooldown, action: game.dodge)
            action("裂界技", cooldown: game.battle.skillCooldown, action: game.skill)
            action("攻击", cooldown: game.battle.attackCooldown, action: game.attack)
        }
    }
    private func action(_ name: String, cooldown: Double, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(name).bold()
                Text(cooldown > 0 ? String(format: "%.1fs", cooldown) : "就绪").font(.caption.monospacedDigit())
            }.frame(width: 74, height: 74).background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
        }.disabled(cooldown > 0)
    }
    private var resultPanel: some View {
        VStack(spacing: 16) {
            Text(game.battle.outcome == .victory ? "本章胜利" : "整备，再出发").font(.largeTitle.bold())
            Text(game.notice).multilineTextAlignment(.center)
            HStack {
                Button("返回列车") { game.travel(.train) }
                Button("建设领地") { game.travel(.citadel) }
            }.buttonStyle(.borderedProminent)
        }.padding(30).frame(maxWidth: 460).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
    private var recruitment: some View {
        Group {
            Text("召集穿越裂界的旅伴").font(.title2.bold())
            Text("每次 160 星晶。传说基础概率 2%，普通 98%；各品质内等概率。连续 59 次未获传说，第 60 次必得；获得传说后计数重置。")
            Text("当前保底进度 \(game.progress.pity)/60 · 星晶 \(game.progress.crystals)")
            Text("重复普通 / 传说分别转化为 5 / 20 星屑；星屑兑换尚未开放。本原型无充值。")
                .font(.footnote).foregroundStyle(.secondary)
            if let draw = game.draw {
                let hero = Hero.find(draw.heroID)
                MangaRecruitCard(hero: hero, duplicate: draw.duplicate)
            }
            Button("召集一次 · 160 星晶") { game.recruit() }.buttonStyle(.borderedProminent)
                .disabled(game.progress.crystals < 160)
        }
    }
    private var roster: some View {
        ForEach(Hero.all) { hero in
            HStack(alignment: .top, spacing: 16) {
                HeroPortrait(hero: hero).frame(width: 100, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 10) {
                Text("\(hero.name) · \(hero.role)").font(.headline)
                if game.progress.owned.contains(hero.id) {
                    HStack {
                        ForEach(0..<3, id: \.self) { slot in
                            Button(game.progress.party[slot] == hero.id ? "✓ 槽位 \(slot + 1)" : "编入 \(slot + 1)") {
                                game.equip(hero.id, slot: slot)
                            }.buttonStyle(.bordered)
                        }
                    }
                } else { Text("尚未招募").foregroundStyle(.secondary) }
                }
            }.padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    private var construction: some View {
        ForEach(Building.allCases, id: \.self) { building in
            VStack(alignment: .leading, spacing: 10) {
                Text("\(building.title) · Lv.\(game.progress.level(building))/3").font(.headline)
                Text(building == .forge ? "每级：全队攻击 +3" : building == .garden ? "每级：胜利物资 +15" : "每级：胜利星晶 +20")
                Button(game.progress.level(building) == 3 ? "已满级" : "升级 · \(game.progress.cost(building)) 物资") {
                    game.upgrade(building)
                }.buttonStyle(.borderedProminent)
                    .disabled(game.progress.level(building) == 3 || game.progress.supplies < game.progress.cost(building))
            }.padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct Joystick: View {
    let onMove: (Point) -> Void
    @State private var offset = CGSize.zero
    var body: some View {
        Circle().fill(.ultraThinMaterial).frame(width: 120, height: 120)
            .overlay(Circle().stroke(.white.opacity(0.3)))
            .overlay(Circle().fill(.white.opacity(0.65)).frame(width: 48, height: 48).offset(offset))
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let x = value.location.x - 60, y = value.location.y - 60
                    let scale = max(1, hypot(x, y) / 42)
                    offset = CGSize(width: x / scale, height: y / scale)
                    onMove(Point(Double(offset.width / 42), Double(offset.height / 42)))
                }.onEnded { _ in offset = .zero; onMove(Point()) })
            .onDisappear { onMove(Point()) }
            .accessibilityLabel("移动摇杆")
    }
}
