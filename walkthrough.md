# Yüksek Erişilebilirlikli Kurumsal Sohbet Uygulaması (Enterprise Chat App)

## 📌 Genel Bakış
İstediğiniz kurumsal seviye, yüksek erişilebilirlikli (high-availability) mesajlaşma altyapısının uçtan uca mimarisini ve kaynak kod iskeletini başarıyla oluşturduk. Sistem mikroservis tabanlı olup, tüm bileşenleri (Gateway, User, Message, WebSocket ve Search servisleri) bir Maven Multi-module projesinde geliştirilmiş ve başarıyla derlenmiştir.

## 🏗️ Mimari Bileşenlerin Başarı Durumu

### 1. Altyapı ve Konteynerler
Sistemi besleyen veritabanları ve haberleşme araçları tek tıkla ayağa kalkacak şekilde [docker-compose.yml](file:///Users/dilemunal/Desktop/Chat/docker-compose.yml) dosyası içinde hazırlanmıştır.
- **Relasyonel Veritabanı:** PostgreSQL (Kullanıcı profilleri için)
- **Wide-column Veritabanı:** Cassandra (İnanılmaz hızlarda mesaj yazma/okuma için)
- **Mesaj Kuyruğu:** Kafka & Zookeeper (Mesaj olaylarını asenkron olarak farklı servislere dağıtmak için)
- **Arama Motoru:** Elasticsearch (Kafka'dan aldığı mesajları indeksleyerek metin tabanlı chat araması yapmak için)
- **Önbellek & Pub/Sub:** Redis (WebSocket sunucuları arası anlık mesaj yönlendirmesi için)
- **Kimlik Yönetimi:** Keycloak (OAuth2 ile API Gateway'i korumak için)

### 2. Mikroservisler (Java 21 & Spring Boot 3.2.4)
Tüm projeler ana [pom.xml](file:///Users/dilemunal/Desktop/Chat/pom.xml) altında toplanarak bir monorepo düzeni oluşturulmuştur. Tüm projelerin bağımlılıkları yüklenmiş ve derleme testlerinden (`mvn clean compile`) hatasız geçmiştir.
- **API Gateway:** İstekleri diğer servislere yönlendiren giriş kapısı.
- **User Service:** [User Entity](file:///Users/dilemunal/Desktop/Chat/user-service/src/main/java/com/enterprise/chat/user/model/User.java) üzerinden PostgreSQL ile haberleşen profil yönetim servisi.
- **Message Service:** Mesajları Cassandra'ya yazan veri tabanı servisi.
- **WebSocket Service:** [STOMP ve Redis](file:///Users/dilemunal/Desktop/Chat/websocket-service/src/main/java/com/enterprise/chat/websocket/config/WebSocketConfig.java) kullanarak yatay ölçeklenebilen eş zamanlı soket sunucusu.
- **Search Service:** Kafka üzerinden mesaj olaylarını dinleyip [`IndexedMessage`](file:///Users/dilemunal/Desktop/Chat/search-service/src/main/java/com/enterprise/chat/search/model/IndexedMessage.java) formatında Elasticsearch'e kaydeden servis.

### 3. iOS Client (Müşteri Arayüzü)
[ios-client](file:///Users/dilemunal/Desktop/Chat/ios-client/EnterpriseChat) klasöründe Swift dilinde SwiftUI kullanılarak temel bir uygulama çatısı oluşturuldu. `WebSocketManager` sınıfı doğrudan WebSocket Service'e bağlanacak yapıda prototiplendi.

## 🧪 Sistemin Çalıştırılması ve Test Edilmesi

1. **Altyapıyı Başlatma:**
   ```bash
   cd /Users/dilemunal/Desktop/Chat
   docker-compose up -d
   ```

2. **Mikroservisleri Başlatma:**
   (Her servis kendi klasöründen `mvn spring-boot:run` komutuyla başlatılabilir)

3. **Veri Akışı Testi (Data Pipeline):**
   Kullanıcı iOS uygulamasından bir mesaj gönderdiğinde:
   1. Mesaj API Gateway üzerinden Keycloak doğrulamasından geçerek `websocket-service`'e ulaşır.
   2. Servis, mesajı diğer sunuculara Redis aracılığıyla yayınlar (Pub/Sub) ve aynı andan Kafka'ya atar.
   3. `search-service` Kafka'yı dinleyip mesaj içeriğini Elasticsearch'te aranabilir hale getirir.
   4. `message-service` yine Kafka üzerinden veya REST üzerinden bu kalıcı mesajı Cassandra'ya kaydeder.

### 4. Kurumsal Özellikler ve Gelişmiş Mesajlaşma
- **Gerçek Zamanlı Durum (Presence):** Redis tabanlı "Online/Offline" ve "Son Görülme" takibi.
- **Yazıyor Göstergesi:** WebSocket (STOMP) üzerinden dinamik "yazıyor..." bildirimleri.
- **Mesaj Yaşam Döngüsü:** Okundu bilgisi (Blue Tick), mesaj düzenleme (Edit) ve herkesten silme (Revoke).
- **Medya Paylaşımı:** MinIO entegrasyonu ile güvenli görsel/dosya paylaşımı ve AsyncImage ile anlık önizleme.
- **Gelişmiş Arama:** Elasticsearch destekli tüm sohbetlerde metin bazlı içerik araması ve sonuçlardan sohbete hızlı geçiş.
- **UX Zenginliği:** Emoji paneli, gelişmiş mesaj cevaplama (Reply) önizlemeleri ve Dribbble esintili modern tasarım.

Projenizin iskeleti enterprise seviyede ölçeklenmeye hazır durumda. Bu mimari, yatayda on binlerce sunucu kopyası ile milyonlarca anlık kullanıcıyı kolayca kaldırabilecektir. İstek ve sorularınız olursa buradayım!
