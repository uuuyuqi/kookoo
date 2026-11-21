import Foundation
import XCTest
@testable import KookyKit

final class AppIconLocalizationTests: XCTestCase {
    private let legacyIDs = [
        "default", "01-pearl", "02-marshmallow", "03-neon", "04-retro",
        "05-ink", "06-jelly", "07-chrome", "08-pixel", "09-hacker",
        "10-swiss", "11-porcelain", "12-sunset", "13-velvet", "14-space",
        "15-noir", "16-ocean", "17-bauhaus", "18-peach", "19-graphite",
        "20-prism",
    ]

    private let expectedEnglish = [
        "Kookoo (Default)", "Pearl", "Marshmallow", "Neon", "Retro",
        "Ink", "Jelly", "Chrome", "Pixel", "Hacker",
        "Swiss", "Porcelain", "Sunset", "Velvet", "Space",
        "Noir", "Ocean", "Bauhaus", "Peach", "Graphite",
        "Prism",
        "Ivory K", "Brushed Titanium", "Burgundy Lacquer", "Blue Porcelain", "Saddle Leather",
        "Cobalt Origami", "Scarlet Cursor", "Pistachio", "Black & Gold", "Midnight Pearl",
        "Jelly Cat", "Yuzu Smile", "Ice Keycap", "Pixel Cat", "Neon Stickers",
        "Acid Lightning", "Orange Balloon", "Milk Carton", "Holo Alien", "Violet Comet",
        "Cyanotype Fern", "Inkbrush K", "Printed Sunset", "Vermilion Seal", "Woodcut Trail",
        "Misty Moon", "Paper Fan", "Jade Sunrise", "Terracotta Cursor", "Inkfish",
        "Oscilloscope", "Green Screen", "Split Flap", "Amber CRT", "Orange Terminal",
        "Mixtape", "Blueprint", "Prism K", "Pocket Pixels", "Obsidian Armor",
    ]

    private let expectedChinese = [
        "Kookoo（默认）", "珍珠", "棉花糖", "霓虹", "复古",
        "水墨", "果冻", "镀铬", "像素", "黑客",
        "瑞士风", "瓷器", "日落", "天鹅绒", "太空",
        "黑金", "海洋", "包豪斯", "蜜桃", "石墨",
        "棱镜",
        "象牙字标", "拉丝钛", "酒红漆", "青花瓷", "鞍棕皮革",
        "蓝白折纸", "釉红光标", "开心果绿", "黑金双线", "深海贝母",
        "果冻猫", "柚子笑脸", "冰蓝键帽", "像素猫", "荧光贴纸",
        "酸绿闪电", "橙气球", "牛奶盒", "镭射外星人", "紫色彗星",
        "蓝晒蕨叶", "墨笔字标", "版印落日", "朱印", "木刻山径",
        "雾紫月亮", "黑纸折扇", "翡翠晨光", "赤陶光标", "蓝墨游鱼",
        "电波示波器", "绿屏终端", "机械翻牌", "琥珀荧屏", "橙透终端",
        "复古磁带", "深蓝图纸", "折光字标", "像素掌机", "黑曜机甲",
    ]

    func testCatalogPreservesExactStableIdentifiersAndOrder() {
        let reviewIDs = (1...40).map { String(format: "review-%02d", $0) }
        XCTAssertEqual(AppIconChoice.all.map(\.id), legacyIDs + reviewIDs)
    }

    func testEveryChoiceHasItsReviewedChineseName() throws {
        let path = try XCTUnwrap(Bundle.kookyResources.path(forResource: "zh-Hans", ofType: "lproj") ?? Bundle.kookyResources.path(forResource: "zh-hans", ofType: "lproj"))
        let chinese = try XCTUnwrap(Bundle(path: path))
        XCTAssertEqual(AppIconChoice.all.map { $0.localizedName(in: chinese) }, expectedChinese)
    }

    func testEveryChoiceHasItsReviewedEnglishName() throws {
        let path = try XCTUnwrap(Bundle.kookyResources.path(forResource: "en", ofType: "lproj"))
        let english = try XCTUnwrap(Bundle(path: path))
        XCTAssertEqual(AppIconChoice.all.map { $0.localizedName(in: english) }, expectedEnglish)
    }

    func testFailureMessagesAreTranslated() throws {
        let path = try XCTUnwrap(Bundle.kookyResources.path(forResource: "zh-Hans", ofType: "lproj") ?? Bundle.kookyResources.path(forResource: "zh-hans", ofType: "lproj"))
        let chinese = try XCTUnwrap(Bundle(path: path))
        for key in ["App Icon", "%@ app icon", "Unknown icon.", "The bundled icon is missing or invalid.", "The app icon is not a regular file.",
                    "Could not change the app icon: %@ Your saved preference was not changed; the selected icon could not be applied. Install Kookoo in a writable Applications folder; no administrator access is requested."] {
            let value = chinese.localizedString(forKey: key, value: key, table: nil)
            XCTAssertNotEqual(value, key)
            XCTAssertFalse(value.isEmpty)
        }
    }
}
