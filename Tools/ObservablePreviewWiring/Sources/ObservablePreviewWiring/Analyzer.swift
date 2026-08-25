import Foundation
import SwiftParser
import SwiftSyntax

/// Finds Optional state on `@Observable` models whose only non-nil writers are
/// preview fixtures.
///
/// The rule is deliberately narrow. It does not try to prove that no runtime
/// writer exists - that needs data flow the compiler alone can see, and the
/// broad "nothing writes this" version reports every property that is only ever
/// set through injected app state. What it reports is a much smaller,
/// syntactically decidable claim: *previews assign this a value and shipping
/// code never does*. That is the shape #64 describes, and a property has to be
/// rendered somewhere for a preview to bother setting it.
///
/// Two consequences follow, both intentional:
/// - Receivers are matched by property name, not by resolved type. A write is
///   attributed to the declaration whenever the name is unique across all
///   `@Observable` models; ambiguous names are skipped entirely. Unknown
///   receivers therefore count *for* reachability, never against it, so a
///   `someModel.foo = x` the analyzer cannot type-check silences the finding
///   rather than causing a false positive.
/// - A computed property is aliased to its backing store, so writing the
///   storage directly counts - except from inside the property's own accessors,
///   where `storage = newValue` is plumbing rather than reachability.
public enum Analyzer {
    public static func analyze(_ files: [SourceFile]) -> [Finding] {
        var declarations: [PropertyDeclaration] = []
        var storedByModel: [String: [String: StoredProperty]] = [:]
        var writes: [Write] = []
        var contexts: [String: FileContext] = [:]

        for file in files {
            let tree = Parser.parse(source: file.text)
            let converter = SourceLocationConverter(fileName: file.path, tree: tree)

            // A model declared inside a preview fixture ships nothing, so its
            // state cannot be under-wired.
            if !file.isPreviewOnly {
                let collector = DeclarationCollector(path: file.path, converter: converter)
                collector.walk(tree)
                declarations += collector.declarations
                for (model, stored) in collector.storedByModel {
                    storedByModel[model, default: [:]].merge(stored) { current, _ in current }
                }
            }

            let context = FileContextCollector()
            context.walk(tree)
            contexts[file.path] = context.context

            let collector = WriteCollector(
                path: file.path,
                converter: converter,
                isPreviewOnly: file.isPreviewOnly,
            )
            collector.walk(tree)
            writes += collector.writes
        }

        let ambiguous = ambiguousNames(declarations, storedByModel)
        var findings: [Finding] = []
        for declaration in declarations {
            if let finding = evaluate(
                declaration,
                writes: writes,
                ambiguous: ambiguous,
                storedByModel: storedByModel,
                contexts: contexts,
            ) {
                findings.append(finding)
            }
        }
        return findings.sorted { ($0.path, $0.line) < ($1.path, $1.line) }
    }

    // MARK: - Decision

    private static func evaluate(
        _ declaration: PropertyDeclaration,
        writes: [Write],
        ambiguous: Set<String>,
        storedByModel: [String: [String: StoredProperty]],
        contexts: [String: FileContext],
    ) -> Finding? {
        func finding(_ kind: Finding.Kind, previewWriters: [String] = []) -> Finding {
            Finding(
                path: declaration.path,
                line: declaration.line,
                model: declaration.model,
                property: declaration.name,
                kind: kind,
                previewWriters: previewWriters,
            )
        }

        switch declaration.exemption {
        case .empty: return finding(.emptyExemptionReason)
        case .reasoned: return nil
        case nil: break
        }

        // A non-nil default means the state occurs the moment the model exists.
        if declaration.hasNonNilDefault { return nil }
        if ambiguous.contains(declaration.name) { return nil }

        var names: Set<String> = [declaration.name]
        if let backing = declaration.backingName {
            // Only a real stored property on the same model is an alias; a
            // getter returning something else is not storage this rule can
            // reason about.
            guard let storage = storedByModel[declaration.model]?[backing] else { return nil }
            guard !ambiguous.contains(backing) else { return nil }
            // A default on the storage is a default on the property it backs:
            // the state occurs the moment the model exists, so previews are not
            // the only thing producing it.
            if storage.holdsAValueFromInit { return nil }
            names.insert(backing)
        }

        var previewWriters: [String] = []
        for write in writes where names.contains(write.name) && !write.isNil {
            if write.path == declaration.path, declaration.accessorRange?.contains(write.offset) == true {
                continue
            }
            guard write.isPreviewOnly else {
                return nil // a shipping writer exists; the state is reachable
            }
            // A shipping write may be attributed loosely - the worst it does is
            // silence a finding. A *preview* write is what produces one, so it
            // has to actually belong to this model.
            guard contexts[write.path]?.attributes(write, to: declaration.model) == true else { continue }
            previewWriters.append("\(write.path):\(write.line)")
        }

        guard !previewWriters.isEmpty else { return nil }
        return finding(.previewOnlyWiring, previewWriters: previewWriters)
    }

