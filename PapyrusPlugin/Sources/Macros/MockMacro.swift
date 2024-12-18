import SwiftSyntax
import SwiftSyntaxMacros

public struct MockMacro: PeerMacro {
    public static func expansion(
        of attribute: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try [
            API.parse(declaration)
                .mockImplementation(suffix: attribute.name)
                .declSyntax()
        ]
    }
}

extension API {
    fileprivate func mockImplementation(suffix: String) -> Declaration {
        Declaration("final class \(name)\(suffix): \(name)") {
            "private let notMockedError: any Error"
            "private let mocks: Papyrus.ResourceMutex<[String: Any]> = .init(resource: [:])"

            Declaration("init(notMockedError: any Error = PapyrusError(\"Not mocked\"))") {
                "self.notMockedError = notMockedError"
            }
            .access(access)

            for endpoint in endpoints {
                endpoint.mockFunction().access(access)
                endpoint.mockerFunction().access(access)
            }
        }
        .access(access)
    }
}

extension API.Endpoint {
    fileprivate func mockFunction() -> Declaration {
        Declaration("func \(name)\(functionSignature)") {
            Declaration("return try await mocks.withLock", "resource") {
                Declaration("guard let mocker = resource[\(name.inQuotes)] as? \(mockClosureType) else") {
                    "throw notMockedError"
                }

                let arguments = parameters.map(\.name).joined(separator: ", ")
                "return try await mocker(\(arguments))"
            }
        }
    }

    fileprivate func mockerFunction() -> Declaration {
        Declaration("func mock\(name.capitalizeFirst)(mock: @escaping \(mockClosureType))") {
            Declaration("mocks.withLock", "resource") {
                "resource[\(name.inQuotes)] = mock"
            }
        }
    }

    private var mockClosureType: String {
        let parameterTypes = parameters.map(\.type).joined(separator: ", ")
        let returnType = responseType ?? "Void"
        return "(\(parameterTypes)) async throws -> \(returnType)"
    }
}
