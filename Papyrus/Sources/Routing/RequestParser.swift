import Foundation

public struct RequestParser {
    public var keyMapping: KeyMapping?
    private let request: RouterRequest

    public var requestQueryDecoder: URLEncodedFormDecoder {
        set { _requestQueryDecoder = newValue }
        get { _requestQueryDecoder.with(keyMapping: keyMapping) }
    }

    public var requestBodyDecoder: any HTTPBodyDecoder {
        set { _requestBodyDecoder = newValue }
        get { _requestBodyDecoder.with(keyMapping: keyMapping) }
    }

    public var responseBodyEncoder: any HTTPBodyEncoder {
        set { _responseBodyEncoder = newValue }
        get { _responseBodyEncoder.with(keyMapping: keyMapping) }
    }

    private var _requestQueryDecoder: URLEncodedFormDecoder
    private var _requestBodyDecoder: any HTTPBodyDecoder
    private var _responseBodyEncoder: any HTTPBodyEncoder

    public init(req: RouterRequest, provider: any CoderProvider) {
        self.request = req
        _requestQueryDecoder = provider.provideQueryDecoder()
        _requestBodyDecoder = provider.provideHttpBodyDecoder()
        _responseBodyEncoder = provider.provideHttpBodyEncoder()
    }

    // MARK: Parsing methods

    public func getQuery<D: Decodable>(_ type: D.Type) throws -> D {
        guard let queryString = request.url.query else {
            throw PapyrusError("request had no query `\(request.url)`")
        }

        return try requestQueryDecoder.decode(type, from: queryString)
    }

    public func getParameter<L: LosslessStringConvertible>(_ name: String, path: String) throws -> L {
        let templatePathComponents = path.components(separatedBy: "/")
        let requestPathComponents = request.url.pathComponents
        let parametersByName = [String: String](
            zip(templatePathComponents, requestPathComponents)
                .compactMap {
                    guard let parameter = $0.extractParameter else { return nil }
                    return (parameter, $1)
                },
            uniquingKeysWith: { a, _ in a }
        )

        guard let string = parametersByName[name] else {
            throw PapyrusError("parameter `\(name)` not found")
        }

        guard let value = L(string) else {
            throw PapyrusError("parameter `\(name)` was not convertible to `\(L.self)`")
        }

        return value
    }

    public func getHeader<L: LosslessStringConvertible>(_ name: String) throws -> L {
        guard let string = request.headers[name] else {
            throw PapyrusError("missing header `\(name)`")
        }

        guard let value = L(string) else {
            throw PapyrusError("header `\(name)` was not convertible to `\(L.self)`")
        }

        return value
    }

    public func getBody<D: Decodable>(_ type: D.Type) throws -> D {
        guard let body = request.body else {
            throw PapyrusError("expected request body")
        }

        return try requestBodyDecoder.decode(type, from: body)
    }
}

extension String {
    fileprivate var extractParameter: String? {
        if hasPrefix(":") {
            String(dropFirst())
        } else if hasPrefix("{") && hasSuffix("}") {
            String(dropFirst().dropLast())
        } else {
            nil
        }
    }
}
