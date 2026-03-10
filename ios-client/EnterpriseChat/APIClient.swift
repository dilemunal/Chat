import Foundation

class APIClient {
    static let shared = APIClient()
    let baseURL = "http://localhost:9090/api/v1" // API Gateway
    let keycloakTokenURL = "http://localhost:8080/realms/chat-realm/protocol/openid-connect/token"
    
    var accessToken: String?
    
    func register(username: String, email: String, firstName: String, lastName: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/register") else { return }
        
        // Explicitly map parameters to keys to avoid any internal swap
        let requestBody: [String: Any] = [
            "username": username,
            "email": email,
            "firstName": firstName,
            "lastName": lastName,
            "password": password
        ]
        
        guard let uploadData = try? JSONSerialization.data(withJSONObject: requestBody) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = uploadData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { return completion(.failure(error)) }
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode >= 400 {
                let msg = String(data: data ?? Data(), encoding: .utf8) ?? "Sunucu hatası."
                return completion(.failure(NSError(domain: "Auth", code: httpResp.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])))
            }
            guard let data = data, let registered = try? JSONDecoder().decode(User.self, from: data) else {
                return completion(.failure(NSError(domain: "Auth", code: 500, userInfo: [NSLocalizedDescriptionKey: "Kayıt verisi işlenemedi."])))
            }
            completion(.success(registered))
        }.resume()
    }
    
    func login(username: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        guard let url = URL(string: keycloakTokenURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let encodedUser = username.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryValueAllowed) ?? ""
        let encodedPass = password.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryValueAllowed) ?? ""
        let bodyString = "client_id=ios-client&grant_type=password&username=\(encodedUser)&password=\(encodedPass)"
        request.httpBody = bodyString.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { return completion(.failure(error)) }
            
            guard let data = data else {
                return completion(.failure(NSError(domain: "Auth", code: 500, userInfo: [NSLocalizedDescriptionKey: "Sunucudan veri alınamadı."])))
            }
            
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode >= 400 {
                let errorDesc = json?["error_description"] as? String ?? json?["error"] as? String ?? "Bilinmeyen bir hata oluştu (Status: \(httpResp.statusCode))"
                return completion(.failure(NSError(domain: "Auth", code: httpResp.statusCode, userInfo: [NSLocalizedDescriptionKey: errorDesc])))
            }
            
            guard let token = json?["access_token"] as? String else {
                return completion(.failure(NSError(domain: "Auth", code: 500, userInfo: [NSLocalizedDescriptionKey: "Token response formatı hatalı."])))
            }
            
            self.accessToken = token
            UserDefaults.standard.set(token, forKey: "last_access_token")
            UserDefaults.standard.set(username, forKey: "last_username")
            
            self.fetchUserProfile(username: username, completion: completion)
        }.resume()
    }
    
    func fetchUserProfile(username: String, completion: @escaping (Result<User, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/\(username)") else { return }
        
        var request = URLRequest(url: url)
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { return completion(.failure(error)) }
            guard let data = data, let user = try? JSONDecoder().decode(User.self, from: data) else {
                return completion(.failure(NSError(domain: "Auth", code: 500, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı profili alınamadı."])))
            }
            completion(.success(user))
        }.resume()
    }
    
    func fetchAllUsers(completion: @escaping (Result<[User], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/users") else { return }
        
        var request = URLRequest(url: url)
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { return completion(.failure(error)) }
            guard let data = data, let users = try? JSONDecoder().decode([User].self, from: data) else {
                return completion(.failure(NSError(domain: "Auth", code: 500, userInfo: [NSLocalizedDescriptionKey: "Kullanıcı listesi alınamadı."])))
            }
            completion(.success(users))
        }.resume()
    }
    
    func fetchMessages(chatId: String, completion: @escaping ([ChatMessage]) -> Void) {
        guard let url = URL(string: "\(baseURL)/messages/\(chatId)") else { return completion([]) }
        var request = URLRequest(url: url)
        
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                do {
                    let messages = try JSONDecoder().decode([ChatMessage].self, from: data)
                    let sorted = messages.sorted { ($0.timestamp ?? 0) < ($1.timestamp ?? 0) }
                    completion(sorted)
                } catch {
                    print("Decoding Error in fetchMessages: \(error)")
                    if let raw = String(data: data, encoding: .utf8) {
                        print("Raw data that failed decoding: \(raw)")
                    }
                    completion([])
                }
            } else {
                completion([])
            }
        }.resume()
    }

    func searchMessages(query: String, chatIds: [String], completion: @escaping (Result<[ChatMessage], Error>) -> Void) {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Build URL with multiple chatIds parameters
        var urlString = "\(baseURL)/search/global?keyword=\(encodedQuery)"
        for id in chatIds {
            urlString += "&chatIds=\(id)"
        }
        
        guard let url = URL(string: urlString) else { return }
        
        print("🔍 Searching messages: \(url.absoluteString)")
        var request = URLRequest(url: url)
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Search messages error: \(error.localizedDescription)")
                return completion(.failure(error))
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Search messages response status: \(httpResponse.statusCode)")
            }

            guard let data = data else {
                return completion(.failure(NSError(domain: "Search", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data"])))
            }
            
            do {
                let messages = try JSONDecoder().decode([ChatMessage].self, from: data)
                print("✅ Found \(messages.count) messages in scoped search")
                completion(.success(messages))
            } catch {
                print("❌ Search messages decoding error: \(error)")
                if let raw = String(data: data, encoding: .utf8) {
                    print("📄 Raw search response: \(raw)")
                }
                completion(.failure(error))
            }
        }.resume()
    }

    func searchRooms(username: String, query: String, completion: @escaping (Result<[ChatRoom], Error>) -> Void) {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "\(baseURL)/rooms/search?username=\(username)&query=\(encodedQuery)") else { return }
        
        print("🔍 Searching rooms: \(url.absoluteString)")
        var request = URLRequest(url: url)
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Search rooms error: \(error.localizedDescription)")
                return completion(.failure(error))
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Search rooms response status: \(httpResponse.statusCode)")
            }

            guard let data = data else {
                return completion(.failure(NSError(domain: "Search", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data"])))
            }
            
            do {
                let rooms = try JSONDecoder().decode([ChatRoom].self, from: data)
                print("✅ Found \(rooms.count) rooms")
                completion(.success(rooms))
            } catch {
                print("❌ Search rooms decoding error: \(error)")
                if let raw = String(data: data, encoding: .utf8) {
                    print("📄 Raw rooms response: \(raw)")
                }
                completion(.failure(error))
            }
        }.resume()
    }

    func fetchRooms(username: String, completion: @escaping (Result<[ChatRoom], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/rooms/user/\(username)") else { return }
        var request = URLRequest(url: url)
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { return completion(.failure(error)) }
            guard let data = data, let rooms = try? JSONDecoder().decode([ChatRoom].self, from: data) else {
                return completion(.failure(NSError(domain: "Rooms", code: 500, userInfo: [NSLocalizedDescriptionKey: "Odalar alınamadı."])))
            }
            completion(.success(rooms))
        }.resume()
    }

    func createRoom(name: String?, group: Bool, members: Set<String>, completion: @escaping (Result<ChatRoom, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/rooms") else { return }
        var requestBody: [String: Any] = [
            "name": name ?? "",
            "group": group,
            "members": Array(members)
        ]
        
        // Deterministic ID for 1:1 chats to avoid duplicates
        if !group && members.count == 2 {
            let sorted = Array(members).sorted()
            requestBody["id"] = "dm_\(sorted[0])_\(sorted[1])"
        }

        guard let uploadData = try? JSONSerialization.data(withJSONObject: requestBody) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = uploadData
        
        print("DEBUG [APIClient]: Sending POST /rooms with body: \(String(data: uploadData, encoding: .utf8) ?? "")")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("DEBUG [APIClient]: POST /rooms Network Error: \(error)")
                return completion(.failure(error))
            }
            if let httpResponse = response as? HTTPURLResponse {
                print("DEBUG [APIClient]: POST /rooms Response Status: \(httpResponse.statusCode)")
            }
            guard let data = data else {
                return completion(.failure(NSError(domain: "Rooms", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
            }
            print("DEBUG [APIClient]: POST /rooms Response Body: \(String(data: data, encoding: .utf8) ?? "")")
            guard let room = try? JSONDecoder().decode(ChatRoom.self, from: data) else {
                print("DEBUG [APIClient]: POST /rooms Decoding Error. Raw data: \(String(data: data, encoding: .utf8) ?? "")")
                return completion(.failure(NSError(domain: "Rooms", code: 500, userInfo: [NSLocalizedDescriptionKey: "Oda oluşturulamadı."])))
            }
            completion(.success(room))
        }.resume()
    }

    func deleteRoom(roomId: String, completion: ((Error?) -> Void)? = nil) {
        // 1. Delete room record from user-service (PostgreSQL)
        guard let roomURL = URL(string: "\(baseURL)/rooms/\(roomId)") else { return }
        var roomRequest = URLRequest(url: roomURL)
        roomRequest.httpMethod = "DELETE"
        if let token = accessToken {
            roomRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        URLSession.shared.dataTask(with: roomRequest) { [weak self] _, _, error in
            if let error = error {
                print("DEBUG [APIClient]: DELETE /rooms/\(roomId) failed: \(error)")
                completion?(error)
                return
            }

            // 2. Delete all messages for this chat from message-service (Cassandra)
            guard let self = self,
                  let msgsURL = URL(string: "\(self.baseURL)/messages/\(roomId)") else {
                completion?(nil)
                return
            }
            var msgsRequest = URLRequest(url: msgsURL)
            msgsRequest.httpMethod = "DELETE"
            if let token = self.accessToken {
                msgsRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            URLSession.shared.dataTask(with: msgsRequest) { _, _, error in
                if let error = error {
                    print("DEBUG [APIClient]: DELETE /messages/\(roomId) failed: \(error)")
                }
                completion?(error)
            }.resume()
        }.resume()
    }
    
    // Phase 5: Message Lifecycle Actions
    
    func editMessage(chatId: String, messageId: String, newContent: String, completion: @escaping (ChatMessage?) -> Void) {
        let encodedContent = newContent.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "\(baseURL)/messages/\(chatId)/\(messageId)/edit?newContent=\(encodedContent)") else { return completion(nil) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data, let updated = try? JSONDecoder().decode(ChatMessage.self, from: data) else {
                return completion(nil)
            }
            completion(updated)
        }.resume()
    }
    
    func revokeMessage(chatId: String, messageId: String, completion: @escaping (ChatMessage?) -> Void) {
        guard let url = URL(string: "\(baseURL)/messages/\(chatId)/\(messageId)/revoke") else { return completion(nil) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data, let updated = try? JSONDecoder().decode(ChatMessage.self, from: data) else {
                return completion(nil)
            }
            completion(updated)
        }.resume()
    }
    
    func markAsRead(chatId: String, messageId: String, completion: @escaping (ChatMessage?) -> Void) {
        guard let url = URL(string: "\(baseURL)/messages/\(chatId)/\(messageId)/read") else { return completion(nil) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data, let updated = try? JSONDecoder().decode(ChatMessage.self, from: data) else {
                return completion(nil)
            }
            completion(updated)
        }.resume()
    }
    
    func sendMessage(message: ChatMessage, completion: @escaping (Result<ChatMessage, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/messages/send") else { return }
        guard let uploadData = try? JSONEncoder().encode(message) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = uploadData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { return completion(.failure(error)) }
            guard let data = data, let sent = try? JSONDecoder().decode(ChatMessage.self, from: data) else {
                return completion(.failure(NSError(domain: "Messages", code: 500, userInfo: [NSLocalizedDescriptionKey: "Mesaj gönderilemedi."])))
            }
            completion(.success(sent))
        }.resume()
    }

    func uploadMedia(data: Data, fileName: String, contentType: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/media/upload") else { return }
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        URLSession.shared.uploadTask(with: request, from: body) { data, _, error in
            if let error = error { return completion(.failure(error)) }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let fileURL = json["url"] else {
                return completion(.failure(NSError(domain: "Media", code: 500, userInfo: [NSLocalizedDescriptionKey: "Yükleme hatası."])))
            }
            completion(.success(fileURL))
        }.resume()
    }
}
extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@" // does not include ? or /
        let subDelimitersToEncode = "!$&'()*+,;="
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        return allowed
    }()
}



