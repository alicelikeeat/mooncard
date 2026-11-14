import SwiftUI

/// First production-art batch; unreleased portraits deliberately keep their existing identity tile.
enum MangaArt {
    static let illustrated: Set<String> = ["rook", "ember", "moss"]
    static func accent(_ hero: Hero) -> Color {
        Color(red: Double((hero.color >> 16) & 255) / 255,
              green: Double((hero.color >> 8) & 255) / 255,
              blue: Double(hero.color & 255) / 255)
    }
}

struct HeroPortrait: View {
    let hero: Hero
    var body: some View {
        GeometryReader { geometry in
            if MangaArt.illustrated.contains(hero.id) {
                Image("portrait-\(hero.id)")
                    .resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                    .clipped()
            } else {
                ZStack {
                    MangaArt.accent(hero).opacity(0.25)
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.square").font(.largeTitle)
                        Text(hero.name).font(.title2.bold())
                        Text("立绘制作中").font(.caption)
                    }
                }
            }
        }.accessibilityLabel("\(hero.name)角色立绘")
    }
}

struct MangaRecruitCard: View {
    let hero: Hero
    let duplicate: Bool
    var body: some View {
        HStack(spacing: 0) {
            HeroPortrait(hero: hero).frame(width: 170, height: 255)
            VStack(alignment: .leading, spacing: 12) {
                Text(hero.legendary ? "LEGENDARY" : "TRAVELER")
                    .font(.caption.weight(.black)).tracking(3)
                Text(hero.name).font(.system(size: 36, weight: .black, design: .rounded))
                Rectangle().fill(MangaArt.accent(hero)).frame(width: 40, height: 4)
                Text(hero.role).font(.headline)
                Text(duplicate ? "再次相逢 · 已转换星屑" : "新旅伴 · 欢迎登车")
                    .font(.subheadline.weight(.semibold))
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Color(red: 0.07, green: 0.1, blue: 0.16))
        .background(Color(red: 0.97, green: 0.94, blue: 0.86))
        .overlay(Rectangle().stroke(.black, lineWidth: 3))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityElement(children: .combine)
    }
}

/// Short, non-interactive cut-in. It never intercepts the movement or combat buttons.
struct MangaCutIn: View {
    let hero: Hero
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 0) {
            HeroPortrait(hero: hero).frame(width: 100, height: 120)
            VStack(alignment: .leading, spacing: 5) {
                Text(hero.name).font(.caption.weight(.black)).tracking(3)
                Text(text).font(.system(size: 23, weight: .black, design: .rounded))
                    .italic().minimumScaleFactor(0.6).lineLimit(2)
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 370, height: 120)
        .foregroundStyle(.black)
        .background(Color(red: 0.99, green: 0.95, blue: 0.83))
        .overlay(Rectangle().stroke(.black, lineWidth: 4))
        .overlay(alignment: .bottom) { Rectangle().fill(MangaArt.accent(hero)).frame(height: 6) }
        .rotationEffect(.degrees(reduceMotion ? 0 : -3))
        .shadow(color: .black.opacity(0.4), radius: 0, x: 6, y: 6)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }
}
