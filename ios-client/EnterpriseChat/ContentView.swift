import SwiftUI
import PhotosUI

// MARK: - App State & Main View
struct ContentView: View {
    @State private var currentUser: User?
    
    var body: some View {
        Group {
            if let user = currentUser {
                MainTabView(currentUser: user, onLogout: {
                    withAnimation(.easeInOut) {
                        currentUser = nil
                    }
                    UserDefaults.standard.removeObject(forKey: "last_access_token")
                    UserDefaults.standard.removeObject(forKey: "last_username")
                    APIClient.shared.accessToken = nil
                })
                .transition(.opacity)
            } else {
                AuthView(onLogin: { user in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        self.currentUser = user
                    }
                })
                .transition(.asymmetric(insertion: .opacity, removal: .scale))
                .onAppear {
                    checkAutoLogin()
                }
            }
        }
    }
    
    private func checkAutoLogin() {
        if currentUser == nil,
           let token = UserDefaults.standard.string(forKey: "last_access_token"),
           let username = UserDefaults.standard.string(forKey: "last_username") {
            APIClient.shared.accessToken = token
            APIClient.shared.fetchUserProfile(username: username) { result in
                DispatchQueue.main.async {
                    if case .success(let user) = result {
                        withAnimation { self.currentUser = user }
                    }
                }
            }
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    let currentUser: User
    let onLogout: () -> Void
    @State private var selectedTab = 0
    
    // UI Theme Constants
    let accentColor = Color(hex: "D1D1FF") // Soft Lavender
    let backgroundColor = Color(hex: "F4F4F4")
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ChatListView(currentUser: currentUser, onLogout: onLogout)
                .tabItem {
                    Label("Chats", systemImage: "message.fill")
                }
                .tag(0)
            
            ContactListView(currentUser: currentUser)
                .tabItem {
                    Label("Contacts", systemImage: "person.2.fill")
                }
                .tag(1)
            
            SearchView(currentUser: currentUser)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(2)
            
            ProfileView(currentUser: currentUser, onLogout: onLogout)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .accentColor(accentColor)
        .onAppear {
            WebSocketManager.shared.connect(username: currentUser.username)
            WebSocketManager.shared.subscribePresence()
            
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .white
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// MARK: - Chat List View
struct ChatListView: View {
    let currentUser: User
    let onLogout: () -> Void
    
    @State private var recentChats: [ChatRoom] = []
    @State private var isShowingGroupCreation = false
    @State private var searchText = ""
    @State private var targetNewRoom: ChatRoom?
    @State private var navigateToNewRoom = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F4F4F4").ignoresSafeArea()
                
                // GİZLİ NAVİGASYON TETİKLEYİCİSİ
                NavigationLink(
                    destination: ChatRoomView(currentUser: currentUser, chatId: targetNewRoom?.id ?? "", title: targetNewRoom?.name ?? "Chat"),
                    isActive: $navigateToNewRoom,
                    label: { EmptyView() }
                )
                .hidden()
                
                VStack(spacing: 12) {
                    HStack {
                        Text("Messages")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Spacer()
                        Button(action: { isShowingGroupCreation = true }) {
                            HStack(spacing: 6) {
                                Text("New Group")
                                    .font(.system(size: 13, weight: .bold))
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(hex: "D1D1FF"))
                            .cornerRadius(15)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)

                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 14))
                        TextField("Search...", text: $searchText)
                            .font(.system(size: 14))
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Color.white)
                    .cornerRadius(18)
                    .padding(.horizontal)
                    
                    if recentChats.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 50))
                                .foregroundColor(Color(hex: "D1D1FF"))
                            Text("No chats yet")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(recentChats.filter { searchText.isEmpty || ($0.name ?? "Chat").contains(searchText) }) { room in
                                    NavigationLink(destination: ChatRoomView(currentUser: currentUser, chatId: room.id, title: room.name ?? "Chat")) {
                                        ChatRowView(room: room, currentUser: currentUser)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            // SHEET KAPANINCA NAVİGASYONU TETİKLE
            .sheet(isPresented: $isShowingGroupCreation, onDismiss: {
                if targetNewRoom != nil {
                    navigateToNewRoom = true
                }
            }) {
                MultiContactSelectionView(currentUser: currentUser) { newRoom in
                    self.recentChats.insert(newRoom, at: 0)
                    self.targetNewRoom = newRoom
                }
            }
            .onAppear(perform: loadRecentChats)
        }
    }
    
    private func loadRecentChats() {
        APIClient.shared.fetchRooms(username: currentUser.username) { result in
            DispatchQueue.main.async {
                if case .success(let rooms) = result {
                    self.recentChats = rooms
                }
            }
        }
    }
}
 
   
struct ChatRowView: View {
    let room: ChatRoom
    let currentUser: User
    