    /// A name declared by more than one model makes every write to it a guess.
    private static func ambiguousNames(
        _ declarations: [PropertyDeclaration],
        _ storedByModel: [String: [String: StoredProperty]],
    ) -> Set<String> {
        var models: [String: Set<String>] = [:]
        for declaration in declarations {
            models[declaration.name, default: []].insert(declaration.model)
        }
        for (model, stored) in storedByModel {
            for name in stored.keys {
                models[name, default: []].insert(model)
            }
        }
        return Set(models.filter { $0.value.count > 1 }.keys)
    }
}

// MARK: - Collected shapes

struct PropertyDeclaration {
    enum Exemption { case reasoned, empty }

    let model: String
    let path: String
    let line: Int
    let name: String
    let hasNonNilDefault: Bool
    /// Stored property this computed property reads through, when the getter is
    /// a plain passthrough.
    let backingName: String?
    /// UTF-8 offsets of the accessor block, so the property's own setter does
    /// not count as a writer to its storage.
    let accessorRange: Range<Int>?
    let exemption: Exemption?
}

/// A stored property, tracked so a computed property aliasing it can see
/// whether the storage already holds a value.
struct StoredProperty {
    let isOptional: Bool
    let hasNonNilDefault: Bool

    /// Non-Optional storage always holds a value; Optional storage does only
    /// when it is initialized to something other than `nil`.
    var holdsAValueFromInit: Bool { !isOptional || hasNonNilDefault }
}

struct Write {
    let name: String
    let path: String
    let line: Int
    let offset: Int
    let isNil: Bool
    let isPreviewOnly: Bool
    /// Identifier the write went through (`model` in `model.value = x`), or nil
    /// for an unqualified `value = x`.
    let baseIdentifier: String?
}

/// What one file knows about its own identifiers, used to decide whether a
/// preview write plausibly targets a given model.
struct FileContext {
    /// `model` → `ReviewModel`, from type annotations, constructor calls, static
    /// factory calls, and parameter types.
    var typeOfIdentifier: [String: String] = [:]
    /// Every identifier token in the file.
    var mentions: Set<String> = []

    func attributes(_ write: Write, to model: String) -> Bool {
        // A file that never names the model is not writing to it.
        guard mentions.contains(model) else { return false }
        // An unqualified `value = x` is only reachable from inside the model's
        // own scope, so it needs no receiver.
        guard let base = write.baseIdentifier else { return true }
        // A receiver has to actually resolve to this model. `SeededRandom.state`
        // and `random.value` resolve away from it; a base that resolves to
        // nothing is unknown, and unknown never produces a finding - the whole
        // rule leans toward silence rather than toward false lint failures.
        if let resolved = typeOfIdentifier[base] { return resolved == model }
        return base == model
    }
}

// MARK: - Declarations

