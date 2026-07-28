import Foundation

struct ZixyCraftKnowledgeResponder {

    private enum Intent {
        case gettingStarted
        case tools
        case materials
        case troubleshooting
        case timing
        case safety
        case general
    }

    private struct Topic {
        let name: String
        let keywords: [String]
        let gettingStarted: String
        let tools: String
        let materials: String
        let troubleshooting: String
        let timing: String
        let safety: String

        func reply(for intent: Intent) -> String {
            switch intent {
            case .gettingStarted:
                return gettingStarted
            case .tools:
                return tools
            case .materials:
                return materials
            case .troubleshooting:
                return troubleshooting
            case .timing:
                return timing
            case .safety:
                return safety
            case .general:
                return "\(gettingStarted) \(materials)"
            }
        }
    }

    private let topics: [Topic] = [
        Topic(
            name: "leathercraft",
            keywords: ["leather", "leathercraft", "wallet", "belt", "hide"],
            gettingStarted: "Make a paper template first, transfer it to the leather, cut with several light passes, then bevel and burnish the edges before saddle stitching.",
            tools: "For a small leather project, start with a sharp craft knife, metal ruler, stitching chisels, two harness needles, waxed thread, an edge beveler, and a burnisher.",
            materials: "Vegetable-tanned leather is a good choice for structured wallets and belts. Use a thinner, softer leather for pockets, and test dye and finish on an offcut.",
            troubleshooting: "Uneven leather edges usually come from cutting through in one heavy pass. Re-trim with a sharp blade, sand progressively, dampen the edge lightly, and burnish again.",
            timing: "Allow water-based dye to dry fully before finishing, and let contact cement become tacky before joining pieces. A simple wallet is usually a multi-hour project.",
            safety: "Cut away from your hands on a stable mat, keep blades sharp, ventilate adhesives and dyes, and wear eye protection while punching holes."
        ),
        Topic(
            name: "resin casting",
            keywords: ["resin", "epoxy", "mold", "casting", "bubble"],
            gettingStarted: "Seal porous inclusions, level the mold, measure both resin parts exactly, mix slowly while scraping the cup, then pour in a thin stream.",
            tools: "Use graduated mixing cups, accurate scales if the product is weight-based, silicone stirrers, nitrile gloves, a level, and a dust cover.",
            materials: "Choose casting resin for deep pours and coating resin for thin surfaces. Confirm the mix ratio, maximum pour depth, and compatible pigments on the product label.",
            troubleshooting: "Cloudiness or softness usually points to an incorrect ratio, incomplete mixing, moisture, or low temperature. Small surface bubbles can be removed carefully within the resin's working time.",
            timing: "Use the exact working, demold, and full-cure times on the resin data sheet. Temperature strongly affects curing, so keep the workspace within the recommended range.",
            safety: "Wear nitrile gloves and eye protection, provide strong ventilation, avoid skin contact, and never use an open flame near resin or solvents."
        ),
        Topic(
            name: "woodworking",
            keywords: ["wood", "woodwork", "carve", "carving", "joinery", "timber"],
            gettingStarted: "Mark the grain direction, square the stock, practice the cut on an offcut, and remove small amounts of material before sanding from coarse to fine grit.",
            tools: "A reliable starter kit includes a square, marking knife, clamps, sharp saw, block plane, chisels, sanding block, and eye and hearing protection.",
            materials: "Straight-grained pine or poplar is forgiving for practice. Choose dry, stable stock and inspect it for twist, checks, and knots before laying out parts.",
            troubleshooting: "Tear-out happens when a tool cuts against the grain or is dull. Reverse the cutting direction, sharpen the edge, take a lighter pass, and support fragile fibers.",
            timing: "Dry-fit before glue-up, follow the adhesive clamp time, and wait for the stated cure time before stressing or finishing the joint.",
            safety: "Clamp the work securely, keep hands out of cutting paths, use dust collection, and wear eye, hearing, and respiratory protection when appropriate."
        ),
        Topic(
            name: "pottery",
            keywords: ["clay", "pottery", "ceramic", "sculpt", "kiln"],
            gettingStarted: "Wedge the clay, keep the wall thickness consistent, join pieces with score-and-slip, compress seams, and dry the work slowly under loose plastic.",
            tools: "Begin with a wire cutter, wooden knife, rib, needle tool, sponge, loop tool, rolling guides, and a smooth non-porous work surface.",
            materials: "Use a clay body and glaze rated for the same firing range. For hand-building, choose a clay with enough grog to hold its shape.",
            troubleshooting: "Cracks often come from uneven thickness, weak joins, or drying too quickly. Compress the clay well, reinforce joins, and slow the drying process.",
            timing: "Wait until the piece is bone dry before bisque firing. Firing and cooling schedules depend on the clay, glaze, kiln, and target cone.",
            safety: "Avoid breathing dry clay or glaze dust, clean with wet methods, verify glaze ingredients, and leave kiln operation to a properly ventilated setup."
        ),
        Topic(
            name: "knitting or crochet",
            keywords: ["knit", "knitting", "crochet", "yarn", "stitch", "needle"],
            gettingStarted: "Make a gauge swatch, count stitches at the end of each row, mark repeats, and keep the working tension relaxed and consistent.",
            tools: "Use the hook or needle size recommended for the yarn, plus stitch markers, a tapestry needle, small scissors, and a row counter.",
            materials: "Choose smooth, light-colored medium-weight yarn for learning because the stitches are easy to see. Check washing instructions before committing to a project.",
            troubleshooting: "Changing width usually means stitches are being added or dropped at row ends. Count every row and place markers in the first and last stitch.",
            timing: "Project time depends on gauge, size, and stitch complexity. Make a timed swatch and use its stitch count to estimate the full piece.",
            safety: "Take regular hand and shoulder breaks, use comfortable tools, and keep needles, hooks, and loose yarn away from young children and pets."
        ),
        Topic(
            name: "jewelry making",
            keywords: ["jewelry", "jewellery", "bead", "wire", "ring", "necklace"],
            gettingStarted: "Sketch the finished size, make one test connection, cut material with a small allowance, and check every closure under gentle tension.",
            tools: "Use flush cutters, round-nose pliers, chain-nose pliers, a file, measuring tools, and the correct mandrel for rings or loops.",
            materials: "Match wire hardness and thickness to the design. Softer wire is easier to form, while half-hard wire holds clasps and structural shapes better.",
            troubleshooting: "Distorted loops usually result from gripping too far from the plier tip or repeatedly bending the same area. Form each bend deliberately and work-harden only when needed.",
            timing: "Make a sample component first and time it, then multiply by the number of repeated links or beads and add time for assembly and finishing.",
            safety: "Wear eye protection while cutting wire, smooth every cut end, keep small parts away from children, and check metal sensitivities before wear."
        ),
        Topic(
            name: "candle making",
            keywords: ["candle", "wax", "wick", "fragrance", "scent"],
            gettingStarted: "Match the wick to the container and wax, secure it in the center, melt the wax gently, add fragrance at the recommended temperature, and pour steadily.",
            tools: "Use a dedicated pouring pitcher, thermometer, accurate scale, wick centering tool, heat-safe containers, and a double-boiler setup.",
            materials: "Choose wax, wick, fragrance load, and container as a tested system. Changing any one of them can change the melt pool and burn behavior.",
            troubleshooting: "Tunneling usually indicates an undersized wick or an initial burn that was too short. Test one controlled change at a time and record the result.",
            timing: "Let the candle cool undisturbed and follow the wax supplier's cure recommendation before conducting a full burn test.",
            safety: "Never leave melting wax or a burning candle unattended. Use heat-safe containers, control temperatures, and keep water away from hot wax."
        ),
        Topic(
            name: "paper craft",
            keywords: ["paper", "origami", "card", "bookbind", "bookbinding"],
            gettingStarted: "Identify the paper grain, make a scoring or folding guide, and use several light knife passes against a metal ruler for clean edges.",
            tools: "A cutting mat, metal ruler, sharp craft knife, bone folder, awl, clips, and pH-neutral adhesive cover most paper and bookbinding basics.",
            materials: "Use long-grain paper parallel to a book spine or major fold. Heavier stock should be scored before folding to prevent surface cracking.",
            troubleshooting: "Cracked folds usually mean the stock was folded against the grain or was not scored deeply enough. Test grain direction and score a sample first.",
            timing: "Allow glued sections to dry under light, even pressure. Build drying time into each stage so moisture does not warp later layers.",
            safety: "Use a metal ruler with a non-slip back, keep fingers behind its guard, cut away from your body, and cap blades immediately after use."
        ),
        Topic(
            name: "painting",
            keywords: ["paint", "painting", "acrylic", "watercolor", "watercolour", "color"],
            gettingStarted: "Prepare the surface, make a small value and color study, work from large shapes to details, and build color in controlled layers.",
            tools: "Start with a limited set of reliable brushes, a palette, two water containers, absorbent cloth, suitable paper or panel, and good neutral lighting.",
            materials: "Use a surface designed for the chosen paint. Heavy watercolor paper controls buckling, while acrylic works best on a clean, properly primed surface.",
            troubleshooting: "Muddy color comes from overmixing or disturbing a layer before it is ready. Use fewer pigments, clean the brush, and let layers dry when the technique requires it.",
            timing: "Thin acrylic layers dry quickly, while watercolor timing depends on paper moisture. Test the surface with the back of a finger before adding another controlled layer.",
            safety: "Do not eat or drink near materials, check pigment labels, ventilate mediums and varnishes, and dispose of solvent or paint waste responsibly."
        )
    ]

