package com.enterprise.chat.websocket.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    @Override
    public void configureMessageBroker(@org.springframework.lang.NonNull MessageBrokerRegistry config) {
        config.enableSimpleBroker("/topic", "/queue");
        config.setApplicationDestinationPrefixes("/app");
        config.setUserDestinationPrefix("/user");
    }

    @Override
    public void registerStompEndpoints(@org.springframework.lang.NonNull StompEndpointRegistry registry) {
        registry.addEndpoint("/ws")
                .setAllowedOriginPatterns("*")
                .addInterceptors(new org.springframework.web.socket.server.support.HttpSessionHandshakeInterceptor() {
                    @Override
                    public boolean beforeHandshake(@org.springframework.lang.NonNull org.springframework.http.server.ServerHttpRequest request,
                                                  @org.springframework.lang.NonNull org.springframework.http.server.ServerHttpResponse response,
                                                  @org.springframework.lang.NonNull org.springframework.web.socket.WebSocketHandler wsHandler,
                                                  @org.springframework.lang.NonNull java.util.Map<String, Object> attributes) throws Exception {
                        if (request instanceof org.springframework.http.server.ServletServerHttpRequest) {
                            String query = request.getURI().getQuery();
                            if (query != null && query.contains("username=")) {
                                String username = query.split("username=")[1].split("&")[0];
                                attributes.put("username", username);
                            }
                        }
                        return super.beforeHandshake(request, response, wsHandler, attributes);
                    }
                })
                .withSockJS();
                
        // Native direct WebSocket for iOS/Android clients
        registry.addEndpoint("/ws-native")
                .setAllowedOriginPatterns("*")
                .addInterceptors(new org.springframework.web.socket.server.support.HttpSessionHandshakeInterceptor() {
                    @Override
                    public boolean beforeHandshake(@org.springframework.lang.NonNull org.springframework.http.server.ServerHttpRequest request,
                                                  @org.springframework.lang.NonNull org.springframework.http.server.ServerHttpResponse response,
                                                  @org.springframework.lang.NonNull org.springframework.web.socket.WebSocketHandler wsHandler,
                                                  @org.springframework.lang.NonNull java.util.Map<String, Object> attributes) throws Exception {
                        if (request instanceof org.springframework.http.server.ServletServerHttpRequest) {
                            String query = request.getURI().getQuery();
                            if (query != null && query.contains("username=")) {
                                String username = query.split("username=")[1].split("&")[0];
                                attributes.put("username", username);
                            }
                        }
                        return super.beforeHandshake(request, response, wsHandler, attributes);
                    }
                });
    }
}
