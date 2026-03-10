#!/bin/bash

# Keycloak Hazırlık Scripti
# Bu script Keycloak'ın hazır olmasını bekler, chat-realm'i ve ios-client'ı oluşturur.

echo "⏳ Keycloak'ın hazır olması bekleniyor (http://localhost:8080)..."
until curl -s http://localhost:8080 > /dev/null; do
  sleep 2
done

echo "🔑 Admin Token alınıyor..."
TOKEN=$(curl -s -X POST http://localhost:8080/realms/master/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r .access_token)

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
  echo "❌ Hata: Admin token alınamadı. Keycloak admin:admin kullanıcı adı/şifresiyle çalışıyor mu?"
  exit 1
fi

echo "🌍 chat-realm oluşturuluyor (varsa atlanır)..."
EXISTING_REALM=$(curl -s -X GET http://localhost:8080/admin/realms/chat-realm \
  -H "Authorization: Bearer $TOKEN" | jq -r .realm)

if [ "$EXISTING_REALM" != "chat-realm" ]; then
  curl -s -X POST http://localhost:8080/admin/realms \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "realm": "chat-realm",
      "enabled": true
    }'
  echo "✅ chat-realm oluşturuldu."
else
  echo "ℹ️ chat-realm zaten mevcut."
fi

echo "📱 ios-client oluşturuluyor (varsa atlanır)..."
EXISTING_CLIENT=$(curl -s -X GET http://localhost:8080/admin/realms/chat-realm/clients?clientId=ios-client \
  -H "Authorization: Bearer $TOKEN" | jq -r '.[0].clientId')

if [ "$EXISTING_CLIENT" != "ios-client" ]; then
  curl -s -X POST http://localhost:8080/admin/realms/chat-realm/clients \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "clientId": "ios-client",
      "enabled": true,
      "publicClient": true,
      "directAccessGrantsEnabled": true,
      "webOrigins": ["*"],
      "redirectUris": ["*"]
    }'
  echo "✅ ios-client oluşturuldu."
else
  echo "ℹ️ ios-client zaten mevcut."
fi

echo "✅ Keycloak hazırlığı tamamlandı! Artık backend servislerini başlatabilirsiniz."