    func reply(to message: String) -> String {
        let normalized = normalizedText(message)
        guard !normalized.isEmpty else {
            return "Tell me what you would like to make or fix."
        }

        if containsAny(
            ["hello", "hey", "hi", "good morning", "good evening"],
            in: normalized
        ) {
            return "Hi! Tell me what you want to make, repair, or improve, and include the material you are using."
        }

        if containsAny(["thank", "thanks"], in: normalized) {
            return "You're welcome. If you share your material, dimensions, and current step, I can refine the advice."
        }

        if containsAny(
            ["what can you do", "help me", "your capabilities"],
            in: normalized
        ) {
            return "I can help plan craft projects, choose materials and tools, troubleshoot problems, estimate process time, and explain safer working steps."
        }

        let intent = detectIntent(in: normalized)
        if let topic = bestTopic(for: normalized) {
            return "For \(topic.name): \(topic.reply(for: intent))"
        }

        return contextualFallback(for: message, intent: intent)
    }

    private func bestTopic(for message: String) -> Topic? {
        topics
            .map { topic in
                let score = topic.keywords.reduce(into: 0) { result, keyword in
                    if message.range(
                        of: "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b",
                        options: .regularExpression
                    ) != nil {
                        result += 1
                    }
                }
                return (topic: topic, score: score)
            }
            .filter { $0.score > 0 }
            .max { $0.score < $1.score }?
            .topic
    }