    private var displayName: String {
        if room.group {
            return room.name ?? "Group Chat"
        } else {
            // Derive name for 1:1 chat from the other member
            let otherMember = room.members.first(where: { $0 != currentUser.username })
            return otherMember ?? "Chat"
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(hex: "D1D1FF").opacity(0.3))
                    .frame(width: 40, height: 40)
                Text(String(displayName.prefix(1)))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: "4A4A8F"))
                
                if WebSocketManager.shared.onlineUsers.contains(displayName) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: 14, y: 14)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(displayName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    Spacer()
                    if let _ = room.lastMessageAt {
                        Text("Now")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                
                Text(room.lastMessage ?? "Start messaging...")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.01), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Contact List View
struct ContactListView: View {
    let currentUser: User
    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var navigateToChat = false
    @State private var targetRoomId = ""
    @State private var targetUserTitle = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F4F4F4").ignoresSafeArea()
                
                // GİZLİ NAVİGASYON TETİKLEYİCİSİ
                NavigationLink(
                    destination: ChatRoomView(currentUser: currentUser, chatId: targetRoomId, title: targetUserTitle),
                    isActive: $navigateToChat,
                    label: { EmptyView() }
                )
                .hidden()
                
                VStack(spacing: 12) {
                    HStack {
                        Text("People")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)

                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 14))
                        TextField("Search names...", text: $searchText)
                            .font(.system(size: 14))
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Color.white)
                    .cornerRadius(18)
                    .padding(.horizontal)

                    if isLoading {
                        ProgressView().padding()
                    }

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(users.filter { $0.username != currentUser.username && (searchText.isEmpty || ($0.username).contains(searchText)) }) { user in
                                ContactRowView(user: user, currentUser: currentUser) { roomId, title in
                                    self.targetRoomId = roomId
                                    self.targetUserTitle = title
                                    self.navigateToChat = true
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear(perform: loadUsers)
        }
    }
    
    private func loadUsers() {
        isLoading = true
        APIClient.shared.fetchAllUsers { result in
            DispatchQueue.main.async {
                isLoading = false
                if case .success(let fetched) = result { self.users = fetched }
            }
        }
    }
}

struct ContactRowView: View {
    let user: User
    let currentUser: User
    let onRoomCreated: (String, String) -> Void
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        Button(action: {
            isLoading = true
            APIClient.shared.createRoom(name: nil, group: false, members: [currentUser.username, user.username]) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    if case .success(let room) = result {
                        print("DEBUG [ContactRowView]: Room created gracefully: \(room.id)")
                        onRoomCreated(room.id, user.firstName ?? user.username)
                    } else if case .failure(let error) = result {
                        print("DEBUG [ContactRowView]: Failed to create room: \(error)")
                        self.errorMessage = error.localizedDescription
                        self.showError = true
                    }
                }
            }
        }) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(hex: "D1D1FF"))
                    .frame(width: 36, height: 36)
                    .overlay(
                        ZStack {
                            Text(String(user.username.prefix(1)).uppercased()).foregroundColor(.white).font(.system(size: 14, weight: .bold))
                            if WebSocketManager.shared.onlineUsers.contains(user.username) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 10, height: 10)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                    .offset(x: 14, y: 14)
                            }
                        }
                    )
                
                VStack(alignment: .leading) {
                    Text("\(user.firstName ?? "") \(user.lastName ?? user.username)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                    Text("@\(user.username)")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                Spacer()
                if isLoading { ProgressView().scaleEffect(0.8) }
                else {
                    Image(systemName: "message.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "D1D1FF"))
                }
            }
            .padding(8)
            .background(Color.white)
            .cornerRadius(16)
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("API Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
    }
}

// MARK: - Search View
struct SearchView: View {
    let currentUser: User
    @State private var query = ""
    @State private var results: [ChatMessage] = []
    @State private var isLoading = false
    @State private var selectedChatId = ""
    @State private var navigateToChat = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F4F4F4").ignoresSafeArea()
                
                VStack(spacing: 12) {
                    HStack {
                        Text("Search")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)

                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray).font(.system(size: 14))
                        TextField("Search message content...", text: $query, onCommit: performSearch)
                            .font(.system(size: 14))
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Color.white)
                    .cornerRadius(18)
                    .padding(.horizontal)

                    if isLoading {
                        ProgressView().padding()
                    }

                    if results.isEmpty && !query.isEmpty && !isLoading {
                        Text("No results found").foregroundColor(.gray).padding()
                    }

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(results) { msg in
                                Button(action: {
                                    self.selectedChatId = msg.chatId
                                    self.navigateToChat = true
                                }) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(msg.senderId)
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(Color(hex: "4A4A8F"))
                                            Spacer()
                                            Text("Chat ID: \(msg.chatId)")
                                                .font(.system(size: 9))
                                                .foregroundColor(.gray)
                                        }
                                        Text(msg.content)
                                            .font(.system(size: 14, design: .rounded))
                                            .foregroundColor(.black)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .padding(12)
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                } // End VStack
            } // End ZStack
            .navigationDestination(isPresented: $navigateToChat) {
                ChatRoomView(currentUser: currentUser, chatId: selectedChatId, title: "Chat")
            }
            .navigationBarHidden(true)
        } // End NavigationStack

    }
    
    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        APIClient.shared.searchMessages(query: query) { result in
            DispatchQueue.main.async {
                isLoading = false
                if case .success(let fetched) = result {
                    self.results = fetched
                }
            }
        }
    }
}