final class DeclarationCollector: SyntaxVisitor {
    private let path: String
    private let converter: SourceLocationConverter
    private(set) var declarations: [PropertyDeclaration] = []
    private(set) var storedByModel: [String: [String: StoredProperty]] = [:]

    init(path: String, converter: SourceLocationConverter) {
        self.path = path
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.attributes.contains(where: \.isObservable) else { return .visitChildren }
        let model = node.name.text

        for member in node.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                  variable.bindingSpecifier.tokenKind == .keyword(.var),
                  !variable.modifiers.isTypeLevel
            else { continue }

            for binding in variable.bindings {
                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
                let name = pattern.identifier.text
                let accessors = binding.accessorBlock
                let isComputed = accessors?.isComputed ?? false
                let isOptional = binding.typeAnnotation?.type.isOptional == true
                let hasNonNilDefault = binding.initializer.map { !$0.value.isNilLiteral } ?? false

                if !isComputed {
                    storedByModel[model, default: [:]][name] = StoredProperty(
                        isOptional: isOptional,
                        hasNonNilDefault: hasNonNilDefault,
                    )
                }
                guard isOptional else { continue }

                declarations.append(
                    PropertyDeclaration(
                        model: model,
                        path: path,
                        line: converter.location(for: variable.positionAfterSkippingLeadingTrivia).line,
                        name: name,
                        hasNonNilDefault: hasNonNilDefault,
                        backingName: isComputed ? accessors?.passthroughStorageName : nil,
                        accessorRange: accessors.map {
                            $0.position.utf8Offset ..< $0.endPosition.utf8Offset
                        },
                        exemption: variable.exemption,
                    ),
                )
            }
        }
        return .visitChildren
    }
}

// MARK: - File context

final class FileContextCollector: SyntaxVisitor {
    private(set) var context = FileContext()
    /// An identifier bound to two different types in one file resolves to
    /// neither, so it stops narrowing anything.
    private var conflicting: Set<String> = []

    init() { super.init(viewMode: .sourceAccurate) }

    override func visit(_ node: TokenSyntax) -> SyntaxVisitorContinueKind {
        if case .identifier = node.tokenKind { context.mentions.insert(node.text) }
        return .skipChildren
    }

    override func visit(_ node: PatternBindingSyntax) -> SyntaxVisitorContinueKind {
        guard let name = node.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
            return .visitChildren
        }
        if let annotated = node.typeAnnotation?.type.as(IdentifierTypeSyntax.self)?.name.text {
            bind(name, to: annotated)
        } else if let inferred = node.initializer?.value.constructedTypeName {
            bind(name, to: inferred)
        }
        return .visitChildren
    }

    override func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
        let name = (node.secondName ?? node.firstName).text
        if let type = node.type.as(IdentifierTypeSyntax.self)?.name.text {
            bind(name, to: type)
        }
        return .visitChildren
    }

    private func bind(_ name: String, to type: String) {
        guard !conflicting.contains(name) else { return }
        if let existing = context.typeOfIdentifier[name], existing != type {
            conflicting.insert(name)
            context.typeOfIdentifier[name] = nil
            return
        }
        context.typeOfIdentifier[name] = type
    }
}

// MARK: - Writes

final class WriteCollector: SyntaxVisitor {
    private let path: String
    private let converter: SourceLocationConverter
    private let isPreviewOnly: Bool
    private(set) var writes: [Write] = []
    /// Nesting depth inside `#Preview { … }`. `check-previews.sh` requires one
    /// in every view file, so most preview code in this repo lives in shipping
    /// sources - a write in there is a preview writer, not a shipping one.
    private var previewDepth = 0

    init(path: String, converter: SourceLocationConverter, isPreviewOnly: Bool) {
        self.path = path
        self.converter = converter
        self.isPreviewOnly = isPreviewOnly
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.macroName.text == "Preview" { previewDepth += 1 }
        return .visitChildren
    }

