import Everything
import SwiftUI

struct SpriteSheetView: View {
    let frames: [SpriteFrame]

    let image: CGImage

    init() {
        let url = Bundle.main.url(forResource: "Sprites", withExtension: "json")!
        let data = try! Data(contentsOf: url)
        let catalog = try! JSONDecoder().decode(TexturePackerSpriteArrayCatalog.self, from: data)
        frames = catalog.frames

        image = try! ImageSource(named: "Sprites").image(at: 0)
    }

    var body: some View {
        List(frames, id: \.filename) { frame in
            HStack {
                let rect = frame.frame.flipped(within: image.frame.size)
//                let rect = frame.frame
                Image(cgImage: image.subimage(at: rect))
                    .border(Color.black)
                Text(frame.filename)
                Text(verbatim: String(describing: rect))
            }
        }
    }
}

struct SpriteFrame: Decodable {
    let filename: String
    let frame: CGRect
    let rotated: Bool
    let trimmed: Bool
    let spriteSource: CGRect
    let sourceSize: CGSize
    let pivot: CGPoint

    enum CodingKeys: String, CodingKey {
        case filename
        case frame
        case rotated
        case trimmed
        case spriteSource = "spriteSourceSize"
        case sourceSize
        case pivot
    }

    init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        filename = try container.decode(String.self, forKey: CodingKeys.filename)
        frame = CGRect(try container.decode([String: CGFloat].self, forKey: CodingKeys.frame))!
        rotated = try container.decode(Bool.self, forKey: CodingKeys.rotated)
        trimmed = try container.decode(Bool.self, forKey: CodingKeys.trimmed)
        spriteSource = CGRect(try container.decode([String: CGFloat].self, forKey: CodingKeys.spriteSource))!
        sourceSize = CGSize(try container.decode([String: CGFloat].self, forKey: CodingKeys.sourceSize))!
        pivot = CGPoint(try container.decode([String: CGFloat].self, forKey: CodingKeys.pivot))!
    }
}

struct TexturePackerSpriteArrayCatalog: Decodable {
    let frames: [SpriteFrame]
}

extension CGPoint {
    init?(_ dictionary: [String: CGFloat]) {
        self = CGPoint(dictionary["x"]!, dictionary["y"]!)
    }
}

extension CGSize {
    init?(_ dictionary: [String: CGFloat]) {
        self = CGSize(dictionary["w"]!, dictionary["h"]!)
    }
}

extension CGRect {
    init?(_ dictionary: [String: CGFloat]) {
        self = CGRect(x: dictionary["x"]!, y: dictionary["y"]!, width: dictionary["w"]!, height: dictionary["h"]!)
    }
}

// {
//    "filename": "acacia_door_bottom.png",
//    "frame": {"x":1596,"y":0,"w":16,"h":16},
//    "rotated": false,
//    "trimmed": false,
//    "spriteSourceSize": {"x":0,"y":0,"w":16,"h":16},
//    "sourceSize": {"w":16,"h":16},
//    "pivot": {"x":0.5,"y":0.5}
// },

extension CGRect {
    func flipped(within size: CGSize) -> CGRect {
        CGRect(x: x, y: size.height - y - height, width: width, height: height)
    }
}
