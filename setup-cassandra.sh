#!/bin/bash

# Cassandra Hazırlık Scripti
# Bu script Cassandra'nın hazır olmasını bekler ve chat_keyspace'i oluşturur.

echo "⏳ Cassandra'nın hazır olması bekleniyor (localhost:9042)..."
until nc -z localhost 9042; do
  sleep 2
done

echo "📦 chat_keyspace oluşturuluyor..."
docker exec cassandra-db cqlsh -e "CREATE KEYSPACE IF NOT EXISTS chat_keyspace WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};"

echo "📝 messages tablosu oluşturuluyor..."
docker exec cassandra-db cqlsh -e "
USE chat_keyspace;
CREATE TABLE IF NOT EXISTS messages (
    chat_id text,
    message_id uuid,
    sender_id text,
    content text,
    timestamp timestamp,
    status text,
    is_edited boolean,
    is_deleted boolean,
    reply_to_id uuid,
    media_url text,
    media_type text,
    PRIMARY KEY (chat_id, message_id)
) WITH CLUSTERING ORDER BY (message_id DESC);"

echo "✅ Cassandra hazırlığı tamamlandı!"