    override func visitPost(_ node: MacroExpansionDeclSyntax) {
        if node.macroName.text == "Preview" { previewDepth -= 1 }
    }

    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        if node.macroName.text == "Preview" { previewDepth += 1 }
        return .visitChildren
    }

    override func visitPost(_ node: MacroExpansionExprSyntax) {
        if node.macroName.text == "Preview" { previewDepth -= 1 }
    }

    /// `Parser.parse` leaves operators unfolded, so a plain `a.b = c` arrives as
    /// a `SequenceExprSyntax` of [lhs, `=`, rhs…] rather than an
    /// `InfixOperatorExprSyntax`. Folding it would need the operator table and
    /// buys nothing here - reading the sequence directly is enough.
    override func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
        let elements = Array(node.elements)
        guard let index = elements.firstIndex(where: { $0.is(AssignmentExprSyntax.self) }),
              index == 1,
              let name = elements[0].assignedPropertyName
        else { return .visitChildren }

        // Anything more complex than a single trailing expression (a ternary
        // arrives as several unfolded elements) counts as potentially non-nil.
        let remainder = elements[(index + 1)...]
        let isNil = remainder.count == 1 && remainder.first?.isNilLiteral == true

        record(name: name, base: elements[0].receiverIdentifier, at: node, isNil: isNil)
        return .visitChildren
    }

    /// Already-folded trees (a caller that ran the operator table first) still
    /// have to be readable, so the folded shape is handled too.
    override func visit(_ node: InfixOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        guard node.operator.is(AssignmentExprSyntax.self),
              let name = node.leftOperand.assignedPropertyName
        else { return .visitChildren }

        record(
            name: name,
            base: node.leftOperand.receiverIdentifier,
            at: node,
            isNil: node.rightOperand.isNilLiteral,
        )
        return .visitChildren
    }

    private func record(name: String, base: String?, at node: some SyntaxProtocol, isNil: Bool) {
        writes.append(
            Write(
                name: name,
                path: path,
                line: converter.location(for: node.positionAfterSkippingLeadingTrivia).line,
                offset: node.position.utf8Offset,
                isNil: isNil,
                isPreviewOnly: isPreviewOnly || previewDepth > 0,
                baseIdentifier: base,
            ),
        )
    }
}

// MARK: - Syntax helpers

extension AttributeListSyntax.Element {
    var isObservable: Bool {
        guard case let .attribute(attribute) = self else { return false }
        return attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "Observable"
    }
}

extension DeclModifierListSyntax {
    var isTypeLevel: Bool {
        contains {
            $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class)
        }
    }
}

extension TypeSyntax {
    /// `T?`, `T!`, and the spelled-out `Optional<T>` all declare Optional state.
    var isOptional: Bool {
        if let attributed = self.as(AttributedTypeSyntax.self) { return attributed.baseType.isOptional }
        if `is`(OptionalTypeSyntax.self) || `is`(ImplicitlyUnwrappedOptionalTypeSyntax.self) { return true }
        guard let identifier = self.as(IdentifierTypeSyntax.self) else { return false }
        return identifier.name.text == "Optional" && identifier.genericArgumentClause != nil
    }
}

extension AccessorBlockSyntax {
    /// `willSet`/`didSet` are observers on *stored* state; anything else means
    /// the property has no storage of its own.
    var isComputed: Bool {
        switch accessors {
        case .getter: true
        case let .accessors(list):
            list.contains {
                $0.accessorSpecifier.tokenKind != .keyword(.willSet)
                    && $0.accessorSpecifier.tokenKind != .keyword(.didSet)
            }
        }
    }

