import Foundation

public struct TeamsApiConfiguration: Equatable, Sendable {
    public var host: String
    public var port: Int
    public var protocolVersion: String
    public var manufacturer: String
    public var device: String
    public var app: String
    public var appVersion: String

    public init(
        host: String = "localhost",
        port: Int = 8124,
        protocolVersion: String = "2.0.0",
        manufacturer: String = "Local",
        device: String = "Mac",
        app: String = "TeamsMuteOverlay",
        appVersion: String = "0.1.0"
    ) {
        self.host = host
        self.port = port
        self.protocolVersion = protocolVersion
        self.manufacturer = manufacturer
        self.device = device
        self.app = app
        self.appVersion = appVersion
    }

    public func socketURL(token: String) -> URL {
        var components = URLComponents()
        components.scheme = "ws"
        components.host = host
        components.port = port
        components.queryItems = [
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "protocol-version", value: protocolVersion),
            URLQueryItem(name: "manufacturer", value: manufacturer),
            URLQueryItem(name: "device", value: device),
            URLQueryItem(name: "app", value: app),
            URLQueryItem(name: "app-version", value: appVersion)
        ]

        return components.url!
    }
}