    private func detectIntent(in message: String) -> Intent {
        if containsAny(
            ["why", "problem", "wrong", "fix", "repair", "crack", "uneven", "failed", "not working"],
            in: message
        ) {
            return .troubleshooting
        }
        if containsAny(
            ["safe", "safety", "danger", "toxic", "protect", "ventilation"],
            in: message
        ) {
            return .safety
        }
        if containsAny(
            ["how long", "time", "dry", "cure", "wait", "finish"],
            in: message
        ) {
            return .timing
        }
        if containsAny(
            ["tool", "equipment", "need to buy", "supplies"],
            in: message
        ) {
            return .tools
        }
        if containsAny(
            ["material", "which", "best", "choose", "type of"],
            in: message
        ) {
            return .materials
        }
        if containsAny(
            ["how", "start", "begin", "make", "steps", "tutorial"],
            in: message
        ) {
            return .gettingStarted
        }
        return .general
    }

    private func contextualFallback(
        for originalMessage: String,
        intent: Intent
    ) -> String {
        let summary = originalMessage
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(80)
        let detailRequest: String

        switch intent {
        case .troubleshooting:
            detailRequest = "Tell me the material, the step where it failed, and what changed just before the problem appeared."
        case .tools:
            detailRequest = "Tell me the craft and project size so I can suggest only the essential tools."
        case .materials:
            detailRequest = "Tell me the item, desired finish, size, and budget so I can compare suitable materials."
        case .timing:
            detailRequest = "Tell me the material, product brand if relevant, temperature, and current stage for a safer estimate."
        case .safety:
            detailRequest = "Share the material, product label, and process. Stop immediately if there is heat, smoke, severe irritation, or an uncontrolled reaction."
        case .gettingStarted, .general:
            detailRequest = "Tell me the material, desired size, tools you already have, and your experience level so I can provide precise steps."
        }

        return "I understand that you are asking about “\(summary)”. \(detailRequest)"
    }

    private func normalizedText(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsAny(
        _ phrases: [String],
        in message: String
    ) -> Bool {
        phrases.contains { phrase in
            let escapedPhrase = NSRegularExpression.escapedPattern(for: phrase)
            return message.range(
                of: "\\b\(escapedPhrase)\\b",
                options: .regularExpression
            ) != nil
        }
    }
}