// MARK: - Multi-Select Group View
struct MultiContactSelectionView: View {
    let currentUser: User
    @Environment(\.presentationMode) var presentationMode
    var onCreated: ((ChatRoom) -> Void)? = nil
    
    @State private var users: [User] = []
    @State private var selectedUserIds = Set<String>()
    @State private var groupName = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "F4F4F4").ignoresSafeArea()
                
                VStack(spacing: 15) {
                    TextField("Group Name", text: $groupName)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(15)
                        .padding(.horizontal)
                    
                    Text("Select Participants (\(selectedUserIds.count))")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(users.filter { $0.username != currentUser.username }) { user in
                                Button(action: {
                                    if selectedUserIds.contains(user.username) {
                                        selectedUserIds.remove(user.username)
                                    } else {
                                        selectedUserIds.insert(user.username)
                                    }
                                }) {
                                    HStack {
                                        Circle()
                                            .fill(Color(hex: "D1D1FF"))
                                            .frame(width: 32, height: 32)
                                            .overlay(Text(String(user.username.prefix(1)).uppercased()).foregroundColor(.white).font(.system(size: 12, weight: .bold)))
                                        
                                        Text("\(user.firstName ?? "") \(user.lastName ?? user.username)")
                                            .font(.system(size: 14))
                                            .foregroundColor(.black)
                                        Spacer()
                                        Image(systemName: selectedUserIds.contains(user.username) ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 16))
                                            .foregroundColor(selectedUserIds.contains(user.username) ? Color(hex: "D1D1FF") : .gray)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Button(action: createGroup) {
                        if isLoading { ProgressView().tint(.white) }
                        else {
                            Text("Create Group")
                                .font(.system(size: 15, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(selectedUserIds.count >= 1 && !groupName.isEmpty ? Color(hex: "D1D1FF") : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(15)
                                .padding(.horizontal)
                                .padding(.bottom, 10)
                        }
                    }
                    .disabled(selectedUserIds.count < 1 || groupName.isEmpty || isLoading)
                }
            }
            .navigationBarTitle("New Group", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() })
            .onAppear(perform: loadUsers)
            .alert(isPresented: $showError) {
                Alert(title: Text("Group API Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private func loadUsers() {
        APIClient.shared.fetchAllUsers { result in
            DispatchQueue.main.async { if case .success(let fetched) = result { self.users = fetched } }
        }
    }
    
    private func createGroup() {
        isLoading = true
        var members = selectedUserIds
        members.insert(currentUser.username)
        
        APIClient.shared.createRoom(name: groupName, group: true, members: members) { result in
            DispatchQueue.main.async {
                isLoading = false
                if case .success(let room) = result {
                    print("DEBUG [MultiContact]: Room created successfully: \(room.id)")
                    onCreated?(room)
                    presentationMode.wrappedValue.dismiss()
                } else if case .failure(let error) = result {
                    print("DEBUG [MultiContact]: Failed to create group room: \(error)")
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
}

// MARK: - Chat Room View (Dribbble Style)
struct ChatRoomView: View {
    let currentUser: User
    let chatId: String
    let title: String
    
    @StateObject private var viewModel = ChatViewModel()
    @State private var editingMessageId: String? = nil
    @State private var replyingToId: String? = nil
    @State private var isPickerPresented = false
    @State private var selectedImage: UIImage? = nil
    @State private var isEmojiPanelPresented = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            ScrollViewReader { proxy in
                messageListView(proxy: proxy)
            }
            
            inputView
        }
        .navigationBarTitle("", displayMode: .inline)
        .onAppear { viewModel.connect(chatId: chatId, username: currentUser.username) }
        .onDisappear { viewModel.disconnect(chatId: chatId) }
        .sheet(isPresented: $isPickerPresented) {
            ImagePicker(image: $selectedImage)
        }
        .sheet(isPresented: $isEmojiPanelPresented) {
            EmojiPanelView(onEmojiSelected: { emoji in
                viewModel.inputText += emoji
                isEmojiPanelPresented = false
            })
        }
        .onChange(of: selectedImage) { newImage in
            if let img = newImage {
                viewModel.uploadAndSendMedia(chatId: chatId, senderId: currentUser.username, image: img)
                selectedImage = nil
            }
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 15) {
            Circle()
                .fill(Color(hex: "D1D1FF"))
                .frame(width: 40, height: 40)
                .overlay(Text(String(title.prefix(1))).foregroundColor(.white).bold())
            
            VStack(alignment: .leading) {
                Text(title).font(.system(size: 18, weight: .bold, design: .rounded))
                if let typers = WebSocketManager.shared.typingUsers[chatId], !typers.filter({ $0 != currentUser.username }).isEmpty {
                    Text("typing...")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "4A4A8F"))
                } else {
                    Text("Active now").font(.caption).foregroundColor(.green)
                }
            }
            Spacer()
            Button(action: {}) {
                Image(systemName: "phone.fill")
                    .padding(10)
                    .background(Color(hex: "D1D1FF").opacity(0.3))
                    .clipShape(Circle())
                    .foregroundColor(Color(hex: "4A4A8F"))
            }
        }
        .padding()
        .background(Color.white)
    }
    
    private func messageListView(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.messages) { msg in
                    DribbbleMessageRow(
                        message: msg,
                        isMe: msg.senderId == currentUser.username,
                        repliedContent: viewModel.messages.first(where: { $0.id == msg.replyToId })?.content,
                        onEdit: {
                            viewModel.inputText = msg.content
                            editingMessageId = msg.messageId
                        },
                        onRevoke: {
                            if let mid = msg.messageId {
                                viewModel.revokeMessage(chatId: chatId, messageId: mid)
                            }
                        },
                        onReply: {
                            replyingToId = msg.messageId
                        }
                    )
                    .id(msg.id)
                    .onAppear {
                        if msg.senderId != currentUser.username && msg.status != "READ" {
                            if let mid = msg.messageId {
                                viewModel.markAsRead(chatId: chatId, messageId: mid)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(hex: "F4F4F4"))
        .onChange(of: viewModel.messages) { _ in
            if let last = viewModel.messages.last {
                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }
    
    private var inputView: some View {
        VStack(spacing: 0) {
            if let replyId = replyingToId, let replyMsg = viewModel.messages.first(where: { $0.messageId == replyId }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Replying to").font(.caption2).foregroundColor(.gray)
                        Text(replyMsg.content).font(.caption).lineLimit(1).foregroundColor(Color(hex: "4A4A8F"))
                    }
                    .padding(.leading, 8)
                    .overlay(HStack { Rectangle().fill(Color(hex: "D1D1FF")).frame(width: 2); Spacer() })
                    Spacer()
                    Button(action: { replyingToId = nil }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(hex: "F8F8FF"))
            }
            
            HStack(spacing: 12) {
                Button(action: { isPickerPresented = true }) {
                    Image(systemName: "plus").foregroundColor(.gray)
                }
                
                Button(action: { isEmojiPanelPresented.toggle() }) {
                    Image(systemName: "face.smiling").foregroundColor(.gray)
                }
                
                TextField("Type something...", text: $viewModel.inputText)
                    .padding(12)
                    .background(Color(hex: "F4F4F4"))
                    .cornerRadius(25)
                    .onChange(of: viewModel.inputText) { newValue in
                        WebSocketManager.shared.sendTyping(chatId: chatId, username: currentUser.username, isTyping: !newValue.isEmpty)
                    }
                
                Button(action: {
                    if let editId = editingMessageId {
                        viewModel.editMessage(chatId: chatId, messageId: editId, newContent: viewModel.inputText)
                        editingMessageId = nil
                        viewModel.inputText = ""
                    } else {
                        viewModel.sendMessage(chatId: chatId, senderId: currentUser.username, replyToId: replyingToId)
                        replyingToId = nil
                    }
                }) {
                    Image(systemName: editingMessageId != nil ? "pencil.circle.fill" : "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color(hex: "D1D1FF"))
                        .clipShape(Circle())
                        .shadow(color: Color(hex: "D1D1FF").opacity(0.4), radius: 5, x: 0, y: 3)
                }
                .disabled(viewModel.inputText.isEmpty)
            }
            .padding()
            .background(Color.white)
        }
    }
}

struct EmojiPanelView: View {
    let onEmojiSelected: (String) -> Void
    let emojis = ["👍", "❤️", "😂", "😮", "😢", "😡", "🔥", "✅", "🙌", "✨", "🚀", "💡"]
    
    var body: some View {
        VStack {
            Text("Select Emoji").font(.headline).padding()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 20) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(action: { onEmojiSelected(emoji) }) {
                        Text(emoji).font(.system(size: 30))
                    }
                }
            }
            .padding()
            Spacer()
        }
    }
}

struct DribbbleMessageRow: View {
    let message: ChatMessage
    let isMe: Bool
    var repliedContent: String? = nil
    
    var onEdit: () -> Void = {}
    var onRevoke: () -> Void = {}
    var onReply: () -> Void = {}
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isMe {
                Circle().fill(Color.gray.opacity(0.1)).frame(width: 24, height: 24)
            } else {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                if message.replyToId != nil {
                    HStack(spacing: 4) {
                        Rectangle().fill(Color(hex: "D1D1FF")).frame(width: 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Replied Message")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.gray)
                            Text(repliedContent ?? "Original message...")
                                .font(.system(size: 10))
                                .foregroundColor(.gray.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(4)
                }
                
                if let mediaUrl = message.mediaUrl, let url = URL(string: mediaUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(maxWidth: 200)
                    .cornerRadius(12)
                    .padding(.horizontal, 8)
                }
                
                if !message.content.isEmpty && message.content != "[Image]" {
                    Text(message.isDeleted == true ? "This message was deleted" : message.content)
                        .font(.system(size: 14, design: .rounded))
                        .italic(message.isDeleted == true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isMe ? Color(hex: "D1D1FF") : Color.white)
                        .foregroundColor(message.isDeleted == true ? .gray : .black)
                        .cornerRadius(18)
                        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
                }
                
                HStack(spacing: 4) {
                    if message.isEdited == true && message.isDeleted != true {
                        Text("edited").font(.system(size: 9)).foregroundColor(.gray)
                    }
                    
                    if isMe && message.isDeleted != true {
                        MessageStatusView(status: message.status ?? "SENT")
                    }
                }
            }
            .contextMenu {
                if message.isDeleted != true {
                    Button(action: onReply) {
                        Label("Reply", systemImage: "arrowshape.turn.up.left")
                    }
                    if isMe {
                        Button(action: onEdit) {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive, action: onRevoke) {
                            Label("Revoke", systemImage: "trash")
                        }
                    }
                }
            }
            
            if isMe {
                Circle().fill(Color(hex: "D1D1FF").opacity(0.4)).frame(width: 24, height: 24)
            } else {
                Spacer(minLength: 40)
            }
        }
    }
}

struct MessageStatusView: View {
    let status: String
    var body: some View {
        HStack(spacing: -4) {
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(status == "READ" ? .blue : .gray)
            if status == "DELIVERED" || status == "READ" {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(status == "READ" ? .blue : .gray)
            }
        }
    }
}

// MARK: - Auth View (Minimalist)
struct AuthView: View {
    let onLogin: (User) -> Void
    @State private var isLoginMode = true
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Color(hex: "F4F4F4").ignoresSafeArea()
            
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "paperplane.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "D1D1FF"))
                    Text("ChatUI")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                }
                .padding(.top, 20)
                
                VStack(spacing: 15) {
                    HStack {
                        Button("Login") { isLoginMode = true }
                            .foregroundColor(isLoginMode ? .black : .gray)
                            .font(.system(size: 15, weight: .bold))
                        Spacer()
                        Button("Register") { isLoginMode = false }
                            .foregroundColor(!isLoginMode ? .black : .gray)
                            .font(.system(size: 15, weight: .bold))
                    }
                    .padding(.horizontal, 30)
                    
                    VStack(spacing: 10) {
                        ModernTextField(placeholder: "Username", text: $username, autoCap: .none)
                        if !isLoginMode {
                            ModernTextField(placeholder: "Email", text: $email, autoCap: .none)
                            ModernTextField(placeholder: "First Name", text: $firstName)
                            ModernTextField(placeholder: "Last Name", text: $lastName)
                        }
                        ModernTextField(placeholder: "Password", text: $password, isSecure: true)
                    }
                    .padding(.horizontal, 15)
                    
                    if let error = errorMessage {
                        Text(error).foregroundColor(.red).font(.system(size: 11)).padding(.horizontal)
                    }
                    
                    Button(action: handleAction) {
                        if isLoading { ProgressView().tint(.white) }
                        else { Text(isLoginMode ? "Sign In" : "Sign Up").font(.system(size: 15, weight: .bold)) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "D1D1FF"))
                    .foregroundColor(.white)
                    .cornerRadius(18)
                    .padding(.horizontal, 20)
                    .shadow(color: Color(hex: "D1D1FF").opacity(0.4), radius: 6, x: 0, y: 3)
                }
                .padding(.vertical, 20)
                .background(Color.white)
                .cornerRadius(30)
                .padding(.horizontal)
                
                Spacer()
            }
        }
    }
    
    private func handleAction() {
        isLoading = true
        errorMessage = nil
        if isLoginMode {
            APIClient.shared.login(username: username, password: password) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    if case .success(let user) = result { onLogin(user) }
                    else if case .failure(let err) = result { errorMessage = err.localizedDescription }
                }
            }
        } else {
            APIClient.shared.register(username: username, email: email, firstName: firstName, lastName: lastName, password: password) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    if case .success(let user) = result { onLogin(user) }
                    else if case .failure(let err) = result { errorMessage = err.localizedDescription }
                }
            }
        }
    }
}

