import Foundation
import XCTest
@testable import KookyKit

final class AppIconLocalizationTests: XCTestCase {
    func testEveryAlternateHasChineseDisplayNameAndStableIdentifier() throws {
        let path = try XCTUnwrap(Bundle.kookyResources.path(forResource: "zh-Hans", ofType: "lproj"))
        let chinese = try XCTUnwrap(Bundle(path: path))
        let expected = ["Kookoo", "珍珠", "棉花糖", "霓虹", "复古", "水墨", "果冻", "镀铬", "像素", "黑客", "瑞士风", "瓷器", "日落", "天鹅绒", "太空", "黑金", "海洋", "包豪斯", "蜜桃", "石墨", "棱镜"]
        XCTAssertEqual(AppIconChoice.all.map { $0.localizedName(in: chinese) }, expected)
        XCTAssertEqual(AppIconChoice.all[2].id, "02-marshmallow")
    }

    func testEnglishNamesRemainAvailable() throws {
        let path = try XCTUnwrap(Bundle.kookyResources.path(forResource: "en", ofType: "lproj"))
        let english = try XCTUnwrap(Bundle(path: path))
        for choice in AppIconChoice.all {
            XCTAssertEqual(choice.localizedName(in: english), choice.name)
        }
    }

    func testConfirmationAndFailureMessagesAreTranslated() throws {
        let path = try XCTUnwrap(Bundle.kookyResources.path(forResource: "zh-Hans", ofType: "lproj"))
        let chinese = try XCTUnwrap(Bundle(path: path))
        for key in ["App Icon", "Change installed app icon?", "Cancel", "Change Icon", "%@ app icon", "Unknown icon.", "The bundled icon is missing or invalid.", "The app icon is not a regular file.",
                    "This changes AppIcon.icns and invalidates the app’s signature integrity. It may affect launching or updates under macOS or your organization’s security policy. Your terminal sessions will not be restarted.",
                    "Could not change the app icon: %@ Your saved preference was not changed; the selected icon could not be applied. Install Kookoo in a writable Applications folder; no administrator access is requested."] {
            let value = chinese.localizedString(forKey: key, value: key, table: nil)
            XCTAssertNotEqual(value, key)
            XCTAssertFalse(value.isEmpty)
        }
    }
}
