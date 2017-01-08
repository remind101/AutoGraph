import Alamofire
import Crust
import Foundation
import JSONValueRX

public protocol Request {
    associatedtype Mapping: Crust.Mapping
    
    var query: Operation { get }
    var mapping: Mapping { get }
}

public typealias RequestCompletion<M: Crust.Mapping> = (_ result: Result<M.MappedObject>) -> ()

public class AutoGraph {
    public var baseUrl: String {
        get {
            return self.dispatcher.url
        }
        set {
            self.dispatcher.url = newValue
            self.authHandler = AuthHandler(baseUrl: newValue,
                                           accessToken: self.authHandler.accessToken,
                                           refreshToken: self.authHandler.refreshToken)
        }
    }
    
    public var authHandler: AuthHandler {
        didSet {
            self.authHandler.delegate = self
        }
    }
    
    let dispatcher: Dispatcher
    
    init(baseUrl: String = "http://localhost:8080/graphql") {
        self.dispatcher = Dispatcher(url: baseUrl)
        self.authHandler = AuthHandler(baseUrl: baseUrl, accessToken: nil, refreshToken: nil)
        self.dispatcher.delegate = self
        self.authHandler.delegate = self
    }
    
    public func send<T: Request>(_ request: T, completion: @escaping RequestCompletion<T.Mapping>) {
        self.dispatcher.send(request: request, completion: completion)
    }
    
    func handle<Mapping: Crust.Mapping>(response: DataResponse<Any>, mapping: Mapping, completion: @escaping RequestCompletion<Mapping>) {
        
        do {
            
            let value: Any = try {
                switch response.result {
                case .success(let value):
                    return value
                    
                case .failure(let e):
                    
                    let gqlError: AutoGraphError? = {
                        guard let value = Alamofire.Request.serializeResponseJSON(
                            options: .allowFragments,
                            response: response.response,
                            data: response.data, error: nil).value,
                            let json = try? JSONValue(object: value) else {
                                
                            return nil
                        }
                        
                        return AutoGraphError(graphQLResponseJSON: json)
                    }()
                    
                    throw AutoGraphError.network(error: e, underlying: gqlError)
                }
            }()
            
            let json = try JSONValue(object: value)
            
            if let queryError = AutoGraphError(graphQLResponseJSON: json) {
                throw queryError
            }
            
            do {
                let mapper = CRMapper<Mapping>()
                let result = try mapper.mapFromJSONToNewObject(json, mapping: mapping)
                completion(.success(result))
            }
            catch let e {
                throw AutoGraphError.mapping(error: e)
            }
        }
        catch let e {
            completion(.failure(e))
        }
    }
    
    public func cancelAll() {
        self.dispatcher.cancelAll()
        Alamofire.SessionManager.default.session.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
            dataTasks.forEach { $0.cancel() }
            uploadTasks.forEach { $0.cancel() }
            downloadTasks.forEach { $0.cancel() }
        }
    }
}

extension AutoGraph: AuthHandlerDelegate {
    func authHandlerBeganReauthentication(_ authHandler: AuthHandler) {
        self.dispatcher.paused = true
    }
    
    func authHandler(_ authHandler: AuthHandler, reauthenticatedSuccessfully: Bool) {
        guard reauthenticatedSuccessfully else {
            self.cancelAll()
            return
        }
        
        self.dispatcher.paused = false
    }
}

extension AutoGraph: DispatcherDelegate {
    func dispatcherDidFinish<Mapping : Crust.Mapping>(response: DataResponse<Any>, mapping: Mapping, completion: @escaping (Result<Mapping.MappedObject>) -> ()) {
        self.handle(response: response, mapping: mapping, completion: completion)
    }
}