// MARK: - Profile View
struct ProfileView: View {
    let currentUser: User
    let onLogout: () -> Void
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "F4F4F4").ignoresSafeArea()
                VStack(spacing: 25) {
                    VStack(spacing: 15) {
                        Circle()
                            .fill(Color(hex: "D1D1FF"))
                            .frame(width: 100, height: 100)
                            .overlay(Text(String(currentUser.username.prefix(1)).uppercased()).font(.largeTitle).foregroundColor(.white))
                        
                        Text("\(currentUser.firstName ?? "") \(currentUser.lastName ?? "")")
                            .font(.title2.bold())
                        Text("@\(currentUser.username)").foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                    
                    VStack(spacing: 1) {
                        ProfileRow(icon: "person.fill", title: "Account")
                        ProfileRow(icon: "bell.fill", title: "Notifications")
                        ProfileRow(icon: "shield.fill", title: "Privacy")
                    }
                    .background(Color.white)
                    .cornerRadius(30)
                    .padding(.horizontal)
                    
                    Button(action: onLogout) {
                        Text("Log Out")
                            .foregroundColor(.white)
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(25)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("Settings")
            .navigationBarHidden(true)
        }
    }
}

struct ProfileRow: View {
    let icon: String; let title: String
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon).foregroundColor(Color(hex: "D1D1FF")).frame(width: 30)
            Text(title).font(.body)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
        }
        .padding()
    }
}

struct ModernTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var autoCap: UITextAutocapitalizationType = .sentences
    
    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .autocapitalization(autoCap)
                    .disableAutocorrection(autoCap == .none)
            }
        }
        .font(.system(size: 14))
        .padding(12)
        .background(Color(hex: "F4F4F4"))
        .cornerRadius(12)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async { self.parent.image = image as? UIImage }
            }
        }
    }
}