    /// The stored property a passthrough getter reads, if the getter is exactly
    /// `{ storage }` or `{ return storage }` (optionally via `self`).
    var passthroughStorageName: String? {
        let body: CodeBlockItemListSyntax
        switch accessors {
        case let .getter(items):
            body = items
        case let .accessors(list):
            guard let getter = list.first(where: { $0.accessorSpecifier.tokenKind == .keyword(.get) }),
                  let block = getter.body
            else { return nil }
            body = block.statements
        }

        guard body.count == 1, let expression = body.first?.item.as(ExprSyntax.self)
            ?? body.first?.item.as(ReturnStmtSyntax.self)?.expression
        else { return nil }

        if let member = expression.as(MemberAccessExprSyntax.self) {
            guard member.base?.as(DeclReferenceExprSyntax.self)?.baseName.tokenKind == .keyword(.self)
            else { return nil }
            return member.declName.baseName.text
        }
        return expression.as(DeclReferenceExprSyntax.self)?.baseName.text
    }
}

extension ExprSyntax {
    /// The member being assigned, for `name = …` and `anything.name = …`.
    /// Subscripts, tuple destructuring, and other shapes report nothing rather
    /// than a guess.
    var assignedPropertyName: String? {
        if let member = self.as(MemberAccessExprSyntax.self) { return member.declName.baseName.text }
        if let reference = self.as(DeclReferenceExprSyntax.self) { return reference.baseName.text }
        return nil
    }

    /// The identifier a write goes through: `model` in `model.value = x`, and
    /// `a` in `a.b.value = x`. Nil for an unqualified `value = x` and for bases
    /// that are not plain identifiers.
    var receiverIdentifier: String? {
        guard var base = self.as(MemberAccessExprSyntax.self)?.base else { return nil }
        while let member = base.as(MemberAccessExprSyntax.self) {
            guard let inner = member.base else { return nil }
            base = inner
        }
        return base.as(DeclReferenceExprSyntax.self)?.baseName.text
    }

    /// The type name a binding is initialized from - `Foo()` and the
    /// `Foo.make()` static-factory shape both name `Foo`.
    var constructedTypeName: String? {
        guard let call = self.as(FunctionCallExprSyntax.self) else { return nil }
        if let reference = call.calledExpression.as(DeclReferenceExprSyntax.self) {
            let name = reference.baseName.text
            return name.first?.isUppercase == true ? name : nil
        }
        guard let member = call.calledExpression.as(MemberAccessExprSyntax.self),
              let name = member.base?.as(DeclReferenceExprSyntax.self)?.baseName.text,
              name.first?.isUppercase == true
        else { return nil }
        return name
    }

    /// Only a literal `nil` fails to make the state occur. A ternary, an
    /// Optional variable, or a failable call all count as potentially non-nil -
    /// the conservative direction, since guessing "nil" would invent findings.
    var isNilLiteral: Bool {
        if `is`(NilLiteralExprSyntax.self) { return true }
        // The spelled-out nils: `.none`, `Optional.none`, `Optional<T>.none`.
        if let member = self.as(MemberAccessExprSyntax.self), member.declName.baseName.text == "none" {
            guard let base = member.base else { return true }
            if base.as(DeclReferenceExprSyntax.self)?.baseName.text == "Optional" { return true }
            return base.as(GenericSpecializationExprSyntax.self)?
                .expression.as(DeclReferenceExprSyntax.self)?.baseName.text == "Optional"
        }
        if let tuple = self.as(TupleExprSyntax.self), tuple.elements.count == 1,
           let only = tuple.elements.first, only.label == nil
        {
            return only.expression.isNilLiteral
        }
        if let cast = self.as(AsExprSyntax.self) { return cast.expression.isNilLiteral }
        return false
    }
}

extension VariableDeclSyntax {
    private static let marker = "observable-preview-wiring-exempt:"

    var exemption: PropertyDeclaration.Exemption? {
        let comments = (leadingTrivia + trailingTrivia).compactMap { piece -> String? in
            switch piece {
            case let .lineComment(text), let .blockComment(text),
                 let .docLineComment(text), let .docBlockComment(text):
                text
            default:
                nil
            }
        }
        for comment in comments {
            guard let range = comment.range(of: Self.marker) else { continue }
            let reason = comment[range.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "*/"))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return reason.isEmpty ? .empty : .reasoned
        }
        return nil
    }
}
