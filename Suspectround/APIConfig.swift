import Alamofire

enum APIConfig {
    private static let host = "https://api.suspectround-hunt.site"
    private static let path = "/api/v1/users/register"

    static func apply() {
        AppConfiguration.configure(host: host, path: path)
    }
}
