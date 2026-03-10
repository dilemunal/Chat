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
            
            ProfileView(currentUser: currentUser, onLogout: onLogout)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
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
    
    // Global Search State
    @State private var messageResults: [ChatMessage] = []
    @State private var isLoadingGlobal = false
    @State private var searchTask: Task<Void, Never>? = nil
    
    private var sortedChats: [ChatRoom] {
        recentChats
            .filter { $0.lastMessage != nil }
            .sorted { (c1, c2) in
                let r1 = c1.lastMessageAt ?? ""
                let r2 = c2.lastMessageAt ?? ""
                return r1 > r2 // ISO8601 strings sort correctly lexicographically
            }
    }

    private var filteredChats: [ChatRoom] {
        sortedChats.filter {
            searchText.isEmpty ||
            ($0.name ?? "Chat").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.softBackground.ignoresSafeArea()
                
                // GİZLİ NAVİGASYON TETİKLEYİCİSİ
                NavigationLink(
                    destination: ChatRoomView(currentUser: currentUser, chatId: targetNewRoom?.id ?? "", title: targetNewRoom?.displayName(currentUser: currentUser) ?? "Chat"),
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
                            .background(Color.softSage)
                            .cornerRadius(15)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)

                    HStack {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .foregroundColor(searchText.isEmpty ? .gray : .blue)
                            .font(.system(size: 20))
                        TextField("Search chats and messages...", text: $searchText)
                            .font(.system(size: 14))
                            .onChange(of: searchText) { newValue in
                                triggerGlobalSearch(query: newValue)
                            }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(18)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.glassBorder, lineWidth: 1))
                    .padding(.horizontal)
                    
                    if sortedChats.isEmpty && searchText.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 50))
                                .foregroundColor(Color.slateBlue.opacity(0.7))
                            Text("No messages yet")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        List {
                            if !searchText.isEmpty {
                                Section("Chats") {
                                    if filteredChats.isEmpty {
                                        Text("No matching chats").font(.system(size: 13)).foregroundColor(.gray)
                                    } else {
                                        ForEach(filteredChats) { room in
                                            NavigationLink(destination: ChatRoomView(currentUser: currentUser, chatId: room.id, title: room.displayName(currentUser: currentUser))) {
                                                ChatRowView(room: room, currentUser: currentUser)
                                            }
                                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                Button(role: .destructive) { deleteChat(roomId: room.id) }
                                                label: { Label("Delete", systemImage: "trash") }
                                            }
                                        }
                                    }
                                }
                                
                                Section("Messages") {
                                    if isLoadingGlobal {
                                        HStack {
                                            ProgressView()
                                            Text("Searching database...").font(.system(size: 13))
                                        }
                                        .foregroundColor(.gray)
                                        .padding(.vertical, 4)
                                    } else if messageResults.isEmpty {
                                        Text("No messages found").font(.system(size: 13)).foregroundColor(.gray)
                                    } else {
                                        ForEach(messageResults) { msg in
                                            NavigationLink(destination: ChatRoomView(currentUser: currentUser, chatId: msg.chatId, title: "Chat")) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack {
                                                        Text(msg.senderId)
                                                            .font(.system(size: 12, weight: .bold))
                                                            .foregroundColor(Color.charcoal)
                                                        Spacer()
                                                        Text(formatDate(msg.timestamp))
                                                            .font(.system(size: 10))
                                                            .foregroundColor(.gray)
                                                    }
                                                    Text(msg.content)
                                                        .font(.system(size: 13))
                                                        .foregroundColor(.black)
                                                        .lineLimit(2)
                                                }
                                                .padding(.vertical, 4)
                                            }
                                        }
                                    }
                                }
                            } else {
                                // Default recent chats view
                                ForEach(sortedChats) { room in
                                    NavigationLink(destination: ChatRoomView(currentUser: currentUser, chatId: room.id, title: room.displayName(currentUser: currentUser))) {
                                        ChatRowView(room: room, currentUser: currentUser)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) { deleteChat(roomId: room.id) }
                                        label: { Label("Delete", systemImage: "trash") }
                                    }
                                    .transition(.move(edge: .top))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                }
                            }
                        }
                        .listStyle(.plain)
                        .background(Color.softBackground)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isShowingGroupCreation, onDismiss: {
                if targetNewRoom != nil { navigateToNewRoom = true }
            }) {
                MultiContactSelectionView(currentUser: currentUser) { newRoom in
                    self.recentChats.insert(newRoom, at: 0)
                    self.targetNewRoom = newRoom
                }
            }
            .onAppear(perform: loadRecentChats)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewMessageReceived"))) { _ in
                withAnimation {
                    loadRecentChats()
                }
            }
        }
    }
    
    private func loadRecentChats() {
        APIClient.shared.fetchRooms(username: currentUser.username) { result in
            DispatchQueue.main.async {
                if case .success(let rooms) = result { self.recentChats = rooms }
            }
        }
    }

    private func deleteChat(roomId: String) {
        withAnimation { recentChats.removeAll { $0.id == roomId } }
        APIClient.shared.deleteRoom(roomId: roomId)
    }
    
    private func triggerGlobalSearch(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            self.messageResults = []
            return
        }
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
            if !Task.isCancelled {
                await performGlobalSearch(query: trimmed)
            }
        }
    }
    
    @MainActor
    private func performGlobalSearch(query: String) async {
        self.isLoadingGlobal = true
        let roomIds = recentChats.map { $0.id }
        
        APIClient.shared.searchMessages(query: query, chatIds: roomIds) { result in
            DispatchQueue.main.async {
                self.isLoadingGlobal = false
                if case .success(let messages) = result {
                    self.messageResults = messages
                }
            }
        }
    }
    
    private func formatDate(_ timestamp: Double?) -> String {
        guard let timestamp = timestamp else { return "" }
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
 
   
struct ChatRowView: View {
    let room: ChatRoom
    let currentUser: User
    
    private var displayName: String {
        room.displayName(currentUser: currentUser)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.slateBlue.opacity(0.2))
                    .frame(width: 46, height: 46)
                Text(String(displayName.prefix(1)))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.charcoal.opacity(0.8))
                
                if WebSocketManager.shared.onlineUsers.contains(displayName) {
                    Circle()
                        .fill(Color.softSage)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: 16, y: 16)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color.charcoal)
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
        .padding(12)
        .background(Color.white.opacity(0.6))
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.glassBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
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
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(18)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.glassBorder, lineWidth: 1))
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
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.slateBlue.opacity(0.2))
                    .frame(width: 42, height: 42)
                    .overlay(
                        ZStack {
                            Text(String(user.username.prefix(1)).uppercased())
                                .foregroundColor(Color.charcoal.opacity(0.8))
                                .font(.system(size: 16, weight: .bold))
                            if WebSocketManager.shared.onlineUsers.contains(user.username) {
                                Circle()
                                    .fill(Color.softSage)
                                    .frame(width: 12, height: 12)
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
            .padding(10)
            .background(Color.white.opacity(0.6))
            .background(.ultraThinMaterial)
            .cornerRadius(18)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.glassBorder, lineWidth: 1))
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("API Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
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
    @StateObject private var audioManager = AudioManager()
    @State private var editingMessageId: String? = nil
    @State private var replyingToId: String? = nil
    @State private var isPickerPresented = false
    @State private var selectedImage: UIImage? = nil
    @State private var isEmojiPanelPresented = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            ScrollViewReader { proxy in
                messageListView(proxy: proxy)
            }
            
            inputView
        }
        .navigationBarHidden(true)
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
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.charcoal)
            }
            
            Circle()
                .fill(Color.slateBlue.opacity(0.3))
                .frame(width: 44, height: 44)
                .overlay(Text(String(title.prefix(1))).foregroundColor(Color.charcoal.opacity(0.8)).font(.system(size: 18, weight: .bold)))
            
            VStack(alignment: .leading) {
                Text(title).font(.system(size: 18, weight: .bold, design: .rounded))
                if let typers = WebSocketManager.shared.typingUsers[chatId], !typers.filter({ $0 != currentUser.username }).isEmpty {
                    Text("typing...")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "4A4A8F"))
                } else {
                    let otherMember = title // In 1:1 chats, title is usually the other user's name
                    if WebSocketManager.shared.onlineUsers.contains(otherMember) {
                        Text("Online").font(.caption).foregroundColor(.green)
                    } else {
                        Text("Active now").font(.caption).foregroundColor(.gray)
                    }
                }
            }
            Spacer()
            Button(action: {}) {
                Image(systemName: "phone.fill")
                    .padding(10)
                    .background(Color.slateBlue.opacity(0.15))
                    .clipShape(Circle())
                    .foregroundColor(Color.charcoal.opacity(0.8))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().frame(width: nil, height: 1, alignment: .bottom).foregroundColor(Color.glassBorder), alignment: .bottom)
    }
    
    private func messageListView(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                let grouped = groupMessagesByDate(viewModel.messages)
                let sortedDates = grouped.keys.sorted()
                
                ForEach(sortedDates, id: \.self) { date in
                    Section(header:
                        HStack {
                            Spacer()
                            Text(formatHeaderDate(date))
                                .font(.system(size: 11, weight: .bold))
                                .padding(.vertical, 4)
                                .padding(.horizontal, 14)
                                .background(Color.white.opacity(0.5))
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.glassBorder, lineWidth: 1))
                                .shadow(color: .black.opacity(0.02), radius: 2)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    ) {
                        
                        ForEach(grouped[date] ?? []) { msg in
                            DribbbleMessageRow(
                                audioManager: audioManager,
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
                                },
                                onQuoteTap: {
                                    if let replyId = msg.replyToId,
                                       let targetMsg = viewModel.messages.first(where: { $0.messageId == replyId }) {
                                        withAnimation { proxy.scrollTo(targetMsg.id, anchor: .center) }
                                    }
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
                }
            }
            .padding()
        }
        .background(Color.softBackground)
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
                
                TextField("Type a message...", text: $viewModel.inputText)
                    .padding(14)
                    .background(Color.white.opacity(0.6))
                    .cornerRadius(25)
                    .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.glassBorder, lineWidth: 1))
                    .onChange(of: viewModel.inputText) { newValue in
                        WebSocketManager.shared.sendTyping(chatId: chatId, username: currentUser.username, isTyping: !newValue.isEmpty)
                    }
                
                if viewModel.inputText.isEmpty && editingMessageId == nil {
                    Image(systemName: audioManager.isRecording ? "stop.fill" : "mic.fill")
                        .foregroundColor(.white)
                        .padding(14)
                        .background(audioManager.isRecording ? Color.red : Color.softSage)
                        .clipShape(Circle())
                        .shadow(color: (audioManager.isRecording ? Color.red : Color.softSage).opacity(0.4), radius: 5, x: 0, y: 3)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !audioManager.isRecording {
                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                        generator.impactOccurred()
                                        audioManager.startRecording()
                                    }
                                }
                                .onEnded { _ in
                                    if let url = audioManager.stopRecording() {
                                        viewModel.uploadAndSendAudio(chatId: chatId, senderId: currentUser.username, audioUrl: url, replyToId: replyingToId)
                                        replyingToId = nil
                                    }
                                }
                        )
                } else {
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
                            .padding(14)
                            .background(Color.softSage)
                            .clipShape(Circle())
                            .shadow(color: Color.softSage.opacity(0.4), radius: 5, x: 0, y: 3)
                    }
                    .disabled(viewModel.inputText.isEmpty)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: -5)
        }
    }

    private func groupMessagesByDate(_ messages: [ChatMessage]) -> [Date: [ChatMessage]] {
        Dictionary(grouping: messages) { msg in
            let timestamp = msg.timestamp ?? Date().timeIntervalSince1970 * 1000
            let date = Date(timeIntervalSince1970: timestamp / 1000)
            return Calendar.current.startOfDay(for: date)
        }
    }

    private func formatHeaderDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
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
    @ObservedObject var audioManager: AudioManager
    let message: ChatMessage
    let isMe: Bool
    var repliedContent: String? = nil
    
    var onEdit: () -> Void = {}
    var onRevoke: () -> Void = {}
    var onReply: () -> Void = {}
    var onQuoteTap: () -> Void = {}
    
    @State private var offset: CGFloat = 0
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isMe {
                Circle().fill(Color.gray.opacity(0.1)).frame(width: 24, height: 24)
            } else {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                if message.replyToId != nil {
                    Button(action: onQuoteTap) {
                        HStack(spacing: 4) {
                            Rectangle().fill(Color.slateBlue).frame(width: 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Replying to")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.gray)
                                Text(repliedContent ?? "Original message...")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray.opacity(0.8))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.slateBlue.opacity(0.05))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Image Content
                if let url = resolveMediaURL(message.mediaUrl) {
                    ZStack(alignment: .bottomTrailing) {
                        AsyncImage(url: url) { image in
                            image.resizable()
                                .scaledToFill()
                        } placeholder: {
                            ZStack {
                                Color.gray.opacity(0.1)
                                ProgressView()
                            }
                        }
                        .frame(maxWidth: 240)
                        .frame(minHeight: 100, maxHeight: 350)
                        .background(Color.gray.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        
                        // Metadata Overlay (if no text content)
                        if message.content == "[Image]" || message.content.isEmpty {
                            HStack(spacing: 4) {
                                Text(formatTime(message.timestamp))
                                    .font(.system(size: 8))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.4))
                                    .cornerRadius(4)
                                
                                if isMe {
                                    MessageStatusView(status: message.status ?? "SENT")
                                        .colorInvert()
                                        .brightness(1)
                                }
                            }
                            .padding(10)
                        }
                    }
                    .padding(.horizontal, 4)
                } else if message.mediaType == "IMAGE" || message.content == "[Uploading Image...]" {
                    // Optimistic Loading State
                    ZStack(alignment: .bottomTrailing) {
                        ZStack {
                            Color.gray.opacity(0.1)
                            VStack(spacing: 8) {
                                ProgressView()
                                Text("Uploading...").font(.system(size: 10)).foregroundColor(.gray)
                            }
                        }
                        .frame(width: 200, height: 150)
                        .cornerRadius(18)
                        
                        // Metadata for optimistic state
                        HStack(spacing: 4) {
                            Text(formatTime(Date().timeIntervalSince1970 * 1000))
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                            if isMe {
                                Image(systemName: "clock").font(.system(size: 8)).foregroundColor(.gray)
                            }
                        }
                        .padding(8)
                    }
                    .padding(.horizontal, 4)
                }
                
                } else if message.mediaType == "AUDIO" {
                    let audioUrl = resolveMediaURL(message.mediaUrl)?.absoluteString ?? ""
                    let isPlayingThis = audioManager.isPlaying(url: audioUrl)
                    let isPlaceholder = message.content == "[Uploading Audio...]"
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            if !isPlaceholder {
                                if isPlayingThis { audioManager.stopAudio() }
                                else { audioManager.playAudio(urlString: audioUrl) }
                            }
                        }) {
                            if isPlaceholder {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: isMe ? .white : .gray))
                                    .frame(width: 40, height: 40)
                                    .background(isMe ? Color.white.opacity(0.3) : Color.softSage.opacity(0.1))
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                                    .foregroundColor(isMe ? .white : Color.softSage)
                                    .font(.system(size: 20))
                                    .frame(width: 40, height: 40)
                                    .background(isMe ? Color.white.opacity(0.3) : Color.softSage.opacity(0.1))
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                            }
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(isMe ? Color.white.opacity(0.3) : Color.gray.opacity(0.2))
                                    .frame(height: 4)
                                Capsule()
                                    .fill(isMe ? Color.white : Color.softSage)
                                    .frame(width: isPlayingThis ? geo.size.width * CGFloat(audioManager.progress) : 0, height: 4)
                                    .animation(.linear(duration: 0.1), value: audioManager.progress)
                            }
                            .frame(height: 40) // For vertical centering inside HStack
                        }
                        .frame(width: 100)
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatTime(message.timestamp))
                                .font(.system(size: 9))
                                .foregroundColor(isMe ? .white.opacity(0.8) : .gray)
                            if isMe && message.isDeleted != true {
                                MessageStatusView(status: message.status ?? "SENT")
                                    .colorInvert()
                                    .brightness(isMe ? 1 : 0)
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(isMe ? Color.softSage : Color.white.opacity(0.6))
                    .background(isMe ? AnyShapeStyle(Color.clear) : AnyShapeStyle(.ultraThinMaterial))
                    .cornerRadius(25)
                    .overlay(RoundedRectangle(cornerRadius: 25).stroke(isMe ? Color.clear : Color.glassBorder, lineWidth: 1))
                    .shadow(color: Color.black.opacity(isMe ? 0.05 : 0.02), radius: 4, x: 0, y: 2)
                }
                
                // Text Content
                let showText = !message.content.isEmpty &&
                              message.content != "[Image]" &&
                              message.content != "[Uploading Image...]" &&
                              message.mediaType != "AUDIO"
                
                if showText {
                    ZStack(alignment: .bottomTrailing) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.isDeleted == true ? "This message was deleted" : message.content)
                                .font(.system(size: 14, design: .rounded))
                                .italic(message.isDeleted == true)
                                .foregroundColor(message.isDeleted == true ? .gray : (isMe ? .black : .black))
                                .padding(.bottom, 12)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 2)
                        
                        HStack(spacing: 4) {
                            Text(formatTime(message.timestamp))
                                .font(.system(size: 8))
                                .foregroundColor(.gray.opacity(0.8))
                            
                            if isMe && message.isDeleted != true {
                                MessageStatusView(status: message.status ?? "SENT")
                            }
                        }
                        .padding(.bottom, 6)
                        .padding(.trailing, 10)
                    }
                    .background(isMe ? Color.softSage : Color.white.opacity(0.6))
                    .background(isMe ? AnyShapeStyle(Color.clear) : AnyShapeStyle(.ultraThinMaterial))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(isMe ? Color.clear : Color.glassBorder, lineWidth: 1))
                    .shadow(color: Color.black.opacity(isMe ? 0.05 : 0.02), radius: 4, x: 0, y: 2)
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
        .offset(x: offset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let translation = value.translation.width
                    if isMe && translation < 0 {
                        offset = max(translation, -60)
                    } else if !isMe && translation > 0 {
                        offset = min(translation, 60)
                    }
                }
                .onEnded { value in
                    if abs(offset) >= 50 {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        onReply()
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        offset = 0
                    }
                }
        )
    }
    
    private func formatTime(_ timestamp: Double?) -> String {
        guard let ts = timestamp else { return "" }
        let date = Date(timeIntervalSince1970: ts / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func resolveMediaURL(_ urlString: String?) -> URL? {
        guard let urlString = urlString, !urlString.isEmpty else { return nil }
        if urlString.hasPrefix("http") {
            return URL(string: urlString)
        }
        // Fallback for relative URLs from API Gateway
        return URL(string: "http://localhost:9090/api/v1" + (urlString.hasPrefix("/") ? "" : "/") + urlString)
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
            LinearGradient(
                gradient: Gradient(colors: [Color.softBackground, Color.slateBlue.opacity(0.15)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 50))
                        .foregroundColor(Color.charcoal.opacity(0.7))
                    Text("Enterprise")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color.charcoal)
                }
                .padding(.top, 20)
                
                VStack(spacing: 20) {
                    HStack {
                        Button("Login") { isLoginMode = true }
                            .foregroundColor(isLoginMode ? Color.charcoal : .gray)
                            .font(.system(size: 15, weight: .bold))
                        Spacer()
                        Button("Register") { isLoginMode = false }
                            .foregroundColor(!isLoginMode ? Color.charcoal : .gray)
                            .font(.system(size: 15, weight: .bold))
                    }
                    .padding(.horizontal, 30)
                    
                    VStack(spacing: 12) {
                        ModernTextField(placeholder: "Username", text: $username, autoCap: .none)
                        if !isLoginMode {
                            ModernTextField(placeholder: "Email", text: $email, autoCap: .none)
                            ModernTextField(placeholder: "First Name", text: $firstName)
                            ModernTextField(placeholder: "Last Name", text: $lastName)
                        }
                        ModernTextField(placeholder: "Password", text: $password, isSecure: true)
                    }
                    .padding(.horizontal, 20)
                    
                    if let error = errorMessage {
                        Text(error).foregroundColor(.red).font(.system(size: 11)).padding(.horizontal)
                    }
                    
                    Button(action: handleAction) {
                        if isLoading { ProgressView().tint(.white) }
                        else { Text(isLoginMode ? "Sign In" : "Sign Up").font(.system(size: 16, weight: .bold)) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.softSage)
                    .foregroundColor(.white)
                    .cornerRadius(25)
                    .padding(.horizontal, 20)
                    .shadow(color: Color.softSage.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding(.vertical, 30)
                .background(.ultraThinMaterial)
                .cornerRadius(35)
                .overlay(RoundedRectangle(cornerRadius: 35).stroke(Color.glassBorder, lineWidth: 1))
                .shadow(color: Color.black.opacity(0.05), radius: 25, x: 0, y: 10)
                .padding(.horizontal, 20)
                
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
        .padding(14)
        .background(Color.white.opacity(0.6))
        .cornerRadius(25)
        .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.glassBorder, lineWidth: 1))
    }
}

extension Color {
    static let softBackground = Color(hex: "F7F8FA")
    static let softSage = Color(hex: "A3B19B")
    static let slateBlue = Color(hex: "A9B5C2")
    static let charcoal = Color(hex: "2F3E46")
    static let glassBorder = Color.white.opacity(0.5)

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




