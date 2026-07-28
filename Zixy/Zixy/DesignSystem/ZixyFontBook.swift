import UIKit

enum ZixyFontBook {

    private static let fontName = "AvenirNext-Bold"

    static func bold(
        size: CGFloat,
        relativeTo textStyle: UIFont.TextStyle? = nil
    ) -> UIFont {
        let font = UIFont(name: fontName, size: size)
            ?? UIFont.systemFont(ofSize: size, weight: .bold)

        guard let textStyle else {
            return font
        }

        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font)
    }
}
